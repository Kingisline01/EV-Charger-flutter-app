import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/charger_repo.dart';

class AddChargerPage extends StatefulWidget {
  const AddChargerPage({super.key});

  @override
  State<AddChargerPage> createState() => _AddChargerPageState();
}

class _AddChargerPageState extends State<AddChargerPage> {
  final ChargerRepo _chargerRepo = ChargerRepo();

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController(text: 'Home Wallbox Type-2');
  final _descCtrl = TextEditingController(text: 'Safe shaded parking inside gated villa community.');
  final _addressCtrl = TextEditingController(text: 'Plot 42, Rajiv Gandhi Salai (OMR), Sholinganallur, Chennai');
  final _rulesCtrl = TextEditingController(text: 'Keep noise low after 10 PM. Park within the designated bay.');

  final double _lat = 12.9010;
  final double _lng = 80.2279;
  String _tierCode = 'AC_7';
  String _connector = 'type2';
  bool _safetyConfirmed = true;
  bool _submitting = false;

  final Map<String, Map<String, dynamic>> _tiers = {
    'AC_3': {'label': 'AC 3.3 kW (Slow / Home Socket)', 'price': 55.0},
    'AC_7': {'label': 'AC 7.4 kW (Type 2 Wallbox)', 'price': 120.0},
    'AC_22': {'label': 'AC 22 kW (Fast AC)', 'price': 330.0},
    'DC_30': {'label': 'DC 30 kW (Commercial Fast)', 'price': 600.0},
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_safetyConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm the electrical safety checklist')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _chargerRepo.addCharger(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        tierCode: _tierCode,
        connector: _connector,
        rules: _rulesCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Charger listed successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Formatters.friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List New EV Charger')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Charger Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Listing Title',
                hintText: 'e.g. My Fast Type 2 Wallbox',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Address',
                hintText: 'House/Street/Area for GPS navigation',
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter address' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Parking instructions, gated access info...',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Platform Fixed Pricing Tier',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Prices are fixed platform-wide to guarantee fair transparent pricing for drivers.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _tierCode,
              decoration: const InputDecoration(
                labelText: 'Charger Power & Fixed Price',
                prefixIcon: Icon(Icons.flash_on),
              ),
              items: _tiers.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.value['label']} • ${Formatters.currency(e.value['price'])}/h'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _tierCode = val);
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _connector,
              decoration: const InputDecoration(
                labelText: 'Connector Type',
                prefixIcon: Icon(Icons.power),
              ),
              items: const [
                DropdownMenuItem(value: 'type2', child: Text('Type 2 (Mennekes AC)')),
                DropdownMenuItem(value: 'ccs2', child: Text('CCS 2 (Combined AC/DC)')),
                DropdownMenuItem(value: 'three_pin', child: Text('3-Pin 16A Heavy Socket')),
                DropdownMenuItem(value: 'chademo', child: Text('CHAdeMO')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _connector = val);
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _rulesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'House Rules',
                hintText: 'e.g. Please do not block the driveway',
                prefixIcon: Icon(Icons.gavel),
              ),
            ),
            const SizedBox(height: 20),

            // Safety checklist
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Mandatory Safety Checklist',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Dedicated electrical circuit with MCB/RCCB installed.\n'
                    '• Proper earth connection verified.\n'
                    '• Weatherproof outdoor socket/enclosure.\n'
                    '• No domestic extension cords used.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _safetyConfirmed,
                    title: const Text(
                      'I confirm my installation complies with all safety requirements.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (v) => setState(() => _safetyConfirmed = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Publish Charger Listing'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
