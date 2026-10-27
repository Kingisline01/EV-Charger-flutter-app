import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool isSupabaseConfigured = false;

SupabaseClient? get supabaseClient {
  try {
    if (isSupabaseConfigured) {
      return Supabase.instance.client;
    }
  } catch (e) {
    debugPrint('Supabase client access error: $e');
  }
  return null;
}

// Fallback convenience getter
SupabaseClient get supabase => supabaseClient!;

Future<void> initSupabase() async {
  const dartUrl = String.fromEnvironment('SUPABASE_URL');
  const dartAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const dartDemoMode = String.fromEnvironment('DEMO_MODE');

  final url = dartUrl.isNotEmpty ? dartUrl : (dotenv.env['SUPABASE_URL'] ?? '');
  final anonKey = dartAnonKey.isNotEmpty ? dartAnonKey : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
  final demoModeStr = dartDemoMode.isNotEmpty ? dartDemoMode : (dotenv.env['DEMO_MODE'] ?? 'false');
  final demoMode = demoModeStr.toLowerCase() == 'true';

  if (!demoMode &&
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR-PROJECT-REF') &&
      !url.contains('your-project-ref')) {
    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(url: url, anonKey: anonKey);
      isSupabaseConfigured = true;
      debugPrint('Supabase initialized successfully.');
      return;
    } catch (e) {
      debugPrint('Failed to initialize Supabase, fallback to Demo Mode: $e');
    }
  }
  isSupabaseConfigured = false;
  debugPrint('Operating in Demo/Local mode.');
}
