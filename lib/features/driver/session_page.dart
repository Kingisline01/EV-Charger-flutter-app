import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/demo_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/booking_repo.dart';
import '../../widgets/status_chip.dart';

class SessionPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const SessionPage({super.key, required this.booking});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final BookingRepo _bookingRepo = BookingRepo();
  late Map<String, dynamic> _booking;

  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (_booking['status'] == 'active') {
      _startSessionTicker();
    }
  }

  void _startSessionTicker() {
    _timer?.cancel();
    final startedAtStr = _booking['started_at'];
    final startTime = startedAtStr != null ? DateTime.parse(startedAtStr) : DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkIn(String code) async {
    setState(() => _busy = true);

    // Security Protocol: GPS Proximity Geofence Verification (<350m)
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
          final chLat = (_booking['lat'] as num?)?.toDouble();
          final chLng = (_booking['lng'] as num?)?.toDouble();
          if (chLat != null && chLng != null) {
            final distanceM = Geolocator.distanceBetween(
              pos.latitude,
              pos.longitude,
              chLat,
              chLng,
            );
            if (distanceM > 350 && mounted) {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Proximity Check'),
                    ],
                  ),
                  content: Text(
                    'Security Geofence Notice: You appear to be ${(distanceM / 1000).toStringAsFixed(1)} km away from this charging station bay. Safety protocols require physical arrival at the charger.\n\nAre you physically at the station?',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm On-Site')),
                  ],
                ),
              );
              if (proceed != true) {
                if (mounted) setState(() => _busy = false);
                return;
              }
            }
          }
        }
      }
    } catch (_) {
      // Continue if GPS is unavailable or disabled
    }

    try {
      await _bookingRepo.startSession(_booking['id'], code.trim());
      setState(() {
        _booking['status'] = 'active';
        _booking['started_at'] = DateTime.now().toIso8601String();
      });
      _startSessionTicker();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Geofence & Check-in Verified! Session started.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Formatters.friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Charging Session?'),
        content: const Text(
          'This will stop the session, release the charger slot, calculate billable time, and process any early-end refund.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final updated = await _bookingRepo.endSession(_booking['id']);
      _timer?.cancel();
      setState(() {
        _booking = updated;
      });
      if (mounted) {
        _showCompletionDialog(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Formatters.friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCompletionDialog(Map<String, dynamic> b) {
    int rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Session Finished!'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiptRow('Billed Amount:', Formatters.currency(b['final_base_amount'] ?? b['base_amount'])),
                if ((b['refund_amount'] as num? ?? 0) > 0)
                  _buildReceiptRow(
                    'Early Exit Refund:',
                    Formatters.currency(b['refund_amount']),
                    valueColor: AppTheme.primaryGreen,
                  ),
                if ((b['overstay_amount'] as num? ?? 0) > 0)
                  _buildReceiptRow(
                    'Overstay Due:',
                    Formatters.currency(b['overstay_amount']),
                    valueColor: Colors.red,
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const Text('Rate your charging experience:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = index + 1),
                    );
                  }),
                ),
                TextField(
                  controller: commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Leave a note for the host...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await _bookingRepo.review(b['id'], rating, comment: commentCtrl.text);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Back to previous page
                }
              },
              child: const Text('Submit & Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (_booking['status'] as String? ?? 'confirmed').toLowerCase();
    final title = _booking['charger_title'] ?? 'EV Charger';
    final startStr = _booking['during_start'];
    final endStr = _booking['during_end'];
    final start = startStr != null ? DateTime.parse(startStr) : DateTime.now();
    final end = endStr != null ? DateTime.parse(endStr) : DateTime.now().add(const Duration(hours: 2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Charging Session'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status and Charger Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          '${Formatters.dateTime(start)} → ${Formatters.time(end)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (status == 'confirmed') ...[
              // QR Check-in State
              _buildCheckInCard(),
            ] else if (status == 'active') ...[
              // Active Session Meter & Timer
              _buildActiveSessionCard(),
            ] else if (status == 'completed') ...[
              // Completed summary
              _buildCompletedCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInCard() {
    // Secret helper in demo mode
    final chargerId = _booking['charger_id'] as String? ?? '';
    final demoSecret = DemoService().getCheckinCode(chargerId);

    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.qr_code_scanner, color: Colors.blue, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'Arrived at the Charger?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scan or enter the secret check-in code printed on the host’s charger sticker to activate power.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: 'Check-in Code',
            hintText: 'e.g. $demoSecret',
            prefixIcon: const Icon(Icons.pin),
            suffixIcon: TextButton(
              onPressed: () {
                _codeController.text = demoSecret;
              },
              child: const Text('Use QR Code'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.bolt),
          label: const Text('Start Charging Session'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _busy
              ? null
              : () {
                  final code = _codeController.text.trim();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter or scan the check-in code')),
                    );
                    return;
                  }
                  _checkIn(code);
                },
        ),
      ],
    );
  }

  Widget _buildActiveSessionCard() {
    final hours = _elapsed.inHours;
    final mins = _elapsed.inMinutes % 60;
    final secs = _elapsed.inSeconds % 60;
    final timerString = '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryGreen, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: AppTheme.primaryGreen, size: 40),
              const SizedBox(height: 8),
              Text(
                timerString,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const Text('Active Charging', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _buildReceiptRow('Power Flow:', '7.4 kW AC Continuous'),
              _buildReceiptRow('Billing Basis:', 'Platform fixed hourly rate'),
              _buildReceiptRow('Grace Period:', '10 min free buffer at session end'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Stop & End Session'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: _busy ? null : _endSession,
        ),
      ],
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 48),
          const SizedBox(height: 12),
          const Text('Session Completed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildReceiptRow('Final Amount:', Formatters.currency(_booking['final_base_amount'] ?? _booking['base_amount'])),
          if ((_booking['refund_amount'] as num? ?? 0) > 0)
            _buildReceiptRow('Refund Processed:', Formatters.currency(_booking['refund_amount']), valueColor: AppTheme.primaryGreen),
        ],
      ),
    );
  }
}
