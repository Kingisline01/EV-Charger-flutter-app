import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/auth_repo.dart';
import '../../data/vehicle_repo.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final VehicleRepo _vehicleRepo = VehicleRepo();
  final AuthRepo _authRepo = AuthRepo();

  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loading = true);
    final driverId = _authRepo.currentUserId() ?? '';
    final list = await _vehicleRepo.getVehicles(driverId);
    if (mounted) {
      setState(() {
        _vehicles = list;
        _loading = false;
      });
    }
  }

  Future<void> _showAddVehicleDialog() async {
    final makeCtrl = TextEditingController(text: 'Tata');
    final modelCtrl = TextEditingController(text: 'Nexon EV');
    final plateCtrl = TextEditingController(text: 'MH 01 AB 9999');
    final batteryCtrl = TextEditingController(text: '40.5');
    String connector = 'ccs2';

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Electric Vehicle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: makeCtrl,
                  decoration: const InputDecoration(labelText: 'Make / Brand'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: connector,
                  decoration: const InputDecoration(labelText: 'Connector Type'),
                  items: const [
                    DropdownMenuItem(value: 'ccs2', child: Text('CCS 2 (Standard DC/AC)')),
                    DropdownMenuItem(value: 'type2', child: Text('Type 2 (Mennekes AC)')),
                    DropdownMenuItem(value: 'three_pin', child: Text('3-Pin 16A Socket')),
                    DropdownMenuItem(value: 'chademo', child: Text('CHAdeMO')),
                    DropdownMenuItem(value: 'gbt', child: Text('GB/T')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => connector = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: batteryCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Battery Capacity (kWh)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(labelText: 'Plate / Registration Number'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (makeCtrl.text.isNotEmpty && modelCtrl.text.isNotEmpty) {
                  await _vehicleRepo.addVehicle(
                    make: makeCtrl.text.trim(),
                    model: modelCtrl.text.trim(),
                    connector: connector,
                    batteryKwh: double.tryParse(batteryCtrl.text.trim()),
                    plateNumber: plateCtrl.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save Vehicle'),
            ),
          ],
        ),
      ),
    );

    if (added == true) {
      _loadVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: _showAddVehicleDialog,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No vehicles added yet', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Add your EV to quickly match compatible chargers'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, i) {
                    final v = _vehicles[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.electric_car, color: AppTheme.primaryGreen),
                        ),
                        title: Text(
                          '${v['make']} ${v['model']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Connector: ${(v['connector'] as String).toUpperCase()} • Battery: ${v['battery_kwh'] ?? 40} kWh\nReg: ${v['plate_number'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await _vehicleRepo.deleteVehicle(v['id']);
                            _loadVehicles();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
