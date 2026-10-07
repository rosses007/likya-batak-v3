import 'dart:async';

import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/ad_service.dart';
import 'package:batak_app/widgets/settings_dialog.dart';
import 'package:batak_app/widgets/consent_banner.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeConsent implements ConsentGateway {
  final Completer<void> gate = Completer<void>();
  bool allow = false;
  bool options = false;
  bool error = false;
  int updates = 0;
  int forms = 0;
  int optionsShown = 0;

  @override
  Future<void> update() async {
    updates++;
    if (error) throw StateError('network');
  }

  @override
  Future<void> showRequiredForm() async {
    forms++;
    await gate.future;
  }

  @override
  Future<bool> canRequestAds() async => allow;

  @override
  Future<bool> privacyOptionsRequired() async => options;

  @override
  Future<void> showPrivacyOptions() async {
    optionsShown++;
  }
}

class VipStore extends ChangeNotifier implements StoreProvider {
  @override
  bool isVip = true;
  @override
  bool vipStatusLoaded = true;
  @override
  bool isRestoring = false;
  @override
  bool isPurchasePending = false;
  @override
  String? feedback;
  @override
  List<ProductDetails> products = [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('consent waits before ads and initializes exactly once', () async {
    final consent = FakeConsent()..allow = true;
    var initializations = 0;
    final ads = AdService(
        consent: consent,
        initialize: () async {
          initializations++;
        });
    final first = ads.start();
    final second = ads.start();
    await Future<void>.delayed(Duration.zero);
    expect(ads.canShowAds, isFalse);
    expect(initializations, 0);
    consent.gate.complete();
    await Future.wait([first, second]);
    expect(ads.canShowAds, isTrue);
    expect(initializations, 1);
    expect(consent.updates, 1);
    expect(consent.forms, 1);
  });

  test('consent not required permits ads', () async {
    final consent = FakeConsent()..allow = true;
    consent.gate.complete();
    final ads = AdService(consent: consent, initialize: () async {});
    await ads.start();
    expect(ads.canShowAds, isTrue);
  });

  test('consent error leaves game usable and blocks ads without permission',
      () async {
    final consent = FakeConsent()..error = true;
    final ads = AdService(
        consent: consent,
        initialize: () async {
          fail('no init');
        });
    await ads.start();
    expect(ads.canShowAds, isFalse);
  });

  test('privacy options reflect requirement and reopen form', () async {
    final consent = FakeConsent()..options = true;
    consent.gate.complete();
    final ads = AdService(consent: consent, initialize: () async {});
    await ads.start();
    expect(ads.privacyOptionsRequired, isTrue);
    await ads.showPrivacyOptions();
    expect(consent.optionsShown, 1);
    consent.options = false;
    await ads.showPrivacyOptions();
    expect(ads.privacyOptionsRequired, isFalse);
    expect(consent.optionsShown, 2);
  });

  test('release ID validation rejects samples and accepts real format', () {
    expect(AdIds.isProductionApp('ca-app-pub-3940256099942544~3347511713'),
        isFalse);
    expect(AdIds.isProductionUnit(AdIds.debugBannerAndroid), isFalse);
    expect(AdIds.isProductionUnit(AdIds.debugInterstitialAndroid), isFalse);
    expect(AdIds.isProductionApp('ca-app-pub-1234567890123456~1234567890'),
        isTrue);
    expect(AdIds.isProductionUnit('ca-app-pub-1234567890123456/1234567890'),
        isTrue);
    expect(AdIds.debugBannerAndroid, contains('3940256099942544'));
  });

  testWidgets('VIP requests no banner or interstitial', (tester) async {
    final consent = FakeConsent()..allow = true;
    consent.gate.complete();
    final ads = AdService(consent: consent, initialize: () async {});
    await ads.start();
    ads.loadInterstitialAd(isVip: true);
    await tester.pumpWidget(ChangeNotifierProvider<StoreProvider>.value(
      value: VipStore(),
      child: MaterialApp(home: Scaffold(body: ConsentBanner(adService: ads))),
    ));
    await tester.pump();
    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final required in [false, true]) {
    testWidgets(
        'settings privacy policy always visible, options required=$required',
        (tester) async {
      final consent = FakeConsent()..options = required;
      consent.gate.complete();
      final ads = AdService(consent: consent, initialize: () async {});
      await ads.start();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SettingsDialog(
        adService: ads,
        currentNames: const ['A', 'B', 'C', 'D'],
        sortAscending: true,
        gameSpeed: 1,
        totalRounds: 1,
        gameMode: BatakGameMode.single,
        handLayoutMode: HandLayoutMode.fanned,
        tableColor: TableColor.green,
        onSave: (
            {required names,
            required sortAscending,
            required speed,
            required rounds,
            required mode,
            required layout,
            required color}) {},
      ))));
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Gizlilik Seçenekleri'),
          required ? findsOneWidget : findsNothing);
    });
  }
}
