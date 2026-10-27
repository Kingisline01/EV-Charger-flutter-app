import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/auth_repo.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  int _selectedRoleIndex = 0; // 0 = Driver, 1 = Host
  bool _isSignUp = false;
  bool _busy = false;

  final _emailController = TextEditingController(text: 'driver@chargeshare.com');
  final _passController = TextEditingController(text: 'password123');
  final _nameController = TextEditingController(text: 'Karthik Ramaswamy');

  String _selectedDriverConnector = 'Type 2';
  String _selectedHostTier = '7.4 kW Fast';

  String get _role => _selectedRoleIndex == 0 ? 'driver' : 'host';

  void _switchRole(int index) {
    setState(() {
      _selectedRoleIndex = index;
      if (index == 0) {
        _emailController.text = 'driver@chargeshare.com';
        _nameController.text = 'Karthik Ramaswamy';
      } else {
        _emailController.text = 'host@chargeshare.com';
        _nameController.text = 'Senthil Kumar';
      }
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passController.text;

    // Security protocol: client-side input validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters for security'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = AuthRepo();
      if (_isSignUp) {
        await repo.signUp(
          email: email,
          password: password,
          name: _nameController.text.trim(),
          role: _role,
        );
      }
      await repo.signIn(
        email: email,
        password: password,
        expectedRole: _role,
      );
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Formatters.friendlyError(e)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = _selectedRoleIndex == 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header & Community Grid Emblem (from Stitch Screen 1)
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.bolt, color: AppTheme.primary, size: 36),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'COMMUNITY EV GRID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ChargeShare',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Turn idle chargers into income. Charge anywhere nearby.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Segmented Dual-Role Switcher (Stitch Screen 1)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _switchRole(0),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: isDriver ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isDriver
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.directions_car,
                                        size: 18,
                                        color: isDriver ? AppTheme.primary : AppTheme.outline,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'I need to charge',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isDriver ? FontWeight.bold : FontWeight.w500,
                                          color: isDriver ? AppTheme.onSurface : AppTheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _switchRole(1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: !isDriver ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isDriver
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.home_work,
                                        size: 18,
                                        color: !isDriver ? AppTheme.amberAccent : AppTheme.outline,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'I own a charger',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !isDriver ? FontWeight.bold : FontWeight.w500,
                                          color: !isDriver ? AppTheme.onSurface : AppTheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Role-Isolated Security Guardrail Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.surfaceContainerHigh),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user, color: AppTheme.primary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Role-Isolated Account Security',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Accounts are role-isolated to guarantee automated UPI settlement tiers and host safety protocols.',
                                style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Role Perks Preview Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isDriver ? Icons.bolt : Icons.account_balance_wallet,
                                  size: 16,
                                  color: isDriver ? AppTheme.primary : AppTheme.amberAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDriver ? 'Driver Privileges' : 'Host Monetization',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDriver ? AppTheme.primary : AppTheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDriver ? AppTheme.surfaceContainer : AppTheme.secondaryFixed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isDriver ? '500+ Local Hubs' : 'Instant UPI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDriver ? AppTheme.primary : AppTheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (isDriver) ...[
                          _buildPerkItem(Icons.map, 'Search 500+ verified residential & wallbox chargers nearby.'),
                          _buildPerkItem(Icons.payments, 'Fixed platform billing from ₹55/hr. Zero peak surcharge.'),
                          _buildPerkItem(Icons.lock_clock, 'Guaranteed slot reservation with instant check-in.'),
                        ] else ...[
                          _buildPerkItem(Icons.trending_up, 'Earn ₹2,000–₹5,000/mo while you sleep or work.'),
                          _buildPerkItem(Icons.calendar_today, 'Block personal 2h (e.g. 18-20h), rent other 22h.'),
                          _buildPerkItem(Icons.qr_code_scanner, 'Printable QR sticker & weekly direct auto-payout.'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gateway Authentication Form Container
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isSignUp ? 'Create an Account' : 'Welcome Back',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _isSignUp = !_isSignUp),
                              child: Text(
                                _isSignUp ? 'Sign In' : 'Sign Up',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isSignUp) ...[
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Context-Aware Dynamic Picker
                        Text(
                          isDriver ? 'EV Connector Standard' : 'Charger Power Rating',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.outline),
                        ),
                        const SizedBox(height: 6),
                        if (isDriver)
                          Row(
                            children: ['Type 2', 'CCS2', '15A Socket'].map((item) {
                              final sel = _selectedDriverConnector == item;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: ChoiceChip(
                                    label: Text(item, style: const TextStyle(fontSize: 11)),
                                    selected: sel,
                                    selectedColor: AppTheme.primaryFixed,
                                    onSelected: (_) => setState(() => _selectedDriverConnector = item),
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Row(
                            children: ['3.3 kW', '7.4 kW Fast', '22 kW Pro'].map((item) {
                              final sel = _selectedHostTier == item;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: ChoiceChip(
                                    label: Text(item, style: const TextStyle(fontSize: 11)),
                                    selected: sel,
                                    selectedColor: AppTheme.secondaryFixed,
                                    onSelected: (_) => setState(() => _selectedHostTier = item),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 18),

                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isSignUp
                                      ? 'Create ${_role.toUpperCase()} Account'
                                      : 'Log In as ${_role.toUpperCase()}',
                                ),
                        ),
                        const SizedBox(height: 14),

                        // Google SSO trigger & Demo shortcuts
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('OR TEST INSTANTLY', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.electric_car, size: 16),
                                label: const Text('Test Driver', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  _switchRole(0);
                                  setState(() => _isSignUp = false);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.home_work, size: 16),
                                label: const Text('Test Host', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  _switchRole(1);
                                  setState(() => _isSignUp = false);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legal notice footer
                  Center(
                    child: Text(
                      'By continuing, you agree to ChargeShare’s Terms and Escrow Policies.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerkItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
