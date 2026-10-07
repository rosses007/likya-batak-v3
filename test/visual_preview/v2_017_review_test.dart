// LIKYA-V2-013 | Game Table & HUD visual review test (dev-only).
// Renders production BatakGameScreen across game modes and phases to PNG.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:batak_app/screens/game_screen.dart';
import 'package:batak_app/widgets/exposed_dummy_hand.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/realistic_playing_card.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _out = 'artifacts/visual_checks/v2_017';
const double _dpr = 3.0;

class FakeStore extends ChangeNotifier implements StoreProvider {
  @override
  bool isVip = false;
  @override
  List<ProductDetails> products = [];
  @override
  void buyVip() {}
  @override
  Future<void> restorePurchases() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFonts() async {
  const root = 'C:/src/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(bytes('$root/$f'));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons');
  icons.addFont(bytes('$root/materialicons-regular.otf'));
  await icons.load();
}

Widget _wrap(Size size, GlobalKey key, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Theme(
          data: ThemeData(
            fontFamily: 'Roboto',
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14492B)),
          ),
          child: Material(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    );

Future<void> _shootScreen(
  WidgetTester tester,
  String name,
  Size size,
  GameProvider provider,
) async {
  tester.view.physicalSize = size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  final key = GlobalKey();
  final widget = MultiProvider(
    providers: [
      ChangeNotifierProvider<GameProvider>.value(value: provider),
      ChangeNotifierProvider<StoreProvider>(create: (_) => FakeStore()),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BatakGameScreen(),
    ),
  );

  await tester.pumpWidget(_wrap(size, key, widget));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SoundService.soundEnabled = false;
    await _loadFonts();
  });

  testWidgets('human declarer sees dummy open', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.partner;
    p.currentPhase = GamePhase.playing;
    p.bidderIndex = 0;
    p.currentTurnIndex = 0;
    p.statusMessage = 'Koz seçildi. İlk kart sizde.';
    await _shootScreen(tester, '01_human_declarer_dummy_open.png', const Size(390, 844), p);
    expect(find.text('AÇIK EL'), findsOneWidget);
    p.dispose();
  });

  testWidgets('human declarer can play dummy open hand', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.partner;
    p.currentPhase = GamePhase.playing;
    p.bidderIndex = 0;
    p.currentTurnIndex = 2;
    p.statusMessage = 'Eşinizin açık elinden kart oynayın.';
    await _shootScreen(tester, '02_dummy_turn_human_controls.png', const Size(390, 844), p);
    expect(p.isHumanControllerForPlayer(2), isTrue);
    expect(find.text('AÇIK EL'), findsOneWidget);
    final dummyCards = find.descendant(
      of: find.byType(ExposedDummyHand),
      matching: find.byType(RealisticPlayingCardWidget),
    );
    expect(dummyCards, findsNWidgets(13));
    await tester.tap(dummyCards.last);
    await tester.pump();
    expect(p.playedCardsByPlayer.containsKey(2), isTrue);
    p.dispose();
  });

  testWidgets('AI declarer controls human dummy', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.partner;
    p.currentPhase = GamePhase.playing;
    p.bidderIndex = 2;
    p.currentTurnIndex = 0;
    p.statusMessage = 'Açık elinizi ihaleyi kazanan eşiniz yönetiyor.';
    await _shootScreen(tester, '03_ai_declarer_human_dummy.png', const Size(390, 844), p);
    expect(p.shouldAIControlPlayer(0), isTrue);
    expect(find.text('AÇIK EL'), findsOneWidget);
    final ownCards = find.descendant(
      of: find.byType(FannedHandView),
      matching: find.byType(RealisticPlayingCardWidget),
    );
    await tester.tap(ownCards.last);
    await tester.pump();
    expect(p.tableCards, isEmpty);
    p.dispose();
  });
}
