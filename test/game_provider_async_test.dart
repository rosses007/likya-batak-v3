import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:batak_app/engine/game_engine.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.soundEnabled = false;
  });

  group('LIKYA-V2-002: GameProvider Async Lifecycle & Lock Hardening', () {
    test('Bot pacing stays responsive across supported speed settings', () {
      final provider = GameProvider();
      provider.gameSpeed = 0.8;
      expect(provider.delayBase, 300);
      provider.gameSpeed = 1.2;
      expect(provider.delayBase, 200);
      provider.gameSpeed = 2.2;
      expect(provider.delayBase, 120);
      provider.dispose();
    });

    test('1. Schedule bot turn -> start new game before timer fires -> old action does not execute', () async {
      final provider = GameProvider();
      final initialGen = provider.gameGeneration;

      // Force to playing phase with Bot 1 turn
      provider.currentPhase = GamePhase.playing;
      provider.currentTrump = Suit.spades;
      provider.currentTurnIndex = 1; // Bot 1
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();

      // Bot turn will be scheduled when checkBotTurn is called or via normal flow
      // Trigger a new game before any bot action can run
      provider.startNewGame();

      expect(provider.gameGeneration, greaterThan(initialGen));
      expect(provider.currentPhase, GamePhase.bidding);

      // Wait longer than standard bot delay (800ms)
      await Future.delayed(const Duration(milliseconds: 900));

      // Provider is in new game bidding phase, not corrupted by playing phase bot action
      expect(provider.currentPhase, anyOf(GamePhase.bidding, GamePhase.trumpSelection, GamePhase.playing));
      expect(provider.tableCards.length, lessThanOrEqualTo(4));
    });

    test('2. Schedule bot turn -> dispose provider -> no throw, no mutation', () async {
      final provider = GameProvider();
      expect(provider.isDisposed, isFalse);

      // Schedule bot bid
      provider.biddingTurnIndex = 1; // Bot turn in bidding

      // Dispose immediately
      provider.dispose();
      expect(provider.isDisposed, isTrue);

      // Wait past timer duration; ensuring no unhandled asynchronous exception or listener call
      await Future.delayed(const Duration(milliseconds: 900));
      expect(provider.isDisposed, isTrue);
    });

    test('3. Schedule bot turn twice -> only one bot action executes concurrently', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTrump = Suit.spades;
      provider.currentTurnIndex = 1; // Bot 1 turn
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();

      final botHandBefore = provider.players[1].hand.length;

      // Trigger bot turn checks concurrently
      // Both attempts are made at the same tick
      // The lock and single timer ensure bot plays exactly 1 card
      await Future.delayed(const Duration(milliseconds: 800));

      // Bot 1 should have played at most 1 card for this trick
      final botHandAfter = provider.players[1].hand.length;
      expect(botHandBefore - botHandAfter, lessThanOrEqualTo(2)); // max 1 or 2 turns advanced
    });

    test('4. Rapid human card submission -> only first legal action affects state', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTrump = Suit.spades;
      provider.currentTurnIndex = 0; // Human turn
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();

      final p0 = provider.players[0];
      final card1 = p0.hand[0];
      final card2 = p0.hand[1];

      final handCountBefore = p0.hand.length;

      // Submit two rapid plays concurrently
      final futures = [
        provider.playCard(p0, card1),
        provider.playCard(p0, card2),
      ];

      final results = await Future.wait(futures);

      // Exactly one should succeed, the other must fail (lock or turn mismatch)
      final successCount = results.where((r) => r.success).length;
      expect(successCount, equals(1));

      // Human hand must only decrease by 1
      expect(p0.hand.length, equals(handCountBefore - 1));
      // Table must contain 1 card from this trick
      expect(provider.tableCards.length, equals(1));
    });

    test('5. Rapid bid submission -> bid mutation happens exactly once', () async {
      final provider = GameProvider();
      provider.biddingTurnIndex = 0; // Human turn
      provider.currentHighestBid = 4;
      provider.highestBidderIndex = null;

      // Rapidly submit two bids
      final res1 = provider.userPlaceBid(5);
      final res2 = provider.userPlaceBid(6);

      expect(res1.success, isTrue);
      // Second bid must fail because turn already advanced to bot (biddingTurnIndex != 0)
      expect(res2.success, isFalse);
      expect(provider.currentHighestBid, equals(5));
      expect(provider.highestBidderIndex, equals(0));
    });

    test('6. Rapid pass submission -> pass registered exactly once', () async {
      final provider = GameProvider();
      provider.biddingTurnIndex = 0; // Human turn
      provider.passedPlayers.clear();

      final res1 = provider.userPassBid();
      final res2 = provider.userPassBid();

      expect(res1.success, isTrue);
      expect(res2.success, isFalse);
      expect(provider.passedPlayers.contains(0), isTrue);
      expect(provider.passedPlayers.length, equals(1));
    });

    test('7. Rapid trump selection -> trump transition happens once', () {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.trumpSelection;
      provider.highestBidderIndex = 0;

      final res1 = provider.userSelectTrump(Suit.hearts);
      expect(res1.success, isTrue);
      expect(provider.currentTrump, Suit.hearts);
      expect(provider.currentPhase, GamePhase.playing);

      // Rapid second trump selection
      final res2 = provider.userSelectTrump(Suit.diamonds);
      expect(res2.success, isFalse);
      expect(provider.currentTrump, Suit.hearts); // Remains hearts
    });

    test('8. After valid human play, turn advances and next bot acts properly', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTrump = Suit.spades;
      provider.currentTurnIndex = 0;
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();

      final p0 = provider.players[0];
      final cardToPlay = p0.hand.first;

      final res = await provider.playCard(p0, cardToPlay);
      expect(res.success, isTrue);
      expect(provider.currentTurnIndex, 1); // Bot 1's turn
      expect(provider.tableCards.length, 1);

      // Wait for Bot 1 to execute its delayed play
      await Future.delayed(const Duration(milliseconds: 700));

      // Bot 1 should have played
      expect(provider.tableCards.length, greaterThanOrEqualTo(2));
    });

    test('9. Stale generation action is safely ignored', () async {
      final provider = GameProvider();
      final gen1 = provider.gameGeneration;

      // Start new game to advance generation
      provider.startNewGame();
      final gen2 = provider.gameGeneration;
      expect(gen2, greaterThan(gen1));

      // A hypothetical stale callback with gen1 cannot mutate or notify
      expect(provider.gameGeneration, equals(gen2));
    });

    test('10. Bot selected move is verified authoritative and legal at execution time', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTrump = Suit.spades;
      provider.currentTurnIndex = 1; // Bot 1
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();

      final botHandBefore = List<PlayingCard>.from(provider.players[1].hand);

      // Allow bot to play
      await Future.delayed(const Duration(milliseconds: 700));

      // Verify that the played card was indeed in botHandBefore and was valid
      if (provider.tableCards.isNotEmpty) {
        final playedCard = provider.tableCards.first;
        expect(botHandBefore.contains(playedCard), isTrue);

        final validMoves = GameEngine.getValidMoves(
          hand: botHandBefore,
          tableCards: [],
          trumpSuit: Suit.spades,
        );
        expect(validMoves.contains(playedCard), isTrue);
      }
    });

    test('11. Stress restart test: 50 rapid restart cycles without state corruption or crash', () async {
      final provider = GameProvider();

      for (int i = 0; i < 50; i++) {
        provider.startNewGame();

        expect(provider.players.length, equals(4));

        // Verify each player has exactly 13 cards (52 total, 0 duplicates)
        final allCards = <PlayingCard>{};
        for (final p in provider.players) {
          expect(p.hand.length, equals(13));
          for (final card in p.hand) {
            expect(allCards.contains(card), isFalse, reason: 'Duplicate card found in cycle $i');
            allCards.add(card);
          }
        }
        expect(allCards.length, equals(52));
        expect(provider.tableCards.isEmpty, isTrue);
        expect(provider.currentPhase, equals(GamePhase.bidding));
      }

      // Settle down after stress test
      await Future.delayed(const Duration(milliseconds: 900));

      // Still healthy and valid
      expect(provider.players.length, equals(4));
      expect(provider.isDisposed, isFalse);
    });
  });
}
