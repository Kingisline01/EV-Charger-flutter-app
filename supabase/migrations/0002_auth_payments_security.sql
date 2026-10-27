-- =====================================================================
-- 0002: ChargeShare Security Hardening, Payments, Refunds & Privacy
-- =====================================================================
create extension if not exists pg_net;

-- ---------- 1. PAYMENTS: support dues, user ownership, partial refunds ----------
alter table payments alter column booking_id drop not null;
alter table payments add column if not exists user_id uuid references profiles(id);
alter table payments add column if not exists kind text not null default 'booking'
  check (kind in ('booking', 'dues'));
alter table payments add column if not exists refunded_amount numeric(10,2) not null default 0;
alter table payments drop constraint if exists payments_kind_booking_chk;
alter table payments add constraint payments_kind_booking_chk
  check (kind = 'dues' or booking_id is not null);

update payments p set user_id = b.driver_id
  from bookings b where b.id = p.booking_id and p.user_id is null;
create index if not exists payments_user_idx on payments (user_id, created_at desc);

drop policy if exists "own payments" on payments;
create policy "own payments" on payments for select to authenticated
  using (user_id = auth.uid());

-- ---------- 2. REFUNDS QUEUE ----------
create table if not exists refunds (
  id                 uuid primary key default gen_random_uuid(),
  payment_id         uuid not null references payments(id),
  booking_id         uuid references bookings(id),
  amount             numeric(10,2) not null check (amount > 0),
  reason             text,
  status             text not null default 'pending'
                     check (status in ('pending', 'processing', 'done', 'failed')),
  attempts           int not null default 0,
  provider_refund_id text,
  last_error         text,
  created_at         timestamptz not null default now(),
  processed_at       timestamptz
);
create index if not exists refunds_status_idx on refunds (status, created_at);
alter table refunds enable row level security;
drop policy if exists "own refunds" on refunds;
create policy "own refunds" on refunds for select to authenticated
  using (exists (select 1 from payments p where p.id = payment_id and p.user_id = auth.uid()));
revoke insert, update, delete on refunds from authenticated;

-- queue a refund automatically whenever a booking asks for one
create or replace function queue_booking_refund() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_pay payments;
begin
  if new.refund_status = 'pending' and old.refund_status is distinct from 'pending'
     and new.refund_amount > 0 then
    select * into v_pay from payments
     where booking_id = new.id and kind = 'booking' and status = 'paid'
     order by paid_at desc limit 1;
    if found then
      insert into refunds (payment_id, booking_id, amount, reason)
      values (v_pay.id, new.id, least(new.refund_amount, v_pay.amount), 'booking_' || new.status);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_queue_refund on bookings;
create trigger trg_queue_refund after update of refund_status on bookings
  for each row execute function queue_booking_refund();

-- claim a batch for processing (safe under concurrency)
create or replace function claim_refunds(p_limit int default 20)
returns setof refunds language plpgsql security definer set search_path = public as $$
begin
  return query
  update refunds r set status = 'processing', attempts = r.attempts + 1
   where r.id in (select id from refunds
                   where status = 'pending' and attempts < 5
                   order by created_at limit p_limit
                   for update skip locked)
  returning r.*;
end $$;

create or replace function finish_refund(p_refund uuid, p_ok boolean, p_provider_refund_id text, p_error text)
returns void language plpgsql security definer set search_path = public as $$
declare r refunds;
begin
  select * into r from refunds where id = p_refund for update;
  if not found then return; end if;
  if p_ok then
    update refunds set status = 'done', provider_refund_id = p_provider_refund_id,
           processed_at = now(), last_error = null where id = p_refund;
    update payments set refunded_amount = refunded_amount + r.amount where id = r.payment_id;
    update bookings set refund_status = 'done' where id = r.booking_id and refund_status <> 'done';
  else
    update refunds set status = case when attempts >= 5 then 'failed' else 'pending' end,
           last_error = left(p_error, 500) where id = p_refund;
  end if;
end $$;

-- ---------- 3. PAYMENT CONFIRMATION (idempotent; order-id based) ----------
drop function if exists confirm_booking_payment(uuid, text, numeric);

create or replace function confirm_payment(p_order_id text, p_payment_id text, p_amount numeric default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare pay payments;
begin
  select * into pay from payments where provider_order_id = p_order_id for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'unknown_order'); end if;
  if pay.status = 'paid' then return jsonb_build_object('ok', true, 'already', true); end if;
  if pay.status <> 'created' then return jsonb_build_object('ok', false, 'reason', pay.status::text); end if;
  if p_amount is not null and p_amount <> pay.amount then
    return jsonb_build_object('ok', false, 'reason', 'amount_mismatch');
  end if;

  update payments set status = 'paid', provider_payment_id = p_payment_id, paid_at = now()
   where id = pay.id;

  if pay.kind = 'dues' then
    update profiles set outstanding_due = greatest(outstanding_due - pay.amount, 0) where id = pay.user_id;
  else
    update bookings set status = 'confirmed' where id = pay.booking_id and status = 'pending_payment';
    if not found then
      -- paid after hold expired / booking cancelled: refund everything
      insert into refunds (payment_id, booking_id, amount, reason)
      values (pay.id, pay.booking_id, pay.amount, 'paid_after_expiry');
      return jsonb_build_object('ok', false, 'reason', 'booking_expired_refund_queued');
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ---------- 4. ANTI-ABUSE: slot hoarding & payout KYC ----------
create or replace function enforce_booking_limits() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from bookings
       where driver_id = new.driver_id and status = 'pending_payment') >= 3 then
    raise exception 'too_many_pending';
  end if;
  if (select count(*) from bookings
       where driver_id = new.driver_id and status in ('confirmed', 'active')) >= 10 then
    raise exception 'too_many_upcoming';
  end if;
  return new;
end $$;

drop trigger if exists trg_booking_limits on bookings;
create trigger trg_booking_limits before insert on bookings
  for each row execute function enforce_booking_limits();

create or replace function require_kyc_for_payout() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = new.host_id and kyc_status = 'verified') then
    raise exception 'kyc_required';
  end if;
  return new;
end $$;

drop trigger if exists trg_payout_kyc on payouts;
create trigger trg_payout_kyc before insert on payouts
  for each row execute function require_kyc_for_payout();

-- ---------- 5. PRIVACY: no exact address/coordinates before a paid booking ----------
alter table chargers add column if not exists area_label text;

drop policy if exists "read chargers" on chargers;
drop policy if exists "host reads own chargers" on chargers;
create policy "host reads own chargers" on chargers for select to authenticated
  using (host_id = auth.uid());
grant insert (area_label) on chargers to authenticated;
grant update (area_label) on chargers to authenticated;

drop function if exists nearby_chargers(double precision, double precision, integer,
                                        timestamptz, timestamptz, connector_type);

create or replace function nearby_chargers(
  p_lat double precision, p_lng double precision, p_radius_m integer default 5000,
  p_start timestamptz default null, p_end timestamptz default null,
  p_connector connector_type default null
) returns table (
  id uuid, title text, area_label text, lat double precision, lng double precision,
  distance_m double precision, tier_code text, power_kw numeric, price_per_hour numeric,
  connector connector_type, rating_avg numeric, rating_count int, host_name text
) language sql stable security definer set search_path = public, extensions as $$
  select c.id, c.title, c.area_label,
         ST_Y(ST_SnapToGrid(c.location::geometry, 0.002)),     -- ~200 m grid: approximate pin only
         ST_X(ST_SnapToGrid(c.location::geometry, 0.002)),
         round(ST_Distance(c.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography) / 100) * 100,
         c.tier_code, t.power_kw, t.price_per_hour, c.connector,
         c.rating_avg, c.rating_count, p.full_name
  from chargers c
  join charger_tiers t on t.code = c.tier_code
  join profiles p on p.id = c.host_id
  where c.status = 'active' and not c.is_paused
    and ST_DWithin(c.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
                   least(p_radius_m, 25000))
    and (p_connector is null or c.connector = p_connector)
    and (p_start is null or p_end is null or (
          is_within_availability(c.id, p_start, p_end)
          and not exists (select 1 from bookings b
                           where b.charger_id = c.id
                             and b.status in ('pending_payment','confirmed','active','completed')
                             and b.during && tstzrange(p_start, p_end))
          and not exists (select 1 from charger_blocks k
                           where k.charger_id = c.id and k.during && tstzrange(p_start, p_end))))
  order by 6
  limit 50;
$$;

create or replace function get_charger_public(p_id uuid)
returns table (
  id uuid, title text, description text, area_label text, lat double precision, lng double precision,
  tier_code text, power_kw numeric, price_per_hour numeric, connector connector_type,
  photos text[], rules text, rating_avg numeric, rating_count int, host_name text
) language sql stable security definer set search_path = public, extensions as $$
  select c.id, c.title, c.description, c.area_label,
         ST_Y(ST_SnapToGrid(c.location::geometry, 0.002)), ST_X(ST_SnapToGrid(c.location::geometry, 0.002)),
         c.tier_code, t.power_kw, t.price_per_hour, c.connector, c.photos, c.rules,
         c.rating_avg, c.rating_count, p.full_name
  from chargers c
  join charger_tiers t on t.code = c.tier_code
  join profiles p on p.id = c.host_id
  where c.id = p_id and c.status = 'active' and not c.is_paused;
$$;

-- exact address + host phone: ONLY for the driver of a paid (confirmed/active) booking
create or replace function get_booking_location(p_booking uuid)
returns table (address text, lat double precision, lng double precision, host_name text, host_phone text)
language sql stable security definer set search_path = public, extensions as $$
  select c.address, ST_Y(c.location::geometry), ST_X(c.location::geometry), p.full_name, p.phone
  from bookings b
  join chargers c on c.id = b.charger_id
  join profiles p on p.id = c.host_id
  where b.id = p_booking and b.driver_id = auth.uid() and b.status in ('confirmed', 'active');
$$;

-- driver's own bookings with charger info (address only once paid)
create or replace view driver_bookings as
select b.id, b.charger_id, c.title as charger_title, c.area_label, b.status,
       lower(b.during) as start_at, upper(b.during) as end_at, b.hours,
       b.base_amount, b.driver_fee, b.total_amount, b.final_base_amount,
       b.overstay_amount, b.refund_amount, b.refund_status, b.started_at, b.ended_at,
       b.created_at,
       case when b.status in ('confirmed', 'active') then c.address end as address
from bookings b join chargers c on c.id = b.charger_id
where b.driver_id = auth.uid();

-- profiles: only people you actually interact with (or active hosts) are visible
create or replace view public_profiles as
select p.id, p.full_name, p.avatar_url, p.rating_avg, p.rating_count, p.role
from profiles p
where p.id = auth.uid()
   or exists (select 1 from chargers c where c.host_id = p.id and c.status = 'active')
   or exists (select 1 from bookings b join chargers c on c.id = b.charger_id
               where (b.driver_id = p.id and c.host_id = auth.uid())
                  or (c.host_id = p.id and b.driver_id = auth.uid()));

-- ---------- 6. PRIVILEGES: deny by default, grant explicitly ----------
-- 6a. anon (not logged in) gets nothing in public
revoke all on all tables    in schema public from anon;
revoke all on all functions in schema public from anon;
alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on functions from anon;

-- 6b. logged-in users: no TRUNCATE / REFERENCES / TRIGGER anywhere
revoke truncate, references, trigger on all tables in schema public from authenticated;

-- 6c. views: authenticated only
revoke all on public_profiles, driver_bookings from anon, public;
grant select on public_profiles, driver_bookings to authenticated;

-- 6d. internal functions: nobody on the API may call them
revoke execute on function
  setting_num(text),
  is_within_availability(uuid, timestamptz, timestamptz),
  handle_new_user(),
  create_charger_secret(),
  queue_booking_refund(),
  enforce_booking_limits(),
  require_kyc_for_payout(),
  expire_pending_bookings(),
  mark_no_shows(),
  settle_due_bookings(),
  claim_refunds(int),
  finish_refund(uuid, boolean, text, text),
  confirm_payment(text, text, numeric)
from public, anon, authenticated;

grant execute on function
  claim_refunds(int),
  finish_refund(uuid, boolean, text, text),
  confirm_payment(text, text, numeric)
to service_role;

-- 6e. client RPCs: logged-in users only
revoke execute on function
  quote_booking(uuid, timestamptz, timestamptz),
  nearby_chargers(double precision, double precision, integer, timestamptz, timestamptz, connector_type),
  get_charger_public(uuid),
  get_booking_location(uuid),
  get_busy_slots(uuid, timestamptz, timestamptz),
  create_booking(uuid, uuid, timestamptz, timestamptz),
  start_session(uuid, text),
  end_session(uuid),
  cancel_booking(uuid, text),
  raise_dispute(uuid, text),
  submit_review(uuid, integer, text),
  request_payout(numeric, text)
from public, anon;

grant execute on function
  quote_booking(uuid, timestamptz, timestamptz),
  nearby_chargers(double precision, double precision, integer, timestamptz, timestamptz, connector_type),
  get_charger_public(uuid),
  get_booking_location(uuid),
  get_busy_slots(uuid, timestamptz, timestamptz),
  create_booking(uuid, uuid, timestamptz, timestamptz),
  start_session(uuid, text),
  end_session(uuid),
  cancel_booking(uuid, text),
  raise_dispute(uuid, text),
  submit_review(uuid, integer, text),
  request_payout(numeric, text)
to authenticated;
