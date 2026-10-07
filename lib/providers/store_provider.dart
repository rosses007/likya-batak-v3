import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const vipMonthlyProductId = 'likya_batak_vip_monthly';

abstract class PurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class PlayPurchaseGateway implements PurchaseGateway {
  final InAppPurchase _client = InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _client.purchaseStream;
  @override
  Future<bool> isAvailable() => _client.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      _client.queryProductDetails(ids);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _client.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<void> restorePurchases() => _client.restorePurchases();
  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _client.completePurchase(purchase);
}

/// Local plausibility only. Server receipt validation is needed for expiry.
abstract class PurchaseVerifier {
  Future<bool> verify(PurchaseDetails purchase);
}

class LocalPurchaseVerifier implements PurchaseVerifier {
  @override
  Future<bool> verify(PurchaseDetails purchase) async =>
      purchase.productID == vipMonthlyProductId &&
      (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) &&
      (purchase.verificationData.serverVerificationData.isNotEmpty ||
          purchase.verificationData.localVerificationData.isNotEmpty);
}

class StoreProvider extends ChangeNotifier {
  final PurchaseGateway _gateway;
  final PurchaseVerifier _verifier;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Set<String> _completed = {};
  final Set<String> _completing = {};
  bool _disposed = false;
  bool _storeRefreshCompleted = false;

  bool isVip = false;
  bool vipStatusLoaded = false;
  bool isPurchasePending = false;
  bool isRestoring = false;
  String? feedback;
  List<ProductDetails> products = [];

  StoreProvider({PurchaseGateway? gateway, PurchaseVerifier? verifier})
      : _gateway = gateway ?? PlayPurchaseGateway(),
        _verifier = verifier ?? LocalPurchaseVerifier() {
    _subscription = _gateway.purchaseStream.listen(
      (events) => unawaited(_onPurchaseUpdate(events)),
      onError: (Object error) {
        isPurchasePending = false;
        isRestoring = false;
        feedback = 'Mağaza bağlantısı kurulamadı.';
        _notify();
      },
    );
    unawaited(_initialize());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      isVip = isVip || (prefs.getBool('isVip') ?? false);
    } catch (error) {
      debugPrint('VIP cache unavailable: $error');
    } finally {
      // Keep ads gated until the initial store refresh has been attempted.
      await refreshEntitlement().timeout(const Duration(seconds: 8), onTimeout: () {});
      // A fresh install offline has no reliable negative entitlement yet.
      vipStatusLoaded = isVip || _storeRefreshCompleted;
      _notify();
    }
  }

  Future<void> refreshEntitlement() async {
    try {
      if (!await _gateway.isAvailable() || _disposed) return;
      final response =
          await _gateway.queryProductDetails({vipMonthlyProductId});
      if (_disposed) return;
      products = response.productDetails
          .where((p) => p.id == vipMonthlyProductId)
          .toList();
      _notify();
      // No restore event does not prove expiry; keep cached VIP until server validation.
      await _gateway.restorePurchases();
      if (_disposed) return;
      _storeRefreshCompleted = true;
      vipStatusLoaded = true;
      _notify();
    } catch (error) {
      debugPrint('VIP refresh unavailable: $error');
    }
  }

  void buyVip() => unawaited(_buyVip());

  Future<void> _buyVip() async {
    if (isPurchasePending || products.isEmpty) return;
    isPurchasePending = true;
    feedback = null;
    _notify();
    try {
      await _gateway.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: products.first));
    } catch (error) {
      isPurchasePending = false;
      feedback = 'Satın alma başlatılamadı.';
      _notify();
    }
  }

  Future<void> restorePurchases() async {
    if (isRestoring) return;
    isRestoring = true;
    feedback = null;
    _notify();
    try {
      if (!await _gateway.isAvailable()) {
        throw StateError('Store unavailable');
      }
      await _gateway.restorePurchases();
      if (!_disposed && isRestoring && feedback == null) {
        feedback = 'Geri yükleme isteği gönderildi.';
      }
    } catch (error) {
      feedback = 'Satın alımlar geri yüklenemedi.';
    } finally {
      isRestoring = false;
      _notify();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> events) async {
    for (final purchase in events) {
      if (_disposed) return;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          isPurchasePending = true;
          feedback = 'Satın alma beklemede.';
          _notify();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          bool valid = false;
          try {
            valid = await _verifier.verify(purchase);
          } catch (error) {
            debugPrint('VIP verification unavailable: $error');
          }
          if (_disposed) return;
          isPurchasePending = false;
          if (!valid) {
            feedback = 'Satın alma doğrulanamadı.';
            _notify();
            break;
          }
          isVip = true;
          vipStatusLoaded = true;
          feedback = purchase.status == PurchaseStatus.restored
              ? 'VIP satın alımı geri yüklendi.'
              : 'VIP üyelik aktif.';
          _notify();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isVip', true);
          } catch (error) {
            debugPrint('VIP cache write unavailable: $error');
          }
          final key =
              '${purchase.productID}:${purchase.purchaseID ?? purchase.transactionDate ?? purchase.verificationData.serverVerificationData}';
          if (purchase.pendingCompletePurchase &&
              !_completed.contains(key) &&
              _completing.add(key)) {
            try {
              await _gateway.completePurchase(purchase);
              _completed.add(key);
            } catch (error) {
              debugPrint('Purchase completion failed: $error');
            } finally {
              _completing.remove(key);
            }
          }
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          isPurchasePending = false;
          feedback = purchase.status == PurchaseStatus.canceled
              ? 'Satın alma iptal edildi.'
              : 'Satın alma başarısız.';
          _notify();
          break;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
