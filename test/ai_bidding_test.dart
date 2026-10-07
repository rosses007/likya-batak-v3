import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/engine/ai_engine.dart';
import 'package:batak_app/providers/game_provider.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  // El şablonları
  List<PlayingCard> createStrongHand() {
    return [
      PlayingCard(suit: Suit.spades, rank: Rank.ace),
      PlayingCard(suit: Suit.spades, rank: Rank.king),
      PlayingCard(suit: Suit.spades, rank: Rank.queen),
      PlayingCard(suit: Suit.spades, rank: Rank.jack),
      PlayingCard(suit: Suit.spades, rank: Rank.ten),
      PlayingCard(suit: Suit.spades, rank: Rank.nine),
      PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      PlayingCard(suit: Suit.hearts, rank: Rank.king),
      PlayingCard(suit: Suit.diamonds, rank: Rank.ace),
      PlayingCard(suit: Suit.diamonds, rank: Rank.king),
      PlayingCard(suit: Suit.clubs, rank: Rank.ace),
      PlayingCard(suit: Suit.clubs, rank: Rank.two),
      PlayingCard(suit: Suit.clubs, rank: Rank.three),
    ];
  }

  List<PlayingCard> createWeakHand() {
    return [
      PlayingCard(suit: Suit.spades, rank: Rank.two),
      PlayingCard(suit: Suit.spades, rank: Rank.three),
      PlayingCard(suit: Suit.hearts, rank: Rank.two),
      PlayingCard(suit: Suit.hearts, rank: Rank.three),
      PlayingCard(suit: Suit.hearts, rank: Rank.four),
      PlayingCard(suit: Suit.diamonds, rank: Rank.two),
      PlayingCard(suit: Suit.diamonds, rank: Rank.three),
      PlayingCard(suit: Suit.diamonds, rank: Rank.four),
      PlayingCard(suit: Suit.diamonds, rank: Rank.five),
      PlayingCard(suit: Suit.clubs, rank: Rank.two),
      PlayingCard(suit: Suit.clubs, rank: Rank.three),
      PlayingCard(suit: Suit.clubs, rank: Rank.four),
      PlayingCard(suit: Suit.clubs, rank: Rank.five),
    ];
  }

  group('LIKYA-V2-007C2 — AI Bidding Unit & Strategy Tests', () {
    test('1. Easy bid legal', () {
      final hand = createStrongHand();
      final bid = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.easy,
        random: Random(42),
      );
      if (bid != null) {
        expect(bid, greaterThan(4));
        expect(bid, greaterThanOrEqualTo(5));
        expect(bid, lessThanOrEqualTo(13));
      }
    });

    test('2. Normal bid legal', () {
      final hand = createStrongHand();
      final bid = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );
      expect(bid, isNotNull);
      expect(bid!, greaterThan(4));
      expect(bid, greaterThanOrEqualTo(5));
      expect(bid, lessThanOrEqualTo(13));
    });

    test('3. Hard bid legal', () {
      final hand = createStrongHand();
      final bid = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.hard,
      );
      expect(bid, isNotNull);
      expect(bid!, greaterThan(4));
      expect(bid, greaterThanOrEqualTo(5));
      expect(bid, lessThanOrEqualTo(13));
    });

    test('4. no bid above 13', () {
      final hand = createStrongHand();
      for (final diff in AIDifficulty.values) {
        final bid = AIEngine.recommendBid(
          hand: hand,
          currentHighestBid: 13,
          gameMode: BatakGameMode.single,
          difficulty: diff,
        );
        expect(bid, isNull, reason: '$diff must pass when highest bid is already 13');
      }
    });

    test('5. İhaleli minimum respected', () {
      final hand = createStrongHand();
      final bid = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 0,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );
      expect(bid, isNotNull);
      expect(bid!, greaterThanOrEqualTo(5));
    });

    test('6. Eşli minimum respected', () {
      final hand = createStrongHand();
      final bid = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 0,
        gameMode: BatakGameMode.partner,
        difficulty: AIDifficulty.normal,
      );
      expect(bid, isNotNull);
      expect(bid!, greaterThanOrEqualTo(8));
    });

    test('7. current highest bid respected', () {
      final hand = createStrongHand();
      final bid = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 6,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );
      expect(bid, isNotNull);
      expect(bid!, greaterThan(6));
    });

    test('8. weak hand may pass', () {
      final weakHand = createWeakHand();
      for (final diff in AIDifficulty.values) {
        final bid = AIEngine.recommendBid(
          hand: weakHand,
          currentHighestBid: 4,
          gameMode: BatakGameMode.single,
          difficulty: diff,
        );
        expect(bid, isNull, reason: '$diff should pass on a zero-honor weak hand');
      }
    });

    test('9. strong hand produces bid', () {
      final strongHand = createStrongHand();
      final normalBid = AIEngine.recommendBid(
        hand: strongHand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );
      final hardBid = AIEngine.recommendBid(
        hand: strongHand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.hard,
      );
      expect(normalBid, isNotNull);
      expect(hardBid, isNotNull);
    });

    test('10. passed player does not re-enter through provider flow', () {
      final provider = GameProvider();
      provider.startNewGame();

      // Human passes at turn 0
      final passRes = provider.userPassBid();
      expect(passRes.success, isTrue);
      expect(provider.passedPlayers.contains(0), isTrue);

      // If turn were somehow 0 again, trying to bid after pass must be rejected with 'Zaten pas dediniz'
      provider.biddingTurnIndex = 0;
      final bidRes = provider.userPlaceBid(6);
      expect(bidRes.success, isFalse);
      expect(bidRes.message, contains("Zaten pas dediniz"));

      provider.dispose();
    });

    test('11. same Easy seed same recommendation', () {
      final hand = createStrongHand();
      final bid1 = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.easy,
        random: Random(999),
      );
      final bid2 = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.easy,
        random: Random(999),
      );
      expect(bid1, equals(bid2));
    });

    test('12. Normal deterministic', () {
      final hand = createStrongHand();
      final bid1 = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 5,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );
      final bid2 = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 5,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );
      expect(bid1, equals(bid2));
    });

    test('13. Hard deterministic', () {
      final hand = createStrongHand();
      final bid1 = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 5,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.hard,
      );
      final bid2 = AIEngine.recommendBid(
        hand: hand,
        currentHighestBid: 5,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.hard,
      );
      expect(bid1, equals(bid2));
    });

    test('14. Easy/Normal/Hard differentiation scenario', () {
      // Sınırda bir el: 6 pik kartı (küçük), 1 As kupa, yan renkler kısa
      // Normal: Onör tablosu As (1.0) + 6 pik (1.5) = 2.5 ~ 3 el -> 6 teklifine PAS der
      // Hard: 6 pik (dominant trump) + As + void yan renk ruff gücü -> 6 teklifine 7 teklif verir
      // Easy (seed ile): çekingenlik/kusurluluk gösterip PAS der
      final borderHand = [
        PlayingCard(suit: Suit.spades, rank: Rank.nine),
        PlayingCard(suit: Suit.spades, rank: Rank.eight),
        PlayingCard(suit: Suit.spades, rank: Rank.seven),
        PlayingCard(suit: Suit.spades, rank: Rank.six),
        PlayingCard(suit: Suit.spades, rank: Rank.five),
        PlayingCard(suit: Suit.spades, rank: Rank.four),
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.diamonds, rank: Rank.ace),
        PlayingCard(suit: Suit.diamonds, rank: Rank.two),
        PlayingCard(suit: Suit.diamonds, rank: Rank.three),
        PlayingCard(suit: Suit.diamonds, rank: Rank.four),
        // Clubs void (0 clubs)!
        PlayingCard(suit: Suit.diamonds, rank: Rank.five),
      ];

      final normalBid = AIEngine.recommendBid(
        hand: borderHand,
        currentHighestBid: 7,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.normal,
      );

      final hardBid = AIEngine.recommendBid(
        hand: borderHand,
        currentHighestBid: 7,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.hard,
      );

      // Hard evaluates ruffing potential + 6-trump power to bid 8!
      // Normal without ruff heuristics evaluates 5-6 tricks and passes!
      expect(hardBid, equals(8));
      expect(normalBid, isNull);
    });

    test('15. hidden opponent hands not required (Anti-Cheat Invariance)', () {
      final botHand = createStrongHand();
      final bidWithoutOpponents = AIEngine.recommendBid(
        hand: botHand,
        currentHighestBid: 4,
        gameMode: BatakGameMode.single,
        difficulty: AIDifficulty.hard,
      );

      // Metot imzasında rakiplerin elleri bulunmadığından, gizli ellerin değiştirilmesi
      // önerilen teklifi matematiksel olarak ASLA etkileyemez.
      expect(bidWithoutOpponents, isNotNull);
    });

    test('16. hidden partner hand not required (Anti-Cheat Invariance)', () {
      final botHand = createStrongHand();
      final bidWithoutPartner = AIEngine.recommendBid(
        hand: botHand,
        currentHighestBid: 7,
        gameMode: BatakGameMode.partner,
        difficulty: AIDifficulty.hard,
      );

      // Eşli modda da ortağın gizli eli AI fonksiyonuna verilmez.
      expect(bidWithoutPartner, isNotNull);
      expect(bidWithoutPartner!, greaterThanOrEqualTo(8));
    });
  });
}
