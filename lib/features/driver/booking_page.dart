import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';
import '../../data/booking_repo.dart';
import '../../data/vehicle_repo.dart';
import '../../widgets/price_breakdown.dart';
import 'session_page.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> charger;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> quote;

  const BookingPage({
    super.key,
    required this.charger,
    required this.start,
    required this.end,
    required this.quote,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final BookingRepo _bookingRepo = BookingRepo();
  final VehicleRepo _vehicleRepo = VehicleRepo();
  final AuthRepo _authRepo = AuthRepo();

  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  bool _loadingVehicles = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final driverId = _authRepo.currentUserId() ?? '';
    final list = await _vehicleRepo.getVehicles(driverId);
    if (mounted) {
      setState(() {
        _vehicles = list;
        if (list.isNotEmpty) {
          _selectedVehicleId = list.first['id'];
        }
        _loadingVehicles = false;
      });
    }
  }

  Future<void> _handleBookAndPay() async {
    setState(() => _processing = true);
    try {
      final booking = await _bookingRepo.create(
        chargerId: widget.charger['id'],
        vehicleId: _selectedVehicleId,
        start: widget.start,
        end: widget.end,
      );

      // In production, Razorpay SDK opens here:
      await _bookingRepo.createPaymentOrder(booking['id']);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Text('Booking Confirmed!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your slot on "${widget.charger['title']}" is reserved.'),
                const SizedBox(height: 8),
                Text('Time: ${Formatters.dateTime(widget.start)} - ${Formatters.time(widget.end)}'),
                const SizedBox(height: 8),
                const Text(
                  'When you arrive at the charger, scan the physical QR sticker on the wallbox to initiate power delivery.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionPage(booking: booking),
                    ),
                  );
                },
                child: const Text('Go to Session & Check-in'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Formatters.friendlyError(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.charger;
    final q = widget.quote;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Charger summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.ev_station, color: AppTheme.primaryGreen, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['title'] ?? 'EV Charger',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c['address'] ?? '',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Time: ${Formatters.dateTime(widget.start)} → ${Formatters.time(widget.end)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Vehicle Selector
            const Text(
              'Select Vehicle',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loadingVehicles)
              const LinearProgressIndicator()
            else if (_vehicles.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No vehicle saved. You can still book now.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedVehicleId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.directions_car),
                  labelText: 'Your EV',
                ),
                items: _vehicles.map((v) {
                  return DropdownMenuItem<String>(
                    value: v['id'] as String,
                    child: Text('${v['make']} ${v['model']} (${v['plate_number'] ?? 'EV'})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedVehicleId = val),
              ),
            const SizedBox(height: 20),

            // Price Breakdown
            PriceBreakdown(
              hours: (q['hours'] as num).toDouble(),
              rate: (q['rate'] as num).toDouble(),
              baseAmount: (q['base_amount'] as num).toDouble(),
              driverFee: (q['driver_fee'] as num).toDouble(),
              total: (q['total'] as num).toDouble(),
            ),
            const SizedBox(height: 16),

            // Cancellation policy card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancellation & Refund Guarantee',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '• Free full cancellation up to 2 hours before slot.\n• Late cancellation retains 30% to compensate host availability.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              icon: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.payment),
              label: Text(
                _processing ? 'Securing Slot...' : 'Pay ${Formatters.currency(q['total'])} & Confirm',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _processing ? null : _handleBookAndPay,
            ),
          ],
        ),
      ),
    );
  }
}
