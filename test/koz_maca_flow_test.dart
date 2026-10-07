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

List<List<PlayingCard>> seededDeal(int seed) {
  final deck = Deck();
  deck.cards.shuffle(Random(seed));
  return deck.dealCards();
}

Player makePlayer(String id, List<PlayingCard> hand, {int tricks = 0}) =>
    Player(id: id, name: id, isAI: true, hand: hand, bid: 0, tricksWon: tricks);

Player makeEmptyPlayer(String id, {int tricks = 0}) =>
    Player(id: id, name: id, isAI: true, hand: [], bid: 0, tricksWon: tricks);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.soundEnabled = false;
  });

  // ============================================================
  // 1. OYUNCU SAYISI VE DESTE DOĞRULAMASI
  // ============================================================
  group('LIKYA-V2-005 — KOZ MAÇA SETUP', () {
    test('1. Koz Maça 4 oyuncu ve 52 benzersiz kart ile başlar', () {
      final hands = seededDeal(10);
      final errors = ScoringEngine.validateDeal(hands);
      expect(errors, isEmpty);
      expect(hands.length, 4);
      for (int i = 0; i < 4; i++) {
        expect(hands[i].length, 13);
      }
    });

    test('2. GameModeRules.kozMaca konfigürasyonu doğrulanır', () {
      const rules = GameModeRules.kozMaca;
      expect(rules.mode, BatakGameMode.kozMaca);
      expect(rules.playerCount, 4);
      expect(rules.hasBidding, isFalse);
      expect(rules.isFixedTrump, isTrue);
      expect(rules.fixedTrumpSuit, Suit.spades);
      expect(rules.isProductionReady, isTrue);
    });
  });

  // ============================================================
  // 2. SABİT KOZ VE FAZ GEÇİŞLERİ
  // ============================================================
  group('LIKYA-V2-005 — KOZ MAÇA PHASE & TRUMP INTEGRITY', () {
    test('3. Koz Maça doğrudan GamePhase.playing fazı ile başlar', () {
      final p = GameProvider();
      p.gameMode = BatakGameMode.kozMaca;
      p.startNewGame();

      expect(p.currentPhase, GamePhase.playing);
      expect(p.currentTrump, Suit.spades);
      expect(p.bidderIndex, -1);
      expect(p.currentHighestBid, 0);
    });

    test('4. Koz Maça modunda ihale verme girişimi reddedilir', () {
      final p = GameProvider();
      p.gameMode = BatakGameMode.kozMaca;
      p.startNewGame();

      final resBid = p.userPlaceBid(5);
      expect(resBid.success, isFalse);
      expect(resBid.message, contains("ihale aşaması yoktur"));

      final resPass = p.userPassBid();
      expect(resPass.success, isFalse);
      expect(resPass.message, contains("ihale aşaması yoktur"));
    });

    test('5. Koz Maça modunda koz değiştirme girişimi reddedilir', () {
      final p = GameProvider();
      p.gameMode = BatakGameMode.kozMaca;
      p.startNewGame();

      final res = p.userSelectTrump(Suit.hearts);
      expect(res.success, isFalse);
      expect(res.message, contains("koz sabittir"));
      expect(p.currentTrump, Suit.spades); // Değişmedi
    });
  });

  // ============================================================
  // 3. KURAL UYUMLULUĞU (FOLLOW SUIT, TRUMPING, OVERTRUMPING)
  // ============================================================
  group('LIKYA-V2-005 — KOZ MAÇA LEGAL MOVES', () {
    test('6. Renge uyma zorunluluğu sabittir', () {
      final hand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.ace), // Koz
      ];
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ];

      final valid = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: Suit.spades,
      );

      // Elinde kupa varken kupa oynamak zorundadır
      expect(valid, [PlayingCard(suit: Suit.hearts, rank: Rank.two)]);
    });

    test('7. Elde yerdeki renk yoksa koz Maça atmak zorunludur', () {
      final hand = [
        PlayingCard(suit: Suit.clubs, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.five), // Koz
      ];
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ];

      final valid = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: Suit.spades,
      );

      expect(valid, [PlayingCard(suit: Suit.spades, rank: Rank.five)]);
    });

    test('8. Koz büyütme zorunluluğu (overtrumping) geçerlidir', () {
      final hand = [
        PlayingCard(suit: Suit.spades, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.ace), // Büyük koz
      ];
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.five), // Yerdeki koz
      ];

      final valid = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: Suit.spades,
      );

      // Yerdeki 5'li maça'yı geçebilecek As Maça varken 2'li atamaz
      expect(valid, [PlayingCard(suit: Suit.spades, rank: Rank.ace)]);
    });
  });

  // ============================================================
  // 4. PUANLAMA MOTORU (SCORING)
  // ============================================================
  group('LIKYA-V2-005 — KOZ MAÇA SCORING', () {
    test('9. Her oyuncu aldığı el * 10 puan kazanır', () {
      final p = makeEmptyPlayer('P0', tricks: 4);
      expect(ScoringEngine.calculateKozMacaPlayerDelta(player: p), 40);

      final p0 = makeEmptyPlayer('P0', tricks: 0);
      expect(ScoringEngine.calculateKozMacaPlayerDelta(player: p0), 0);
    });

    test('10. computeKozMacaRound tam tur sonucunu hesaplar', () {
      final players = [
        makeEmptyPlayer('P0', tricks: 5),
        makeEmptyPlayer('P1', tricks: 3),
        makeEmptyPlayer('P2', tricks: 3),
        makeEmptyPlayer('P3', tricks: 2),
      ];

      final result = ScoringEngine.computeKozMacaRound(
        players: players,
        roundNumber: 1,
        prevCumulativeScores: [0, 0, 0, 0],
      );

      expect(result.gameMode, 'kozMaca');
      expect(result.trump, Suit.spades);
      expect(result.bid, 0);
      expect(result.bidderIndex, -1);
      expect(result.scoreDeltaByPlayer, [50, 30, 30, 20]);
      expect(result.cumulativeScores, [50, 30, 30, 20]);
      expect(result.tricksByPlayer, [5, 3, 3, 2]);
    });

    test('11. Kümülatif puanlar turlar arasında korunur', () {
      final playersRound1 = [
        makeEmptyPlayer('P0', tricks: 4),
        makeEmptyPlayer('P1', tricks: 4),
        makeEmptyPlayer('P2', tricks: 3),
        makeEmptyPlayer('P3', tricks: 2),
      ];

      final r1 = ScoringEngine.computeKozMacaRound(
        players: playersRound1,
        roundNumber: 1,
        prevCumulativeScores: [0, 0, 0, 0],
      );

      final playersRound2 = [
        makeEmptyPlayer('P0', tricks: 2),
        makeEmptyPlayer('P1', tricks: 5),
        makeEmptyPlayer('P2', tricks: 4),
        makeEmptyPlayer('P3', tricks: 2),
      ];

      final r2 = ScoringEngine.computeKozMacaRound(
        players: playersRound2,
        roundNumber: 2,
        prevCumulativeScores: r1.cumulativeScores,
      );

      expect(r2.cumulativeScores, [40 + 20, 40 + 50, 30 + 40, 20 + 20]);
    });
  });

  // ============================================================
  // 5. 100 TUR DETERMINİSTİK KOZ MAÇA SİMÜLASYONU
  // ============================================================
  group('LIKYA-V2-005 — 100-ROUND KOZ MAÇA SİMÜLASYON', () {
    test('100 full Koz Maça rounds simulate deterministically with 0 errors', () {
      int totalDealErrors = 0;
      int totalTrickErrors = 0;
      int totalIllegalPlays = 0;
      int totalScoringErrors = 0;

      final List<int> cumulative = [0, 0, 0, 0];

      for (int round = 0; round < 100; round++) {
        // 1. Deste
        final hands = seededDeal(round * 17 + 5);
        final errors = ScoringEngine.validateDeal(hands);
        totalDealErrors += errors.length;

        final players = List.generate(4, (i) => makePlayer('$i', hands[i]));

        // 2. Koz her zaman Maça ♠
        const trump = Suit.spades;

        // 3. İlk lider dağıtıcının solu
        int lead = round % 4;
        final tricksPerPlayer = [0, 0, 0, 0];
        int illegalThisRound = 0;

        for (int trick = 0; trick < 13; trick++) {
          final table = <PlayingCard>[];
          final playedByPlayer = <int, PlayingCard>{};

          for (int seat = 0; seat < 4; seat++) {
            final pidx = (lead + seat) % 4;
            final p = players[pidx];

            final valid = GameEngine.getValidMoves(
              hand: p.hand,
              tableCards: table,
              trumpSuit: trump,
            );
            if (valid.isEmpty) {
              illegalThisRound++;
              break;
            }

            final card = AIEngine.chooseCard(
              bot: p,
              tableCards: table,
              trumpSuit: trump,
            );
            if (!valid.contains(card)) illegalThisRound++;
            p.hand.remove(card);
            table.add(card);
            playedByPlayer[pidx] = card;
          }

          if (table.length == 4) {
            final winIdx = GameEngine.determineWinnerIndex(table, trump);
            final winPlayerIdx = (lead + winIdx) % 4;
            tricksPerPlayer[winPlayerIdx]++;
            players[winPlayerIdx].tricksWon++;
            lead = winPlayerIdx;
          }
        }

        totalIllegalPlays += illegalThisRound;

        final total = tricksPerPlayer.fold(0, (a, b) => a + b);
        if (total != 13) totalTrickErrors++;

        // 4. Skorlama
        final result = ScoringEngine.computeKozMacaRound(
          players: players,
          roundNumber: round + 1,
          prevCumulativeScores: List.of(cumulative),
        );

        if (result.tricksByPlayer.fold(0, (a, b) => a + b) != 13) {
          totalScoringErrors++;
        }
        for (int i = 0; i < 4; i++) {
          cumulative[i] = result.cumulativeScores[i];
        }
      }

      expect(totalDealErrors, 0, reason: 'Deal errors found');
      expect(totalTrickErrors, 0, reason: 'Trick total != 13 in some rounds');
      expect(totalIllegalPlays, 0, reason: 'Illegal plays detected');
      expect(totalScoringErrors, 0, reason: 'Scoring errors');
    });
  });
}
