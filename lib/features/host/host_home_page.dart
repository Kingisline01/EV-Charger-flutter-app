import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';
import '../../data/charger_repo.dart';
import '../../data/wallet_repo.dart';
import 'add_charger_page.dart';
import 'availability_page.dart';
import 'host_bookings_page.dart';
import 'qr_sticker_page.dart';
import 'wallet_page.dart';

class HostHomePage extends StatefulWidget {
  final VoidCallback? onSignOut;

  const HostHomePage({super.key, this.onSignOut});

  @override
  State<HostHomePage> createState() => _HostHomePageState();
}

class _HostHomePageState extends State<HostHomePage> {
  int _currentIndex = 0;
  final ChargerRepo _chargerRepo = ChargerRepo();
  final WalletRepo _walletRepo = WalletRepo();
  final AuthRepo _authRepo = AuthRepo();

  List<Map<String, dynamic>> _myChargers = [];
  double _balance = 1450.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHostData();
  }

  Future<void> _loadHostData() async {
    setState(() => _loading = true);
    final hostId = _authRepo.currentUserId() ?? '';
    final chargers = await _chargerRepo.getHostChargers(hostId);
    final bal = await _walletRepo.getBalance(hostId);
    if (mounted) {
      setState(() {
        _myChargers = chargers;
        _balance = bal;
        _loading = false;
      });
    }
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
                color: AppTheme.secondaryFixed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront, color: AppTheme.secondary, size: 20),
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
                        color: AppTheme.secondaryFixed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Host Hub', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                    ),
                  ],
                ),
                Text(_authRepo.currentUserName(), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
        actions: [
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
          _buildHubOverview(),
          const HostBookingsPage(),
          const WalletPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primary),
            label: 'Host Hub',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppTheme.primary),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.primary),
            label: 'Wallet',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add Charger'),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddChargerPage()),
                ).then((_) => _loadHostData());
              },
            )
          : null,
    );
  }

  Widget _buildHubOverview() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final primaryCharger = _myChargers.isNotEmpty ? _myChargers.first : null;
    final isPaused = primaryCharger?['is_paused'] == true;

    return RefreshIndicator(
      onRefresh: _loadHostData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Charger Telemetry & Rentable Switch Card (Stitch Screen 4)
          if (primaryCharger != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.ev_station, color: AppTheme.onPrimaryFixed, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              primaryCharger['title'] ?? 'My EV Wallbox',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              primaryCharger['address'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: !isPaused,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) async {
                          await _chargerRepo.setPaused(primaryCharger['id'], !val);
                          _loadHostData();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPaused ? AppTheme.secondaryFixed : AppTheme.primaryFixed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isPaused ? AppTheme.secondary : AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPaused ? 'Paused by Host' : 'Active & Ready for Drivers',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaused ? AppTheme.secondary : AppTheme.onPrimaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user, size: 12, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text('Earthing & MCB Verified', style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.qr_code_2, size: 18),
                        label: const Text('QR Sticker'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QrStickerPage(charger: primaryCharger),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Schedule'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AvailabilityPage(
                                chargerId: primaryCharger['id'],
                                title: primaryCharger['title'],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Wallet & Financial Overview Bento Card (Stitch Screen 4)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Host Earnings Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('UPI Auto-Settled', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onPrimaryFixed)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AVAILABLE FOR INSTANT PAYOUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            Formatters.currency(_balance),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          const Text('+18.4% this wk', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('This Month Gross', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(Formatters.currency(_balance * 2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Text('28 sessions done', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pending Escrow', style: TextStyle(fontSize: 10, color: AppTheme.secondary)),
                                  Text('₹378.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Releases in 14h', style: TextStyle(fontSize: 10, color: AppTheme.secondary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text('Request Instant UPI Payout (${Formatters.currency(_balance)})'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _currentIndex = 2), // Go to Wallet
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Weekly Schedule Notice Banner (Stitch Screen 4)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondaryFixed.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.secondaryFixedDim),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_clock, color: AppTheme.secondary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Personal Block: 18:00 – 20:00',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your own EV charges uninterrupted. Charger remains publicly bookable for the remaining 22 hours each day.',
                        style: TextStyle(fontSize: 12, color: AppTheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
