import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chargeshare/features/auth/login_page.dart';
import 'package:chargeshare/widgets/status_chip.dart';
import 'package:chargeshare/widgets/price_breakdown.dart';
import 'package:chargeshare/widgets/charger_card.dart';

void main() {
  testWidgets('Login page displays both role tabs ("I need to charge" & "I own a charger")',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    expect(find.text('ChargeShare'), findsOneWidget);
    expect(find.text('I need to charge'), findsOneWidget);
    expect(find.text('I own a charger'), findsOneWidget);
    expect(find.textContaining('DRIVER', findRichText: true), findsOneWidget);

    // Switch to Host tab
    await tester.tap(find.text('I own a charger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('HOST', findRichText: true), findsOneWidget);
  });

  testWidgets('StatusChip renders appropriate colors and uppercase text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatusChip(status: 'confirmed'),
              StatusChip(status: 'active'),
              StatusChip(status: 'completed'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.text('CHARGING NOW'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('PriceBreakdown renders base, fees, and total correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PriceBreakdown(
            hours: 3.0,
            rate: 120.0,
            baseAmount: 360.0,
            driverFee: 18.0,
            total: 378.0,
          ),
        ),
      ),
    );

    expect(find.text('Price Summary'), findsOneWidget);
    expect(find.text('Total Payable'), findsOneWidget);
    expect(find.textContaining('378'), findsOneWidget);
  });

  testWidgets('ChargerCard renders power kw and fixed price', (WidgetTester tester) async {
    final mockCharger = {
      'id': 'test-1',
      'title': 'Test Fast Wallbox',
      'address': '123 EV St, Anna Nagar, Chennai',
      'power_kw': 7.4,
      'price_per_hour': 120.0,
      'connector': 'type2',
      'rating_avg': 4.9,
      'rating_count': 10,
      'host_name': 'Senthil',
      'is_paused': false,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChargerCard(
            charger: mockCharger,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Test Fast Wallbox'), findsOneWidget);
    expect(find.text('7.4 kW'), findsOneWidget);
    expect(find.text('TYPE2'), findsOneWidget);
  });
}
