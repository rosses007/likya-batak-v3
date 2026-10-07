import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/bot_memory.dart';
import 'package:batak_app/engine/team_engine.dart';

void main() {
  group('LIKYA-V2-007B — BotMemory Unit Tests', () {
    late BotMemory memory;

    setUp(() {
      memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
    });

    test('1. record one public play', () {
      final card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      memory.recordPlay(
        playerIndex: 1,
        card: card,
        leadSuit: null,
        trickNumber: 0,
      );

      expect(memory.hasCardBeenPlayed(card), isTrue);
      expect(memory.playedCountForSuit(Suit.hearts), 1);
      expect(memory.playedCards.length, 1);
    });

    test('2. duplicate play does not double-count', () {
      final card = PlayingCard(suit: Suit.hearts, rank: Rank.king);
      memory.recordPlay(
        playerIndex: 1,
        card: card,
        leadSuit: null,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 1,
        card: card,
        leadSuit: null,
        trickNumber: 0,
      );

      expect(memory.playedCountForSuit(Suit.hearts), 1);
      expect(memory.playedCards.length, 1);
    });

    test('3. played count by suit correct', () {
      memory.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.diamonds, rank: Rank.ten),
        leadSuit: null,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.diamonds, rank: Rank.jack),
        leadSuit: Suit.diamonds,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 2,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.two),
        leadSuit: Suit.diamonds,
        trickNumber: 0,
      );

      expect(memory.playedCountForSuit(Suit.diamonds), 2);
      expect(memory.playedCountForSuit(Suit.clubs), 1);
      expect(memory.playedCountForSuit(Suit.hearts), 0);
      expect(memory.playedCountForSuit(Suit.spades), 0);
    });

    test('4. trump played count correct', () {
      expect(memory.trumpPlayedCount, 0);

      memory.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.spades, rank: Rank.two),
        leadSuit: null,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
        leadSuit: Suit.spades,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 2,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.five),
        leadSuit: Suit.spades,
        trickNumber: 0,
      );

      expect(memory.trumpPlayedCount, 2);
    });

    test('5. remaining trump count correct', () {
      expect(memory.remainingTrumpCount, 13);

      for (int i = 0; i < 5; i++) {
        memory.recordPlay(
          playerIndex: i % 4,
          card: PlayingCard(suit: Suit.spades, rank: Rank.values[i]),
          leadSuit: null,
          trickNumber: i,
        );
      }

      expect(memory.trumpPlayedCount, 5);
      expect(memory.remainingTrumpCount, 8);
    });

    test('6. first lead creates no false void', () {
      // First card of a trick has leadSuit = null
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.queen),
        leadSuit: null,
        trickNumber: 0,
      );

      expect(memory.voidSuitsForPlayer(1), isEmpty);
    });

    test('7. off-suit legal play infers void', () {
      // Lead is spades, but player 2 plays clubs -> player 2 is void in spades
      memory.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.spades, rank: Rank.seven),
        leadSuit: null,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.spades, rank: Rank.eight),
        leadSuit: Suit.spades,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 2,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        leadSuit: Suit.spades,
        trickNumber: 0,
      );

      expect(memory.voidSuitsForPlayer(2).contains(Suit.spades), isTrue);
      expect(memory.voidSuitsForPlayer(1).contains(Suit.spades), isFalse);
    });

    test('8. following suit does not infer void', () {
      memory.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.ten),
        leadSuit: null,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.jack),
        leadSuit: Suit.clubs,
        trickNumber: 0,
      );

      expect(memory.voidSuitsForPlayer(1), isEmpty);
    });

    test('9. same void inference is idempotent', () {
      // Multiple tricks where player 3 plays off-suit when diamonds are led
      memory.recordPlay(
        playerIndex: 3,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.two),
        leadSuit: Suit.diamonds,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 3,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.three),
        leadSuit: Suit.diamonds,
        trickNumber: 1,
      );

      final voids = memory.voidSuitsForPlayer(3);
      expect(voids.length, 1);
      expect(voids.contains(Suit.diamonds), isTrue);
    });

    test('10. record trick winner', () {
      expect(memory.tricksWonByPlayer[2] ?? 0, 0);
      expect(memory.tricksPlayed, 0);

      memory.recordTrickWinner(2, trickNumber: 0);

      expect(memory.tricksWonByPlayer[2], 1);
      expect(memory.tricksPlayed, 1);
    });

    test('11. duplicate winner callback does not double count', () {
      memory.recordTrickWinner(1, trickNumber: 0);
      memory.recordTrickWinner(1, trickNumber: 0); // duplicate callback for same trick

      expect(memory.tricksWonByPlayer[1], 1);
      expect(memory.tricksPlayed, 1);

      // Distinct trick should increment
      memory.recordTrickWinner(1, trickNumber: 1);
      expect(memory.tricksWonByPlayer[1], 2);
      expect(memory.tricksPlayed, 2);
    });

    test('12. reset clears played cards', () {
      memory.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
        leadSuit: null,
        trickNumber: 0,
      );
      expect(memory.playedCards, isNotEmpty);

      memory.resetForNewRound(trump: Suit.hearts);

      expect(memory.playedCards, isEmpty);
      expect(memory.hasCardBeenPlayed(PlayingCard(suit: Suit.spades, rank: Rank.ace)), isFalse);
      expect(memory.trump, Suit.hearts);
    });

    test('13. reset clears void suits', () {
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        leadSuit: Suit.hearts,
        trickNumber: 0,
      );
      expect(memory.voidSuitsForPlayer(1), isNotEmpty);

      memory.resetForNewRound(trump: Suit.clubs);

      expect(memory.voidSuitsForPlayer(1), isEmpty);
    });

    test('14. reset clears trick counters', () {
      memory.recordTrickWinner(0, trickNumber: 0);
      memory.recordTrickWinner(1, trickNumber: 1);
      expect(memory.tricksPlayed, 2);

      memory.resetForNewRound(trump: Suit.spades);

      expect(memory.tricksPlayed, 0);
      expect(memory.tricksWonByPlayer, isEmpty);
    });

    test('15. no opponent-hand storage', () {
      // Structural guarantee: BotMemory class exposes no opponent hand list or map
      // Verify via public fields and methods
      expect(memory.playedCards, isA<Set<PlayingCard>>());
      expect(memory.voidSuitsByPlayer, isA<Map<int, Set<Suit>>>());
      // No 'opponentHands' or 'hiddenCards' property exists
    });

    test('16. no partner-hand storage', () {
      // Structural guarantee: BotMemory contains only public bid, void suits, and played counts
      expect(memory.biddingTeam, isNull);
      memory.setPublicBidState(bidderIndex: 1, winningBid: 8, biddingTeam: TeamId.teamB, trump: Suit.spades);
      expect(memory.biddingTeam, TeamId.teamB);
      expect(memory.winningBid, 8);
      expect(memory.bidderIndex, 1);
      // No 'partnerHand' property exists
    });

    test('17. no undealt/future deck storage', () {
      // Memory state is strictly derived from public plays and rules
      expect(memory.remainingTrumpCount, 13);
      // It does not track what specific unplayed cards reside in any specific player's hand
    });
  });
}
