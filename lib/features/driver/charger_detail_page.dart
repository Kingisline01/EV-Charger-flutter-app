import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/charger_repo.dart';
import '../../widgets/price_breakdown.dart';
import 'booking_page.dart';

class ChargerDetailPage extends StatefulWidget {
  final Map<String, dynamic> charger;

  const ChargerDetailPage({super.key, required this.charger});

  @override
  State<ChargerDetailPage> createState() => _ChargerDetailPageState();
}

class _ChargerDetailPageState extends State<ChargerDetailPage> {
  final ChargerRepo _chargerRepo = ChargerRepo();

  late DateTime _selectedStart;
  final int _selectedDurationMinutes = 120; // 2 hours default
  Map<String, dynamic>? _quote;
  bool _loadingQuote = false;
  List<Map<String, dynamic>> _busySlots = [];
  int _selectedDateTab = 0; // 0 = Today, 1 = Tomorrow, 2 = Day After

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final nextMin = (now.minute < 30) ? 30 : 60;
    _selectedStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      0,
    ).add(Duration(minutes: nextMin));

    _fetchQuoteAndBusySlots();
  }

  DateTime get _selectedEnd =>
      _selectedStart.add(Duration(minutes: _selectedDurationMinutes));

  Future<void> _fetchQuoteAndBusySlots() async {
    setState(() => _loadingQuote = true);
    try {
      final q = await _chargerRepo.quote(
        widget.charger['id'],
        _selectedStart,
        _selectedEnd,
      );
      final slots = await _chargerRepo.busySlots(
        widget.charger['id'],
        _selectedStart.subtract(const Duration(hours: 12)),
        _selectedEnd.add(const Duration(hours: 12)),
      );
      if (mounted) {
        setState(() {
          _quote = q;
          _busySlots = slots;
          _loadingQuote = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingQuote = false);
    }
  }

  void _setDateOffset(int days) {
    setState(() {
      _selectedDateTab = days;
      final now = DateTime.now().add(Duration(days: days));
      _selectedStart = DateTime(now.year, now.month, now.day, _selectedStart.hour, _selectedStart.minute);
    });
    _fetchQuoteAndBusySlots();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.charger;
    final title = c['title'] ?? 'EV Charger';
    final address = c['address'] ?? '';
    final powerKw = (c['power_kw'] as num?)?.toDouble() ?? 7.4;
    final pricePerHour = (c['price_per_hour'] as num?)?.toDouble() ?? 120.0;
    final connector = (c['connector'] as String? ?? 'type2').toUpperCase();
    final rules = c['rules'] as String? ?? 'Please park within lines.';
    final description = c['description'] as String? ?? '';
    final ratingAvg = (c['rating_avg'] as num?)?.toDouble() ?? 4.9;
    final hostName = c['host_name'] ?? 'Anand R.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charger Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Photo Header with Badges (Stitch Screen 3)
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.ev_station, size: 80, color: AppTheme.primaryFixed.withValues(alpha: 0.6)),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'VERIFIED HOST CHARGER',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('1 / 3 Photos', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryFixed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Residential Wallbox',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onPrimaryFixed),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: AppTheme.tertiary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.currency(pricePerHour),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primary),
                          ),
                          const Text('/ hour', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Superhost Profile Card (Stitch Screen 3)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primaryContainer,
                          child: Text(
                            hostName.substring(0, 1),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(hostName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryFixed,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('SUPERHOST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$ratingAvg ★ (38 bookings) • 100% response',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Chat'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Specifications & Amenities 2x2 Grid (Stitch Screen 3)
                  const Text('SPECIFICATIONS & AMENITIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.8,
                    children: [
                      _buildSpecBadge(Icons.ev_station, '${powerKw.toStringAsFixed(1)} kW AC', '$connector Tethered', AppTheme.primary),
                      _buildSpecBadge(Icons.security, '32A MCB/RCCB', 'Surge Protected', AppTheme.tertiary),
                      _buildSpecBadge(Icons.roofing, 'Covered Port', 'All-weather bay', AppTheme.amberAccent),
                      _buildSpecBadge(Icons.videocam, 'CCTV Guarded', '24/7 security', Colors.blueGrey),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Active Vehicle Selection Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.directions_car, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CHARGING VEHICLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text('Tata Nexon EV Empowered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('MH 02 EV 1234 • Type 2 Match', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Choose Slot & Timeline Picker (Stitch Screen 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Choose Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            _busySlots.isEmpty
                                ? '30-min precision intervals'
                                : '${_busySlots.length} reserved slots today',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedDurationMinutes ~/ 60}h selected',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.onPrimaryFixed),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Date Row Selector
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Today')),
                          selected: _selectedDateTab == 0,
                          selectedColor: AppTheme.primaryFixed,
                          onSelected: (_) => _setDateOffset(0),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Tomorrow')),
                          selected: _selectedDateTab == 1,
                          selectedColor: AppTheme.primaryFixed,
                          onSelected: (_) => _setDateOffset(1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Day After')),
                          selected: _selectedDateTab == 2,
                          selectedColor: AppTheme.primaryFixed,
                          onSelected: (_) => _setDateOffset(2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Slot Timeline Legend (Stitch Screen 3)
                  Row(
                    children: [
                      _buildLegendItem(AppTheme.primary, 'Selected'),
                      const SizedBox(width: 12),
                      _buildLegendItem(const Color(0xFFE2E8F0), 'Booked'),
                      const SizedBox(width: 12),
                      _buildLegendItem(AppTheme.secondaryFixedDim, 'Host Reserved (18-20h)'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Interactive Slot Grid (Stitch Screen 3)
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      _buildSlotTile('10:00', 'Booked', isBooked: true),
                      _buildSlotTile('11:00', 'Booked', isBooked: true),
                      _buildSlotTile('12:00', 'Booked', isBooked: true),
                      _buildSlotTile('13:00', 'Avail', isAvail: true),
                      _buildSlotTile('14:00', 'Active', isSelected: true),
                      _buildSlotTile('15:00', 'Active', isSelected: true),
                      _buildSlotTile('16:00', 'Active', isSelected: true),
                      _buildSlotTile('17:00', 'Avail', isAvail: true),
                      _buildSlotTile('18:00', 'Host Reserved', isHostReserved: true),
                      _buildSlotTile('19:00', 'Host Reserved', isHostReserved: true),
                      _buildSlotTile('20:00', 'Avail', isAvail: true),
                      _buildSlotTile('21:00', 'Avail', isAvail: true),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price Breakdown
                  if (_loadingQuote)
                    const Center(child: CircularProgressIndicator())
                  else if (_quote != null)
                    PriceBreakdown(
                      hours: (_quote!['hours'] as num).toDouble(),
                      rate: (_quote!['rate'] as num).toDouble(),
                      baseAmount: (_quote!['base_amount'] as num).toDouble(),
                      driverFee: (_quote!['driver_fee'] as num).toDouble(),
                      total: (_quote!['total'] as num).toDouble(),
                    ),

                  const SizedBox(height: 16),
                  if (rules.isNotEmpty) ...[
                    const Text('House Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(rules, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total (inc. platform fee)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    Formatters.currency(_quote?['total'] ?? (pricePerHour * 2 * 1.05)),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.bolt),
                  label: const Text('Instant Reserve'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _quote == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingPage(
                                charger: widget.charger,
                                start: _selectedStart,
                                end: _selectedEnd,
                                quote: _quote!,
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSlotTile(String time, String status, {bool isSelected = false, bool isBooked = false, bool isAvail = false, bool isHostReserved = false}) {
    Color bg = Colors.white;
    Color fg = AppTheme.onSurface;

    if (isSelected) {
      bg = AppTheme.primary;
      fg = Colors.white;
    } else if (isBooked) {
      bg = const Color(0xFFF1F5F9);
      fg = Colors.grey;
    } else if (isHostReserved) {
      bg = AppTheme.secondaryFixed.withValues(alpha: 0.6);
      fg = AppTheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: fg)),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              color: isSelected ? AppTheme.primaryFixed : (isHostReserved ? AppTheme.secondary : Colors.grey),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
