import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const _samplePublisher = 'ca-app-pub-3940256099942544';

class AdIds {
  static const debugBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const debugInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const debugBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const debugInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

  static const productionBannerAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const productionInterstitialAndroid =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const productionBannerIos = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const productionInterstitialIos =
      String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');

  static bool isProductionUnit(String value) =>
      RegExp(r'^ca-app-pub-\d{16}/\d+$').hasMatch(value) &&
      !value.startsWith(_samplePublisher);

  static bool isProductionApp(String value) =>
      RegExp(r'^ca-app-pub-\d{16}~\d+$').hasMatch(value) &&
      !value.startsWith(_samplePublisher);

  static String get banner {
    if (Platform.isAndroid) {
      return kReleaseMode ? productionBannerAndroid : debugBannerAndroid;
    }
    if (Platform.isIOS) {
      return kReleaseMode ? productionBannerIos : debugBannerIos;
    }
    return '';
  }

  static String get interstitial {
    if (Platform.isAndroid) {
      return kReleaseMode
          ? productionInterstitialAndroid
          : debugInterstitialAndroid;
    }
    if (Platform.isIOS) {
      return kReleaseMode ? productionInterstitialIos : debugInterstitialIos;
    }
    return '';
  }
}

abstract class ConsentGateway {
  Future<void> update();
  Future<void> showRequiredForm();
  Future<bool> canRequestAds();
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

class UmpConsentGateway implements ConsentGateway {
  @override
  Future<void> update() {
    final result = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => result.complete(),
      (error) => result.completeError(error),
    );
    return result.future;
  }

  @override
  Future<void> showRequiredForm() async {
    final result = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error == null) {
        result.complete();
      } else {
        result.completeError(error);
      }
    });
    await result.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    final result = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        result.complete();
      } else {
        result.completeError(error);
      }
    });
    await result.future;
  }
}

class AdService extends ChangeNotifier {
  AdService({ConsentGateway? consent, Future<void> Function()? initialize})
      : _consent = consent ?? UmpConsentGateway(),
        _initialize = initialize ??
            (() async {
              await MobileAds.instance.initialize();
            });

  static final AdService instance = AdService();
  final ConsentGateway _consent;
  final Future<void> Function() _initialize;
  Future<void>? _startFuture;
  Future<void>? _initializeFuture;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  bool canShowAds = false;
  bool privacyOptionsRequired = false;

  Future<void> start() => _startFuture ??= _resolveConsent();

  Future<void> _resolveConsent() async {
    try {
      await _consent.update();
      await _consent.showRequiredForm();
    } catch (error) {
      debugPrint('Consent unavailable: $error');
    }
    await _refreshState();
  }

  Future<void> _refreshState() async {
    try {
      privacyOptionsRequired = await _consent.privacyOptionsRequired();
      canShowAds = await _consent.canRequestAds();
      if (canShowAds) await (_initializeFuture ??= _initialize());
    } catch (error) {
      debugPrint('Ad consent check unavailable: $error');
      canShowAds = false;
    }
    notifyListeners();
  }

  Future<void> showPrivacyOptions() async {
    if (!privacyOptionsRequired) return;
    try {
      await _consent.showPrivacyOptions();
    } catch (error) {
      debugPrint('Privacy options unavailable: $error');
    }
    await _refreshState();
  }

  void loadInterstitialAd({required bool isVip}) {
    if (isVip ||
        !canShowAds ||
        _loadingInterstitial ||
        _interstitial != null ||
        (kReleaseMode && !AdIds.isProductionUnit(AdIds.interstitial))) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('Interstitial unavailable: $error');
        },
      ),
    );
  }

  void showInterstitialAd(
      {required bool isVip, required VoidCallback onAdDismissed}) {
    final ad = _interstitial;
    _interstitial = null;
    if (isVip || !canShowAds || ad == null) {
      ad?.dispose();
      onAdDismissed();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        onAdDismissed();
      },
    );
    ad.show();
  }
}
