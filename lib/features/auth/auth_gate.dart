import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../data/auth_repo.dart';
import '../driver/driver_home_page.dart';
import '../host/host_home_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepo _authRepo = AuthRepo();
  Key _refreshKey = UniqueKey();

  void _refresh() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isSupabaseConfigured && supabaseClient != null) {
      return StreamBuilder<AuthState>(
        key: _refreshKey,
        stream: supabaseClient!.auth.onAuthStateChange,
        builder: (context, _) {
          if (supabaseClient!.auth.currentSession == null) {
            return LoginPage(onLoginSuccess: _refresh);
          }
          return FutureBuilder<String?>(
            future: _authRepo.currentRole(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final role = snap.data;
              if (role == 'host') {
                return HostHomePage(onSignOut: _refresh);
              }
              return DriverHomePage(onSignOut: _refresh);
            },
          );
        },
      );
    } else {
      // Demo Mode / In-memory Mode
      return FutureBuilder<String?>(
        key: _refreshKey,
        future: _authRepo.currentRole(),
        builder: (context, snap) {
          final role = snap.data;
          if (role == null) {
            return LoginPage(onLoginSuccess: _refresh);
          }
          if (role == 'host') {
            return HostHomePage(onSignOut: _refresh);
          }
          return DriverHomePage(onSignOut: _refresh);
        },
      );
    }
  }
}
