import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  );

  static String currency(num amount) {
    return _currencyFormat.format(amount);
  }

  static String date(DateTime dt) {
    return DateFormat('EEE, d MMM yyyy').format(dt.toLocal());
  }

  static String time(DateTime dt) {
    return DateFormat('HH:mm').format(dt.toLocal());
  }

  static String dateTime(DateTime dt) {
    return DateFormat('d MMM, HH:mm').format(dt.toLocal());
  }

  static String duration(num minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String friendlyError(dynamic error) {
    final e = error.toString().toLowerCase();
    if (e.contains('slot_taken')) {
      return 'Someone just booked this slot. Please pick another time.';
    }
    if (e.contains('outside_availability')) {
      return 'The host is not available during that time window.';
    }
    if (e.contains('host_blocked')) {
      return 'The host has blocked this time slot.';
    }
    if (e.contains('outstanding_dues') || e.contains('outstanding_due')) {
      return 'Please clear your pending dues before booking again.';
    }
    if (e.contains('cannot_book_own_charger')) {
      return 'You cannot book your own charger.';
    }
    if (e.contains('wrong_code')) {
      return 'Invalid check-in code. Please scan the QR code on the physical charger.';
    }
    if (e.contains('outside_checkin_window')) {
      return 'Check-in is allowed from 15 mins before slot start until slot end.';
    }
    if (e.contains('not_confirmed')) {
      return 'Booking is not confirmed yet.';
    }
    if (e.contains('session_not_active')) {
      return 'Charging session is not active.';
    }
    if (e.contains('below_min_payout')) {
      return 'Minimum payout request is ₹200.';
    }
    if (e.contains('insufficient_balance')) {
      return 'Insufficient wallet balance for this payout.';
    }
    if (e.contains('only_drivers_can_book')) {
      return 'Only driver accounts can book chargers.';
    }
    return error.toString().replaceAll('Exception: ', '');
  }
}
