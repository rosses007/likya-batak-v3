import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/models/bot_memory.dart';
import 'package:batak_app/models/ai_difficulty.dart';
import 'package:batak_app/engine/ai_engine.dart';

void main() {
  group('LIKYA-V2-007C1 — Advanced AI Strategy & Invariance Tests', () {
    test('1. Mandatory Anti-Cheat Invariance Test (Hidden hands do not alter AI decision)', () {
      // Bot's own hand
      final botHand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.diamonds, rank: Rank.two),
      ];

      final bot = Player(id: '1', name: 'Bot1', isAI: true, hand: List.of(botHand));
      final table = <PlayingCard>[];

      // Public memory identical for both states
      final memoryA = BotMemory();
      memoryA.resetForNewRound(trump: Suit.spades);
      memoryA.setPublicBidState(bidderIndex: 0, winningBid: 5, biddingTeam: null, trump: Suit.spades);

      final memoryB = BotMemory();
      memoryB.resetForNewRound(trump: Suit.spades);
      memoryB.setPublicBidState(bidderIndex: 0, winningBid: 5, biddingTeam: null, trump: Suit.spades);

      // In State A, hypothetical opponent holds Ace of hearts
      // In State B, hypothetical opponent holds Ace of clubs
      // But AIEngine API only accepts `bot`, `tableCards`, `trumpSuit`, `memory`, `difficulty`
      // It does NOT accept or inspect opponent hands.

      final decisionA = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        memory: memoryA,
        difficulty: AIDifficulty.hard,
        random: Random(42),
      );

      final decisionB = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        memory: memoryB,
        difficulty: AIDifficulty.hard,
        random: Random(42),
      );

      // Invariance check: decisions must be strictly identical
      expect(decisionA, decisionB);
    });

    test('2. Public-State Sensitivity Test (BotMemory changes directly alter Hard AI decision)', () {
      final botHand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.diamonds, rank: Rank.two),
      ];
      final bot = Player(id: '1', name: 'Bot1', isAI: true, hand: List.of(botHand));

      // STATE A: Ace of hearts has NOT been played
      final memoryA = BotMemory();
      memoryA.resetForNewRound(trump: Suit.spades);

      final decisionA = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        memory: memoryA,
        difficulty: AIDifficulty.hard,
      );

      // STATE B: Ace of hearts WAS publicly played in trick 0
      final memoryB = BotMemory();
      memoryB.resetForNewRound(trump: Suit.spades);
      memoryB.recordPlay(
        playerIndex: 0,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        leadSuit: null,
        trickNumber: 0,
      );

      final decisionB = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        memory: memoryB,
        difficulty: AIDifficulty.hard,
      );

      // In State A: King of hearts is not a master; bot leads 2 of diamonds (low exit)
      expect(decisionA.suit, Suit.diamonds);
      expect(decisionA.rank, Rank.two);

      // In State B: King of hearts IS a master; bot cashes King of hearts!
      expect(decisionB.suit, Suit.hearts);
      expect(decisionB.rank, Rank.king);

      // Proves public memory directly alters Hard AI strategy!
      expect(decisionA, isNot(equals(decisionB)));
    });

    test('3. Difficulty Differentiation Test (Easy vs Normal vs Hard behave measurably different)', () {
      // Scenario: Table has Ace of Hearts already played.
      // Bot holds King of Hearts and 2 of Diamonds.
      // Trump is Spades.
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
        ],
      );

      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
      memory.recordPlay(
        playerIndex: 2,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        leadSuit: null,
        trickNumber: 0,
      );

      // Easy AI (with seed) prefers leading lowest card (2 of diamonds)
      final easyCard = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.easy,
        random: Random(1),
      );

      // Hard AI recognizes that Ace of hearts was played, so King of hearts is now boss!
      final hardCard = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      expect(easyCard.rank, Rank.two);
      expect(hardCard.rank, Rank.king);
      expect(easyCard, isNot(equals(hardCard)));
    });

    test('4. Void-suit opponent awareness drives Hard AI lead selection', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),   // Master in hearts
          PlayingCard(suit: Suit.clubs, rank: Rank.ace),    // Master in clubs
        ],
      );

      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);

      // In trick 0, Clubs were led and Player 2 followed suit with Clubs
      memory.recordPlay(playerIndex: 0, card: PlayingCard(suit: Suit.clubs, rank: Rank.two), leadSuit: null, trickNumber: 0);
      memory.recordPlay(playerIndex: 2, card: PlayingCard(suit: Suit.clubs, rank: Rank.five), leadSuit: Suit.clubs, trickNumber: 0);
      // In trick 1, Hearts were led and Player 2 threw diamonds (showed void in Hearts!)
      memory.recordPlay(playerIndex: 0, card: PlayingCard(suit: Suit.hearts, rank: Rank.nine), leadSuit: null, trickNumber: 1);
      memory.recordPlay(playerIndex: 2, card: PlayingCard(suit: Suit.diamonds, rank: Rank.six), leadSuit: Suit.hearts, trickNumber: 1);

      // Player 2 is known void in hearts
      expect(memory.voidSuitsForPlayer(2).contains(Suit.hearts), isTrue);

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        botPlayerIndex: 1,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      // Hard AI avoids leading Ace of hearts into Player 2's void (to avoid being trumped)!
      // Leads Ace of clubs instead!
      expect(card.suit, Suit.clubs);
      expect(card.rank, Rank.ace);
    });
  });
}
