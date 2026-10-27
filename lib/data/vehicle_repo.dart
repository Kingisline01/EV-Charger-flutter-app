import '../core/demo_service.dart';
import '../core/supabase.dart';

class VehicleRepo {
  Future<List<Map<String, dynamic>>> getVehicles(String driverId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('vehicles')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      return DemoService().getVehicles(driverId);
    }
  }

  Future<void> addVehicle({
    required String make,
    required String model,
    required String connector,
    double? batteryKwh,
    String? plateNumber,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.from('vehicles').insert({
        'driver_id': supabaseClient!.auth.currentUser!.id,
        'make': make,
        'model': model,
        'connector': connector,
        'battery_kwh': batteryKwh,
        'plate_number': plateNumber,
      });
    } else {
      DemoService().addVehicle(
        make: make,
        model: model,
        connector: connector,
        batteryKwh: batteryKwh,
        plateNumber: plateNumber,
      );
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.from('vehicles').delete().eq('id', vehicleId);
    } else {
      DemoService().deleteVehicle(vehicleId);
    }
  }
}
