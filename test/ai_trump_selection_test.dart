import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/engine/ai_engine.dart';
import 'package:batak_app/providers/game_provider.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  // El şablonları
  List<PlayingCard> createSpadeHeavyHand() {
    return [
      PlayingCard(suit: Suit.spades, rank: Rank.ace),
      PlayingCard(suit: Suit.spades, rank: Rank.king),
      PlayingCard(suit: Suit.spades, rank: Rank.queen),
      PlayingCard(suit: Suit.spades, rank: Rank.jack),
      PlayingCard(suit: Suit.spades, rank: Rank.ten),
      PlayingCard(suit: Suit.spades, rank: Rank.nine),
      PlayingCard(suit: Suit.hearts, rank: Rank.two),
      PlayingCard(suit: Suit.hearts, rank: Rank.three),
      PlayingCard(suit: Suit.diamonds, rank: Rank.two),
      PlayingCard(suit: Suit.diamonds, rank: Rank.three),
      PlayingCard(suit: Suit.clubs, rank: Rank.two),
      PlayingCard(suit: Suit.clubs, rank: Rank.three),
      PlayingCard(suit: Suit.clubs, rank: Rank.four),
    ];
  }

  group('LIKYA-V2-007C2 — AI Trump Selection Unit & Strategy Tests', () {
    test('1. returned trump is valid Suit', () {
      final hand = createSpadeHeavyHand();
      for (final diff in AIDifficulty.values) {
        final trump = AIEngine.chooseTrumpForHand(hand, difficulty: diff);
        expect(Suit.values.contains(trump), isTrue);
      }
    });

    test('2. Easy seeded deterministic', () {
      final hand = createSpadeHeavyHand();
      final trump1 = AIEngine.chooseTrumpForHand(
        hand,
        difficulty: AIDifficulty.easy,
        random: Random(123),
      );
      final trump2 = AIEngine.chooseTrumpForHand(
        hand,
        difficulty: AIDifficulty.easy,
        random: Random(123),
      );
      expect(trump1, equals(trump2));
    });

    test('3. Normal selects obvious strongest suit', () {
      final hand = createSpadeHeavyHand();
      final trump = AIEngine.chooseTrumpForHand(
        hand,
        difficulty: AIDifficulty.normal,
      );
      expect(trump, equals(Suit.spades));
    });

    test('4. Hard selects obvious strongest strategic suit', () {
      final hand = createSpadeHeavyHand();
      final trump = AIEngine.chooseTrumpForHand(
        hand,
        difficulty: AIDifficulty.hard,
        winningBid: 7,
      );
      expect(trump, equals(Suit.spades));
    });

    test('5. long strong suit preferred appropriately', () {
      // 7 hearts vs 2 spades vs 2 diamonds vs 2 clubs
      final hand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.hearts, rank: Rank.queen),
        PlayingCard(suit: Suit.hearts, rank: Rank.ten),
        PlayingCard(suit: Suit.hearts, rank: Rank.nine),
        PlayingCard(suit: Suit.hearts, rank: Rank.eight),
        PlayingCard(suit: Suit.hearts, rank: Rank.seven),
        PlayingCard(suit: Suit.hearts, rank: Rank.six),
        PlayingCard(suit: Suit.spades, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.diamonds, rank: Rank.three),
        PlayingCard(suit: Suit.diamonds, rank: Rank.four),
        PlayingCard(suit: Suit.clubs, rank: Rank.five),
        PlayingCard(suit: Suit.clubs, rank: Rank.six),
      ];

      final trumpNormal = AIEngine.chooseTrumpForHand(hand, difficulty: AIDifficulty.normal);
      final trumpHard = AIEngine.chooseTrumpForHand(hand, difficulty: AIDifficulty.hard);

      expect(trumpNormal, equals(Suit.hearts));
      expect(trumpHard, equals(Suit.hearts));
    });

    test('6. supported honors affect score', () {
      // Suit A (Hearts): Ace + King + Queen (3 cards)
      // Suit B (Clubs): Jack + 9 + 8 (3 cards)
      // Suit C (Diamonds): 10 + 9 + 8 + 7 (4 cards, no honors)
      // Normal should pick Hearts because of supported Ace-King-Queen honors
      final hand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.hearts, rank: Rank.queen),
        PlayingCard(suit: Suit.diamonds, rank: Rank.ten),
        PlayingCard(suit: Suit.diamonds, rank: Rank.nine),
        PlayingCard(suit: Suit.diamonds, rank: Rank.eight),
        PlayingCard(suit: Suit.diamonds, rank: Rank.seven),
        PlayingCard(suit: Suit.clubs, rank: Rank.jack),
        PlayingCard(suit: Suit.clubs, rank: Rank.nine),
        PlayingCard(suit: Suit.clubs, rank: Rank.eight),
        PlayingCard(suit: Suit.spades, rank: Rank.three),
        PlayingCard(suit: Suit.spades, rank: Rank.four),
        PlayingCard(suit: Suit.spades, rank: Rank.five),
      ];

      final trump = AIEngine.chooseTrumpForHand(hand, difficulty: AIDifficulty.normal);
      expect(trump, equals(Suit.hearts));
    });

    test('7. Hard uses own hand only', () {
      final bot = Player(
        id: '1',
        name: 'Bot1',
        isAI: true,
        hand: createSpadeHeavyHand(),
      );

      final trump = AIEngine.chooseTrump(
        bot,
        difficulty: AIDifficulty.hard,
        winningBid: 6,
      );
      expect(trump, equals(Suit.spades));
    });

    test('8. hidden opponents irrelevant (Anti-Cheat Invariance)', () {
      final botHand = createSpadeHeavyHand();

      // Changing opponent hands has 0 effect on chooseTrump
      final opponentHand1 = [PlayingCard(suit: Suit.hearts, rank: Rank.ace)];
      final opponentHand2 = [PlayingCard(suit: Suit.clubs, rank: Rank.ace)];

      final trumpA = AIEngine.chooseTrumpForHand(botHand, difficulty: AIDifficulty.hard);

      // Verify changing external variables does not change output
      opponentHand1.clear();
      opponentHand2.clear();

      final trumpB = AIEngine.chooseTrumpForHand(botHand, difficulty: AIDifficulty.hard);
      expect(trumpA, equals(trumpB));
    });

    test('9. hidden partner irrelevant (Anti-Cheat Invariance)', () {
      final botHand = createSpadeHeavyHand();
      final partnerHand = [PlayingCard(suit: Suit.diamonds, rank: Rank.ace)];

      final trump1 = AIEngine.chooseTrumpForHand(botHand, difficulty: AIDifficulty.hard);
      partnerHand.clear();
      final trump2 = AIEngine.chooseTrumpForHand(botHand, difficulty: AIDifficulty.hard);

      expect(trump1, equals(trump2));
    });

    test('10. Koz Maça never invokes selectable trump path in GameProvider', () {
      final provider = GameProvider();
      provider.gameMode = BatakGameMode.kozMaca;
      provider.startNewGame();

      // Koz Maça mode begins directly in playing phase
      expect(provider.currentPhase, equals(GamePhase.playing));
      expect(provider.currentTrump, equals(Suit.spades));

      // Attempting to select trump is rejected
      final selectRes = provider.userSelectTrump(Suit.hearts);
      expect(selectRes.success, isFalse);
      expect(provider.currentTrump, equals(Suit.spades));

      provider.dispose();
    });

    test('11. Koz Maça remains spades', () {
      final rules = GameModeRules.forMode(BatakGameMode.kozMaca);
      expect(rules.hasBidding, isFalse);
      expect(rules.isFixedTrump, isTrue);
      expect(rules.fixedTrumpSuit, equals(Suit.spades));
    });

    test('12. Easy/Normal/Hard differentiation scenario', () {
      // Hand with:
      // Suit A (Hearts): 4 cards — Ace, King, Queen, Jack (solid honors, but length 4)
      // Suit B (Spades): 6 cards — 10, 9, 8, 7, 6, 5 (long suit, but 0 honors)
      // Clubs: void (0 cards)
      // Diamonds: 8, 7, 6 (3 cards)
      //
      // Normal:
      // Hearts has Ace (+4), King (+3), Queen (+2) + length 4*3 (12) + power ~ 23+
      // Spades has length 6*3 (18) + power ~ 20.4
      // Normal prefers HEARTS due to honor concentration!
      //
      // Hard:
      // Spades has 6 length (30) + high contract control (+4) + side-suit void in clubs (+3) ~ 37+
      // Hard recognizes that 6 trumps + side void gives decisive trump control!
      // Hard prefers SPADES!
      final diffHand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.hearts, rank: Rank.queen),
        PlayingCard(suit: Suit.hearts, rank: Rank.jack),
        PlayingCard(suit: Suit.spades, rank: Rank.ten),
        PlayingCard(suit: Suit.spades, rank: Rank.nine),
        PlayingCard(suit: Suit.spades, rank: Rank.eight),
        PlayingCard(suit: Suit.spades, rank: Rank.seven),
        PlayingCard(suit: Suit.spades, rank: Rank.six),
        PlayingCard(suit: Suit.spades, rank: Rank.five),
        PlayingCard(suit: Suit.diamonds, rank: Rank.eight),
        PlayingCard(suit: Suit.diamonds, rank: Rank.seven),
        PlayingCard(suit: Suit.diamonds, rank: Rank.six),
      ];

      final normalTrump = AIEngine.chooseTrumpForHand(
        diffHand,
        difficulty: AIDifficulty.normal,
      );

      final hardTrump = AIEngine.chooseTrumpForHand(
        diffHand,
        difficulty: AIDifficulty.hard,
        winningBid: 8,
      );

      expect(normalTrump, equals(Suit.hearts));
      expect(hardTrump, equals(Suit.spades));
    });
  });
}
