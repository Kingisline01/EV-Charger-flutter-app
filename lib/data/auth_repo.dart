import '../core/demo_service.dart';
import '../core/supabase.dart';

class AuthRepo {
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role, // 'driver' | 'host'
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.auth.signUp(
        email: email,
        password: password,
        data: {'role': role, 'full_name': name},
      );
    } else {
      await DemoService().signUp(
        email: email,
        password: password,
        name: name,
        role: role,
      );
    }
  }

  /// Signs in and verifies the account matches the chosen login tab.
  Future<String> signIn({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final p = await supabaseClient!
          .from('profiles')
          .select('role')
          .eq('id', supabaseClient!.auth.currentUser!.id)
          .single();
      final role = p['role'] as String;
      if (role != expectedRole) {
        await supabaseClient!.auth.signOut();
        throw Exception(
          'This account is a $role account. Please use the "$role" login tab.',
        );
      }
      return role;
    } else {
      return await DemoService().signIn(
        email: email,
        password: password,
        expectedRole: expectedRole,
      );
    }
  }

  Future<String?> currentRole() async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final u = supabaseClient!.auth.currentUser;
      if (u == null) return null;
      final p = await supabaseClient!
          .from('profiles')
          .select('role')
          .eq('id', u.id)
          .single();
      return p['role'] as String;
    } else {
      return DemoService().currentUser?.role;
    }
  }

  String? currentUserId() {
    if (isSupabaseConfigured && supabaseClient != null) {
      return supabaseClient!.auth.currentUser?.id;
    }
    return DemoService().currentUser?.id;
  }

  String currentUserName() {
    if (isSupabaseConfigured && supabaseClient != null) {
      return supabaseClient!.auth.currentUser?.userMetadata?['full_name'] ??
          supabaseClient!.auth.currentUser?.email ??
          'User';
    }
    return DemoService().currentUser?.fullName ?? 'EV User';
  }

  Future<void> signOut() async {
    if (isSupabaseConfigured && supabaseClient != null) {
      await supabaseClient!.auth.signOut();
    } else {
      DemoService().signOut();
    }
  }
}
