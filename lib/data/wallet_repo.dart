import '../core/demo_service.dart';
import '../core/supabase.dart';

class WalletRepo {
  Future<double> getBalance(String userId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .single();
      return (res['balance'] as num).toDouble();
    } else {
      return DemoService().getWalletBalance(userId);
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(res as List);
    } else {
      return DemoService().getTransactions(userId);
    }
  }

  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String upiId,
  }) async {
    if (isSupabaseConfigured && supabaseClient != null) {
      final res = await supabaseClient!.rpc(
        'request_payout',
        params: {'p_amount': amount, 'p_upi': upiId},
      );
      return Map<String, dynamic>.from(res as Map);
    } else {
      return DemoService().requestPayout(amount: amount, upiId: upiId);
    }
  }
}
