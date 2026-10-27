import 'dart:async';
import 'dart:math';

class DemoUser {
  final String id;
  final String email;
  final String role; // 'driver' | 'host'
  final String fullName;
  final String phone;
  double outstandingDue;

  DemoUser({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.phone = '+91 98765 43210',
    this.outstandingDue = 0.0,
  });
}

class DemoService {
  static final DemoService _instance = DemoService._internal();
  factory DemoService() => _instance;

  DemoService._internal() {
    _initSeed();
  }

  DemoUser? currentUser;

  // Stream controllers for realtime updates
  final _bookingStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get bookingStream => _bookingStreamController.stream;

  final List<DemoUser> users = [];
  final List<Map<String, dynamic>> chargers = [];
  final Map<String, String> secrets = {}; // charger_id -> checkin_code
  final List<Map<String, dynamic>> availability = [];
  final List<Map<String, dynamic>> blocks = [];
  final List<Map<String, dynamic>> bookings = [];
  final List<Map<String, dynamic>> vehicles = [];
  final Map<String, double> wallets = {}; // user_id -> balance
  final List<Map<String, dynamic>> transactions = [];
  final List<Map<String, dynamic>> payouts = [];
  final List<Map<String, dynamic>> reviews = [];

  void _initSeed() {
    // Seed users
    final driver = DemoUser(
      id: 'driver-001',
      email: 'driver@chargeshare.com',
      role: 'driver',
      fullName: 'Karthik Ramaswamy (EV Driver)',
      phone: '+91 98401 22334',
    );
    final host = DemoUser(
      id: 'host-001',
      email: 'host@chargeshare.com',
      role: 'host',
      fullName: 'Senthil Kumar (Host)',
      phone: '+91 94440 33445',
    );
    users.addAll([driver, host]);
    currentUser = driver;

    wallets[host.id] = 1850.0;
    wallets[driver.id] = 0.0;

    // Seed transactions for host
    transactions.addAll([
      {
        'id': 'tx-1',
        'user_id': host.id,
        'booking_id': 'bk-prev-1',
        'kind': 'earning',
        'amount': 306.0,
        'balance_after': 1850.0,
        'note': 'Booking earning (3 hrs on 7.4 kW Wallbox - Anna Nagar)',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 'tx-2',
        'user_id': host.id,
        'booking_id': 'bk-prev-0',
        'kind': 'earning',
        'amount': 1544.0,
        'balance_after': 1544.0,
        'note': 'Initial earnings balance (Chennai host)',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
    ]);

    // Seed vehicles with Tamil Nadu registrations
    vehicles.addAll([
      {
        'id': 'veh-1',
        'driver_id': driver.id,
        'make': 'Tata',
        'model': 'Nexon EV Empowered',
        'connector': 'ccs2',
        'battery_kwh': 40.5,
        'plate_number': 'TN 09 EV 4521',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'veh-2',
        'driver_id': driver.id,
        'make': 'MG',
        'model': 'ZS EV Excite',
        'connector': 'ccs2',
        'battery_kwh': 50.3,
        'plate_number': 'TN 10 EV 8899',
        'created_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Seed chargers across Chennai key EV corridors
    const chargerId1 = 'ch-001';
    const chargerId2 = 'ch-002';
    const chargerId3 = 'ch-003';
    const chargerId4 = 'ch-004';
    const chargerId5 = 'ch-005';
    const chargerId6 = 'ch-006';

    chargers.addAll([
      {
        'id': chargerId1,
        'host_id': host.id,
        'title': 'GreenDrive 7.4 kW Wallbox - Anna Nagar',
        'description': 'Dedicated covered parking slot with 7.4 kW smart AC charger. CCTV protected with 24/7 security.',
        'address': 'Plot 104, 2nd Avenue, Anna Nagar West, Chennai, Tamil Nadu 600040',
        'area_label': 'Anna Nagar, Chennai',
        'lat': 13.0850,
        'lng': 80.2101,
        'tier_code': 'AC_7',
        'power_kw': 7.4,
        'price_per_hour': 120.0,
        'connector': 'type2',
        'status': 'active',
        'safety_checked': true,
        'is_paused': false,
        'rating_avg': 4.9,
        'rating_count': 24,
        'host_name': host.fullName,
        'rules': 'Please park strictly within the marked EV bay. Do not yank cable.',
      },
      {
        'id': chargerId2,
        'host_id': host.id,
        'title': 'Solar 22 kW Fast AC Point - OMR Corridor',
        'description': 'High speed 22 kW AC 3-phase charger powered by rooftop solar in Sholinganallur IT hub.',
        'address': 'Elcot SEZ, Rajiv Gandhi Salai (OMR), Sholinganallur, Chennai, Tamil Nadu 600119',
        'area_label': 'OMR Sholinganallur, Chennai',
        'lat': 12.9010,
        'lng': 80.2279,
        'tier_code': 'AC_22',
        'power_kw': 22.0,
        'price_per_hour': 330.0,
        'connector': 'type2',
        'status': 'active',
        'safety_checked': true,
        'is_paused': false,
        'rating_avg': 4.8,
        'rating_count': 16,
        'host_name': host.fullName,
        'rules': 'Gate security entry code provided upon paid booking confirmation.',
      },
      {
        'id': chargerId3,
        'host_id': 'host-002',
        'title': 'EcoCharge 11 kW Point - T. Nagar Central',
        'description': 'Prime shopping district charging. Clean restroom access, air conditioning lounge & cafes nearby.',
        'address': '42 Usman Road, T. Nagar, Chennai, Tamil Nadu 600017',
        'area_label': 'T. Nagar, Chennai',
        'lat': 13.0418,
        'lng': 80.2341,
        'tier_code': 'AC_7',
        'power_kw': 11.0,
        'price_per_hour': 150.0,
        'connector': 'type2',
        'status': 'active',
        'safety_checked': true,
        'is_paused': false,
        'rating_avg': 4.7,
        'rating_count': 19,
        'host_name': 'Venkatesh Raghavan',
        'rules': 'Valet assist available. 15-minute grace period before overstay fees.',
      },
      {
        'id': chargerId4,
        'host_id': 'host-003',
        'title': 'Kathipara Hub - 30 kW CCS2 DC Fast Charger',
        'description': 'Commercial grade DC fast charging station next to Kathipara junction & Guindy Metro station.',
        'address': 'SIDCO Industrial Estate, Guindy, Chennai, Tamil Nadu 600032',
        'area_label': 'Guindy, Chennai',
        'lat': 13.0067,
        'lng': 80.2025,
        'tier_code': 'DC_30',
        'power_kw': 30.0,
        'price_per_hour': 600.0,
        'connector': 'ccs2',
        'status': 'active',
        'safety_checked': true,
        'is_paused': false,
        'rating_avg': 4.9,
        'rating_count': 42,
        'host_name': 'Murugan Subbiah',
        'rules': 'High voltage DC fast charger. Follow screen instructions carefully.',
      },
      {
        'id': chargerId5,
        'host_id': 'host-004',
        'title': 'Elliot Beach 3.3 kW 16A Overnight Socket',
        'description': 'Safe 16A socket with RCCB & earthing protection near Besant Nagar beach. Perfect for overnight charging.',
        'address': 'Beach Road, Besant Nagar, Chennai, Tamil Nadu 600090',
        'area_label': 'Besant Nagar, Chennai',
        'lat': 13.0003,
        'lng': 80.2667,
        'tier_code': 'AC_3',
        'power_kw': 3.3,
        'price_per_hour': 55.0,
        'connector': 'three_pin',
        'status': 'active',
        'safety_checked': true,
        'is_paused': false,
        'rating_avg': 4.6,
        'rating_count': 11,
        'host_name': 'Priya Sundaram',
        'rules': 'Please carry your own 16A portable charging box.',
      },
      {
        'id': chargerId6,
        'host_id': host.id,
        'title': 'Phoenix Bay 7.4 kW Wallbox - Velachery',
        'description': 'Convenient charging right off Velachery Bypass Road, close to Grand Square & Phoenix Marketcity.',
        'address': '142 Velachery Bypass Road, Velachery, Chennai, Tamil Nadu 600042',
        'area_label': 'Velachery, Chennai',
        'lat': 12.9759,
        'lng': 80.2212,
        'tier_code': 'AC_7',
        'power_kw': 7.4,
        'price_per_hour': 120.0,
        'connector': 'type2',
        'status': 'active',
        'safety_checked': true,
        'is_paused': false,
        'rating_avg': 4.8,
        'rating_count': 15,
        'host_name': host.fullName,
        'rules': 'Covered bay with lighting.',
      },
    ]);

    secrets[chargerId1] = 'ANNA74KW';
    secrets[chargerId2] = 'OMR22KW';
    secrets[chargerId3] = 'TNAGAR11KW';
    secrets[chargerId4] = 'GUINDY30KW';
    secrets[chargerId5] = 'BESANT33KW';
    secrets[chargerId6] = 'VELACH74KW';

    // Seed weekly availability for all Chennai chargers
    final allChargerIds = [chargerId1, chargerId2, chargerId3, chargerId4, chargerId5, chargerId6];
    for (int day = 0; day < 7; day++) {
      for (final cid in allChargerIds) {
        availability.add({
          'id': 'avail-$cid-$day',
          'charger_id': cid,
          'day_of_week': day,
          'start_time': '00:00',
          'end_time': '24:00',
        });
      }
    }

    // Seed an initial confirmed booking for testing check-in
    final now = DateTime.now();
    final slotStart = DateTime(now.year, now.month, now.day, now.hour, 0);
    final slotEnd = slotStart.add(const Duration(hours: 2));

    bookings.add({
      'id': 'bk-demo-test',
      'charger_id': chargerId1,
      'charger_title': 'GreenDrive 7.4 kW Wallbox - Anna Nagar',
      'driver_id': driver.id,
      'driver_name': driver.fullName,
      'vehicle_id': 'veh-1',
      'during_start': slotStart.toIso8601String(),
      'during_end': slotEnd.toIso8601String(),
      'status': 'confirmed',
      'hours': 2.0,
      'base_amount': 240.0,
      'driver_fee': 12.0,
      'total_amount': 252.0,
      'host_commission': 36.0,
      'host_earning': 204.0,
      'final_base_amount': null,
      'overstay_minutes': 0,
      'overstay_amount': 0.0,
      'refund_amount': 0.0,
      'refund_status': 'none',
      'no_show': false,
      'started_at': null,
      'ended_at': null,
      'settled_at': null,
      'created_at': now.subtract(const Duration(minutes: 45)).toIso8601String(),
    });
  }

  // --- Auth Methods ---
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final existing = users.where((u) => u.email.toLowerCase() == email.toLowerCase()).firstOrNull;
    if (existing != null) {
      throw Exception('An account with this email already exists.');
    }
    final newUser = DemoUser(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      role: role,
      fullName: name,
    );
    users.add(newUser);
    wallets[newUser.id] = 0.0;
    currentUser = newUser;
  }

  Future<String> signIn({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final user = users.where((u) => u.email.toLowerCase() == email.toLowerCase()).firstOrNull;
    if (user == null) {
      // Auto-create or reject
      throw Exception('User not found. Please click Sign Up first.');
    }
    if (user.role != expectedRole) {
      throw Exception('This account is a ${user.role} account. Please use the "${user.role}" login tab.');
    }
    currentUser = user;
    return user.role;
  }

  void signOut() {
    currentUser = null;
  }

  // --- Quotes & Pricing ---
  Map<String, dynamic> quoteBooking({
    required String chargerId,
    required DateTime start,
    required DateTime end,
  }) {
    final ch = chargers.firstWhere((c) => c['id'] == chargerId, orElse: () => throw Exception('charger_not_found'));
    final rate = (ch['price_per_hour'] as num).toDouble();
    final hours = end.difference(start).inMinutes / 60.0;
    final baseAmount = (rate * hours * 100).round() / 100;
    final driverFee = max((baseAmount * 0.05 * 100).round() / 100, 5.0);
    final hostComm = (baseAmount * 0.15 * 100).round() / 100;
    final hostEarning = baseAmount - hostComm;

    return {
      'hours': hours,
      'rate': rate,
      'base_amount': baseAmount,
      'driver_fee': driverFee,
      'total': baseAmount + driverFee,
      'host_commission': hostComm,
      'host_earning': hostEarning,
    };
  }

  // --- Search & Filters ---
  List<Map<String, dynamic>> searchNearby({
    required double lat,
    required double lng,
    int radiusM = 25000,
    DateTime? start,
    DateTime? end,
    String? connector,
  }) {
    return chargers.where((c) {
      if (c['is_paused'] == true) return false;
      if (connector != null && connector.isNotEmpty && c['connector'] != connector) {
        return false;
      }
      return true;
    }).toList();
  }

  // --- Create Booking with Exclusion Check ---
  Map<String, dynamic> createBooking({
    required String chargerId,
    String? vehicleId,
    required DateTime start,
    required DateTime end,
  }) {
    if (currentUser == null) throw Exception('not_authenticated');
    if (currentUser!.role != 'driver') throw Exception('only_drivers_can_book');
    if (currentUser!.outstandingDue > 0) throw Exception('outstanding_dues');

    final ch = chargers.firstWhere((c) => c['id'] == chargerId);
    if (ch['host_id'] == currentUser!.id) throw Exception('cannot_book_own_charger');

    // Overlap check (Simulates Postgres EXCLUDE USING gist)
    final isOverlap = bookings.any((b) {
      if (b['charger_id'] != chargerId) return false;
      if (!['pending_payment', 'confirmed', 'active', 'completed'].contains(b['status'])) return false;

      final bStart = DateTime.parse(b['during_start']);
      final bEnd = DateTime.parse(b['during_end']);
      return start.isBefore(bEnd) && end.isAfter(bStart);
    });

    if (isOverlap) {
      throw Exception('slot_taken');
    }

    final quote = quoteBooking(chargerId: chargerId, start: start, end: end);
    final bookingId = 'bk-${DateTime.now().millisecondsSinceEpoch}';

    final booking = {
      'id': bookingId,
      'charger_id': chargerId,
      'charger_title': ch['title'],
      'driver_id': currentUser!.id,
      'driver_name': currentUser!.fullName,
      'vehicle_id': vehicleId,
      'during_start': start.toIso8601String(),
      'during_end': end.toIso8601String(),
      'status': 'confirmed', // Auto-confirm in demo mode
      'hours': quote['hours'],
      'base_amount': quote['base_amount'],
      'driver_fee': quote['driver_fee'],
      'total_amount': quote['total'],
      'host_commission': quote['host_commission'],
      'host_earning': quote['host_earning'],
      'final_base_amount': null,
      'overstay_minutes': 0,
      'overstay_amount': 0.0,
      'refund_amount': 0.0,
      'refund_status': 'none',
      'no_show': false,
      'started_at': null,
      'ended_at': null,
      'settled_at': null,
      'created_at': DateTime.now().toIso8601String(),
    };

    bookings.insert(0, booking);
    _bookingStreamController.add(bookings);
    return booking;
  }

  // --- QR Check-in ---
  void startSession(String bookingId, String scannedCode) {
    final idx = bookings.indexWhere((b) => b['id'] == bookingId);
    if (idx == -1) throw Exception('not_found');
    final b = bookings[idx];

    final expectedSecret = secrets[b['charger_id']];
    if (expectedSecret != null && expectedSecret.trim().toUpperCase() != scannedCode.trim().toUpperCase()) {
      throw Exception('wrong_code');
    }

    b['status'] = 'active';
    b['started_at'] = DateTime.now().toIso8601String();
    bookings[idx] = b;
    _bookingStreamController.add(bookings);
  }

  // --- End Session (Refund & Overstay Calculation) ---
  Map<String, dynamic> endSession(String bookingId) {
    final idx = bookings.indexWhere((b) => b['id'] == bookingId);
    if (idx == -1) throw Exception('not_found');
    final b = bookings[idx];
    if (b['status'] != 'active') throw Exception('session_not_active');

    final ch = chargers.firstWhere((c) => c['id'] == b['charger_id']);
    final rate = (ch['price_per_hour'] as num).toDouble();
    final now = DateTime.now();

    final bookedStart = DateTime.parse(b['during_start']);
    final bookedEnd = DateTime.parse(b['during_end']);

    final totalBookedMin = bookedEnd.difference(bookedStart).inMinutes.toDouble();
    final usedMin = max(now.difference(bookedStart).inMinutes.toDouble(), 0.0);
    // Round up to 30 min, min 30 min, max totalBookedMin
    final billMin = min(totalBookedMin, max(30.0, (usedMin / 30.0).ceil() * 30.0));

    double overMin = 0.0;
    double overAmt = 0.0;
    if (now.isAfter(bookedEnd.add(const Duration(minutes: 10)))) {
      final diff = now.difference(bookedEnd).inMinutes.toDouble();
      overMin = (diff / 15.0).ceil() * 15.0;
      overAmt = (rate * overMin / 60.0 * 1.5 * 100).round() / 100;
    }

    final finalBase = (rate * billMin / 60.0 * 100).round() / 100;
    final comm = ((finalBase + overAmt) * 0.15 * 100).round() / 100;
    final hostEarning = (finalBase + overAmt) - comm;
    final refund = max((b['base_amount'] as double) - finalBase, 0.0);

    b['status'] = 'completed';
    b['ended_at'] = now.toIso8601String();
    b['final_base_amount'] = finalBase;
    b['overstay_minutes'] = overMin.toInt();
    b['overstay_amount'] = overAmt;
    b['host_commission'] = comm;
    b['host_earning'] = hostEarning;
    b['refund_amount'] = refund;
    b['refund_status'] = refund > 0 ? 'done' : 'none';

    // Credit host wallet
    final hostId = ch['host_id'] as String;
    final currentBal = wallets[hostId] ?? 0.0;
    final newBal = currentBal + hostEarning;
    wallets[hostId] = newBal;

    transactions.insert(0, {
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': hostId,
      'booking_id': bookingId,
      'kind': 'earning',
      'amount': hostEarning,
      'balance_after': newBal,
      'note': 'Session completed on ${ch['title']}',
      'created_at': DateTime.now().toIso8601String(),
    });

    bookings[idx] = b;
    _bookingStreamController.add(bookings);
    return b;
  }

  // --- Cancellation ---
  void cancelBooking(String bookingId, {String? reason}) {
    final idx = bookings.indexWhere((b) => b['id'] == bookingId);
    if (idx == -1) throw Exception('not_found');
    final b = bookings[idx];

    final start = DateTime.parse(b['during_start']);
    final now = DateTime.now();
    double lateFee = 0.0;

    // Driver cancel less than 2 hours before start => 30% late fee
    if (start.difference(now).inHours < 2) {
      lateFee = ((b['base_amount'] as double) * 0.3 * 100).round() / 100;
    }

    b['status'] = 'cancelled_by_driver';
    b['ended_at'] = now.toIso8601String();
    b['cancel_reason'] = reason;
    b['refund_amount'] = (b['total_amount'] as double) - lateFee;
    b['refund_status'] = 'done';

    bookings[idx] = b;
    _bookingStreamController.add(bookings);
  }

  // --- Wallet & Payout ---
  double getWalletBalance(String userId) {
    return wallets[userId] ?? 0.0;
  }

  List<Map<String, dynamic>> getTransactions(String userId) {
    return transactions.where((t) => t['user_id'] == userId).toList();
  }

  Map<String, dynamic> requestPayout({
    required double amount,
    required String upiId,
  }) {
    if (currentUser == null) throw Exception('not_authenticated');
    if (amount < 200) throw Exception('below_min_payout');

    final bal = wallets[currentUser!.id] ?? 0.0;
    if (bal < amount) throw Exception('insufficient_balance');

    final newBal = bal - amount;
    wallets[currentUser!.id] = newBal;

    final payoutId = 'pay-${DateTime.now().millisecondsSinceEpoch}';
    final payout = {
      'id': payoutId,
      'host_id': currentUser!.id,
      'amount': amount,
      'upi_id': upiId,
      'status': 'requested',
      'requested_at': DateTime.now().toIso8601String(),
    };
    payouts.add(payout);

    transactions.insert(0, {
      'id': 'tx-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': currentUser!.id,
      'booking_id': null,
      'kind': 'payout',
      'amount': -amount,
      'balance_after': newBal,
      'note': 'Payout requested to $upiId',
      'created_at': DateTime.now().toIso8601String(),
    });

    return payout;
  }

  // --- Charger Management (Host) ---
  String addCharger({
    required String title,
    required String address,
    required double lat,
    required double lng,
    required String tierCode,
    required String connector,
    String? rules,
    String? description,
  }) {
    if (currentUser == null) throw Exception('not_authenticated');

    final tierRates = {
      'AC_3': {'power': 3.3, 'price': 55.0},
      'AC_7': {'power': 7.4, 'price': 120.0},
      'AC_22': {'power': 22.0, 'price': 330.0},
      'DC_30': {'power': 30.0, 'price': 600.0},
    };

    final t = tierRates[tierCode] ?? {'power': 7.4, 'price': 120.0};
    final newId = 'ch-${DateTime.now().millisecondsSinceEpoch}';
    final checkCode = 'CS${Random().nextInt(90000) + 10000}';

    final charger = {
      'id': newId,
      'host_id': currentUser!.id,
      'title': title,
      'description': description ?? '',
      'address': address,
      'lat': lat,
      'lng': lng,
      'tier_code': tierCode,
      'power_kw': t['power'],
      'price_per_hour': t['price'],
      'connector': connector,
      'status': 'active', // Demo auto-activated
      'safety_checked': true,
      'is_paused': false,
      'rating_avg': 5.0,
      'rating_count': 1,
      'host_name': currentUser!.fullName,
      'rules': rules ?? '',
    };

    chargers.add(charger);
    secrets[newId] = checkCode;

    // Default availability
    for (int day = 0; day < 7; day++) {
      availability.add({
        'id': 'avail-$newId-$day',
        'charger_id': newId,
        'day_of_week': day,
        'start_time': '00:00',
        'end_time': '24:00',
      });
    }

    return newId;
  }

  String getCheckinCode(String chargerId) {
    return secrets[chargerId] ?? 'CHARGE2026';
  }

  void saveAvailability(String chargerId, List<Map<String, dynamic>> rules) {
    availability.removeWhere((a) => a['charger_id'] == chargerId);
    for (final r in rules) {
      availability.add({
        'id': 'avail-$chargerId-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000)}',
        'charger_id': chargerId,
        'day_of_week': r['day_of_week'],
        'start_time': r['start_time'],
        'end_time': r['end_time'],
      });
    }
  }

  List<Map<String, dynamic>> getAvailability(String chargerId) {
    return availability.where((a) => a['charger_id'] == chargerId).toList();
  }

  void togglePauseCharger(String chargerId) {
    final ch = chargers.firstWhere((c) => c['id'] == chargerId);
    ch['is_paused'] = !(ch['is_paused'] as bool);
  }

  // --- Vehicles (Driver) ---
  List<Map<String, dynamic>> getVehicles(String driverId) {
    return vehicles.where((v) => v['driver_id'] == driverId).toList();
  }

  void addVehicle({
    required String make,
    required String model,
    required String connector,
    double? batteryKwh,
    String? plateNumber,
  }) {
    if (currentUser == null) throw Exception('not_authenticated');
    vehicles.add({
      'id': 'veh-${DateTime.now().millisecondsSinceEpoch}',
      'driver_id': currentUser!.id,
      'make': make,
      'model': model,
      'connector': connector,
      'battery_kwh': batteryKwh,
      'plate_number': plateNumber,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  void deleteVehicle(String vehicleId) {
    vehicles.removeWhere((v) => v['id'] == vehicleId);
  }
}
