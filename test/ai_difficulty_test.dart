import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/models/bot_memory.dart';
import 'package:batak_app/engine/ai_engine.dart';
import 'package:batak_app/engine/game_engine.dart';
import 'package:batak_app/engine/team_engine.dart';
import 'package:batak_app/providers/game_provider.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('LIKYA-V2-007C1 — AI Difficulty Unit & Strategy Tests', () {
    test('1. Easy always selects legal card', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.hearts, rank: Rank.five),
          PlayingCard(suit: Suit.spades, rank: Rank.ten),
        ],
      );
      final tableCards = [PlayingCard(suit: Suit.hearts, rank: Rank.ace)];
      final valid = GameEngine.getValidMoves(hand: bot.hand, tableCards: tableCards, trumpSuit: Suit.spades);

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.easy,
        random: Random(123),
      );

      expect(valid.contains(card), isTrue);
    });

    test('2. Normal always selects legal card', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.diamonds, rank: Rank.king),
          PlayingCard(suit: Suit.diamonds, rank: Rank.queen),
        ],
      );
      final tableCards = [PlayingCard(suit: Suit.diamonds, rank: Rank.two)];
      final valid = GameEngine.getValidMoves(hand: bot.hand, tableCards: tableCards, trumpSuit: Suit.spades);

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.normal,
      );

      expect(valid.contains(card), isTrue);
    });

    test('3. Hard always selects legal card', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.clubs, rank: Rank.ace),
          PlayingCard(suit: Suit.spades, rank: Rank.two),
        ],
      );
      final tableCards = [PlayingCard(suit: Suit.clubs, rank: Rank.seven)];
      final valid = GameEngine.getValidMoves(hand: bot.hand, tableCards: tableCards, trumpSuit: Suit.spades);

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.hard,
      );

      expect(valid.contains(card), isTrue);
    });

    test('4. same seed produces same Easy result', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.hearts, rank: Rank.three),
          PlayingCard(suit: Suit.hearts, rank: Rank.four),
          PlayingCard(suit: Suit.hearts, rank: Rank.five),
        ],
      );
      final table = [PlayingCard(suit: Suit.hearts, rank: Rank.six)];

      final card1 = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.easy,
        random: Random(999),
      );

      final card2 = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.easy,
        random: Random(999),
      );

      expect(card1, card2);
    });

    test('5. Easy does not require BotMemory', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [PlayingCard(suit: Suit.spades, rank: Rank.ace)],
      );

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        memory: null, // Zero memory passed
        difficulty: AIDifficulty.easy,
      );

      expect(card, bot.hand.first);
    });

    test('6. Normal selects smallest adequate winner', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.five),
          PlayingCard(suit: Suit.hearts, rank: Rank.eight),
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        ],
      );
      // Table has 6 of hearts. Both 8 and Ace can win.
      // Normal should select 8 (smallest adequate winner), saving the Ace!
      final table = [PlayingCard(suit: Suit.hearts, rank: Rank.six)];

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.normal,
      );

      expect(chosen.suit, Suit.hearts);
      expect(chosen.rank, Rank.eight);
    });

    test('7. Normal avoids unnecessary high winner', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.clubs, rank: Rank.ten),
          PlayingCard(suit: Suit.clubs, rank: Rank.king),
          PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        ],
      );
      // Table has 9 of clubs. 10, King, Ace can all win.
      final table = [PlayingCard(suit: Suit.clubs, rank: Rank.nine)];

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.normal,
      );

      expect(chosen.rank, Rank.ten);
    });

    test('8. Normal preserves higher trump when smaller trump wins', () {
      // Void in clubs, must trump
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.six),
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
        ],
      );
      // Opponent cut with 4 of spades. Bot has 6 and Ace of spades.
      // Smallest winning trump is 6 of spades.
      final table = [
        PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.four),
      ];

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.normal,
      );

      expect(chosen.rank, Rank.six);
    });

    test('9. Hard uses publicly played high-card history', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);

      // Publicly record that Ace of Hearts was already played in trick 0
      memory.recordPlay(
        playerIndex: 1,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        leadSuit: null,
        trickNumber: 0,
      );

      final bot = Player(
        id: '2',
        name: 'Bot2',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.king), // Now a master because Ace is gone!
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
        ],
      );

      // When leading, Hard recognizes King of Hearts is the boss card
      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      expect(chosen.suit, Suit.hearts);
      expect(chosen.rank, Rank.king);
    });

    test('10. Hard uses remaining trump count', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);

      // Play 13 trumps
      for (int i = 0; i < 13; i++) {
        memory.recordPlay(
          playerIndex: i % 4,
          card: PlayingCard(suit: Suit.spades, rank: Rank.values[i]),
          leadSuit: null,
          trickNumber: i,
        );
      }

      expect(memory.remainingTrumpCount, 0);

      // Since remaining trumps is 0, any side master card is 100% safe
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.diamonds, rank: Rank.ace),
          PlayingCard(suit: Suit.clubs, rank: Rank.two),
        ],
      );

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      expect(chosen.suit, Suit.diamonds);
      expect(chosen.rank, Rank.ace);
    });

    test('11. Hard tracks bidder target', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
      memory.setPublicBidState(
        bidderIndex: 0,
        winningBid: 7,
        biddingTeam: null,
        trump: Suit.spades,
      );
      memory.recordTrickWinner(0, trickNumber: 0);
      memory.recordTrickWinner(0, trickNumber: 1);

      expect(memory.bidderIndex, 0);
      expect(memory.winningBid, 7);
      expect(memory.tricksWonByPlayer[0], 2);
    });

    test('12. Hard protects own contract', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
      memory.setPublicBidState(
        bidderIndex: 1, // Bot is bidder
        winningBid: 6,
        biddingTeam: null,
        trump: Suit.spades,
      );

      final bot = Player(
        id: '2',
        name: 'Bot1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
        ],
      );

      // Bot as bidder leads high trump to pull opponent trumps
      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: [],
        trumpSuit: Suit.spades,
        botPlayerIndex: 1,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      expect(chosen.suit, Suit.spades);
      expect(chosen.rank, Rank.ace);
    });

    test('13. Hard pressures opponent contract', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
      memory.setPublicBidState(
        bidderIndex: 0, // Opponent is bidder
        winningBid: 6,
        biddingTeam: null,
        trump: Suit.spades,
      );

      final bot = Player(
        id: '2',
        name: 'Defender',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        ],
      );
      final table = [PlayingCard(suit: Suit.hearts, rank: Rank.queen)];

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        botPlayerIndex: 1,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      // Defends with smallest winner
      expect(chosen.rank, Rank.king);
    });

    test('14. Hard supports partner contract', () {
      final memory = BotMemory();
      memory.resetForNewRound(trump: Suit.spades);
      memory.setPublicBidState(
        bidderIndex: 0, // Partner (Player 0) is bidder
        winningBid: 8,
        biddingTeam: TeamId.teamA,
        trump: Suit.spades,
      );

      final bot = Player(
        id: '3',
        name: 'PartnerBot', // Player 2
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.spades, rank: Rank.five),
        ],
      );

      // Partner (player 0) is winning with Ace of hearts
      final table = [PlayingCard(suit: Suit.hearts, rank: Rank.ace)];
      final played = {0: table[0]};

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        botPlayerIndex: 2,
        playedCardsByPlayer: played,
        leadPlayerIndex: 0,
        memory: memory,
        difficulty: AIDifficulty.hard,
      );

      // Supports partner by sloughing low 2 of hearts, NOT trumping partner
      expect(chosen.suit, Suit.hearts);
      expect(chosen.rank, Rank.two);
    });

    test('15. Hard avoids overtaking winning partner', () {
      final bot = Player(
        id: '3',
        name: 'P2',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.diamonds, rank: Rank.three),
          PlayingCard(suit: Suit.diamonds, rank: Rank.king),
        ],
      );
      // Partner (player 0) played Ace of diamonds
      final table = [PlayingCard(suit: Suit.diamonds, rank: Rank.ace)];
      final played = {0: table[0]};

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        botPlayerIndex: 2,
        playedCardsByPlayer: played,
        leadPlayerIndex: 0,
        difficulty: AIDifficulty.hard,
      );

      // Must follow suit, but throws lowest 3 instead of King
      expect(chosen.rank, Rank.three);
    });

    test('16. Hard avoids unnecessary trump on partner win', () {
      final bot = Player(
        id: '3',
        name: 'P2',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.clubs, rank: Rank.two), // follow suit
          PlayingCard(suit: Suit.spades, rank: Rank.ten), // trump
        ],
      );
      // Partner leads and wins with Ace of clubs.
      final table = [PlayingCard(suit: Suit.clubs, rank: Rank.ace)];
      final played = {0: table[0]};

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        botPlayerIndex: 2,
        playedCardsByPlayer: played,
        leadPlayerIndex: 0,
        difficulty: AIDifficulty.hard,
      );

      // Throws 2 of clubs (follow suit) rather than burning 10 of spades trump
      expect(chosen.suit, Suit.clubs);
      expect(chosen.rank, Rank.two);
    });

    test('17. Hard chooses smallest adequate winning trump', () {
      final bot = Player(
        id: '2',
        name: 'P1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.seven),
          PlayingCard(suit: Suit.spades, rank: Rank.jack),
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
        ],
      );
      // Opponent cut with 5 of spades. Bot must trump higher.
      // Smallest adequate winning trump is 7 of spades.
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ten),
        PlayingCard(suit: Suit.spades, rank: Rank.five),
      ];

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.hard,
      );

      expect(chosen.rank, Rank.seven);
    });

    test('18. Hard strategic discard remains legal', () {
      final bot = Player(
        id: '2',
        name: 'P1',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
          PlayingCard(suit: Suit.diamonds, rank: Rank.five),
        ],
      );
      final table = [
        PlayingCard(suit: Suit.clubs, rank: Rank.ace),
      ];
      final valid = GameEngine.getValidMoves(hand: bot.hand, tableCards: table, trumpSuit: Suit.spades);

      final chosen = AIEngine.chooseCard(
        bot: bot,
        tableCards: table,
        trumpSuit: Suit.spades,
        difficulty: AIDifficulty.hard,
      );

      expect(valid.contains(chosen), isTrue);
    });

    test('19. unknown/missing difficulty setting defaults to Normal', () {
      expect(AIDifficulty.fromString(null), AIDifficulty.normal);
      expect(AIDifficulty.fromString(''), AIDifficulty.normal);
      expect(AIDifficulty.fromString('expert'), AIDifficulty.normal);
      expect(AIDifficulty.fromString('unknown_val'), AIDifficulty.normal);
      expect(AIDifficulty.fromString('easy'), AIDifficulty.easy);
      expect(AIDifficulty.fromString('kolay'), AIDifficulty.easy);
      expect(AIDifficulty.fromString('hard'), AIDifficulty.hard);
      expect(AIDifficulty.fromString('zor'), AIDifficulty.hard);
      expect(AIDifficulty.fromString('normal'), AIDifficulty.normal);
    });

    test('20. difficulty persistence round-trip', () async {
      final provider = GameProvider();
      expect(provider.aiDifficulty, AIDifficulty.normal);

      await provider.setAIDifficulty(AIDifficulty.hard);
      expect(provider.aiDifficulty, AIDifficulty.hard);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GameProvider.aiDifficultyKey), 'hard');

      // Create new provider and verify it restores from prefs
      final provider2 = GameProvider();
      await provider2.loadAIDifficulty();
      expect(provider2.aiDifficulty, AIDifficulty.hard);
    });
  });
}
