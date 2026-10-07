import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/models/bot_memory.dart';
import 'package:batak_app/engine/ai_engine.dart';
import 'package:batak_app/engine/team_engine.dart';

void main() {
  group('LIKYA-V2-007B — AI Public Information & Anti-Cheat Tests', () {
    test('1. Bot decision invoked using only bot hand, table, trump, and public memory', () {
      final bot = Player(
        id: 'bot_2',
        name: 'Arda',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
          PlayingCard(suit: Suit.clubs, rank: Rank.seven),
        ],
      );

      final tableCards = [
        PlayingCard(suit: Suit.hearts, rank: Rank.jack),
      ];

      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
      memory.setPublicBidState(
        bidderIndex: 0,
        winningBid: 5,
        biddingTeam: TeamId.teamA,
        trump: Suit.spades,
      );

      // Invoking AIEngine.chooseCard requires ONLY public data and bot's own hand
      final chosenCard = AIEngine.chooseCard(
        bot: bot,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        botPlayerIndex: 1,
        memory: memory,
      );

      expect(chosenCard, isNotNull);
      expect(bot.hand.contains(chosenCard), isTrue);
      // Valid rule: must follow lead suit (hearts) if possible
      expect(chosenCard.suit, Suit.hearts);
      expect(chosenCard.rank, Rank.king);
    });

    test('2. BotMemory exposes NO hidden hands of opponents or partners', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.diamonds);

      // Verify that BotMemory only tracks public sets/counts:
      expect(memory.playedCards, isA<Set<PlayingCard>>());
      expect(memory.voidSuitsByPlayer, isA<Map<int, Set<Suit>>>());
      expect(memory.tricksWonByPlayer, isA<Map<int, int>>());
      expect(memory.tricksPlayed, isA<int>());
      expect(memory.trumpPlayedCount, isA<int>());
      expect(memory.remainingTrumpCount, isA<int>());
      expect(memory.bidderIndex, isNull);
      expect(memory.winningBid, isNull);
      expect(memory.biddingTeam, isNull);
      expect(memory.trump, Suit.diamonds);

      // Type inspection: verify BotMemory contains only derived public information
      expect(memory.hasCardBeenPlayed(PlayingCard(suit: Suit.diamonds, rank: Rank.ace)), isFalse);
      expect(memory.playedCountForSuit(Suit.diamonds), 0);
      expect(memory.voidSuitsForPlayer(0), isEmpty);
    });

    test('3. Bot decision works without opponent hands, partner hand, or undealt deck', () {
      final bot = Player(
        id: 'bot_3',
        name: 'Uğur',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.diamonds, rank: Rank.queen),
          PlayingCard(suit: Suit.diamonds, rank: Rank.nine),
        ],
      );

      final tableCards = <PlayingCard>[]; // Lead play
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        memory: memory,
      );

      expect(card, isNotNull);
      expect(bot.hand.contains(card), isTrue);
    });

    test('4. Void suit inference informs memory without leaking exact cards', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);

      // Trick 0: Lead is hearts. Player 1 plays clubs -> Player 1 is void in hearts
      memory.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        leadSuit: null,
        trickNumber: 0,
      );
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.two),
        leadSuit: Suit.hearts,
        trickNumber: 0,
      );

      // Public memory knows Player 1 has no hearts
      expect(memory.voidSuitsForPlayer(1).contains(Suit.hearts), isTrue);

      // But public memory does NOT know what cards Player 1 holds in clubs, spades, or diamonds
      expect(memory.hasCardBeenPlayed(PlayingCard(suit: Suit.clubs, rank: Rank.king)), isFalse);
      expect(memory.voidSuitsForPlayer(1).contains(Suit.clubs), isFalse);
    });
  });
}
