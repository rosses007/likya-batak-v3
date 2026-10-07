import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:batak_app/widgets/fanned_hand_view.dart';
import 'package:batak_app/widgets/game_action_panels.dart';
import 'package:batak_app/widgets/realistic_playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.soundEnabled = false;
  });

  for (final mode in [
    BatakGameMode.single,
    BatakGameMode.partner,
    BatakGameMode.kozMaca,
  ]) {
    test('V2-016 $mode legal card is played on first submission', () async {
      final provider = GameProvider();
      provider.gameMode = mode;
      provider.startNewGame();
      provider.currentPhase = GamePhase.playing;
      provider.currentTurnIndex = 0;
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();
      final player = provider.players[0];
      final card = provider.getValidMovesForPlayer(player).first;
      final before = player.hand.length;

      final result = await provider.playCard(player, card);

      expect(result.success, isTrue);
      expect(player.hand.length, before - 1);
      expect(provider.tableCards, [card]);
      expect(provider.currentTurnIndex, 1);
      provider.dispose();
    });
  }

  test('V2-016 invalid play leaves game state intact', () async {
    final provider = GameProvider();
    provider.currentPhase = GamePhase.playing;
    provider.currentTurnIndex = 1;
    final player = provider.players[0];
    final card = player.hand.first;
    final before = List<PlayingCard>.of(player.hand);
    final result = await provider.playCard(player, card);
    expect(result.success, isFalse);
    expect(player.hand, before);
    expect(provider.tableCards, isEmpty);
    expect(provider.currentTurnIndex, 1);
    provider.dispose();
  });

  testWidgets('V2-016 PAS is above number bids and keeps bid limits', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: BiddingKeypadWidget(
            currentHighestBid: 8,
            onBidSelected: (_) {},
            onPass: () {},
          ),
        ),
      ),
    ));
    final pass = find.text('PAS');
    expect(pass, findsOneWidget);
    expect(tester.getTopLeft(pass).dy, lessThan(tester.getTopLeft(find.text('5')).dy));
    final passInk = find.ancestor(of: pass, matching: find.byType(InkWell)).first;
    expect(tester.getSize(passInk).height, greaterThanOrEqualTo(48));
    final disabled = find.ancestor(of: find.text('8'), matching: find.byType(InkWell)).first;
    final enabled = find.ancestor(of: find.text('9'), matching: find.byType(InkWell)).first;
    expect(tester.widget<InkWell>(disabled).onTap, isNull);
    expect(tester.widget<InkWell>(enabled).onTap, isNotNull);
  });

  for (final width in [344.0, 390.0, 430.0]) {
    for (final count in [13, 16]) {
      testWidgets('V2-016 $count cards fit ${width.toInt()} px', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final hand = <PlayingCard>[
          for (final suit in Suit.values)
            for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
        ].take(count).toList();
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
        ));
        expect(tester.takeException(), isNull);
        final cards = find.byType(RealisticPlayingCardWidget);
        expect(cards, findsNWidgets(count));
        for (final element in cards.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(-1));
          expect(rect.right, lessThanOrEqualTo(width + 1));
        }
        expect(find.byKey(const ValueKey('top_spades_two')), findsOneWidget);
      });
    }
  }
}
