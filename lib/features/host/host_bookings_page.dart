import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';
import '../../data/booking_repo.dart';
import '../../widgets/status_chip.dart';

class HostBookingsPage extends StatefulWidget {
  const HostBookingsPage({super.key});

  @override
  State<HostBookingsPage> createState() => _HostBookingsPageState();
}

class _HostBookingsPageState extends State<HostBookingsPage> {
  final BookingRepo _bookingRepo = BookingRepo();
  final AuthRepo _authRepo = AuthRepo();

  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final hostId = _authRepo.currentUserId() ?? '';
    final list = await _bookingRepo.getHostBookings(hostId);
    if (mounted) {
      setState(() {
        _bookings = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No bookings yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Incoming driver reservations will appear here in realtime.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, i) {
          final b = _bookings[i];
          final title = b['charger_title'] ?? 'My Charger';
          final driverName = b['driver_name'] ?? 'EV Driver';
          final status = (b['status'] as String? ?? '').toLowerCase();
          final startStr = b['during_start'];
          final endStr = b['during_end'];
          final start = startStr != null ? DateTime.parse(startStr) : DateTime.now();
          final end = endStr != null ? DateTime.parse(endStr) : DateTime.now().add(const Duration(hours: 2));
          final earning = (b['host_earning'] as num?)?.toDouble() ?? 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: $driverName',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${Formatters.dateTime(start)} → ${Formatters.time(end)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status == 'active' ? '🟢 Driver Currently Charging' : 'Host Earning (Net)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status == 'active' ? AppTheme.primaryGreen : Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        Formatters.currency(earning),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
