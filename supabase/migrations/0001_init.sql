-- ===== 0. EXTENSIONS =====
create extension if not exists postgis;
create extension if not exists btree_gist;   -- needed for the double-booking exclusion constraint
create extension if not exists pg_cron;      -- if this errors: Dashboard > Database > Extensions > enable pg_cron

-- ===== 1. ENUMS =====
create type user_role        as enum ('driver', 'host', 'admin');
create type charger_status   as enum ('pending_verification', 'active', 'rejected');
create type connector_type   as enum ('type1', 'type2', 'ccs2', 'chademo', 'gbt', 'three_pin', 'other');
create type booking_status   as enum (
  'pending_payment', 'confirmed', 'active', 'completed',
  'cancelled_by_driver', 'cancelled_by_host', 'expired', 'disputed'
);
create type payment_status   as enum ('created', 'paid', 'failed', 'refund_pending', 'refunded');
create type payout_status    as enum ('requested', 'processing', 'paid', 'failed');

-- ===== 2. PLATFORM SETTINGS (editable by admin only) =====
create table platform_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

insert into platform_settings (key, value) values
  ('currency',                    '"INR"'),
  ('host_commission_pct',         '15'),
  ('driver_fee_pct',              '5'),
  ('driver_fee_min',              '5'),
  ('slot_minutes',                '30'),
  ('min_booking_minutes',         '30'),
  ('max_booking_minutes',         '720'),
  ('pending_payment_ttl_minutes', '10'),
  ('free_cancel_hours',           '2'),
  ('late_cancel_fee_pct',         '30'),
  ('overstay_multiplier',         '1.5'),
  ('overstay_grace_minutes',      '10'),
  ('dispute_window_hours',        '24'),
  ('min_payout',                  '200'),
  ('checkin_early_minutes',       '15');

create or replace function setting_num(k text) returns numeric
language sql stable as $$
  select (value #>> '{}')::numeric from platform_settings where key = k
$$;

-- ===== 3. PROFILES (1:1 with auth.users) =====
create table profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  role            user_role not null default 'driver',
  full_name       text not null default '',
  phone           text,
  avatar_url      text,
  kyc_status      text not null default 'none' check (kyc_status in ('none','submitted','verified','rejected')),
  rating_avg      numeric(3,2) not null default 0,
  rating_count    int not null default 0,
  strikes         int not null default 0,
  outstanding_due numeric(10,2) not null default 0,   -- unpaid overstay fees (driver)
  created_at      timestamptz not null default now()
);

create table vehicles (
  id           uuid primary key default gen_random_uuid(),
  driver_id    uuid not null references profiles(id) on delete cascade,
  make         text not null,
  model        text not null,
  connector    connector_type not null,
  battery_kwh  numeric(5,1),
  plate_number text,
  created_at   timestamptz not null default now()
);

-- ===== 4. FIXED PRICING TIERS (admin-only) =====
create table charger_tiers (
  code           text primary key,
  label          text not null,
  power_kw       numeric(5,1) not null,
  price_per_hour numeric(10,2) not null,
  price_per_kwh  numeric(10,2),            -- used in v2 with metering
  is_active      boolean not null default true
);

insert into charger_tiers (code, label, power_kw, price_per_hour, price_per_kwh) values
  ('AC_3',  'AC 3.3 kW (home socket / slow)',  3.3,  55.00, 16.70),
  ('AC_7',  'AC 7.4 kW (Type 2 wallbox)',      7.4, 120.00, 16.20),
  ('AC_22', 'AC 22 kW',                       22.0, 330.00, 15.00),
  ('DC_30', 'DC 30 kW (commercial)',          30.0, 600.00, 20.00);

-- ===== 5. CHARGERS =====
create table chargers (
  id            uuid primary key default gen_random_uuid(),
  host_id       uuid not null references profiles(id) on delete cascade,
  title         text not null,
  description   text,
  address       text not null,
  location      geography(point, 4326) not null,
  timezone      text not null default 'Asia/Kolkata',  -- change for your country
  tier_code     text not null references charger_tiers(code),
  connector     connector_type not null,
  photos        text[] not null default '{}',
  rules         text,
  status        charger_status not null default 'pending_verification',
  safety_checked boolean not null default false,
  is_paused     boolean not null default false,
  rating_avg    numeric(3,2) not null default 0,
  rating_count  int not null default 0,
  created_at    timestamptz not null default now()
);
create index chargers_location_gix on chargers using gist (location);
create index chargers_host_idx on chargers (host_id);

-- secret check-in code (printed as QR). Hosts can read it; drivers cannot.
create table charger_secrets (
  charger_id   uuid primary key references chargers(id) on delete cascade,
  checkin_code text not null default substr(md5(random()::text || clock_timestamp()::text), 1, 10)
);

create or replace function create_charger_secret() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into charger_secrets (charger_id) values (new.id);
  return new;
end $$;
create trigger trg_charger_secret after insert on chargers
  for each row execute function create_charger_secret();

-- weekly recurring availability, local time of the charger. 24:00 is allowed as end_time.
create table charger_availability (
  id          uuid primary key default gen_random_uuid(),
  charger_id  uuid not null references chargers(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),  -- 0 = Sunday
  start_time  time not null,
  end_time    time not null,
  check (end_time > start_time)
);
create index charger_avail_idx on charger_availability (charger_id, day_of_week);

-- one-off blocks (host's own use, travel, maintenance)
create table charger_blocks (
  id         uuid primary key default gen_random_uuid(),
  charger_id uuid not null references chargers(id) on delete cascade,
  during     tstzrange not null,
  reason     text,
  exclude using gist (charger_id with =, during with &&)
);

-- ===== 6. BOOKINGS =====
create table bookings (
  id                 uuid primary key default gen_random_uuid(),
  charger_id         uuid not null references chargers(id),
  driver_id          uuid not null references profiles(id),
  vehicle_id         uuid references vehicles(id),
  during             tstzrange not null,
  status             booking_status not null default 'pending_payment',
  hours              numeric(6,2) not null,
  base_amount        numeric(10,2) not null,      -- what was quoted (before fees)
  driver_fee         numeric(10,2) not null,
  total_amount       numeric(10,2) not null,      -- what driver pays up front
  host_commission    numeric(10,2) not null,
  host_earning       numeric(10,2) not null,
  final_base_amount  numeric(10,2),               -- after early end
  overstay_minutes   int not null default 0,
  overstay_amount    numeric(10,2) not null default 0,
  refund_amount      numeric(10,2) not null default 0,
  refund_status      text not null default 'none' check (refund_status in ('none','pending','done')),
  no_show            boolean not null default false,
  started_at         timestamptz,
  ended_at           timestamptz,
  settled_at         timestamptz,
  cancel_reason      text,
  dispute_reason     text,
  created_at         timestamptz not null default now(),
  constraint no_overlapping_bookings
    exclude using gist (charger_id with =, during with &&)
    where (status in ('pending_payment','confirmed','active','completed'))
);
create index bookings_driver_idx  on bookings (driver_id, created_at desc);
create index bookings_charger_idx on bookings (charger_id, created_at desc);
create index bookings_status_idx  on bookings (status);

-- ===== 7. PAYMENTS, WALLET, PAYOUTS, REVIEWS =====
create table payments (
  id                   uuid primary key default gen_random_uuid(),
  booking_id           uuid not null references bookings(id),
  provider             text not null default 'razorpay',
  provider_order_id    text unique,
  provider_payment_id  text,
  amount               numeric(10,2) not null,
  currency             text not null default 'INR',
  status               payment_status not null default 'created',
  created_at           timestamptz not null default now(),
  paid_at              timestamptz
);
create index payments_booking_idx on payments (booking_id);

create table wallets (
  user_id uuid primary key references profiles(id) on delete cascade,
  balance numeric(12,2) not null default 0 check (balance >= 0)
);

create table wallet_transactions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references profiles(id),
  booking_id    uuid references bookings(id),
  kind          text not null check (kind in ('earning','payout','adjustment')),
  amount        numeric(12,2) not null,           -- signed
  balance_after numeric(12,2) not null,
  note          text,
  created_at    timestamptz not null default now()
);
create index wtx_user_idx on wallet_transactions (user_id, created_at desc);

create table payouts (
  id           uuid primary key default gen_random_uuid(),
  host_id      uuid not null references profiles(id),
  amount       numeric(12,2) not null,
  upi_id       text,
  bank_details text,
  status       payout_status not null default 'requested',
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  reference    text
);

create table reviews (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references bookings(id),
  reviewer_id uuid not null references profiles(id),
  reviewee_id uuid not null references profiles(id),
  rating      smallint not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  unique (booking_id, reviewer_id)
);

-- ===== 8. NEW USER => PROFILE + WALLET =====
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_role user_role;
begin
  v_role := case when new.raw_user_meta_data->>'role' = 'host'
                 then 'host'::user_role else 'driver'::user_role end;
  insert into profiles (id, role, full_name)
  values (new.id, v_role, coalesce(new.raw_user_meta_data->>'full_name', ''));
  insert into wallets (user_id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

create view public_profiles as
  select id, full_name, avatar_url, rating_avg, rating_count, role from profiles;

-- ===== 9. AVAILABILITY CHECK =====
create or replace function is_within_availability(p_charger uuid, p_start timestamptz, p_end timestamptz)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_tz text; v_ls timestamp; v_le timestamp; v_end_t time;
begin
  select timezone into v_tz from chargers where id = p_charger;
  v_ls := p_start at time zone v_tz;
  v_le := p_end   at time zone v_tz;
  if v_le::date = v_ls::date then
    v_end_t := v_le::time;
  elsif v_le = (v_ls::date + 1)::timestamp then
    v_end_t := time '24:00';
  else
    return false;
  end if;
  return exists (
    select 1 from charger_availability a
    where a.charger_id = p_charger
      and a.day_of_week = extract(dow from v_ls)::int
      and a.start_time <= v_ls::time
      and a.end_time   >= v_end_t
  );
end $$;

-- ===== 10. QUOTE =====
create or replace function quote_booking(p_charger uuid, p_start timestamptz, p_end timestamptz)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_rate numeric; v_hours numeric; v_base numeric; v_dfee numeric; v_comm numeric;
begin
  select t.price_per_hour into v_rate
  from chargers c join charger_tiers t on t.code = c.tier_code where c.id = p_charger;
  if v_rate is null then raise exception 'charger_not_found'; end if;

  v_hours := extract(epoch from (p_end - p_start)) / 3600.0;
  v_base  := round(v_rate * v_hours, 2);
  v_dfee  := greatest(round(v_base * setting_num('driver_fee_pct') / 100, 2), setting_num('driver_fee_min'));
  v_comm  := round(v_base * setting_num('host_commission_pct') / 100, 2);

  return jsonb_build_object(
    'hours', v_hours, 'rate', v_rate, 'base_amount', v_base,
    'driver_fee', v_dfee, 'total', v_base + v_dfee,
    'host_commission', v_comm, 'host_earning', v_base - v_comm
  );
end $$;

-- ===== 11. SEARCH =====
create or replace function nearby_chargers(
  p_lat double precision, p_lng double precision, p_radius_m int default 5000,
  p_start timestamptz default null, p_end timestamptz default null,
  p_connector connector_type default null
) returns table (
  id uuid, title text, address text, lat double precision, lng double precision,
  distance_m double precision, tier_code text, power_kw numeric, price_per_hour numeric,
  connector connector_type, rating_avg numeric, rating_count int, host_name text
) language sql stable security definer set search_path = public as $$
  select c.id, c.title, c.address,
         ST_Y(c.location::geometry), ST_X(c.location::geometry),
         ST_Distance(c.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography),
         c.tier_code, t.power_kw, t.price_per_hour, c.connector,
         c.rating_avg, c.rating_count, p.full_name
  from chargers c
  join charger_tiers t on t.code = c.tier_code
  join profiles p on p.id = c.host_id
  where c.status = 'active' and not c.is_paused
    and ST_DWithin(c.location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius_m)
    and (p_connector is null or c.connector = p_connector)
    and (p_start is null or p_end is null or (
          is_within_availability(c.id, p_start, p_end)
          and not exists (select 1 from bookings b
                          where b.charger_id = c.id
                            and b.status in ('pending_payment','confirmed','active','completed')
                            and b.during && tstzrange(p_start, p_end))
          and not exists (select 1 from charger_blocks k
                          where k.charger_id = c.id and k.during && tstzrange(p_start, p_end))
        ))
  order by 6
  limit 50;
$$;

create or replace function get_busy_slots(p_charger uuid, p_from timestamptz, p_to timestamptz)
returns table (slot_start timestamptz, slot_end timestamptz)
language sql stable security definer set search_path = public as $$
  select lower(during), upper(during) from bookings
   where charger_id = p_charger
     and status in ('pending_payment','confirmed','active','completed')
     and during && tstzrange(p_from, p_to)
  union all
  select lower(during), upper(during) from charger_blocks
   where charger_id = p_charger and during && tstzrange(p_from, p_to)
  order by 1;
$$;

-- ===== 12. CREATE BOOKING =====
create or replace function create_booking(p_charger uuid, p_vehicle uuid, p_start timestamptz, p_end timestamptz)
returns bookings language plpgsql security definer set search_path = public as $$
declare
  v_ch chargers; v_prof profiles; v_q jsonb; v_b bookings;
  v_mins numeric; v_slot int := setting_num('slot_minutes')::int; v_ls timestamp; v_le timestamp;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select * into v_prof from profiles where id = auth.uid();
  if v_prof.role <> 'driver' then raise exception 'only_drivers_can_book'; end if;
  if v_prof.outstanding_due > 0 then raise exception 'outstanding_dues'; end if;

  select * into v_ch from chargers where id = p_charger and status = 'active' and not is_paused;
  if not found then raise exception 'charger_unavailable'; end if;
  if v_ch.host_id = auth.uid() then raise exception 'cannot_book_own_charger'; end if;

  if p_start < now() then raise exception 'start_in_past'; end if;
  v_mins := extract(epoch from (p_end - p_start)) / 60;
  if v_mins < setting_num('min_booking_minutes') or v_mins > setting_num('max_booking_minutes') then
    raise exception 'invalid_duration';
  end if;

  v_ls := p_start at time zone v_ch.timezone;
  v_le := p_end   at time zone v_ch.timezone;
  if mod(extract(minute from v_ls)::int, v_slot) <> 0 or mod(extract(minute from v_le)::int, v_slot) <> 0
     or extract(second from v_ls) <> 0 or extract(second from v_le) <> 0 then
    raise exception 'not_slot_aligned';
  end if;

  if p_vehicle is not null and not exists (select 1 from vehicles where id = p_vehicle and driver_id = auth.uid()) then
    raise exception 'invalid_vehicle';
  end if;

  if not is_within_availability(p_charger, p_start, p_end) then raise exception 'outside_availability'; end if;
  if exists (select 1 from charger_blocks k where k.charger_id = p_charger and k.during && tstzrange(p_start, p_end)) then
    raise exception 'host_blocked';
  end if;

  v_q := quote_booking(p_charger, p_start, p_end);

  begin
    insert into bookings (charger_id, driver_id, vehicle_id, during, status, hours,
                          base_amount, driver_fee, total_amount, host_commission, host_earning)
    values (p_charger, auth.uid(), p_vehicle, tstzrange(p_start, p_end, '[)'), 'pending_payment',
            (v_q->>'hours')::numeric, (v_q->>'base_amount')::numeric, (v_q->>'driver_fee')::numeric,
            (v_q->>'total')::numeric, (v_q->>'host_commission')::numeric, (v_q->>'host_earning')::numeric)
    returning * into v_b;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;

  return v_b;
end $$;

-- ===== 13. START SESSION (QR check-in) =====
create or replace function start_session(p_booking uuid, p_code text)
returns bookings language plpgsql security definer set search_path = public as $$
declare b bookings; v_code text;
begin
  select * into b from bookings where id = p_booking for update;
  if not found or b.driver_id <> auth.uid() then raise exception 'forbidden'; end if;
  if b.status <> 'confirmed' then raise exception 'not_confirmed'; end if;
  if now() < lower(b.during) - make_interval(mins => setting_num('checkin_early_minutes')::int)
     or now() >= upper(b.during) then
    raise exception 'outside_checkin_window';
  end if;
  select checkin_code into v_code from charger_secrets where charger_id = b.charger_id;
  if v_code is distinct from p_code then raise exception 'wrong_code'; end if;

  update bookings set status = 'active', started_at = now() where id = b.id returning * into b;
  return b;
end $$;

-- ===== 14. END SESSION =====
create or replace function end_session(p_booking uuid)
returns bookings language plpgsql security definer set search_path = public as $$
declare
  b bookings; v_host uuid; v_rate numeric; v_slot numeric := setting_num('slot_minutes');
  v_booked_min numeric; v_used_min numeric; v_bill_min numeric;
  v_over_min numeric := 0; v_over_amt numeric := 0; v_final numeric; v_comm numeric;
begin
  select * into b from bookings where id = p_booking for update;
  if not found or b.status <> 'active' then raise exception 'session_not_active'; end if;

  select c.host_id, t.price_per_hour into v_host, v_rate
  from chargers c join charger_tiers t on t.code = c.tier_code where c.id = b.charger_id;
  if auth.uid() not in (b.driver_id, v_host) then raise exception 'forbidden'; end if;

  v_booked_min := extract(epoch from (upper(b.during) - lower(b.during))) / 60;
  v_used_min   := greatest(extract(epoch from (now() - lower(b.during))) / 60, 0);
  v_bill_min   := least(v_booked_min,
                        greatest(setting_num('min_booking_minutes'), ceil(v_used_min / v_slot) * v_slot));

  if now() > upper(b.during) + make_interval(mins => setting_num('overstay_grace_minutes')::int) then
    v_over_min := ceil(extract(epoch from (now() - upper(b.during))) / 60 / 15) * 15;
    v_over_amt := round(v_rate * v_over_min / 60 * setting_num('overstay_multiplier'), 2);
  end if;

  v_final := round(v_rate * v_bill_min / 60, 2);
  v_comm  := round((v_final + v_over_amt) * setting_num('host_commission_pct') / 100, 2);

  update bookings set
    status            = 'completed',
    ended_at          = now(),
    during            = tstzrange(lower(b.during), lower(b.during) + make_interval(mins => v_bill_min::int), '[)'),
    final_base_amount = v_final,
    overstay_minutes  = v_over_min::int,
    overstay_amount   = v_over_amt,
    host_commission   = v_comm,
    host_earning      = v_final + v_over_amt - v_comm,
    refund_amount     = greatest(b.base_amount - v_final, 0),
    refund_status     = case when b.base_amount - v_final > 0 then 'pending' else 'none' end
  where id = b.id returning * into b;

  if v_over_amt > 0 then
    update profiles set outstanding_due = outstanding_due + v_over_amt where id = b.driver_id;
  end if;
  return b;
end $$;

-- ===== 15. CANCEL BOOKING =====
create or replace function cancel_booking(p_booking uuid, p_reason text default null)
returns bookings language plpgsql security definer set search_path = public as $$
declare b bookings; v_host uuid; v_late numeric := 0; v_comm numeric := 0;
begin
  select * into b from bookings where id = p_booking for update;
  if not found then raise exception 'not_found'; end if;
  if b.status not in ('pending_payment', 'confirmed') then raise exception 'cannot_cancel'; end if;
  select host_id into v_host from chargers where id = b.charger_id;

  if auth.uid() = b.driver_id then
    if b.status = 'confirmed'
       and lower(b.during) - now() < make_interval(hours => setting_num('free_cancel_hours')::int) then
      v_late := round(b.base_amount * setting_num('late_cancel_fee_pct') / 100, 2);
    end if;
    v_comm := round(v_late * setting_num('host_commission_pct') / 100, 2);
    update bookings set
      status = 'cancelled_by_driver', ended_at = now(), cancel_reason = p_reason,
      refund_amount = case when b.status = 'confirmed' then b.total_amount - v_late else 0 end,
      refund_status = case when b.status = 'confirmed' then 'pending' else 'none' end,
      host_commission = v_comm, host_earning = v_late - v_comm
    where id = b.id returning * into b;

  elsif auth.uid() = v_host then
    update bookings set
      status = 'cancelled_by_host', ended_at = now(), cancel_reason = p_reason,
      refund_amount = case when b.status = 'confirmed' then b.total_amount else 0 end,
      refund_status = case when b.status = 'confirmed' then 'pending' else 'none' end,
      host_commission = 0, host_earning = 0
    where id = b.id returning * into b;
    update profiles set strikes = strikes + 1 where id = v_host;

  else
    raise exception 'forbidden';
  end if;
  return b;
end $$;

-- ===== 16. DISPUTE =====
create or replace function raise_dispute(p_booking uuid, p_reason text)
returns bookings language plpgsql security definer set search_path = public as $$
declare b bookings;
begin
  select * into b from bookings where id = p_booking for update;
  if not found or b.driver_id <> auth.uid() then raise exception 'forbidden'; end if;
  if b.status <> 'completed' or b.settled_at is not null
     or now() > b.ended_at + make_interval(hours => setting_num('dispute_window_hours')::int) then
    raise exception 'dispute_not_allowed';
  end if;
  update bookings set status = 'disputed', dispute_reason = p_reason where id = b.id returning * into b;
  return b;
end $$;

-- ===== 17. REVIEWS =====
create or replace function submit_review(p_booking uuid, p_rating int, p_comment text default null)
returns void language plpgsql security definer set search_path = public as $$
declare b bookings; v_host uuid; v_reviewee uuid;
begin
  select * into b from bookings where id = p_booking;
  if not found or b.status <> 'completed' then raise exception 'not_reviewable'; end if;
  select host_id into v_host from chargers where id = b.charger_id;
  if auth.uid() = b.driver_id then v_reviewee := v_host;
  elsif auth.uid() = v_host then v_reviewee := b.driver_id;
  else raise exception 'forbidden'; end if;

  insert into reviews (booking_id, reviewer_id, reviewee_id, rating, comment)
  values (p_booking, auth.uid(), v_reviewee, p_rating, p_comment);

  update profiles p set
    rating_avg   = coalesce((select round(avg(rating), 2) from reviews where reviewee_id = v_reviewee), 0),
    rating_count = (select count(*) from reviews where reviewee_id = v_reviewee)
  where p.id = v_reviewee;

  if auth.uid() = b.driver_id then
    update chargers c set
      rating_avg   = coalesce((select round(avg(r.rating), 2) from reviews r join bookings bk on bk.id = r.booking_id
                                where bk.charger_id = c.id and r.reviewer_id = bk.driver_id), 0),
      rating_count = (select count(*) from reviews r join bookings bk on bk.id = r.booking_id
                      where bk.charger_id = c.id and r.reviewer_id = bk.driver_id)
    where c.id = b.charger_id;
  end if;
end $$;

-- ===== 18. PAYOUT REQUEST (host) =====
create or replace function request_payout(p_amount numeric, p_upi text)
returns payouts language plpgsql security definer set search_path = public as $$
declare v_bal numeric; v_p payouts;
begin
  if (select role from profiles where id = auth.uid()) <> 'host' then raise exception 'only_hosts'; end if;
  if p_amount < setting_num('min_payout') then raise exception 'below_min_payout'; end if;

  update wallets set balance = balance - p_amount
   where user_id = auth.uid() and balance >= p_amount
   returning balance into v_bal;
  if not found then raise exception 'insufficient_balance'; end if;

  insert into payouts (host_id, amount, upi_id) values (auth.uid(), p_amount, p_upi) returning * into v_p;
  insert into wallet_transactions (user_id, kind, amount, balance_after, note)
  values (auth.uid(), 'payout', -p_amount, v_bal, 'Payout request ' || v_p.id);
  return v_p;
end $$;

-- ===== 19. PAYMENT CONFIRMATION =====
create or replace function confirm_booking_payment(p_booking uuid, p_provider_payment_id text, p_amount numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  update payments set status = 'paid', provider_payment_id = p_provider_payment_id, paid_at = now()
   where booking_id = p_booking and status = 'created' and amount = p_amount;
  if not found then return; end if;

  update bookings set status = 'confirmed' where id = p_booking and status = 'pending_payment';
  if not found then
    update payments set status = 'refund_pending' where booking_id = p_booking and provider_payment_id = p_provider_payment_id;
  end if;
end $$;

-- ===== 20. CRON JOBS =====
create or replace function expire_pending_bookings() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update bookings set status = 'expired'
   where status = 'pending_payment'
     and created_at < now() - make_interval(mins => setting_num('pending_payment_ttl_minutes')::int);
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function mark_no_shows() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update bookings set status = 'completed', no_show = true,
         ended_at = upper(during), final_base_amount = base_amount
   where status = 'confirmed' and upper(during) < now();
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function settle_due_bookings() returns int
language plpgsql security definer set search_path = public as $$
declare r record; v_bal numeric; n int := 0;
begin
  for r in
    select b.id, b.host_earning, c.host_id
      from bookings b join chargers c on c.id = b.charger_id
     where b.settled_at is null
       and b.host_earning > 0
       and (b.status = 'completed' or b.status = 'cancelled_by_driver')
       and b.ended_at < now() - make_interval(hours => setting_num('dispute_window_hours')::int)
     for update of b skip locked
  loop
    update wallets set balance = balance + r.host_earning where user_id = r.host_id returning balance into v_bal;
    insert into wallet_transactions (user_id, booking_id, kind, amount, balance_after, note)
    values (r.host_id, r.id, 'earning', r.host_earning, v_bal, 'Booking earning');
    update bookings set settled_at = now() where id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke execute on function confirm_booking_payment(uuid, text, numeric) from public, anon, authenticated;
revoke execute on function expire_pending_bookings()  from public, anon, authenticated;
revoke execute on function mark_no_shows()            from public, anon, authenticated;
revoke execute on function settle_due_bookings()      from public, anon, authenticated;
grant  execute on function confirm_booking_payment(uuid, text, numeric) to service_role;

select cron.schedule('expire-pending', '* * * * *',    $$select expire_pending_bookings()$$);
select cron.schedule('mark-no-shows',  '*/10 * * * *', $$select mark_no_shows()$$);
select cron.schedule('settle-bookings','*/15 * * * *', $$select settle_due_bookings()$$);

-- ===== 21. RLS =====
alter table platform_settings    enable row level security;
alter table profiles             enable row level security;
alter table vehicles             enable row level security;
alter table charger_tiers        enable row level security;
alter table chargers             enable row level security;
alter table charger_secrets      enable row level security;
alter table charger_availability enable row level security;
alter table charger_blocks       enable row level security;
alter table bookings             enable row level security;
alter table payments             enable row level security;
alter table wallets              enable row level security;
alter table wallet_transactions  enable row level security;
alter table payouts              enable row level security;
alter table reviews              enable row level security;

create policy "read settings" on platform_settings for select to authenticated using (true);
create policy "read tiers"    on charger_tiers     for select to authenticated using (true);

create policy "own profile" on profiles for select to authenticated using (id = auth.uid());
create policy "own profile update" on profiles for update to authenticated using (id = auth.uid());
revoke update on profiles from authenticated;
grant  update (full_name, phone, avatar_url) on profiles to authenticated;
grant  select on public_profiles to authenticated;

create policy "own vehicles" on vehicles for all to authenticated
  using (driver_id = auth.uid()) with check (driver_id = auth.uid());

create policy "read chargers" on chargers for select to authenticated
  using (status = 'active' or host_id = auth.uid());
create policy "host insert charger" on chargers for insert to authenticated
  with check (host_id = auth.uid()
              and exists (select 1 from profiles where id = auth.uid() and role = 'host'));
create policy "host update charger" on chargers for update to authenticated
  using (host_id = auth.uid());
revoke insert, update on chargers from authenticated;
grant insert (host_id, title, description, address, location, timezone, tier_code, connector, photos, rules)
  on chargers to authenticated;
grant update (title, description, photos, rules, is_paused) on chargers to authenticated;

create policy "host reads secret" on charger_secrets for select to authenticated
  using (exists (select 1 from chargers c where c.id = charger_id and c.host_id = auth.uid()));

create policy "read availability" on charger_availability for select to authenticated using (true);
create policy "host edits availability" on charger_availability for all to authenticated
  using (exists (select 1 from chargers c where c.id = charger_id and c.host_id = auth.uid()))
  with check (exists (select 1 from chargers c where c.id = charger_id and c.host_id = auth.uid()));

create policy "host blocks" on charger_blocks for all to authenticated
  using (exists (select 1 from chargers c where c.id = charger_id and c.host_id = auth.uid()))
  with check (exists (select 1 from chargers c where c.id = charger_id and c.host_id = auth.uid()));

create policy "booking participants" on bookings for select to authenticated
  using (driver_id = auth.uid()
         or exists (select 1 from chargers c where c.id = charger_id and c.host_id = auth.uid()));
revoke insert, update, delete on bookings from authenticated;

create policy "own payments" on payments for select to authenticated
  using (exists (select 1 from bookings b where b.id = booking_id and b.driver_id = auth.uid()));
revoke insert, update, delete on payments from authenticated;

create policy "own wallet" on wallets for select to authenticated using (user_id = auth.uid());
create policy "own wallet tx" on wallet_transactions for select to authenticated using (user_id = auth.uid());
create policy "own payouts" on payouts for select to authenticated using (host_id = auth.uid());
revoke insert, update, delete on wallets, wallet_transactions, payouts from authenticated;

create policy "read reviews" on reviews for select to authenticated using (true);
revoke insert, update, delete on reviews from authenticated;

alter publication supabase_realtime add table bookings;
