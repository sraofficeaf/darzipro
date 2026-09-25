import 'package:supabase_flutter/supabase_flutter.dart';
import '../payment_provider.dart';

/// Manual payment provider for offline transfers (Bank, JazzCash, Easypaisa).
/// Status is submitted as `awaitingReview` until admin approves in the Approvals queue.
class ManualPaymentProvider implements PaymentProvider {
  const ManualPaymentProvider();

  @override
  String get code => 'manual';

  @override
  String get displayName => 'Bank / Easypaisa / JazzCash';

  @override
  String get iconAsset => 'assets/icons/bank_transfer.svg';

  @override
  List<String> get supportedCurrencies => const ['*'];

  @override
  bool get isInstant => false;

  @override
  Future<PaymentSession> createPayment({
    required String shopId,
    required int amountMinor,
    required String currency,
    required PaymentPurpose purpose,
    Map<String, dynamic>? metadata,
  }) async {
    final client = Supabase.instance.client;

    final receiptUrl = metadata?['receipt_url'] as String?;
    final manualTxId = metadata?['manual_transaction_id'] as String?;
    final usageCycleId = metadata?['usage_cycle_id'] as String?;

    final payload = {
      'shop_id': shopId,
      'provider_code': code,
      'purpose': purpose.name,
      'amount_minor': amountMinor,
      'currency': currency,
      'status': PaymentStatus.awaitingReview.name,
      if (receiptUrl != null && receiptUrl.isNotEmpty)
        'receipt_url': receiptUrl,
      if (manualTxId != null && manualTxId.isNotEmpty)
        'manual_transaction_id': manualTxId,
      if (usageCycleId != null && usageCycleId.isNotEmpty)
        'usage_cycle_id': usageCycleId,
      'metadata': metadata ?? {},
    };

    final row = await client
        .from('unified_payments')
        .insert(payload)
        .select('id, status')
        .single();

    final paymentId = row['id'] as String;
    final statusStr = row['status'] as String? ?? 'awaitingReview';

    return PaymentSession(
      providerReference: paymentId,
      status: PaymentStatus.fromString(statusStr),
      metadata: metadata,
    );
  }

  @override
  Future<PaymentStatus> checkStatus(String providerReference) async {
    final client = Supabase.instance.client;
    try {
      final row = await client
          .from('unified_payments')
          .select('status')
          .eq('id', providerReference)
          .maybeSingle();

      if (row == null) return PaymentStatus.pending;
      final statusStr = row['status'] as String? ?? 'pending';
      return PaymentStatus.fromString(statusStr);
    } catch (_) {
      return PaymentStatus.pending;
    }
  }
}
