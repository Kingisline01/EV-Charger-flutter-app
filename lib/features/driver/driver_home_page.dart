import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';
import '../../data/charger_repo.dart';
import '../../widgets/charger_card.dart';
import 'charger_detail_page.dart';
import 'my_bookings_page.dart';
import 'vehicles_page.dart';

class DriverHomePage extends StatefulWidget {
  final VoidCallback? onSignOut;

  const DriverHomePage({super.key, this.onSignOut});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _currentIndex = 0;
  final ChargerRepo _chargerRepo = ChargerRepo();
  final AuthRepo _authRepo = AuthRepo();
  final MapController _mapController = MapController();

  // Chennai Central default: 13.0418° N, 80.2341° E (T. Nagar / Chennai Hub)
  LatLng _center = const LatLng(13.0418, 80.2341);
  String _locationLabel = 'Chennai, Tamil Nadu';
  List<Map<String, dynamic>> _chargers = [];
  Map<String, dynamic>? _selectedCharger;
  bool _loading = true;
  bool _showMap = true;
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _loadChargers();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final hasService = await Geolocator.isLocationServiceEnabled();
      if (!hasService) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );

      // Check if within Tamil Nadu / Chennai bounds
      if (mounted) {
        setState(() {
          _center = LatLng(pos.latitude, pos.longitude);
          _locationLabel = (pos.latitude >= 12.8 && pos.latitude <= 13.3 && pos.longitude >= 80.0 && pos.longitude <= 80.4)
              ? 'Near You (Chennai)'
              : 'Current Location';
        });
        _mapController.move(_center, 13.5);
        _loadChargers();
      }
    } catch (_) {
      // Fallback gracefully to Chennai center
    }
  }

  Future<void> _moveTo(LatLng target, String label) async {
    setState(() {
      _center = target;
      _locationLabel = label;
    });
    _mapController.move(target, 13.5);
    await _loadChargers();
  }

  Future<void> _loadChargers() async {
    setState(() => _loading = true);
    try {
      final list = await _chargerRepo.nearby(
        _center.latitude,
        _center.longitude,
        connector: _selectedFilter == 'type2' || _selectedFilter == 'ccs2' || _selectedFilter == 'three_pin'
            ? _selectedFilter
            : null,
      );
      if (mounted) {
        setState(() {
          _chargers = list;
          if (list.isNotEmpty && _selectedCharger == null) {
            _selectedCharger = list.first;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChargerDetail(Map<String, dynamic> c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChargerDetailPage(charger: c),
      ),
    ).then((_) => _loadChargers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: AppTheme.onPrimaryFixed, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('ChargeShare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Driver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onPrimaryFixed)),
                    ),
                  ],
                ),
                Text('Chennai Metro & OMR Corridor', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(_showMap ? Icons.view_list : Icons.map_outlined),
              tooltip: _showMap ? 'List View' : 'Map View',
              onPressed: () => setState(() => _showMap = !_showMap),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _authRepo.signOut();
              widget.onSignOut?.call();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildExploreView(),
          const MyBookingsPage(),
          const VehiclesPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppTheme.primary),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.electric_bolt_outlined),
            selectedIcon: Icon(Icons.electric_bolt, color: AppTheme.primary),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car, color: AppTheme.primary),
            label: 'Vehicles',
          ),
        ],
      ),
    );
  }

  Widget _buildExploreView() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _showMap
                  ? _buildMap()
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      {'label': 'All Chargers (${_chargers.length})', 'val': null},
      {'label': 'Type 2 Wallbox (7.4 kW)', 'val': 'type2'},
      {'label': 'CCS2 Fast', 'val': 'ccs2'},
      {'label': '3.3 kW Socket', 'val': 'three_pin'},
      {'label': '₹120/hr & under', 'val': 'budget'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          // Sub-bar showing location & radius badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(_locationLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Within 15 km', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text('Today, 2:00 PM – 5:00 PM', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Filter pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final item = filters[i];
                final isSelected = _selectedFilter == item['val'];
                return ChoiceChip(
                  label: Text(item['label'] as String, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryFixed,
                  onSelected: (_) {
                    setState(() => _selectedFilter = item['val']);
                    _loadChargers();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.chargeshare.app',
            ),
            MarkerLayer(
              markers: [
                for (final c in _chargers)
                  Marker(
                    point: LatLng(
                      (c['lat'] as num).toDouble(),
                      (c['lng'] as num).toDouble(),
                    ),
                    width: 90,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCharger = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedCharger?['id'] == c['id'] ? AppTheme.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedCharger?['id'] == c['id'] ? AppTheme.primaryFixed : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 14,
                              color: _selectedCharger?['id'] == c['id'] ? Colors.white : AppTheme.primary,
                            ),
                            Text(
                              '₹${(c['price_per_hour'] as num).toInt()}/h',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _selectedCharger?['id'] == c['id'] ? Colors.white : AppTheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Floating Quick GPS & Corridor Switcher
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'btnGps',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                onPressed: _initLocation,
                tooltip: 'My GPS Location',
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              PopupMenuButton<String>(
                tooltip: 'Chennai Corridors',
                color: Colors.white,
                icon: Material(
                  elevation: 2,
                  shape: const CircleBorder(),
                  color: Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.hub_outlined, color: AppTheme.primary, size: 20),
                  ),
                ),
                onSelected: (val) {
                  if (val == 'annanagar') {
                    _moveTo(const LatLng(13.0850, 80.2101), 'Anna Nagar West');
                  } else if (val == 'tnagar') {
                    _moveTo(const LatLng(13.0418, 80.2341), 'T. Nagar Central');
                  } else if (val == 'omr') {
                    _moveTo(const LatLng(12.9010, 80.2279), 'OMR Sholinganallur');
                  } else if (val == 'guindy') {
                    _moveTo(const LatLng(13.0067, 80.2025), 'Guindy Kathipara');
                  } else if (val == 'besant') {
                    _moveTo(const LatLng(13.0003, 80.2667), 'Besant Nagar Coastal');
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'annanagar', child: Text('📍 Anna Nagar (7.4 kW)')),
                  PopupMenuItem(value: 'tnagar', child: Text('📍 T. Nagar (11 kW)')),
                  PopupMenuItem(value: 'omr', child: Text('📍 OMR Sholinganallur (22 kW)')),
                  PopupMenuItem(value: 'guindy', child: Text('📍 Guindy Kathipara (30 kW DC)')),
                  PopupMenuItem(value: 'besant', child: Text('📍 Besant Nagar (3.3 kW)')),
                ],
              ),
            ],
          ),
        ),

        // Bottom Selected Charger Preview Sheet (Stitch Screen 2)
        if (_selectedCharger != null)
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryFixed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, size: 12, color: AppTheme.onPrimaryFixed),
                              SizedBox(width: 4),
                              Text('Verified MCB/RCCB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onPrimaryFixed)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.directions_walk, size: 12, color: AppTheme.outline),
                              SizedBox(width: 4),
                              Text('350m (4 min)', style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCharger!['title'] ?? 'EV Charger',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedCharger!['address'] ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_selectedCharger!['rating_avg'] ?? 4.9}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    ' (${_selectedCharger!['rating_count'] ?? 18} reviews) • Host: ${_selectedCharger!['host_name'] ?? 'Host'}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                              Formatters.currency(_selectedCharger!['price_per_hour'] ?? 120),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
                            ),
                            const Text('/ hour', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('View Details & Book Slot'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _openChargerDetail(_selectedCharger!),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildList() {
    if (_chargers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ev_station_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No chargers found matching your filter'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _chargers.length,
      itemBuilder: (context, i) {
        final c = _chargers[i];
        return ChargerCard(
          charger: c,
          onTap: () => _openChargerDetail(c),
        );
      },
    );
  }
}
