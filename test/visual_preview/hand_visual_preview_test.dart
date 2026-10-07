// LIKYA-V2-010A | Off-device visual preview (dev-only, no production changes).
// Renders the real FannedHandView / RealisticPlayingCardWidget to PNG files
// under artifacts/visual_checks/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/realistic_playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _outDir = 'artifacts/visual_checks';
const double _dpr = 3.0;
const double _canvasHeight = 400;

Future<void> _loadFonts() async {
  const root = 'C:/src/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async {
    final b = await File(path).readAsBytes();
    return ByteData.view(Uint8List.fromList(b).buffer);
  }

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

  // Suit glyph fallback (♠ ♥ ♦ ♣) available on Windows dev machines.
  final sym = File('C:/Windows/Fonts/seguisym.ttf');
  if (sym.existsSync()) {
    final symLoader = FontLoader('SegoeSym')..addFont(bytes(sym.path));
    await symLoader.load();
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('$root/materialicons-regular.otf'));
  await icons.load();
}

/// Mixed-suit hand (all four suits, incl. J/Q/K/A and 10) in the same order
/// FannedHandView sorts them (suit index, then power ascending).
List<PlayingCard> _deck(int count) {
  final all = <PlayingCard>[];
  for (var i = 0; i < 52; i++) {
    all.add(PlayingCard(
        suit: Suit.values[i % 4], rank: Rank.values[(i * 5) % 13]));
  }
  final cards = all.take(count).toList();
  cards.sort((a, b) {
    if (a.suit != b.suit) return a.suit.index.compareTo(b.suit.index);
    return a.power.compareTo(b.power);
  });
  return cards;
}

Widget _scene(double width, List<PlayingCard> hand, GlobalKey boundaryKey) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: Size(width, _canvasHeight)),
      child: Theme(
        data: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        child: Material(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: width,
              height: _canvasHeight,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [
                            Color(0xFF2E7D4F),
                            Color(0xFF1B5E3A),
                            Color(0xFF0D3B22),
                          ],
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                              fontFamilyFallback: ['SegoeSym']),
                          child: FannedHandView(
                            hand: hand,
                            isMyTurn: true,
                            isCardValid: (_) => true,
                            onPlayCard: (_) {},
                          ),
                        ),
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
                    child: const Text(
                      'REKLAM ALANI',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _render(
  WidgetTester tester, {
  required String fileName,
  required double width,
  required int cardCount,
  int? tapCardIndexInSorted,
  String? tapPrefix,
}) async {
  final hand = _deck(cardCount);
  final key = GlobalKey();
  tester.view.physicalSize = Size(width * _dpr, _canvasHeight * _dpr);
  tester.view.devicePixelRatio = _dpr;

  await tester.pumpWidget(_scene(width, hand, key));
  await tester.pump();

  if (tapPrefix != null && tapCardIndexInSorted != null) {
    final card = hand[tapCardIndexInSorted];
    final finder = find.byKey(
        ValueKey('${tapPrefix}_${card.suit.name}_${card.rank.name}'));
    expect(finder, findsOneWidget);
    // Tap the exposed top-left index area of the card.
    await tester.tapAt(tester.getTopLeft(finder) + const Offset(14, 14));
    await tester.pump();
  }

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  tearDown(() {});

  for (final w in [344, 390, 430]) {
    testWidgets('hand_13_$w', (tester) async {
      addTearDown(tester.view.reset);
      await _render(tester,
          fileName: 'hand_13_$w.png', width: w.toDouble(), cardCount: 13);
      expect(tester.takeException(), isNull);
    });
    testWidgets('hand_16_$w', (tester) async {
      addTearDown(tester.view.reset);
      await _render(tester,
          fileName: 'hand_16_$w.png', width: w.toDouble(), cardCount: 16);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hand_13_selected_top', (tester) async {
    addTearDown(tester.view.reset);
    await _render(tester,
        fileName: 'hand_13_selected_top.png',
        width: 390,
        cardCount: 13,
        tapPrefix: 'top',
        tapCardIndexInSorted: 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hand_13_selected_bottom', (tester) async {
    addTearDown(tester.view.reset);
    await _render(tester,
        fileName: 'hand_13_selected_bottom.png',
        width: 390,
        cardCount: 13,
        tapPrefix: 'bottom',
        tapCardIndexInSorted: 10);
    expect(tester.takeException(), isNull);
  });

  for (final suit in [Suit.hearts, Suit.spades, Suit.diamonds, Suit.clubs]) {
    testWidgets('faces_${suit.name}', (tester) async {
      addTearDown(tester.view.reset);
      const double gw = 396;
      const double gh = 560;
      tester.view.physicalSize = const Size(gw * _dpr, gh * _dpr);
      tester.view.devicePixelRatio = _dpr;
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(gw, gh)),
            child: Theme(
              data: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
              child: Material(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    width: gw,
                    height: gh,
                    color: const Color(0xFF1B5E3A),
                    padding: const EdgeInsets.all(10),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontFamilyFallback: ['SegoeSym']),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final r in Rank.values)
                            RealisticPlayingCardWidget(
                              card: PlayingCard(suit: suit, rank: r),
                              width: 84,
                              height: 84 * 1.42,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: _dpr);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_outDir/faces_${suit.name}.png');
        await file.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
