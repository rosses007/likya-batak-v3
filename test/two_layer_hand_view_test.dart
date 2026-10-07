import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/two_row_hand_view.dart';
import 'package:batak_app/widgets/realistic_playing_card.dart';

void main() {
  group('LIKYA-V2-010 | Two-Layer Diagonal Hand Layout (8+8 Stacked)', () {
    List<PlayingCard> createDeck(int count) {
      final suits = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
      final cards = <PlayingCard>[];
      for (var suit in suits) {
        for (var rank in Rank.values) {
          cards.add(PlayingCard(suit: suit, rank: rank));
          if (cards.length == count) return cards;
        }
      }
      return cards;
    }

    testWidgets('1. Hand count <= 8 renders single-row fan layout',
        (WidgetTester tester) async {
      final hand8 = createDeck(8);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: FannedHandView(
                  hand: hand8,
                  isMyTurn: true,
                  isCardValid: (_) => true,
                  onPlayCard: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify all 8 cards are rendered
      expect(find.byType(RealisticPlayingCardWidget), findsNWidgets(8));

      // Verify keys start with single_
      for (var card in hand8) {
        expect(
            find.byKey(
                ValueKey('single_${card.suit.name}_${card.rank.name}')),
            findsOneWidget);
      }
    });

    testWidgets(
        '2. Hand count > 8 (13 cards) automatically switches to 2-layer stacked (8 top + 5 bottom)',
        (WidgetTester tester) async {
      final hand13 = createDeck(13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: FannedHandView(
                  hand: hand13,
                  isMyTurn: true,
                  isCardValid: (_) => true,
                  onPlayCard: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify all 13 cards are rendered
      expect(find.byType(RealisticPlayingCardWidget), findsNWidgets(13));

      // Verify top layer has 8 cards and bottom layer has 5 cards
      int topLayerCount = 0;
      int bottomLayerCount = 0;
      for (var card in hand13) {
        if (find
            .byKey(ValueKey('top_${card.suit.name}_${card.rank.name}'))
            .evaluate()
            .isNotEmpty) {
          topLayerCount++;
        }
        if (find
            .byKey(ValueKey('bottom_${card.suit.name}_${card.rank.name}'))
            .evaluate()
            .isNotEmpty) {
          bottomLayerCount++;
        }
      }

      expect(topLayerCount, equals(8));
      expect(bottomLayerCount, equals(5));
      expect(topLayerCount + bottomLayerCount, equals(13));
    });

    testWidgets('3. Diagonal rotations (Transform.rotate) preserved on cards',
        (WidgetTester tester) async {
      final hand13 = createDeck(13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: FannedHandView(
                  hand: hand13,
                  isMyTurn: true,
                  isCardValid: (_) => true,
                  onPlayCard: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Transforms should exist for fanned cards
      final transforms = tester.widgetList<Transform>(find.byType(Transform));
      expect(transforms.length, greaterThanOrEqualTo(13));
    });

    testWidgets('4. First tap plays a legal card without selection',
        (WidgetTester tester) async {
      final hand13 = createDeck(13);
      PlayingCard? playedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: FannedHandView(
                  hand: hand13,
                  isMyTurn: true,
                  isCardValid: (_) => true,
                  onPlayCard: (card) {
                    playedCard = card;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // A legal card is played on the first tap.
      final bottomCardWidget = find.byType(RealisticPlayingCardWidget).last;
      await tester.tap(bottomCardWidget);
      await tester.pump();

      expect(playedCard, isNotNull);
      expect(
        tester.widgetList<RealisticPlayingCardWidget>(find.byType(RealisticPlayingCardWidget))
            .every((card) => !card.isSelected),
        isTrue,
      );
    });

    testWidgets('5. Invalid play shows snackbar and rejects selection/play',
        (WidgetTester tester) async {
      final hand13 = createDeck(13);
      PlayingCard? playedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: FannedHandView(
                  hand: hand13,
                  isMyTurn: true,
                  isCardValid: (_) => false, // No moves valid
                  onPlayCard: (card) {
                    playedCard = card;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final bottomCardWidget = find.byType(RealisticPlayingCardWidget).last;
      await tester.tap(bottomCardWidget);
      await tester.pump();

      expect(playedCard, isNull);
      expect(find.textContaining('Geçersiz Hamle'), findsOneWidget);
    });

    testWidgets('6. TwoRowHandView delegates to 8+8 stacked diagonal layout',
        (WidgetTester tester) async {
      final hand13 = createDeck(13);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: TwoRowHandView(
                  hand: hand13,
                  isMyTurn: true,
                  isCardValid: (_) => true,
                  onPlayCard: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify all 13 cards rendered via TwoRowHandView
      expect(find.byType(RealisticPlayingCardWidget), findsNWidgets(13));
      expect(find.byType(FannedHandView), findsOneWidget);
    });

    testWidgets(
        '7. Tapping exposed top of an upper layer card plays it immediately',
        (WidgetTester tester) async {
      final hand13 = createDeck(13);
      PlayingCard? playedCard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: FannedHandView(
                  hand: hand13,
                  isMyTurn: true,
                  isCardValid: (_) => true,
                  onPlayCard: (card) {
                    playedCard = card;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final topCardFinder = find.byKey(
          ValueKey('top_${hand13.first.suit.name}_${hand13.first.rank.name}'));
      expect(topCardFinder, findsOneWidget);

      // Tap near the top of the upper layer card (exposed rank/suit area)
      await tester.tapAt(tester.getTopLeft(topCardFinder) + const Offset(15, 15));
      await tester.pump();

      expect(playedCard, isNotNull);
      expect(playedCard, equals(hand13.first));
    });
  });
}
