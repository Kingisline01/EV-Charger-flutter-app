import '../core/demo_service.dart';
import '../core/supabase.dart';

class ChargerRepo {
  Future<List<Map<String, dynamic>>> nearby(
    double lat,
    double lng, {
    int radiusM = 25000,
    DateTime? start,
    DateTime? end,
    String? connector,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.rpc(
        'nearby_chargers',
        params: {
          'p_lat': lat,
          'p_lng': lng,
          'p_radius_m': radiusM,
          'p_start': start?.toUtc().toIso8601String(),
          'p_end': end?.toUtc().toIso8601String(),
          'p_connector': connector,
        },
      );
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      return DemoService().searchNearby(
        lat: lat,
        lng: lng,
        radiusM: radiusM,
        start: start,
        end: end,
        connector: connector,
      );
    }
  }

  Future<List<Map<String, dynamic>>> busySlots(
    String chargerId,
    DateTime from,
    DateTime to,
  ) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.rpc(
        'get_busy_slots',
        params: {
          'p_charger': chargerId,
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
        },
      );
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      final bookings = DemoService().bookings.where((b) {
        if (b['charger_id'] != chargerId) return false;
        if (!['pending_payment', 'confirmed', 'active', 'completed'].contains(b['status'])) return false;
        final s = DateTime.parse(b['during_start']);
        final e = DateTime.parse(b['during_end']);
        return s.isBefore(to) && e.isAfter(from);
      });
      return bookings.map((b) => {
        'slot_start': b['during_start'],
        'slot_end': b['during_end'],
      }).toList();
    }
  }

  Future<Map<String, dynamic>> quote(
    String chargerId,
    DateTime start,
    DateTime end,
  ) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.rpc(
        'quote_booking',
        params: {
          'p_charger': chargerId,
          'p_start': start.toUtc().toIso8601String(),
          'p_end': end.toUtc().toIso8601String(),
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } else {
      return DemoService().quoteBooking(
        chargerId: chargerId,
        start: start,
        end: end,
      );
    }
  }

  Future<String> addCharger({
    required String title,
    required String address,
    required double lat,
    required double lng,
    required String tierCode,
    required String connector,
    String? rules,
    String? description,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final row = await supabaseClient!
          .from('chargers')
          .insert({
            'host_id': supabaseClient!.auth.currentUser!.id,
            'title': title,
            'description': description,
            'address': address,
            'location': 'SRID=4326;POINT($lng $lat)',
            'tier_code': tierCode,
            'connector': connector,
            'rules': rules,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } else {
      return DemoService().addCharger(
        title: title,
        address: address,
        lat: lat,
        lng: lng,
        tierCode: tierCode,
        connector: connector,
        rules: rules,
        description: description,
      );
    }
  }

  Future<void> setPaused(String chargerId, bool paused) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!
          .from('chargers')
          .update({'is_paused': paused})
          .eq('id', chargerId);
    } else {
      DemoService().togglePauseCharger(chargerId);
    }
  }

  Future<void> saveAvailability(
    String chargerId,
    List<Map<String, dynamic>> rules,
  ) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!
          .from('charger_availability')
          .delete()
          .eq('charger_id', chargerId);
      await supabaseClient!.from('charger_availability').insert([
        for (final r in rules) {'charger_id': chargerId, ...r}
      ]);
    } else {
      DemoService().saveAvailability(chargerId, rules);
    }
  }

  Future<List<Map<String, dynamic>>> getAvailability(String chargerId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('charger_availability')
          .select()
          .eq('charger_id', chargerId);
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      return DemoService().getAvailability(chargerId);
    }
  }

  Future<String> checkinCode(String chargerId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final r = await supabaseClient!
          .from('charger_secrets')
          .select('checkin_code')
          .eq('charger_id', chargerId)
          .single();
      return r['checkin_code'] as String;
    } else {
      return DemoService().getCheckinCode(chargerId);
    }
  }

  Future<List<Map<String, dynamic>>> getHostChargers(String hostId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('chargers')
          .select()
          .eq('host_id', hostId);
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      return DemoService().chargers.where((c) => c['host_id'] == hostId).toList();
    }
  }
}
