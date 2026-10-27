import 'package:flutter_test/flutter_test.dart';
import 'package:chargeshare/core/demo_service.dart';
import 'package:chargeshare/data/auth_repo.dart';
import 'package:chargeshare/data/charger_repo.dart';
import 'package:chargeshare/data/booking_repo.dart';
import 'package:chargeshare/data/wallet_repo.dart';

void main() {
  group('1. Auth & Two-Login Role Checks (README Section 2 & 9.4)', () {
    final authRepo = AuthRepo();

    test('Driver sign in succeeds when selecting driver tab', () async {
      final role = await authRepo.signIn(
        email: 'driver@chargeshare.com',
        password: 'password123',
        expectedRole: 'driver',
      );
      expect(role, equals('driver'));
      expect(await authRepo.currentRole(), equals('driver'));
    });

    test('Driver account signing in on Host tab throws role mismatch error', () async {
      expect(
        () => authRepo.signIn(
          email: 'driver@chargeshare.com',
          password: 'password123',
          expectedRole: 'host',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('This account is a driver account. Please use the "driver" login tab.'))),
      );
    });

    test('Host account signing in on Driver tab throws role mismatch error', () async {
      expect(
        () => authRepo.signIn(
          email: 'host@chargeshare.com',
          password: 'password123',
          expectedRole: 'driver',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('This account is a host account. Please use the "host" login tab.'))),
      );
    });
  });

  group('2. Fixed Platform Pricing Quote (README Section 4.1 Worked Example)', () {
    final chargerRepo = ChargerRepo();

    test('Quote matches worked example: 3h on 7.4 kW (₹120/hr) => ₹378 total, ₹306 host earn', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 10, 0);
      final end = start.add(const Duration(hours: 3));

      final quote = await chargerRepo.quote('ch-001', start, end);

      expect(quote['hours'], equals(3.0));
      expect(quote['rate'], equals(120.0));
      expect(quote['base_amount'], equals(360.0)); // 3 * 120
      expect(quote['driver_fee'], equals(18.0)); // max(5% * 360, 5) = 18
      expect(quote['total'], equals(378.0)); // 360 + 18
      expect(quote['host_commission'], equals(54.0)); // 15% * 360
      expect(quote['host_earning'], equals(306.0)); // 360 - 54
    });
  });

  group('3. Double-Booking Prevention & Booking Flow (README Section 4.3)', () {
    final authRepo = AuthRepo();
    final bookingRepo = BookingRepo();

    setUp(() async {
      await authRepo.signIn(
        email: 'driver@chargeshare.com',
        password: 'password123',
        expectedRole: 'driver',
      );
    });

    test('First booking succeeds, overlapping second booking throws slot_taken', () async {
      final now = DateTime.now().add(const Duration(days: 1));
      final start = DateTime(now.year, now.month, now.day, 14, 0);
      final end = start.add(const Duration(hours: 2));

      // First booking
      final b1 = await bookingRepo.create(
        chargerId: 'ch-001',
        start: start,
        end: end,
      );
      expect(b1['status'], isIn(['confirmed', 'pending_payment']));

      // Attempt overlapping booking at same charger: 15:00 - 17:00
      final overlapStart = start.add(const Duration(hours: 1));
      final overlapEnd = overlapStart.add(const Duration(hours: 2));

      expect(
        () => bookingRepo.create(
          chargerId: 'ch-001',
          start: overlapStart,
          end: overlapEnd,
        ),
        throwsA(predicate((e) => e.toString().contains('slot_taken'))),
      );
    });
  });

  group('4. QR Check-In & Live Session Lifecycle (README Section 4.4 & 4.5)', () {
    final authRepo = AuthRepo();
    final bookingRepo = BookingRepo();
    final demoService = DemoService();

    setUp(() async {
      await authRepo.signIn(
        email: 'driver@chargeshare.com',
        password: 'password123',
        expectedRole: 'driver',
      );
    });

    test('QR check-in with wrong code throws wrong_code', () async {
      expect(
        () => bookingRepo.startSession('bk-demo-test', 'WRONG_SECRET'),
        throwsA(predicate((e) => e.toString().contains('wrong_code'))),
      );
    });

    test('QR check-in with correct code starts active charging session', () async {
      final code = demoService.getCheckinCode('ch-001');
      await bookingRepo.startSession('bk-demo-test', code);

      final b = demoService.bookings.firstWhere((item) => item['id'] == 'bk-demo-test');
      expect(b['status'], equals('active'));
      expect(b['started_at'], isNotNull);
    });

    test('Ending session completes booking and credits host wallet', () async {
      final hostBefore = demoService.getWalletBalance('host-001');

      final completed = await bookingRepo.endSession('bk-demo-test');
      expect(completed['status'], equals('completed'));
      expect(completed['ended_at'], isNotNull);

      final hostAfter = demoService.getWalletBalance('host-001');
      expect(hostAfter, greaterThan(hostBefore));
    });
  });

  group('5. Host Availability & Wallet Payouts (README Section 4.7 & 7.7)', () {
    final authRepo = AuthRepo();
    final chargerRepo = ChargerRepo();
    final walletRepo = WalletRepo();

    setUp(() async {
      await authRepo.signIn(
        email: 'host@chargeshare.com',
        password: 'password123',
        expectedRole: 'host',
      );
    });

    test('Save custom availability with blocked hours', () async {
      // Host blocks own 18:00 - 20:00 every day
      final rules = [
        {'day_of_week': 1, 'start_time': '00:00:00', 'end_time': '18:00:00'},
        {'day_of_week': 1, 'start_time': '20:00:00', 'end_time': '24:00:00'},
      ];

      await chargerRepo.saveAvailability('ch-001', rules);
      final saved = await chargerRepo.getAvailability('ch-001');
      expect(saved.length, equals(2));
    });

    test('Payout request below ₹200 is rejected with below_min_payout', () async {
      expect(
        () => walletRepo.requestPayout(amount: 150.0, upiId: 'host@upi'),
        throwsA(predicate((e) => e.toString().contains('below_min_payout'))),
      );
    });

    test('Valid payout request deducts from host wallet balance', () async {
      final currentBal = await walletRepo.getBalance('host-001');
      expect(currentBal, greaterThanOrEqualTo(200.0));

      final payout = await walletRepo.requestPayout(amount: 200.0, upiId: 'host@upi');
      expect(payout['status'], equals('requested'));

      final newBal = await walletRepo.getBalance('host-001');
      expect(newBal, equals(currentBal - 200.0));
    });
  });
}
