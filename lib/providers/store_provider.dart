import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreProvider extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool isVip = false;
  bool vipStatusLoaded = false;
  List<ProductDetails> products = [];
  
  // Mağazalarda oluşturulabilecek abonelik ürün kimlikleri
  final Set<String> _vipProductIds = {
    'likya_batak_vip_monthly',
  };

  StoreProvider() {
    _loadVipStatus();
    // Uygulama açıkken gerçekleşen satın alımları dinle
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
    _loadProducts();
  }

  /// Cihaz hafızasından VIP durumunu kontrol et
  Future<void> _loadVipStatus() async {
    final prefs = await SharedPreferences.getInstance();
    isVip = prefs.getBool('isVip') ?? false;
    vipStatusLoaded = true;
    notifyListeners();
  }

  /// Google Play / App Store'dan ürün fiyatlarını çek
  Future<void> _loadProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;

    final ProductDetailsResponse response = await _iap.queryProductDetails(_vipProductIds);
    if (response.productDetails.isNotEmpty) {
      products = response.productDetails;
      notifyListeners();
    }
  }

  /// Satın alma butonuna basıldığında tetiklenir
  void buyVip() {
    if (products.isEmpty) return;
    
    final ProductDetails productDetails = products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Abonelik olduğu için buyNonConsumable kullanıyoruz
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Satın alımları geri yükleme (Google Play restore)
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint("Restore purchases error: $e");
    }
  }

  /// Satın alma işlemi başarılı olduğunda VIP durumunu aktifleştirir
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased || 
          purchaseDetails.status == PurchaseStatus.restored) {
        
        // İşlem başarılı! VIP yap ve cihaza kaydet
        isVip = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isVip', true);
        
        notifyListeners();

        // Mağazaya işlemi tamamladığımızı bildir
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint("Satın alma hatası: ${purchaseDetails.error}");
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
