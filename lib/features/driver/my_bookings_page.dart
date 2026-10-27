import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';
import '../../data/booking_repo.dart';
import '../../widgets/status_chip.dart';
import 'session_page.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
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
    final driverId = _authRepo.currentUserId() ?? '';
    final list = await _bookingRepo.getDriverBookings(driverId);
    if (mounted) {
      setState(() {
        _bookings = list;
        _loading = false;
      });
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> b) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Refund policy:\n• ≥ 2 hours before start: 100% full refund.\n• < 2 hours before start: 30% late fee applies to compensate host.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Slot')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _bookingRepo.cancel(b['id'], reason: reasonCtrl.text);
      _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Formatters.friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No bookings found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Book an EV charger nearby from the Explore tab',
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
          final title = b['charger_title'] ?? 'EV Charger';
          final status = (b['status'] as String? ?? '').toLowerCase();
          final startStr = b['during_start'];
          final start = startStr != null ? DateTime.parse(startStr) : DateTime.now();
          final total = (b['total_amount'] as num?)?.toDouble() ?? 0.0;
          final canCancel = ['confirmed', 'pending_payment'].contains(status);
          final canOpenSession = ['confirmed', 'active'].contains(status);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canOpenSession
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionPage(booking: b),
                        ),
                      ).then((_) => _loadBookings());
                    }
                  : null,
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          Formatters.dateTime(start),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.currency(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    if (canOpenSession || canCancel) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (canCancel)
                            TextButton(
                              onPressed: () => _cancelBooking(b),
                              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                            ),
                          if (canOpenSession) ...[
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              icon: const Icon(Icons.qr_code_scanner, size: 16),
                              label: Text(status == 'active' ? 'Live Session' : 'Check-in'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SessionPage(booking: b),
                                  ),
                                ).then((_) => _loadBookings());
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
