import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/engine/scoring_engine.dart';
import 'package:batak_app/models/deck.dart';

void main() {
  group('ScoringEngine — Tekli İhaleli Batak Puan Kuralları', () {

    // -------------------------------------------------------
    // KURAL ÖZETİ:
    //   İhaleci: bid*10 + fazlalık  (başarı) / -(bid*10) (batar)
    //   Diğerleri: tricksWon * 1
    // -------------------------------------------------------

    Player makePlayer(String name, {int bid = 0, int tricks = 0}) {
      return Player(
        id: name,
        name: name,
        isAI: true,
        hand: [],
        bid: bid,
        tricksWon: tricks,
      );
    }

    // TEST 23: bidder succeeds
    test('23. Bidder succeeds: bid 7, won 7 → +70', () {
      final p = makePlayer('Erol', bid: 7, tricks: 7);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: p, isBidder: true), 70);
    });

    // TEST 24: bidder fails
    test('24. Bidder fails: bid 7, won 5 → -70', () {
      final p = makePlayer('Erol', bid: 7, tricks: 5);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: p, isBidder: true), -70);
    });

    // TEST 25: exact bid
    test('25. Exact bid: bid 5, won 5 → +50 (no overtrick bonus)', () {
      final p = makePlayer('Erol', bid: 5, tricks: 5);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: p, isBidder: true), 50);
    });

    // TEST 26: over bid result
    test('26. Over bid: bid 5, won 8 → 50 + 3 = 53', () {
      final p = makePlayer('Erol', bid: 5, tricks: 8);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: p, isBidder: true), 53);
    });

    // TEST 27: minimum bid 5 scoring
    test('27. Minimum bid 5: success → 50, fail → -50', () {
      final pSuccess = makePlayer('A', bid: 5, tricks: 5);
      final pFail = makePlayer('B', bid: 5, tricks: 4);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: pSuccess, isBidder: true), 50);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: pFail, isBidder: true), -50);
    });

    // TEST 28: 13 bid scoring
    test('28. 13 bid: success 13 tricks → 130, fail 12 tricks → -130', () {
      final pSuccess = makePlayer('A', bid: 13, tricks: 13);
      final pFail = makePlayer('B', bid: 13, tricks: 12);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: pSuccess, isBidder: true), 130);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: pFail, isBidder: true), -130);
    });

    // TEST 29: non-bidder scoring
    test('29. Non-bidder: 3 tricks → +3, 0 tricks → 0', () {
      final p3 = makePlayer('X', tricks: 3);
      final p0 = makePlayer('Y', tricks: 0);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: p3, isBidder: false), 3);
      expect(ScoringEngine.calculateSinglePlayerDelta(player: p0, isBidder: false), 0);
    });

    // TEST 30: cumulative score accumulation
    test('30. Cumulative score accumulation across two rounds', () {
      final players1 = [
        makePlayer('P0', bid: 5, tricks: 5),
        makePlayer('P1', bid: 0, tricks: 4),
        makePlayer('P2', bid: 0, tricks: 3),
        makePlayer('P3', bid: 0, tricks: 1),
      ];

      final result1 = ScoringEngine.computeSingleModeRound(
        players: players1,
        bidderIndex: 0,
        bid: 5,
        trump: Suit.spades,
        roundNumber: 1,
        prevCumulativeScores: [0, 0, 0, 0],
      );
      // P0: 50+0=50, P1: 4, P2: 3, P3: 1
      expect(result1.scoreDeltaByPlayer[0], 50);
      expect(result1.scoreDeltaByPlayer[1], 4);
      expect(result1.scoreDeltaByPlayer[2], 3);
      expect(result1.scoreDeltaByPlayer[3], 1);
      expect(result1.cumulativeScores, [50, 4, 3, 1]);

      // Round 2: P1 bids 6, gets 6; others get various tricks
      final players2 = [
        makePlayer('P0', bid: 0, tricks: 3),
        makePlayer('P1', bid: 6, tricks: 6),
        makePlayer('P2', bid: 0, tricks: 2),
        makePlayer('P3', bid: 0, tricks: 2),
      ];

      final result2 = ScoringEngine.computeSingleModeRound(
        players: players2,
        bidderIndex: 1,
        bid: 6,
        trump: Suit.hearts,
        roundNumber: 2,
        prevCumulativeScores: result1.cumulativeScores,
      );
      expect(result2.scoreDeltaByPlayer[1], 60);
      expect(result2.cumulativeScores[0], 50 + 3);  // 53
      expect(result2.cumulativeScores[1], 4 + 60);   // 64
    });

    // TEST 31: scoring cannot occur twice - via RoundResult immutability
    test('31. Scoring result is immutable; duplicate calls produce independent objects', () {
      final players = [
        makePlayer('P0', bid: 5, tricks: 5),
        makePlayer('P1', bid: 0, tricks: 4),
        makePlayer('P2', bid: 0, tricks: 3),
        makePlayer('P3', bid: 0, tricks: 1),
      ];

      final prev = [10, 20, 30, 40];
      final result1 = ScoringEngine.computeSingleModeRound(
        players: players,
        bidderIndex: 0,
        bid: 5,
        trump: Suit.spades,
        roundNumber: 1,
        prevCumulativeScores: prev,
      );
      final result2 = ScoringEngine.computeSingleModeRound(
        players: players,
        bidderIndex: 0,
        bid: 5,
        trump: Suit.spades,
        roundNumber: 1,
        prevCumulativeScores: prev,
      );

      // Both calls produce identical independent results
      expect(result1.cumulativeScores, result2.cumulativeScores);
      expect(result1.scoreDeltaByPlayer, result2.scoreDeltaByPlayer);

      // Modifying prev does not affect result1 (defensive copy)
      prev[0] = 9999;
      expect(result1.cumulativeScores[0], isNot(9999));
    });
  });

  // ============================================================
  // DECK DOĞRULAMA TESTLERİ
  // ============================================================
  group('ScoringEngine — Deck Validation', () {
    Deck makeDeal() {
      final d = Deck();
      d.shuffle();
      return d;
    }

    // TEST 1: 52 unique cards
    test('1. Deck produces 52 unique cards', () {
      final deck = makeDeal();
      final hands = deck.dealCards();
      final errors = ScoringEngine.validateDeal(hands);
      expect(errors, isEmpty, reason: errors.join(', '));
    });

    // TEST 2: four hands of 13
    test('2. Each player receives exactly 13 cards', () {
      final hands = makeDeal().dealCards();
      for (int i = 0; i < 4; i++) {
        expect(hands[i].length, 13, reason: 'Player $i hand size mismatch');
      }
    });

    // TEST 3: repeated rounds still produce valid deck state
    test('3. Repeated rounds produce valid decks (50 iterations)', () {
      for (int i = 0; i < 50; i++) {
        final hands = makeDeal().dealCards();
        final errors = ScoringEngine.validateDeal(hands);
        expect(errors, isEmpty, reason: 'Round $i: ${errors.join(', ')}');
      }
    });
  });

  // ============================================================
  // TRICK TOTAL VALIDATION
  // ============================================================
  group('ScoringEngine — Trick Total Validation', () {
    test('validateTrickTotals passes with sum = 13', () {
      final players = [
        Player(id: '0', name: 'A', isAI: false, hand: [], tricksWon: 4),
        Player(id: '1', name: 'B', isAI: true, hand: [], tricksWon: 3),
        Player(id: '2', name: 'C', isAI: true, hand: [], tricksWon: 4),
        Player(id: '3', name: 'D', isAI: true, hand: [], tricksWon: 2),
      ];
      expect(ScoringEngine.validateTrickTotals(players), isEmpty);
    });

    test('validateTrickTotals fails with sum != 13', () {
      final players = [
        Player(id: '0', name: 'A', isAI: false, hand: [], tricksWon: 3),
        Player(id: '1', name: 'B', isAI: true, hand: [], tricksWon: 3),
        Player(id: '2', name: 'C', isAI: true, hand: [], tricksWon: 3),
        Player(id: '3', name: 'D', isAI: true, hand: [], tricksWon: 3),
      ];
      expect(ScoringEngine.validateTrickTotals(players), isNotEmpty);
    });
  });

  // ============================================================
  // WINNER DETERMINATION
  // ============================================================
  group('ScoringEngine — Winner Determination', () {
    test('determineWinnerIndex returns highest scorer', () {
      expect(ScoringEngine.determineWinnerIndex([10, 50, 30, 20]), 1);
    });

    test('determineWinnerIndex handles tie: returns first (lowest index)', () {
      expect(ScoringEngine.determineWinnerIndex([50, 50, 30, 20]), 0);
    });

    test('determineWinnerIndex handles all negative: returns least negative', () {
      expect(ScoringEngine.determineWinnerIndex([-100, -50, -70, -80]), 1);
    });
  });

  // ============================================================
  // ROUND RESULT STRUCTURE
  // ============================================================
  group('ScoringEngine — RoundResult Structure', () {
    test('RoundResult stores all fields correctly', () {
      final players = [
        Player(id: '0', name: 'A', isAI: false, hand: [], bid: 6, tricksWon: 8),
        Player(id: '1', name: 'B', isAI: true,  hand: [], tricksWon: 2),
        Player(id: '2', name: 'C', isAI: true,  hand: [], tricksWon: 1),
        Player(id: '3', name: 'D', isAI: true,  hand: [], tricksWon: 2),
      ];

      final result = ScoringEngine.computeSingleModeRound(
        players: players,
        bidderIndex: 0,
        bid: 6,
        trump: Suit.diamonds,
        roundNumber: 3,
        prevCumulativeScores: [100, 10, 5, 8],
      );

      expect(result.roundNumber, 3);
      expect(result.bidderIndex, 0);
      expect(result.bid, 6);
      expect(result.trump, Suit.diamonds);
      expect(result.tricksByPlayer, [8, 2, 1, 2]);
      // Bidder: bid 6, won 8 → 60 + 2 = 62
      expect(result.scoreDeltaByPlayer[0], 62);
      expect(result.scoreDeltaByPlayer[1], 2);
      expect(result.scoreDeltaByPlayer[2], 1);
      expect(result.scoreDeltaByPlayer[3], 2);
      expect(result.cumulativeScores[0], 162);
      expect(result.cumulativeScores[1], 12);
    });

    test('RoundResult toString does not throw', () {
      final players = [
        Player(id: '0', name: 'A', isAI: false, hand: [], bid: 5, tricksWon: 5),
        Player(id: '1', name: 'B', isAI: true,  hand: [], tricksWon: 4),
        Player(id: '2', name: 'C', isAI: true,  hand: [], tricksWon: 3),
        Player(id: '3', name: 'D', isAI: true,  hand: [], tricksWon: 1),
      ];
      final result = ScoringEngine.computeSingleModeRound(
        players: players,
        bidderIndex: 0,
        bid: 5,
        trump: Suit.clubs,
        roundNumber: 1,
        prevCumulativeScores: [0, 0, 0, 0],
      );
      expect(() => result.toString(), returnsNormally);
    });
  });

  // ============================================================
  // EŞLI BATAK PUANLAMA (shared engine)
  // ============================================================
  group('ScoringEngine — Eşli Batak Partner Mode', () {
    Player p(String id, {int bid = 0, int tricks = 0}) =>
        Player(id: id, name: id, isAI: true, hand: [], bid: bid, tricksWon: tricks);

    test('Team 1 bidder succeeds: bid 8, team1 takes 9 → (8*10)+1=81 each', () {
      final players = [
        p('0', bid: 8, tricks: 5), // Team 1
        p('1', tricks: 4),          // Team 2
        p('2', tricks: 4),          // Team 1
        p('3', tricks: 0),          // Team 2
      ];
      final result = ScoringEngine.computePartnerModeRound(
        players: players,
        bidderIndex: 0,
        bid: 8,
        trump: Suit.hearts,
        roundNumber: 1,
        prevCumulativeScores: [0, 0, 0, 0],
      );
      // Team1: 9 tricks >= 8 bid → 80+1=81
      expect(result.scoreDeltaByPlayer[0], 81);
      expect(result.scoreDeltaByPlayer[2], 81);
      // Team2: 4 tricks * 10 = 40
      expect(result.scoreDeltaByPlayer[1], 40);
      expect(result.scoreDeltaByPlayer[3], 40);
    });

    test('Team 1 bidder fails: bid 8, team1 takes 6 → -80 each', () {
      final players = [
        p('0', bid: 8, tricks: 3), // Team 1
        p('1', tricks: 4),          // Team 2
        p('2', tricks: 3),          // Team 1
        p('3', tricks: 3),          // Team 2
      ];
      final result = ScoringEngine.computePartnerModeRound(
        players: players,
        bidderIndex: 0,
        bid: 8,
        trump: Suit.spades,
        roundNumber: 1,
        prevCumulativeScores: [0, 0, 0, 0],
      );
      expect(result.scoreDeltaByPlayer[0], -80);
      expect(result.scoreDeltaByPlayer[2], -80);
    });
  });
}
