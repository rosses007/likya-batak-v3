// LIKYA-V2-013 | Game Table & HUD visual review test (dev-only).
// Renders production BatakGameScreen across game modes and phases to PNG.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:batak_app/engine/scoring_engine.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/providers/store_provider.dart';
import 'package:batak_app/screens/game_screen.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _out = 'artifacts/visual_checks/v2_013';
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

  testWidgets('01_ihaleli_table.png', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.single;
    p.currentPhase = GamePhase.playing;
    p.currentTurnIndex = 0;
    p.bidderIndex = 0;
    p.currentHighestBid = 8;
    p.currentTrump = Suit.spades;
    p.tricksPlayed = 4;
    p.statusMessage = "Sıra sizde, bir kart seçin";
    p.playedCardsByPlayer = {
      1: PlayingCard(suit: Suit.clubs, rank: Rank.king),
      2: PlayingCard(suit: Suit.clubs, rank: Rank.ace),
    };
    p.players[0].tricksWon = 2;
    p.players[1].tricksWon = 1;
    p.players[2].tricksWon = 1;
    p.players[3].tricksWon = 0;

    await _shootScreen(tester, '01_ihaleli_table.png', const Size(390, 844), p);
  });

  testWidgets('02_ihaleli_bidding.png', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.single;
    p.currentPhase = GamePhase.bidding;
    p.biddingTurnIndex = 0;
    p.currentHighestBid = 6;
    p.statusMessage = "İhale sizde, teklif verin";

    await _shootScreen(tester, '02_ihaleli_bidding.png', const Size(390, 844), p);
  });

  testWidgets('03_esli_table.png', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.partner;
    p.currentPhase = GamePhase.playing;
    p.currentTurnIndex = 2;
    p.bidderIndex = 2;
    p.currentHighestBid = 9;
    p.currentTrump = Suit.hearts;
    p.tricksPlayed = 5;
    p.statusMessage = "Arda oynuyor...";
    p.playedCardsByPlayer = {
      1: PlayingCard(suit: Suit.hearts, rank: Rank.jack),
    };
    p.players[0].tricksWon = 2;
    p.players[1].tricksWon = 1;
    p.players[2].tricksWon = 2;
    p.players[3].tricksWon = 0;

    await _shootScreen(tester, '03_esli_table.png', const Size(390, 844), p);
  });

  testWidgets('04_koz_maca_table.png', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.kozMaca;
    p.currentPhase = GamePhase.playing;
    p.currentTurnIndex = 0;
    p.currentTrump = Suit.spades;
    p.tricksPlayed = 2;
    p.statusMessage = "Koz Maça başladı";
    p.playedCardsByPlayer = {
      3: PlayingCard(suit: Suit.spades, rank: Rank.ten),
    };

    await _shootScreen(tester, '04_koz_maca_table.png', const Size(390, 844), p);
  });

  testWidgets('05_round_result.png', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.single;
    p.currentPhase = GamePhase.roundFinished;
    p.currentRound = 1;
    p.totalRounds = 5;
    p.currentTrump = Suit.spades;
    p.bidderIndex = 0;
    p.currentHighestBid = 8;
    p.roundResults = [
      const RoundResult(
        roundNumber: 1,
        bidderIndex: 0,
        bid: 8,
        trump: Suit.spades,
        tricksByPlayer: [8, 3, 2, 0],
        scoreDeltaByPlayer: [82, -30, 20, 10],
        cumulativeScores: [82, -30, 20, 10],
      ),
    ];
    p.cumulativeScores = [82, -30, 20, 10];

    await _shootScreen(tester, '05_round_result.png', const Size(390, 844), p);
  });

  testWidgets('06_compact_table_344.png', (tester) async {
    final p = GameProvider();
    p.gameMode = BatakGameMode.single;
    p.currentPhase = GamePhase.playing;
    p.currentTurnIndex = 0;
    p.bidderIndex = 0;
    p.currentHighestBid = 7;
    p.currentTrump = Suit.diamonds;
    p.tricksPlayed = 3;
    p.statusMessage = "Sıra sizde";
    p.playedCardsByPlayer = {
      1: PlayingCard(suit: Suit.diamonds, rank: Rank.nine),
    };

    await _shootScreen(tester, '06_compact_table_344.png', const Size(344, 700), p);
  });
}
