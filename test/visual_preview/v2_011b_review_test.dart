// LIKYA-V2-011B | Visual review sheets (dev-only). Renders real production
// card widgets to PNG under artifacts/visual_checks/v2_011b/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/realistic_playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _out = 'artifacts/visual_checks/v2_011b';
const double _dpr = 3.0;
const Color _felt = Color(0xFF1B5E3A);

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
}

Widget _wrap(Size size, GlobalKey key, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Theme(
          data: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
          child: Material(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    );

Future<void> _shoot(
    WidgetTester tester, String name, Size size, Widget child,
    {Future<void> Function()? interact}) async {
  tester.view.physicalSize = size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  final key = GlobalKey();
  await tester.pumpWidget(_wrap(size, key, child));
  await tester.pump();
  if (interact != null) await interact();
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: _dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
  expect(tester.takeException(), isNull);
}

Widget _cardGrid(List<PlayingCard> cards, double cw, int perRow) => Container(
      color: _felt,
      padding: const EdgeInsets.all(14),
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        children: [
          for (final c in cards)
            RealisticPlayingCardWidget(card: c, width: cw, height: cw * 1.42),
        ],
      ),
    );

Size _gridSize(int n, double cw, int perRow) {
  final rows = (n / perRow).ceil();
  return Size(28 + perRow * cw + (perRow - 1) * 12,
      28 + rows * cw * 1.42 + (rows - 1) * 14);
}

List<PlayingCard> _hand(int count) {
  final all = <PlayingCard>[];
  for (var i = 0; i < 52; i++) {
    all.add(PlayingCard(
        suit: Suit.values[i % 4], rank: Rank.values[(i * 5) % 13]));
  }
  final cards = all.take(count).toList()
    ..sort((a, b) => a.suit != b.suit
        ? a.suit.index.compareTo(b.suit.index)
        : a.power.compareTo(b.power));
  return cards;
}

Widget _handScene(List<PlayingCard> hand) => Column(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [Color(0xFF2E7D4F), Color(0xFF1B5E3A), Color(0xFF0D3B22)],
              ),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: FannedHandView(
              hand: hand,
              isMyTurn: true,
              isCardValid: (_) => true,
              onPlayCard: (_) {},
            ),
          ),
        ),
        Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              Color(0xFF381504),
              Color(0xFFD4A373),
              Color(0xFF381504),
            ]),
          ),
        ),
        Container(
          height: 57,
          color: Colors.black,
          alignment: Alignment.center,
          child: const Text('REKLAM ALANI',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
        ),
      ],
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  const suitsOrder = {
    '01_spades_full_deck.png': Suit.spades,
    '02_hearts_full_deck.png': Suit.hearts,
    '03_diamonds_full_deck.png': Suit.diamonds,
    '04_clubs_full_deck.png': Suit.clubs,
  };

  suitsOrder.forEach((name, suit) {
    testWidgets(name, (tester) async {
      addTearDown(tester.view.reset);
      final cards = [for (final r in Rank.values) PlayingCard(suit: suit, rank: r)];
      await _shoot(tester, name, _gridSize(13, 100, 5), _cardGrid(cards, 100, 5));
    });
  });

  testWidgets('05_court_cards_large.png', (tester) async {
    addTearDown(tester.view.reset);
    final cards = [
      for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
        for (final r in [Rank.jack, Rank.queen, Rank.king])
          PlayingCard(suit: s, rank: r),
    ];
    await _shoot(tester, '05_court_cards_large.png', _gridSize(12, 160, 3),
        _cardGrid(cards, 160, 3));
  });

  testWidgets('06_aces_large.png', (tester) async {
    addTearDown(tester.view.reset);
    final cards = [
      for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
        PlayingCard(suit: s, rank: Rank.ace),
    ];
    await _shoot(tester, '06_aces_large.png', _gridSize(4, 160, 2),
        _cardGrid(cards, 160, 2));
  });

  testWidgets('07_hand_13_390.png', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, '07_hand_13_390.png', const Size(390, 400),
        _handScene(_hand(13)));
  });

  testWidgets('08_hand_16_390.png', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, '08_hand_16_390.png', const Size(390, 400),
        _handScene(_hand(16)));
  });

  testWidgets('09_selected_card_390.png', (tester) async {
    addTearDown(tester.view.reset);
    final hand = _hand(13);
    await _shoot(tester, '09_selected_card_390.png', const Size(390, 400),
        _handScene(hand), interact: () async {
      final c = hand[2];
      final f = find.byKey(ValueKey('top_${c.suit.name}_${c.rank.name}'));
      expect(f, findsOneWidget);
      await tester.tapAt(tester.getTopLeft(f) + const Offset(14, 14));
      await tester.pump();
    });
  });
}
