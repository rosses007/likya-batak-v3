import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  // Google resmi test ID'leri ve üretim yapılandırması
  static const String _prodInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const String _prodInterstitialIOS = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _prodInterstitialAndroid;
    } else if (Platform.isIOS) {
      return _prodInterstitialIOS;
    }
    throw UnsupportedError('Desteklenmeyen platform');
  }

  /// Reklamı arka planda yükler
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          debugPrint('Geçiş reklamı başarıyla yüklendi.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Geçiş reklamı yüklenemedi: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Reklamı gösterir. Kapandığında veya hata verdiğinde 'onAdDismissed' fonksiyonunu tetikler.
  static void showInterstitialAd({required Function onAdDismissed}) {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdLoaded = false;
          loadInterstitialAd();
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdLoaded = false;
          onAdDismissed();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint('Reklam hazır değil, direkt geçiş yapılıyor.');
      onAdDismissed();
    }
  }
}
