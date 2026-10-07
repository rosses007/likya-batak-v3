// LIKYA-V2-012 | Main menu widget tests: branding, mode availability,
// responsive widths (no overflow), fake leaderboard removal, VIP price.
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:batak_app/screens/main_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Billing-free StoreProvider stand-in (the real one touches platform plugins).
class FakeStore extends ChangeNotifier implements StoreProvider {
  @override
  bool isVip = false;
  @override
  bool vipStatusLoaded = true;
  @override
  bool isRestoring = false;
  @override
  bool isPurchasePending = false;
  @override
  String? feedback;
  int restoreCalls = 0;
  @override
  List<ProductDetails> products = [];
  @override
  void buyVip() {}
  @override
  Future<void> restorePurchases() async { restoreCalls++; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpMenu(WidgetTester tester, Size size, {FakeStore? store}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameProvider>(create: (_) => GameProvider()),
        ChangeNotifierProvider<StoreProvider>(create: (_) => store ?? FakeStore()),
      ],
      child: const MaterialApp(home: MainMenuScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('restore action calls StoreProvider', (tester) async {
    final store = FakeStore();
    await _pumpMenu(tester, const Size(390, 760), store: store);
    final button = find.text('Satın Alımları Geri Yükle');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(store.restoreCalls, 1);
  });
  const widths = [344.0, 390.0, 430.0];

  for (final w in widths) {
    testWidgets('menu renders without overflow at ${w.toInt()} px', (tester) async {
      await _pumpMenu(tester, Size(w, 760));
      expect(tester.takeException(), isNull);

      // Branding
      expect(find.text('Likya Batak'), findsOneWidget);
      expect(find.text('LİKYA BATAK'), findsNothing);
      expect(find.textContaining('Noir', findRichText: true), findsNothing);
      expect(find.textContaining('NOİR', findRichText: true), findsNothing);
      expect(find.textContaining('Batakçı', findRichText: true), findsNothing);
      expect(find.textContaining('Batak Pro', findRichText: true), findsNothing);

      // Playable + coming-soon modes
      expect(find.byKey(const ValueKey('mode_ihaleli')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_esli')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_koz_maca')), findsOneWidget);
      expect(find.text('Koz Maça'), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_gommeli')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_online')), findsOneWidget);
      // One YAKINDA badge per coming-soon card (+ section label)
      expect(find.text('YAKINDA'), findsNWidgets(3));

      // No mock leaderboard
      expect(find.textContaining('EN İYİLER'), findsNothing);
      expect(find.textContaining('Caner Demir'), findsNothing);
      expect(find.textContaining('Selin'), findsNothing);

      // VIP: no hard-coded price before Billing responds
      expect(find.text('VIP Ol'), findsOneWidget);
      expect(find.text('Reklamları Kaldır'), findsOneWidget);
      expect(find.textContaining('100 TL'), findsNothing);

      // Settings icon is reachable
      expect(find.byTooltip('Ayarlar'), findsOneWidget);
    });
  }

  testWidgets('menu fits a short 344x600 screen (scrolls, no overflow)', (tester) async {
    await _pumpMenu(tester, const Size(344, 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('coming-soon modes do not start a game', (tester) async {
    await _pumpMenu(tester, const Size(390, 760));
    for (final key in ['mode_gommeli', 'mode_online']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.text('ANLADIM'), findsOneWidget);
      await tester.tap(find.text('ANLADIM'));
      await tester.pumpAndSettle();
      expect(find.byType(MainMenuScreen), findsOneWidget);
    }
  });

  testWidgets('settings icon opens the settings dialog', (tester) async {
    await _pumpMenu(tester, const Size(390, 760));
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('AYARLAR & SEÇENEKLER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
