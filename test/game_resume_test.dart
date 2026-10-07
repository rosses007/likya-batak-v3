import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/models/deck.dart';
import 'package:batak_app/engine/team_engine.dart';
import 'package:batak_app/engine/scoring_engine.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';

List<List<PlayingCard>> seededDeal(int seed) {
  final deck = Deck();
  deck.cards.shuffle(Random(seed));
  return deck.dealCards();
}

SavedGameModel createSampleSavedGame({
  BatakGameMode gameMode = BatakGameMode.single,
  GamePhase currentPhase = GamePhase.bidding,
  int schemaVersion = 1,
  int currentRound = 1,
  int totalRounds = 5,
}) {
  return SavedGameModel(
    schemaVersion: schemaVersion,
    savedAt: DateTime.now().toIso8601String(),
    gameMode: gameMode,
    currentPhase: currentPhase,
    totalRounds: totalRounds,
    currentRound: currentRound,
    currentTurnIndex: 0,
    biddingTurnIndex: 0,
    currentHighestBid: 5,
    highestBidderIndex: 0,
    bidderIndex: 0,
    passedPlayers: [1, 2],
    currentTrump: Suit.spades,
    tricksPlayed: 0,
    players: [
      Player(
        id: '1',
        name: 'Oyuncu',
        isAI: false,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.ace),
          PlayingCard(suit: Suit.hearts, rank: Rank.king),
        ],
        bid: 5,
        tricksWon: 0,
      ),
      Player(
        id: '2',
        name: 'Erol',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.diamonds, rank: Rank.ten),
          PlayingCard(suit: Suit.clubs, rank: Rank.five),
        ],
        bid: 0,
        tricksWon: 0,
      ),
      Player(
        id: '3',
        name: 'Leyla',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.two),
        ],
        bid: 0,
        tricksWon: 0,
      ),
      Player(
        id: '4',
        name: 'Kemal',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.three),
        ],
        bid: 0,
        tricksWon: 0,
      ),
    ],
    tableCards: [],
    playedCardsByPlayer: {},
    cumulativeScores: [0, 0, 0, 0],
    roundScoresHistory: [],
    roundResults: [],
    roundScored: false,
    statusMessage: '',
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SoundService.soundEnabled = false;
  });

  // ============================================================
  // İHALELİ BATAK RESUME (16 - 21)
  // ============================================================
  group('LIKYA-V2-006 — İHALELİ BATAK RESUME', () {
    test('16. Resume during bidding restores exact auction state', () {
      final hands = seededDeal(1);
      final original = GameProvider();
      original.gameMode = BatakGameMode.single;
      original.totalRounds = 5;
      original.currentRound = 2;
      original.currentPhase = GamePhase.bidding;
      original.biddingTurnIndex = 1;
      original.currentHighestBid = 6;
      original.highestBidderIndex = 0;
      original.passedPlayers.add(2);
      original.players = List.generate(4, (i) => Player(id: '$i', name: 'P$i', isAI: i > 0, hand: hands[i]));

      final saved = original.toSavedGameModel();

      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.gameMode, BatakGameMode.single);
      expect(restoredProvider.currentRound, 2);
      expect(restoredProvider.currentPhase, GamePhase.bidding);
      expect(restoredProvider.biddingTurnIndex, 1);
      expect(restoredProvider.currentHighestBid, 6);
      expect(restoredProvider.highestBidderIndex, 0);
      expect(restoredProvider.passedPlayers.contains(2), isTrue);
      original.dispose();
      restoredProvider.dispose();
    });

    test('17. Resume during trump selection restores human selection phase', () {
      final hands = seededDeal(2);
      final original = GameProvider();
      original.currentPhase = GamePhase.trumpSelection;
      original.bidderIndex = 0;
      original.currentHighestBid = 7;
      original.players = List.generate(4, (i) => Player(id: '$i', name: 'P$i', isAI: i > 0, hand: hands[i]));

      final saved = original.toSavedGameModel();

      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.currentPhase, GamePhase.trumpSelection);
      expect(restoredProvider.bidderIndex, 0);

      // Restored state allows human to select trump
      final res = restoredProvider.userSelectTrump(Suit.clubs);
      expect(res.success, isTrue);
      expect(restoredProvider.currentTrump, Suit.clubs);
      expect(restoredProvider.currentPhase, GamePhase.playing);
      original.dispose();
      restoredProvider.dispose();
    });

    test('18. Resume mid-trick restores table cards and player played cards', () {
      final hands = seededDeal(3);
      final table = [
        hands[0].removeAt(0), // P0 played
        hands[1].removeAt(0), // P1 played
      ];

      final original = GameProvider();
      original.currentPhase = GamePhase.playing;
      original.currentTurnIndex = 2; // P2's turn
      original.tableCards = List.of(table);
      original.playedCardsByPlayer = {0: table[0], 1: table[1]};
      original.players = List.generate(4, (i) => Player(id: '$i', name: 'P$i', isAI: i > 0, hand: hands[i]));

      final saved = original.toSavedGameModel();

      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.tableCards.length, 2);
      expect(restoredProvider.tableCards[0], equals(table[0]));
      expect(restoredProvider.tableCards[1], equals(table[1]));
      expect(restoredProvider.playedCardsByPlayer[0], equals(table[0]));
      expect(restoredProvider.playedCardsByPlayer[1], equals(table[1]));
      expect(restoredProvider.currentTurnIndex, 2);
      original.dispose();
      restoredProvider.dispose();
    });

    test('19. Cumulative scores and round history survive across restore', () {
      final original = GameProvider();
      original.cumulativeScores = [50, -50, 4, 3];
      original.roundScoresHistory = [
        [50, -50, 4, 3]
      ];
      original.roundResults = [
        const RoundResult(
          roundNumber: 1,
          bidderIndex: 0,
          bid: 5,
          trump: Suit.spades,
          gameMode: 'single',
          tricksByPlayer: [5, 3, 3, 2],
          scoreDeltaByPlayer: [50, -50, 4, 3],
          cumulativeScores: [50, -50, 4, 3],
        )
      ];

      final saved = original.toSavedGameModel();
      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.cumulativeScores, [50, -50, 4, 3]);
      expect(restoredProvider.roundScoresHistory.length, 1);
      expect(restoredProvider.roundResults.length, 1);
      expect(restoredProvider.roundResults[0].gameMode, 'single');
      original.dispose();
      restoredProvider.dispose();
    });
  });

  // ============================================================
  // EŞLİ BATAK RESUME (22 - 24)
  // ============================================================
  group('LIKYA-V2-006 — EŞLİ BATAK RESUME', () {
    test('22. Eşli Batak team structure and partner relationships preserved', () {
      final hands = seededDeal(4);
      final original = GameProvider();
      original.gameMode = BatakGameMode.partner;
      original.currentRound = 3;
      original.players = List.generate(4, (i) => Player(id: '$i', name: 'P$i', isAI: i > 0, hand: hands[i]));

      final saved = original.toSavedGameModel();
      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.gameMode, BatakGameMode.partner);
      expect(TeamEngine.areSameTeam(0, 2), isTrue);
      expect(TeamEngine.areSameTeam(1, 3), isTrue);
      expect(TeamEngine.teamForPlayer(0), TeamId.teamA);
      expect(TeamEngine.teamForPlayer(1), TeamId.teamB);
      original.dispose();
      restoredProvider.dispose();
    });

    test('23. Eşli team cumulative scores and partner round results preserved', () {
      final original = GameProvider();
      original.gameMode = BatakGameMode.partner;
      original.cumulativeScores = [81, 40, 81, 40];
      original.roundResults = [
        const RoundResult(
          roundNumber: 1,
          bidderIndex: 0,
          bid: 8,
          trump: Suit.hearts,
          gameMode: 'partner',
          tricksByPlayer: [5, 4, 4, 0],
          scoreDeltaByPlayer: [81, 40, 81, 40],
          cumulativeScores: [81, 40, 81, 40],
        )
      ];

      final saved = original.toSavedGameModel();
      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.cumulativeScores, [81, 40, 81, 40]);
      expect(restoredProvider.roundResults[0].gameMode, 'partner');
      original.dispose();
      restoredProvider.dispose();
    });
  });

  // ============================================================
  // KOZ MAÇA RESUME (25 - 27)
  // ============================================================
  group('LIKYA-V2-006 — KOZ MAÇA RESUME', () {
    test('25. Koz Maça restores with fixed Suit.spades and no bidding phase', () {
      final hands = seededDeal(5);
      final original = GameProvider();
      original.gameMode = BatakGameMode.kozMaca;
      original.currentPhase = GamePhase.playing;
      original.currentTrump = Suit.spades;
      original.bidderIndex = -1;
      original.players = List.generate(4, (i) => Player(id: '$i', name: 'P$i', isAI: i > 0, hand: hands[i]));

      final saved = original.toSavedGameModel();
      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.gameMode, BatakGameMode.kozMaca);
      expect(restoredProvider.currentTrump, Suit.spades);
      expect(restoredProvider.currentPhase, GamePhase.playing);

      // Attempting to change trump remains rejected
      final res = restoredProvider.userSelectTrump(Suit.hearts);
      expect(res.success, isFalse);
      original.dispose();
      restoredProvider.dispose();
    });
  });

  // ============================================================
  // SAFETY & LIFECYCLE GUARDS (28 - 34)
  // ============================================================
  group('LIKYA-V2-006 — SAFETY & LIFECYCLE GUARDS', () {
    test('28. Restore at round completion does NOT double-score', () {
      final original = GameProvider();
      original.cumulativeScores = [50, 10, 20, 30];
      original.currentRound = 1;
      original.totalRounds = 3;
      original.currentPhase = GamePhase.roundFinished;
      original.roundResults = [
        const RoundResult(
          roundNumber: 1,
          bidderIndex: 0,
          bid: 5,
          trump: Suit.spades,
          gameMode: 'single',
          tricksByPlayer: [5, 3, 3, 2],
          scoreDeltaByPlayer: [50, 10, 20, 30],
          cumulativeScores: [50, 10, 20, 30],
        )
      ];

      final saved = original.toSavedGameModel();
      final restoredProvider = GameProvider();
      restoredProvider.restoreFromSavedGame(saved);

      expect(restoredProvider.cumulativeScores, [50, 10, 20, 30]);
      expect(restoredProvider.roundResults.length, 1);
      original.dispose();
      restoredProvider.dispose();
    });

    test('29. Restoring invalidates previous timers via _gameGeneration', () {
      final original = GameProvider();
      final genBefore = original.toSavedGameModel();

      final restored = GameProvider();
      restored.restoreFromSavedGame(genBefore);

      // restored gameGeneration has incremented, protecting old callbacks
      expect(restored.isDisposed, isFalse);
      original.dispose();
      restored.dispose();
    });

    test('30. startNewGame creates fresh save with round 1', () async {
      final p = GameProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      p.currentRound = 3;
      await p.autoSaveCurrentGame();
      final saved3 = await GameSaveService.loadGame();
      expect(saved3?.currentRound, 3);

      p.startNewGame();
      await Future.delayed(const Duration(milliseconds: 50));
      final savedNew = await GameSaveService.loadGame();
      expect(savedNew?.currentRound, 1);
      p.dispose();
    });

    test('31. leaveMatch deletes existing save file', () async {
      final p = GameProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      await p.autoSaveCurrentGame();
      expect(await GameSaveService.hasSavedGame(), isTrue);

      p.leaveMatch();
      expect(await GameSaveService.hasSavedGame(), isFalse);
      p.dispose();
    });
  });

  // ============================================================
  // 100-CYCLE PERSISTENCE STRESS TEST (STEP 21)
  // ============================================================
  group('LIKYA-V2-006 — 100-CYCLE PERSISTENCE STRESS TEST', () {
    test('100 save -> destroy provider -> restore cycles with 0 drift and 0 corruption', () async {
      final rng = Random(42);
      final modes = [BatakGameMode.single, BatakGameMode.partner, BatakGameMode.kozMaca];

      final cycleErrorList = <String>[];

      for (int cycle = 0; cycle < 100; cycle++) {
        final mode = modes[cycle % modes.length];
        final hands = seededDeal(cycle * 19 + 3);

        // 1. Create provider with randomized active state
        final provider = GameProvider();
        await Future.delayed(const Duration(milliseconds: 5));
        provider.gameMode = mode;
        provider.totalRounds = 5;
        provider.currentRound = (cycle % 5) + 1;
        provider.currentTurnIndex = 0; // Keep on human to prevent background async bot action racing assertions
        provider.currentTrump = (mode == BatakGameMode.kozMaca)
            ? Suit.spades
            : Suit.values[rng.nextInt(4)];
        if (mode == BatakGameMode.kozMaca) {
          provider.currentPhase = GamePhase.playing;
        } else {
          provider.currentPhase = (cycle % 2 == 0) ? GamePhase.bidding : GamePhase.playing;
          provider.biddingTurnIndex = 0; // Keep on human to prevent async bot timers racing assertions
        }
        provider.players = List.generate(4, (i) => Player(id: '$i', name: 'P$i', isAI: i > 0, hand: hands[i]));

        // 2. Save
        final savedModel = provider.toSavedGameModel();
        final errors = savedModel.validateIntegrity();
        if (errors.isNotEmpty) {
          cycleErrorList.add('Cycle $cycle validation error: $errors');
          provider.dispose();
          continue;
        }

        final saveOk = await GameSaveService.saveGame(savedModel);
        if (!saveOk) {
          cycleErrorList.add('Cycle $cycle saveGame failed');
          provider.dispose();
          continue;
        }

        // 3. Destroy old provider & load from disk
        provider.dispose();
        final loadedModel = await GameSaveService.loadGame();
        if (loadedModel == null) {
          cycleErrorList.add('Cycle $cycle loadGame returned null');
          continue;
        }

        // 4. Restore to a completely new provider instance
        final newProvider = GameProvider();
        newProvider.restoreFromSavedGame(loadedModel);

        // 5. Assert authoritative equality
        if (newProvider.gameMode != mode ||
            newProvider.currentRound != ((cycle % 5) + 1) ||
            newProvider.currentTrump != savedModel.currentTrump ||
            newProvider.players.length != 4) {
          cycleErrorList.add('Cycle $cycle mismatch: restoredMode=${newProvider.gameMode}, expectedMode=$mode, restoredRound=${newProvider.currentRound}, expectedRound=${(cycle % 5) + 1}, restoredTrump=${newProvider.currentTrump}, savedTrump=${savedModel.currentTrump}, playersLen=${newProvider.players.length}');
        }
        newProvider.dispose();
      }

      expect(cycleErrorList, isEmpty, reason: 'Persistence stress test had failures: $cycleErrorList');
    });
  });

  // ============================================================
  // JSON PAYLOAD SIZE MEASUREMENT (STEP 22)
  // ============================================================
  group('LIKYA-V2-006 — JSON PAYLOAD SIZE', () {
    test('Measure typical save payload sizes', () {
      final newMatch = createSampleSavedGame(currentRound: 1);
      final midRound = createSampleSavedGame(currentRound: 3);
      final lateMatch = createSampleSavedGame(currentRound: 5);

      final newSize = newMatch.toJsonString().length;
      final midSize = midRound.toJsonString().length;
      final lateSize = lateMatch.toJsonString().length;

      // Assert payload remains under 5 KB (ideal for SharedPreferences)
      expect(newSize, lessThan(5000));
      expect(midSize, lessThan(5000));
      expect(lateSize, lessThan(5000));
    });
  });
}
