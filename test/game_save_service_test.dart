import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/engine/scoring_engine.dart';
import 'package:batak_app/providers/game_provider.dart';

SavedGameModel createSampleSavedGame({
  BatakGameMode gameMode = BatakGameMode.single,
  GamePhase currentPhase = GamePhase.bidding,
  int schemaVersion = 1,
  List<PlayingCard>? customP0Hand,
  List<PlayingCard>? customTableCards,
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
        hand: customP0Hand ??
            [
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
        name: 'Arda',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.hearts, rank: Rank.queen),
          PlayingCard(suit: Suit.spades, rank: Rank.jack),
        ],
        bid: 0,
        tricksWon: 0,
      ),
      Player(
        id: '4',
        name: 'Uğur',
        isAI: true,
        hand: [
          PlayingCard(suit: Suit.clubs, rank: Rank.ace),
          PlayingCard(suit: Suit.diamonds, rank: Rank.two),
        ],
        bid: 0,
        tricksWon: 0,
      ),
    ],
    tableCards: customTableCards ?? [],
    playedCardsByPlayer: {},
    cumulativeScores: [0, 0, 0, 0],
    roundScoresHistory: [],
    roundResults: [
      const RoundResult(
        roundNumber: 1,
        bidderIndex: 0,
        bid: 5,
        trump: Suit.spades,
        gameMode: 'single',
        tricksByPlayer: [5, 3, 3, 2],
        scoreDeltaByPlayer: [50, 3, 3, 2],
        cumulativeScores: [50, 3, 3, 2],
      ),
    ],
    roundScored: false,
    statusMessage: "Oyun kaydedildi",
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // SERIALIZATION TESTS (1 - 4)
  // ============================================================
  group('LIKYA-V2-006 — SERIALIZATION', () {
    test('1. PlayingCard round-trip serialization is exact', () {
      final card = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      final json = SavedGameModel.cardToJson(card);
      final restored = SavedGameModel.cardFromJson(json);

      expect(restored, isNotNull);
      expect(restored!.suit, Suit.hearts);
      expect(restored.rank, Rank.ace);
      expect(restored, equals(card));
    });

    test('2. Player round-trip serialization preserves hand and properties', () {
      final player = Player(
        id: '1',
        name: 'Test Oyuncu',
        isAI: false,
        hand: [
          PlayingCard(suit: Suit.spades, rank: Rank.king),
          PlayingCard(suit: Suit.diamonds, rank: Rank.seven),
        ],
        bid: 6,
        tricksWon: 4,
      );

      final json = SavedGameModel.playerToJson(player);
      final restored = SavedGameModel.playerFromJson(json);

      expect(restored, isNotNull);
      expect(restored!.id, '1');
      expect(restored.name, 'Test Oyuncu');
      expect(restored.isAI, isFalse);
      expect(restored.bid, 6);
      expect(restored.tricksWon, 4);
      expect(restored.hand.length, 2);
      expect(restored.hand[0], equals(player.hand[0]));
      expect(restored.hand[1], equals(player.hand[1]));
    });

    test('3. RoundResult round-trip serialization is lossless', () {
      const result = RoundResult(
        roundNumber: 2,
        bidderIndex: 1,
        bid: 8,
        trump: Suit.clubs,
        gameMode: 'partner',
        tricksByPlayer: [2, 5, 2, 4],
        scoreDeltaByPlayer: [40, 81, 40, 81],
        cumulativeScores: [40, 81, 40, 81],
      );

      final json = SavedGameModel.roundResultToJson(result);
      final restored = SavedGameModel.roundResultFromJson(json);

      expect(restored, isNotNull);
      expect(restored!.roundNumber, 2);
      expect(restored.bidderIndex, 1);
      expect(restored.bid, 8);
      expect(restored.trump, Suit.clubs);
      expect(restored.gameMode, 'partner');
      expect(restored.tricksByPlayer, [2, 5, 2, 4]);
      expect(restored.scoreDeltaByPlayer, [40, 81, 40, 81]);
      expect(restored.cumulativeScores, [40, 81, 40, 81]);
    });

    test('4. Complete SavedGameModel round-trip preserves full session state', () {
      final original = createSampleSavedGame();
      final jsonStr = original.toJsonString();
      final restored = SavedGameModel.fromJsonString(jsonStr);

      expect(restored, isNotNull);
      expect(restored!.schemaVersion, 1);
      expect(restored.gameMode, original.gameMode);
      expect(restored.currentPhase, original.currentPhase);
      expect(restored.totalRounds, original.totalRounds);
      expect(restored.currentRound, original.currentRound);
      expect(restored.currentTrump, original.currentTrump);
      expect(restored.players.length, 4);
      expect(restored.roundResults.length, 1);
    });
  });

  // ============================================================
  // SAVE SERVICE TESTS (5 - 8)
  // ============================================================
  group('LIKYA-V2-006 — GAME SAVE SERVICE', () {
    test('5. Initially no saved game exists', () async {
      expect(await GameSaveService.hasSavedGame(), isFalse);
      expect(await GameSaveService.loadGame(), isNull);
    });

    test('6. saveGame followed by loadGame returns identical model', () async {
      final sample = createSampleSavedGame();
      final saveResult = await GameSaveService.saveGame(sample);
      expect(saveResult, isTrue);

      expect(await GameSaveService.hasSavedGame(), isTrue);

      final loaded = await GameSaveService.loadGame();
      expect(loaded, isNotNull);
      expect(loaded!.gameMode, sample.gameMode);
      expect(loaded.currentRound, sample.currentRound);
      expect(loaded.totalRounds, sample.totalRounds);
      expect(loaded.currentTrump, sample.currentTrump);
    });

    test('7. deleteSave removes saved game completely', () async {
      final sample = createSampleSavedGame();
      await GameSaveService.saveGame(sample);
      expect(await GameSaveService.hasSavedGame(), isTrue);

      final deleteResult = await GameSaveService.deleteSave();
      expect(deleteResult, isTrue);
      expect(await GameSaveService.hasSavedGame(), isFalse);
      expect(await GameSaveService.loadGame(), isNull);
    });

    test('8. Malformed JSON string is safely quarantined and deleted without crash', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(GameSaveService.saveKey, "NOT_A_VALID_JSON{:::malformed");

      final loaded = await GameSaveService.loadGame();
      expect(loaded, isNull);
      // Corrupt save must be deleted automatically
      expect(await GameSaveService.hasSavedGame(), isFalse);
    });
  });

  // ============================================================
  // INTEGRITY & CARD CONSERVATION VALIDATION (9 - 15)
  // ============================================================
  group('LIKYA-V2-006 — INTEGRITY VALIDATION', () {
    test('9. Invalid suit name in JSON returns null safely', () {
      final invalidCard = SavedGameModel.cardFromJson({'suit': 'unknown_suit', 'rank': 'ace'});
      expect(invalidCard, isNull);
    });

    test('10. Invalid rank name in JSON returns null safely', () {
      final invalidCard = SavedGameModel.cardFromJson({'suit': 'hearts', 'rank': 'super_rank'});
      expect(invalidCard, isNull);
    });

    test('11. Duplicate cards across hands/table triggers validation failure', () {
      final duplicateCard = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      final modelWithDuplicate = createSampleSavedGame(
        customP0Hand: [duplicateCard],
        customTableCards: [duplicateCard], // Same card on table and in hand!
      );

      final errors = modelWithDuplicate.validateIntegrity();
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains("Mükerrer") || e.contains("eldeki kart")), isTrue);
    });

    test('12. Player count != 4 triggers validation error', () {
      final model = SavedGameModel(
        savedAt: DateTime.now().toIso8601String(),
        gameMode: BatakGameMode.single,
        currentPhase: GamePhase.bidding,
        totalRounds: 5,
        currentRound: 1,
        currentTurnIndex: 0,
        biddingTurnIndex: 0,
        currentHighestBid: 5,
        highestBidderIndex: 0,
        bidderIndex: 0,
        passedPlayers: [],
        currentTrump: Suit.spades,
        tricksPlayed: 0,
        players: [
          Player(id: '1', name: '1', hand: []),
          Player(id: '2', name: '2', hand: []),
        ], // Only 2 players
        tableCards: [],
        playedCardsByPlayer: {},
        cumulativeScores: [0, 0],
        roundScoresHistory: [],
        roundResults: [],
        roundScored: false,
        statusMessage: '',
      );

      final errors = model.validateIntegrity();
      expect(errors.any((e) => e.contains("Oyuncu sayısı 4 olmalı")), isTrue);
    });

    test('13. Unsupported schemaVersion != 1 is rejected', () {
      final model = createSampleSavedGame(schemaVersion: 99);
      expect(model.validateIntegrity().any((e) => e.contains("şema versiyonu")), isTrue);

      final jsonStr = model.toJsonString();
      final loaded = SavedGameModel.fromJsonString(jsonStr);
      expect(loaded, isNull);
    });

    test('14. Invalid player turn index out of bounds is rejected', () {
      final model = SavedGameModel(
        savedAt: DateTime.now().toIso8601String(),
        gameMode: BatakGameMode.single,
        currentPhase: GamePhase.playing,
        totalRounds: 5,
        currentRound: 1,
        currentTurnIndex: 9, // Out of bounds
        biddingTurnIndex: 0,
        currentHighestBid: 5,
        highestBidderIndex: 0,
        bidderIndex: 0,
        passedPlayers: [],
        currentTrump: Suit.spades,
        tricksPlayed: 0,
        players: List.generate(4, (i) => Player(id: '$i', name: '$i', hand: [])),
        tableCards: [],
        playedCardsByPlayer: {},
        cumulativeScores: [0, 0, 0, 0],
        roundScoresHistory: [],
        roundResults: [],
        roundScored: false,
        statusMessage: '',
      );

      final errors = model.validateIntegrity();
      expect(errors.any((e) => e.contains("Geçersiz sıra indeksi")), isTrue);
    });

    test('15. Gömmeli mode is not persisted by GameSaveService', () async {
      final gommeliModel = createSampleSavedGame(gameMode: BatakGameMode.gommeli);
      final saved = await GameSaveService.saveGame(gommeliModel);
      expect(saved, isFalse);
    });
  });
}
