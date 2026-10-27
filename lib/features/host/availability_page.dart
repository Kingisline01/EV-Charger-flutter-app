import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/charger_repo.dart';

class AvailabilityPage extends StatefulWidget {
  final String chargerId;
  final String title;

  const AvailabilityPage({
    super.key,
    required this.chargerId,
    required this.title,
  });

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends State<AvailabilityPage> {
  final ChargerRepo _chargerRepo = ChargerRepo();
  bool _loading = true;
  bool _saving = false;

  final List<String> _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  // Map of day index -> list of time windows [{'start': '00:00', 'end': '18:00'}, ...]
  final Map<int, List<Map<String, String>>> _rules = {};

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => _loading = true);
    final raw = await _chargerRepo.getAvailability(widget.chargerId);
    for (int i = 0; i < 7; i++) {
      _rules[i] = [];
    }
    for (final r in raw) {
      final d = (r['day_of_week'] as num).toInt();
      _rules[d]?.add({
        'start': r['start_time'].toString().substring(0, 5),
        'end': r['end_time'].toString().substring(0, 5),
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyStandardPreset() {
    // Preset from README: 00:00 - 18:00 & 20:00 - 24:00 (host blocks own 18-20h)
    setState(() {
      for (int i = 0; i < 7; i++) {
        _rules[i] = [
          {'start': '00:00', 'end': '18:00'},
          {'start': '20:00', 'end': '24:00'},
        ];
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Applied "Block own 18:00-20:00" preset to all 7 days!'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  void _apply24HoursPreset() {
    setState(() {
      for (int i = 0; i < 7; i++) {
        _rules[i] = [
          {'start': '00:00', 'end': '24:00'},
        ];
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied "24 Hours Available" preset to all 7 days!')),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final flatList = <Map<String, dynamic>>[];
    _rules.forEach((day, windows) {
      for (final w in windows) {
        flatList.add({
          'day_of_week': day,
          'start_time': '${w['start']}:00',
          'end_time': w['end'] == '24:00' ? '24:00:00' : '${w['end']}:00',
        });
      }
    });

    try {
      await _chargerRepo.saveAvailability(widget.chargerId, flatList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability rules saved successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Availability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.blue.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Quick Availability Presets',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Example: If you charge your own vehicle daily from 18:00 to 20:00, block those 2 hours so drivers can rent the other 22 hours.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.schedule, size: 16),
                              label: const Text('Block Own 18:00-20:00 (Rent 22 hrs)'),
                              onPressed: _applyStandardPreset,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.all_inclusive, size: 16),
                              label: const Text('24/7 Rentable'),
                              onPressed: _apply24HoursPreset,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Daily Rentable Windows',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (int day = 0; day < 7; day++) _buildDayTile(day),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save Availability'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }

  Widget _buildDayTile(int day) {
    final windows = _rules[day] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _days[day],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Window'),
                  onPressed: () {
                    setState(() {
                      windows.add({'start': '08:00', 'end': '18:00'});
                    });
                  },
                ),
              ],
            ),
            if (windows.isEmpty)
              const Text('Not available for rent on this day', style: TextStyle(color: Colors.grey, fontSize: 12))
            else
              Column(
                children: windows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final w = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          '${w['start']} — ${w['end']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              windows.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
