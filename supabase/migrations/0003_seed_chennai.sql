-- =====================================================================
-- 0003: Seed Chennai EV Infrastructure & Default Profiles
-- =====================================================================

-- Ensure demo profiles exist if auth users are created
-- Note: In production Supabase, users are created via GoTrue auth.
-- This script provides seed records and helper functions for Chennai stations.

-- Insert Chennai Charging Stations
do $$
declare
  v_host_id uuid;
  v_ch1 uuid := '11111111-1111-1111-1111-111111111101'::uuid;
  v_ch2 uuid := '11111111-1111-1111-1111-111111111102'::uuid;
  v_ch3 uuid := '11111111-1111-1111-1111-111111111103'::uuid;
  v_ch4 uuid := '11111111-1111-1111-1111-111111111104'::uuid;
  v_ch5 uuid := '11111111-1111-1111-1111-111111111105'::uuid;
  v_ch6 uuid := '11111111-1111-1111-1111-111111111106'::uuid;
  d int;
begin
  -- Find any host or use a system fallback profile
  select id into v_host_id from profiles where role = 'host' limit 1;

  if v_host_id is not null then
    -- 1. Anna Nagar West
    insert into chargers (id, host_id, title, description, address, area_label, location, timezone, tier_code, connector, rules, status)
    values (
      v_ch1, v_host_id,
      'GreenDrive 7.4 kW Wallbox - Anna Nagar',
      'Dedicated covered parking slot with 7.4 kW smart AC charger. CCTV protected with 24/7 security.',
      'Plot 104, 2nd Avenue, Anna Nagar West, Chennai, Tamil Nadu 600040',
      'Anna Nagar, Chennai',
      ST_SetSRID(ST_MakePoint(80.2101, 13.0850), 4326)::geography,
      'Asia/Kolkata', 'AC_7', 'type2',
      'Please park strictly within the marked EV bay. Do not yank cable.',
      'active'
    ) on conflict (id) do nothing;

    -- 2. OMR Sholinganallur
    insert into chargers (id, host_id, title, description, address, area_label, location, timezone, tier_code, connector, rules, status)
    values (
      v_ch2, v_host_id,
      'Solar 22 kW Fast AC Point - OMR Corridor',
      'High speed 22 kW AC 3-phase charger powered by rooftop solar in Sholinganallur IT hub.',
      'Elcot SEZ, Rajiv Gandhi Salai (OMR), Sholinganallur, Chennai, Tamil Nadu 600119',
      'OMR Sholinganallur, Chennai',
      ST_SetSRID(ST_MakePoint(80.2279, 12.9010), 4326)::geography,
      'Asia/Kolkata', 'AC_22', 'type2',
      'Gate security entry code provided upon paid booking confirmation.',
      'active'
    ) on conflict (id) do nothing;

    -- 3. T. Nagar Central
    insert into chargers (id, host_id, title, description, address, area_label, location, timezone, tier_code, connector, rules, status)
    values (
      v_ch3, v_host_id,
      'EcoCharge 11 kW Point - T. Nagar Central',
      'Prime shopping district charging. Clean restroom access, air conditioning lounge & cafes nearby.',
      '42 Usman Road, T. Nagar, Chennai, Tamil Nadu 600017',
      'T. Nagar, Chennai',
      ST_SetSRID(ST_MakePoint(80.2341, 13.0418), 4326)::geography,
      'Asia/Kolkata', 'AC_7', 'type2',
      'Valet assist available. 15-minute grace period before overstay fees.',
      'active'
    ) on conflict (id) do nothing;

    -- 4. Guindy Kathipara
    insert into chargers (id, host_id, title, description, address, area_label, location, timezone, tier_code, connector, rules, status)
    values (
      v_ch4, v_host_id,
      'Kathipara Hub - 30 kW CCS2 DC Fast Charger',
      'Commercial grade DC fast charging station next to Kathipara junction & Guindy Metro station.',
      'SIDCO Industrial Estate, Guindy, Chennai, Tamil Nadu 600032',
      'Guindy, Chennai',
      ST_SetSRID(ST_MakePoint(80.2025, 13.0067), 4326)::geography,
      'Asia/Kolkata', 'DC_30', 'ccs2',
      'High voltage DC fast charger. Follow screen instructions carefully.',
      'active'
    ) on conflict (id) do nothing;

    -- 5. Besant Nagar Beach
    insert into chargers (id, host_id, title, description, address, area_label, location, timezone, tier_code, connector, rules, status)
    values (
      v_ch5, v_host_id,
      'Elliot Beach 3.3 kW 16A Overnight Socket',
      'Safe 16A socket with RCCB & earthing protection near Besant Nagar beach. Perfect for overnight charging.',
      'Beach Road, Besant Nagar, Chennai, Tamil Nadu 600090',
      'Besant Nagar, Chennai',
      ST_SetSRID(ST_MakePoint(80.2667, 13.0003), 4326)::geography,
      'Asia/Kolkata', 'AC_3', 'three_pin',
      'Please carry your own 16A portable charging box.',
      'active'
    ) on conflict (id) do nothing;

    -- 6. Velachery Bypass
    insert into chargers (id, host_id, title, description, address, area_label, location, timezone, tier_code, connector, rules, status)
    values (
      v_ch6, v_host_id,
      'Phoenix Bay 7.4 kW Wallbox - Velachery',
      'Convenient charging right off Velachery Bypass Road, close to Grand Square & Phoenix Marketcity.',
      '142 Velachery Bypass Road, Velachery, Chennai, Tamil Nadu 600042',
      'Velachery, Chennai',
      ST_SetSRID(ST_MakePoint(80.2212, 12.9759), 4326)::geography,
      'Asia/Kolkata', 'AC_7', 'type2',
      'Covered bay with lighting.',
      'active'
    ) on conflict (id) do nothing;

    -- Set secrets
    insert into charger_secrets (charger_id, checkin_code) values
      (v_ch1, 'ANNA74KW'),
      (v_ch2, 'OMR22KW'),
      (v_ch3, 'TNAGAR11KW'),
      (v_ch4, 'GUINDY30KW'),
      (v_ch5, 'BESANT33KW'),
      (v_ch6, 'VELACH74KW')
    on conflict (charger_id) do nothing;

    -- Set 24/7 availability for all 7 days
    for d in 0..6 loop
      insert into charger_availability (charger_id, day_of_week, start_time, end_time)
      values
        (v_ch1, d, '00:00', '24:00'),
        (v_ch2, d, '00:00', '24:00'),
        (v_ch3, d, '00:00', '24:00'),
        (v_ch4, d, '00:00', '24:00'),
        (v_ch5, d, '00:00', '24:00'),
        (v_ch6, d, '00:00', '24:00')
      on conflict do nothing;
    end loop;
  end if;
end $$;
