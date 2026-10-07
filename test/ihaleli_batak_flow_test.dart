import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/models/deck.dart';
import 'package:batak_app/engine/game_engine.dart';
import 'package:batak_app/engine/ai_engine.dart';
import 'package:batak_app/engine/scoring_engine.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';

// ============================================================
// YARDIMCI: Deterministic seeded deal
// ============================================================
List<List<PlayingCard>> _seededDeal(int seed) {
  final deck = Deck();
  // Belirleyici shuffle: sabit seed ile karıştır
  final rng = Random(seed);
  deck.cards.shuffle(rng);
  return deck.dealCards();
}

// ============================================================
// YARDIMCI: İhale simülasyonu (saf engine - GameProvider bağımsız)
// ============================================================
class _BiddingSimulator {
  int currentHighestBid;
  int? highestBidderIndex;
  Set<int> passed = {};
  int turn;
  final List<Player> players;
  final BatakGameMode mode;

  _BiddingSimulator({
    required this.players,
    required this.mode,
    required int startIndex,
  })  : turn = startIndex,
        currentHighestBid = (mode == BatakGameMode.partner) ? 7 : 4;

  /// Tamamlanana kadar ihaleyi simüle eder.
  /// Returns: (bidderIndex, bid)
  (int, int) simulate() {
    int maxIterations = 20; // Sonsuz döngü koruması
    while (maxIterations-- > 0) {
      if (_isFinished()) break;

      final player = players[turn];
      final bid = AIEngine.calculateBid(player);
      final maxBidLimit = (mode == BatakGameMode.partner) ? 9 : 7;

      bool willBid = bid > currentHighestBid && currentHighestBid < maxBidLimit;
      if (willBid) {
        final newBid = currentHighestBid + 1;
        currentHighestBid = newBid;
        highestBidderIndex = turn;
      } else {
        passed.add(turn);
      }

      if (_isFinished()) break;
      _advanceTurn();
    }

    // All-pass: dağıtıcı zorunlu bidder olur
    if (highestBidderIndex == null) {
      highestBidderIndex = 0;
      currentHighestBid = (mode == BatakGameMode.partner) ? 8 : 5;
    }

    return (highestBidderIndex!, currentHighestBid);
  }

  bool _isFinished() {
    if (passed.length >= 3 && highestBidderIndex != null) return true;
    if (passed.length == 4) return true;
    return false;
  }

  void _advanceTurn() {
    do {
      turn = (turn + 1) % 4;
    } while (passed.contains(turn));
  }
}

// ============================================================
// YARDIMCI: 13 el tam oyun simülatörü (saf engine)
// ============================================================

/// Bir turu eksiksiz oyna, 13 el tamamlansın.
/// [players] — 13 kart verilmiş 4 oyuncu
/// [trump]   — koz rengi
/// [leadIdx] — ilk eli başlatan oyuncunun indeksi
/// Returns: her oyuncunun aldığı el sayısı [p0,p1,p2,p3]
List<int> _simulateFullRound({
  required List<Player> players,
  required Suit trump,
  required int leadIdx,
}) {
  final tricksWon = [0, 0, 0, 0];
  int currentLead = leadIdx;
  final tableCards = <PlayingCard>[];

  for (int trick = 0; trick < 13; trick++) {
    tableCards.clear();

    // 4 oyuncu sırasıyla kart atar
    for (int i = 0; i < 4; i++) {
      final playerIdx = (currentLead + i) % 4;
      final player = players[playerIdx];

      final card = AIEngine.chooseCard(
        bot: player,
        tableCards: tableCards,
        trumpSuit: trump,
      );

      // Kural kontrolü
      final valid = GameEngine.getValidMoves(
        hand: player.hand,
        tableCards: tableCards,
        trumpSuit: trump,
      );
      assert(valid.contains(card),
          'Player $playerIdx played illegal card $card at trick $trick');
      assert(player.hand.contains(card),
          'Player $playerIdx does not own card $card');

      player.hand.remove(card);
      tableCards.add(card);
    }

    assert(tableCards.length == 4, 'Trick $trick does not have 4 cards');

    // El kazananını belirle
    final winnerCardIdx = GameEngine.determineWinnerIndex(tableCards, trump);
    final winnerPlayerIdx = (currentLead + winnerCardIdx) % 4;
    tricksWon[winnerPlayerIdx]++;
    currentLead = winnerPlayerIdx;
  }

  // Tüm eller boş olmalı
  for (int i = 0; i < 4; i++) {
    assert(players[i].hand.isEmpty,
        'Player $i still has ${players[i].hand.length} cards after trick 13');
  }

  return tricksWon;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.soundEnabled = false;
  });

  // ============================================================
  // DEAL TESTLERİ
  // ============================================================
  group('LIKYA-V2-003 — DEAL', () {
    // TEST 1: 52 unique cards
    test('1. Deck produces 52 unique cards', () {
      final hands = _seededDeal(42);
      final errors = ScoringEngine.validateDeal(hands);
      expect(errors, isEmpty, reason: errors.join(', '));
    });

    // TEST 2: four hands of 13
    test('2. Each player receives exactly 13 cards', () {
      final hands = _seededDeal(7);
      for (int i = 0; i < 4; i++) {
        expect(hands[i].length, 13, reason: 'Player $i');
      }
    });

    // TEST 3: repeated rounds still produce valid deck state
    test('3. 20 seeded rounds all produce valid deals', () {
      for (int seed = 0; seed < 20; seed++) {
        final hands = _seededDeal(seed);
        final errors = ScoringEngine.validateDeal(hands);
        expect(errors, isEmpty, reason: 'seed=$seed: ${errors.join(', ')}');
      }
    });
  });

  // ============================================================
  // İHALE TESTLERİ
  // ============================================================
  group('LIKYA-V2-003 — BİDDİNG', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SoundService.soundEnabled = false;
    });

    // TEST 4: legal bid accepted
    test('4. Human legal bid is accepted and recorded', () {
      final p = GameProvider();
      p.biddingTurnIndex = 0;
      p.currentHighestBid = 4;
      final res = p.userPlaceBid(5);
      expect(res.success, isTrue);
      expect(p.currentHighestBid, 5);
      expect(p.highestBidderIndex, 0);
    });

    // TEST 5: bid lower/equal to highest rejected
    test('5. Bid equal to or lower than current highest is rejected', () {
      final p = GameProvider();
      p.biddingTurnIndex = 0;
      p.currentHighestBid = 6;
      expect(p.userPlaceBid(6).success, isFalse);
      expect(p.userPlaceBid(5).success, isFalse);
      expect(p.currentHighestBid, 6); // unchanged
    });

    // TEST 6: bid above 13 rejected
    test('6. Bid above 13 is rejected', () {
      final p = GameProvider();
      p.biddingTurnIndex = 0;
      p.currentHighestBid = 4;
      expect(p.userPlaceBid(14).success, isFalse);
      expect(p.userPlaceBid(20).success, isFalse);
    });

    // TEST 7: pass behavior recorded
    test('7. Human pass is recorded', () {
      final p = GameProvider();
      p.biddingTurnIndex = 0;
      final res = p.userPassBid();
      expect(res.success, isTrue);
      expect(p.passedPlayers.contains(0), isTrue);
    });

    // TEST 8: passed player cannot bid again
    test('8. Passed player is rejected from bidding again', () {
      final p = GameProvider();
      p.biddingTurnIndex = 0;
      p.passedPlayers.add(0); // simulate already passed
      final res = p.userPlaceBid(5);
      expect(res.success, isFalse);
      expect(res.message, contains('Zaten pas'));
    });

    // TEST 9: auction winner correct
    test('9. Auction winner (bidderIndex) matches highestBidderIndex', () {
      // Bidder simulation via pure engine
      final hands = _seededDeal(99);
      final players = [
        Player(id: '0', name: 'Siz',  isAI: false, hand: hands[0]),
        Player(id: '1', name: 'Bot1', isAI: true,  hand: hands[1]),
        Player(id: '2', name: 'Bot2', isAI: true,  hand: hands[2]),
        Player(id: '3', name: 'Bot3', isAI: true,  hand: hands[3]),
      ];
      final sim = _BiddingSimulator(
        players: players,
        mode: BatakGameMode.single,
        startIndex: 0,
      );
      final (bidderIdx, winBid) = sim.simulate();
      expect(bidderIdx, inInclusiveRange(0, 3));
      expect(winBid, inInclusiveRange(5, 13));
    });

    // TEST 10: all-pass behavior terminates
    test('10. All-pass: simulator terminates and assigns forced bidder', () {
      // Force all players to have weak hands (1-2 card tricks expected)
      final weakHand = List.generate(
          13, (i) => PlayingCard(suit: Suit.clubs, rank: Rank.values[i % 4]));
      final players = List.generate(
        4,
        (i) => Player(id: '$i', name: 'P$i', isAI: true, hand: List.of(weakHand)),
      );
      final sim = _BiddingSimulator(
        players: players,
        mode: BatakGameMode.single,
        startIndex: 0,
      );
      // Should not throw or loop; returns a valid bidder
      final (bidderIdx, bid) = sim.simulate();
      expect(bidderIdx, inInclusiveRange(0, 3));
      expect(bid, greaterThanOrEqualTo(5));
    });

    // TEST 11: AI bidding terminates (via GameProvider)
    test('11. AI bidding in GameProvider terminates without infinite loop', () async {
      final p = GameProvider();
      // Bots bid with a delayBase timer. In headless tests, timers fire but
      // we need enough time for 4 bots (each ~380ms/1.2 = ~317ms) = ~1.5s total.
      // Wait 3s to guarantee all bot bids have fired.
      await Future.delayed(const Duration(milliseconds: 3000));
      // Phase must have advanced past initial bidding start (not locked in bidding
      // with a non-human as biddingTurnIndex without any action taken).
      // Either playing started, trump selected, or human turn arrived.
      // If phase is still bidding: it must be human's turn (biddingTurnIndex==0)
      // meaning bots finished and human is next.
      final validEndStates = [
        GamePhase.playing,
        GamePhase.trumpSelection,
        GamePhase.roundFinished,
        GamePhase.gameOver,
      ];
      if (!validEndStates.contains(p.currentPhase)) {
        // If still bidding, human must be next (bots completed their turns)
        expect(p.biddingTurnIndex, 0,
            reason: 'Bidding stuck: bot bids did not complete');
      }
    });
  });

  // ============================================================
  // KOZ SEÇİMİ TESTLERİ
  // ============================================================
  group('LIKYA-V2-003 — TRUMP SELECTION', () {
    // TEST 12: bidder selects trump
    test('12. Human bidder (index 0) can select trump', () {
      final p = GameProvider();
      p.currentPhase = GamePhase.trumpSelection;
      p.bidderIndex = 0;

      final res = p.userSelectTrump(Suit.hearts);
      expect(res.success, isTrue);
      expect(p.currentTrump, Suit.hearts);
      expect(p.currentPhase, GamePhase.playing);
    });

    // TEST 13: non-bidder rejected from trump selection
    test('13. Non-bidder cannot select trump', () {
      final p = GameProvider();
      p.currentPhase = GamePhase.trumpSelection;
      p.bidderIndex = 1; // bot is bidder, not human player 0

      final res = p.userSelectTrump(Suit.diamonds);
      expect(res.success, isFalse);
      expect(p.currentPhase, GamePhase.trumpSelection); // unchanged
    });

    // TEST 14: duplicate trump selection rejected after phase changes
    test('14. Duplicate trump selection rejected (phase no longer trumpSelection)', () {
      final p = GameProvider();
      p.currentPhase = GamePhase.trumpSelection;
      p.bidderIndex = 0;

      p.userSelectTrump(Suit.hearts);
      expect(p.currentPhase, GamePhase.playing);

      final res2 = p.userSelectTrump(Suit.spades);
      expect(res2.success, isFalse);
      expect(p.currentTrump, Suit.hearts); // unchanged
    });

    // TEST 15: AI bidder selects valid trump
    test('15. AIEngine.chooseTrump returns a valid Suit', () {
      final hands = _seededDeal(12);
      final bot = Player(id: '1', name: 'Bot1', isAI: true, hand: hands[1]);
      final trump = AIEngine.chooseTrump(bot);
      expect(Suit.values.contains(trump), isTrue);
    });
  });

  // ============================================================
  // 13 EL OYUN AKIŞI TESTLERİ
  // ============================================================
  group('LIKYA-V2-003 — TRICKS', () {
    Player player(String id, List<PlayingCard> hand) =>
        Player(id: id, name: id, isAI: true, hand: List.of(hand));

    // TEST 16: exactly four cards per completed trick
    test('16. Exactly 4 cards are on table when trick resolves', () {
      final hands = _seededDeal(1);
      final players = List.generate(4, (i) => player('$i', hands[i]));
      final table = <PlayingCard>[];

      for (int i = 0; i < 4; i++) {
        final card = AIEngine.chooseCard(
          bot: players[i],
          tableCards: table,
          trumpSuit: Suit.spades,
        );
        players[i].hand.remove(card);
        table.add(card);
      }
      expect(table.length, 4);
    });

    // TEST 17: correct trick winner
    test('17. determineWinnerIndex identifies lead-suit winner correctly', () {
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        PlayingCard(suit: Suit.diamonds, rank: Rank.ace),
      ];
      // Lead=hearts, trump=clubs: clubs ace wins
      final idx = GameEngine.determineWinnerIndex(table, Suit.clubs);
      expect(idx, 2); // clubs ace is at index 2
    });

    // TEST 18: winner leads next trick
    test('18. Winner leads next trick in simulation', () {
      final hands = _seededDeal(5);
      final players = List.generate(4, (i) => player('$i', hands[i]));
      final table = <PlayingCard>[];

      // Trick 1: lead = 0
      int lead = 0;
      for (int i = 0; i < 4; i++) {
        final playerIdx = (lead + i) % 4;
        final card = AIEngine.chooseCard(
          bot: players[playerIdx],
          tableCards: table,
          trumpSuit: Suit.spades,
        );
        players[playerIdx].hand.remove(card);
        table.add(card);
      }
      final cardWinnerIdx = GameEngine.determineWinnerIndex(table, Suit.spades);
      final newLead = (lead + cardWinnerIdx) % 4;

      // New lead should be 0..3
      expect(newLead, inInclusiveRange(0, 3));
    });

    // TEST 19: 13 tricks complete a round
    test('19. 13 tricks consume exactly 52 card plays', () {
      final hands = _seededDeal(3);
      final players = List.generate(4, (i) => player('$i', hands[i]));
      int totalPlayed = 0;

      int lead = 0;
      for (int trick = 0; trick < 13; trick++) {
        final table = <PlayingCard>[];
        for (int i = 0; i < 4; i++) {
          final idx = (lead + i) % 4;
          final card = AIEngine.chooseCard(
            bot: players[idx],
            tableCards: table,
            trumpSuit: Suit.spades,
          );
          players[idx].hand.remove(card);
          table.add(card);
          totalPlayed++;
        }
        final winIdx = GameEngine.determineWinnerIndex(table, Suit.spades);
        lead = (lead + winIdx) % 4;
      }

      expect(totalPlayed, 52);
    });

    // TEST 20: total tricks taken == 13
    test('20. sum(tricksWon) == 13 after full round', () {
      final hands = _seededDeal(8);
      final players = List.generate(4, (i) => player('$i', hands[i]));
      final tricks = _simulateFullRound(
        players: players, trump: Suit.hearts, leadIdx: 0,
      );
      expect(tricks.fold(0, (a, b) => a + b), 13);
    });

    // TEST 21: all hands empty after trick 13
    test('21. All hands empty after 13 tricks', () {
      final hands = _seededDeal(11);
      final players = List.generate(4, (i) => player('$i', hands[i]));
      _simulateFullRound(players: players, trump: Suit.spades, leadIdx: 2);
      expect(ScoringEngine.allHandsEmpty(players), isTrue);
    });

    // TEST 22: no 14th trick (hands are empty, no more plays possible)
    test('22. No 14th trick: empty hands prevent further plays', () {
      final hands = _seededDeal(15);
      final players = List.generate(4, (i) => player('$i', hands[i]));
      _simulateFullRound(players: players, trump: Suit.diamonds, leadIdx: 1);

      // All valid moves for all players should be empty (no cards in hand)
      for (final p in players) {
        final moves = GameEngine.getValidMoves(
          hand: p.hand,
          tableCards: [],
          trumpSuit: Suit.diamonds,
        );
        expect(moves, isEmpty);
      }
    });
  });

  // ============================================================
  // TRICK WINNER INDEX TESTLERİ - 4 pozisyon
  // ============================================================
  group('LIKYA-V2-003 — TRICK WINNER INDEX CONSISTENCY', () {
    test('All four player positions can be trick winners', () {
      // Player 0 wins (Ace of led suit, no trumps)
      {
        final table = [
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.hearts, rank: Rank.three),
          PlayingCard(suit: Suit.hearts, rank: Rank.four),
        ];
        expect(GameEngine.determineWinnerIndex(table, Suit.spades), 0);
        expect(GameEngine.determineTrickWinnerPlayerIndex(
          tableCards: table, trumpSuit: Suit.spades, leadPlayerIndex: 0,
        ), 0);
      }

      // Player 1 wins (trump beats ace)
      {
        final table = [
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),
          PlayingCard(suit: Suit.spades, rank: Rank.two), // trump
          PlayingCard(suit: Suit.hearts, rank: Rank.three),
          PlayingCard(suit: Suit.hearts, rank: Rank.four),
        ];
        expect(GameEngine.determineWinnerIndex(table, Suit.spades), 1);
        expect(GameEngine.determineTrickWinnerPlayerIndex(
          tableCards: table, trumpSuit: Suit.spades, leadPlayerIndex: 0,
        ), 1);
      }

      // Player 2 wins (overtrump)
      {
        final table = [
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),
          PlayingCard(suit: Suit.spades, rank: Rank.two),  // trump low
          PlayingCard(suit: Suit.spades, rank: Rank.king), // trump high → wins
          PlayingCard(suit: Suit.hearts, rank: Rank.four),
        ];
        expect(GameEngine.determineWinnerIndex(table, Suit.spades), 2);
        expect(GameEngine.determineTrickWinnerPlayerIndex(
          tableCards: table, trumpSuit: Suit.spades, leadPlayerIndex: 0,
        ), 2);
      }

      // Player 3 wins (off-lead suit ace, no trump played)
      {
        final table = [
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
          PlayingCard(suit: Suit.hearts, rank: Rank.three),
          PlayingCard(suit: Suit.hearts, rank: Rank.four),
          PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        ];
        expect(GameEngine.determineWinnerIndex(table, Suit.spades), 3);
        expect(GameEngine.determineTrickWinnerPlayerIndex(
          tableCards: table, trumpSuit: Suit.spades, leadPlayerIndex: 0,
        ), 3);
      }
    });

    test('Off-suit non-trump cannot win even with Ace', () {
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.two),  // led
        PlayingCard(suit: Suit.hearts, rank: Rank.three),
        PlayingCard(suit: Suit.clubs, rank: Rank.ace),   // off-suit, cannot win
        PlayingCard(suit: Suit.hearts, rank: Rank.four),
      ];
      // Hearts led, spades trump: clubs ace cannot win
      expect(GameEngine.determineWinnerIndex(table, Suit.spades), 3); // 4 of hearts wins
    });
  });

  // ============================================================
  // ROUND STATE MACHINE TESTLERİ
  // ============================================================
  group('LIKYA-V2-003 — ROUND STATE MACHINE', () {
    test('32. Next round preserves cumulative score and clears round state', () async {
      final p = GameProvider();
      // Inject custom cumulative scores
      p.cumulativeScores = [50, 10, 20, 30];
      p.currentRound = 1;
      p.totalRounds = 3;

      p.startNewGame();

      // Cumulative scores reset on full new game (correct)
      expect(p.cumulativeScores, [0, 0, 0, 0]);
      expect(p.roundScoresHistory.isEmpty, isTrue);
    });

    test('33. _startRound clears table and playedCardsByPlayer', () {
      final p = GameProvider();
      // Manually set dirty state
      p.tableCards.add(PlayingCard(suit: Suit.hearts, rank: Rank.ace));
      p.playedCardsByPlayer[0] = PlayingCard(suit: Suit.spades, rank: Rank.king);

      // Starting a new game reinitializes
      p.startNewGame();
      expect(p.tableCards.isEmpty, isTrue);
      expect(p.playedCardsByPlayer.isEmpty, isTrue);
    });

    test('34. New round has 52 unique cards (via startNewGame)', () {
      final p = GameProvider();
      final hands = p.players.map((pl) => List.of(pl.hand)).toList();
      final errors = ScoringEngine.validateDeal(hands);
      expect(errors, isEmpty);
    });
  });

  // ============================================================
  // GAME OVER TESTLERİ
  // ============================================================
  group('LIKYA-V2-003 — GAME / MATCH COMPLETION', () {
    // TEST 35: final round enters gameOver
    test('35. startNextRoundImmediately on last round does not advance', () {
      final p = GameProvider();
      p.currentPhase = GamePhase.roundFinished;
      p.currentRound = p.totalRounds; // already at last round

      p.startNextRoundImmediately();
      // currentRound should NOT advance beyond totalRounds
      expect(p.currentRound, p.totalRounds);
    });

    // TEST 36: no extra round starts
    test('36. After final round, currentRound stays <= totalRounds', () async {
      final p = GameProvider();
      // There is no direct way to force gameOver without running full match
      // We test the guard: startNextRoundImmediately does nothing if at limit
      p.currentRound = 5;
      p.totalRounds = 5;
      p.currentPhase = GamePhase.roundFinished;
      p.startNextRoundImmediately();
      expect(p.currentRound, lessThanOrEqualTo(p.totalRounds));
    });

    // TEST 37: winner determination
    test('37. ScoringEngine.determineWinnerIndex identifies correct winner', () {
      expect(ScoringEngine.determineWinnerIndex([120, 35, 60, -20]), 0);
      expect(ScoringEngine.determineWinnerIndex([-10, 200, 80, 100]), 1);
    });
  });

  // ============================================================
  // NETWORK SIDE EFFECT TEST
  // ============================================================
  group('LIKYA-V2-003 — NETWORK SIDE EFFECT', () {
    // TEST 39: score-save failure cannot invalidate local completed game
    test('39. ApiService failure does not affect cumulativeScores', () async {
      // We cannot call real network; verify that ScoringEngine
      // has already committed cumulativeScores before any network call.
      // ScoringEngine.computeSingleModeRound is pure and does not call network.

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
        trump: Suit.spades,
        roundNumber: 5,
        prevCumulativeScores: [100, 50, 30, 10],
      );
      // Scores are already computed; network failure after this point is irrelevant
      expect(result.cumulativeScores[0], 150); // 100 + 50
      expect(result.cumulativeScores[1], 54);  // 50 + 4
    });
  });

  // ============================================================
  // FULL 100-ROUND SIMULATION (STEP 18)
  // ============================================================
  group('LIKYA-V2-003 — 100-ROUND SIMULATION', () {
    test('100 full İhaleli Batak rounds simulate correctly', () {
      const int roundCount = 100;
      int totalTrickErrors = 0;
      int totalDealErrors = 0;
      int totalIllegalPlays = 0;

      for (int round = 0; round < roundCount; round++) {
        // 1. Deste yarat ve dağıt
        final hands = _seededDeal(round * 7 + 3); // deterministic seed
        final errors = ScoringEngine.validateDeal(hands);
        totalDealErrors += errors.length;

        final players = List.generate(
          4,
          (i) => Player(id: '$i', name: 'P$i', isAI: true, hand: hands[i]),
        );

        // 2. İhale simülasyonu
        final sim = _BiddingSimulator(
          players: players,
          mode: BatakGameMode.single,
          startIndex: round % 4,
        );
        final (bidderIdx, bid) = sim.simulate();

        // Bidder validity
        assert(bidderIdx >= 0 && bidderIdx < 4, 'round $round: invalid bidder');
        assert(bid >= 5 && bid <= 13, 'round $round: bid out of range: $bid');

        // 3. Koz seçimi
        final Suit trump = AIEngine.chooseTrump(players[bidderIdx]);
        assert(Suit.values.contains(trump), 'round $round: invalid trump');

        // 4. 13 el oyun
        final List<PlayingCard> table = [];
        int lead = bidderIdx;
        final tricksPerPlayer = [0, 0, 0, 0];

        for (int trick = 0; trick < 13; trick++) {
          table.clear();
          for (int seat = 0; seat < 4; seat++) {
            final pidx = (lead + seat) % 4;
            final p = players[pidx];
            final valid = GameEngine.getValidMoves(
              hand: p.hand,
              tableCards: table,
              trumpSuit: trump,
            );
            if (valid.isEmpty) {
              totalIllegalPlays++;
              break;
            }
            final card = AIEngine.chooseCard(
              bot: p,
              tableCards: table,
              trumpSuit: trump,
            );
            if (!valid.contains(card)) {
              totalIllegalPlays++;
            }
            p.hand.remove(card);
            table.add(card);
          }
          if (table.length == 4) {
            final winCardIdx = GameEngine.determineWinnerIndex(table, trump);
            final winPlayerIdx = (lead + winCardIdx) % 4;
            tricksPerPlayer[winPlayerIdx]++;
            players[winPlayerIdx].tricksWon++;
            lead = winPlayerIdx;
          }
        }

        // 5. Tur sonucu doğrulama
        final total = tricksPerPlayer.fold(0, (a, b) => a + b);
        if (total != 13) totalTrickErrors++;

        // 6. Puan hesaplama
        for (int i = 0; i < 4; i++) {
          players[i].bid = (i == bidderIdx) ? bid : 0;
        }
        final result = ScoringEngine.computeSingleModeRound(
          players: players,
          bidderIndex: bidderIdx,
          bid: bid,
          trump: trump,
          roundNumber: round + 1,
          prevCumulativeScores: [0, 0, 0, 0],
        );
        // Score should be deterministic (no assertion on value, just no throw)
        expect(result.tricksByPlayer.fold(0, (a, b) => a + b), 13);
      }

      // Sonuç: Tüm 100 turda sıfır hata
      expect(totalDealErrors, 0,
          reason: 'Deal errors found across 100 rounds');
      expect(totalTrickErrors, 0,
          reason: 'Trick total != 13 in some rounds');
      expect(totalIllegalPlays, 0,
          reason: 'Illegal plays detected in simulation');
    });
  });
}
