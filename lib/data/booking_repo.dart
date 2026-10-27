import 'dart:async';
import '../core/demo_service.dart';
import '../core/supabase.dart';

class BookingRepo {
  Future<Map<String, dynamic>> create({
    required String chargerId,
    String? vehicleId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.rpc(
        'create_booking',
        params: {
          'p_charger': chargerId,
          'p_vehicle': vehicleId,
          'p_start': start.toUtc().toIso8601String(),
          'p_end': end.toUtc().toIso8601String(),
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } else {
      return DemoService().createBooking(
        chargerId: chargerId,
        vehicleId: vehicleId,
        start: start,
        end: end,
      );
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder(String bookingId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.functions.invoke(
        'create-payment-order',
        body: {'booking_id': bookingId},
      );
      return Map<String, dynamic>.from(res.data as Map);
    } else {
      // Demo simulated payment response
      return {
        'order_id': 'order_demo_${DateTime.now().millisecondsSinceEpoch}',
        'amount': 25200,
        'currency': 'INR',
        'key_id': 'rzp_test_demoKey',
      };
    }
  }

  Future<void> startSession(String bookingId, String scannedCode) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.rpc(
        'start_session',
        params: {'p_booking': bookingId, 'p_code': scannedCode},
      );
    } else {
      DemoService().startSession(bookingId, scannedCode);
    }
  }

  Future<Map<String, dynamic>> endSession(String bookingId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.rpc(
        'end_session',
        params: {'p_booking': bookingId},
      );
      return Map<String, dynamic>.from(res as Map);
    } else {
      return DemoService().endSession(bookingId);
    }
  }

  Future<void> cancel(String bookingId, {String? reason}) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.rpc(
        'cancel_booking',
        params: {'p_booking': bookingId, 'p_reason': reason},
      );
    } else {
      DemoService().cancelBooking(bookingId, reason: reason);
    }
  }

  Future<void> review(
    String bookingId,
    int rating, {
    String? comment,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.rpc(
        'submit_review',
        params: {
          'p_booking': bookingId,
          'p_rating': rating,
          'p_comment': comment,
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> getDriverBookings(String driverId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('bookings')
          .select('*, chargers(title, address, tier_code, connector)')
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      return DemoService().bookings.where((b) => b['driver_id'] == driverId).toList();
    }
  }

  Future<List<Map<String, dynamic>>> getHostBookings(String hostId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('bookings')
          .select('*, chargers!inner(title, host_id)')
          .eq('chargers.host_id', hostId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      // Find charger IDs owned by host
      final hostChargerIds = DemoService().chargers
          .where((c) => c['host_id'] == hostId)
          .map((c) => c['id'])
          .toSet();
      return DemoService().bookings
          .where((b) => hostChargerIds.contains(b['charger_id']))
          .toList();
    }
  }

  Stream<String> watchStatus(String bookingId) {
    if (isSupabaseConfigured && supabaseClient != null) {
      return supabaseClient!
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', bookingId)
          .map((rows) => rows.first['status'] as String);
    } else {
      return DemoService().bookingStream.map((list) {
        final found = list.firstWhere((b) => b['id'] == bookingId, orElse: () => {});
        return (found['status'] ?? 'pending_payment') as String;
      });
    }
  }
}
