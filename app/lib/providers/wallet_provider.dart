import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/wallet.dart';
import 'async_value.dart';

class WalletProvider extends ChangeNotifier {
  WalletProvider(this._api);

  final ApiClient _api;

  AsyncValue<WalletSummary> _summary = const AsyncValue.idle();
  AsyncValue<WalletSummary> get summary => _summary;

  Future<void> load({bool refresh = false}) async {
    _summary = refresh ? _summary.toLoading() : const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.walletData);
      _summary = AsyncValue.data(WalletSummary(
        balance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
        loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
        transactions: listFrom(json, 'transactions', WalletTransaction.fromJson),
      ));
    } on ApiException catch (e) {
      _summary = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  /// Kicks off the gateway session. Returns the payment URL the app opens.
  Future<Map<String, dynamic>> initiateTopUp(double amount) => _api.post(
        Api.initiatePayment,
        body: {'amount': amount, 'productinfo': 'Pulse Wallet Top-up'},
      );

  /// Called once the gateway hands control back to the app.
  Future<double> confirmTopUp({required String txnId, required double amount}) async {
    final json = await _api.post(Api.paymentCallback, query: {
      'txn_id': txnId,
      'amount': amount,
      'status': 'success',
    });
    await load(refresh: true);
    return (json['wallet_balance'] as num?)?.toDouble() ?? 0;
  }
}
