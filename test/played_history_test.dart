import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/played_card_record.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SoundService.soundEnabled = false;
  });

  group('LIKYA-V2-007B — Played History Tests', () {
    test('1. valid card adds one record', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTurnIndex = 0;
      final card = provider.players[0].hand.first;

      expect(provider.playedHistory, isEmpty);
      final result = await provider.playCard(provider.players[0], card);
      expect(result.success, isTrue);

      expect(provider.playedHistory.length, 1);
      expect(provider.playedHistory.first.card, card);
      expect(provider.playedHistory.first.playerIndex, 0);
    });

    test('2. illegal card adds zero records', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTurnIndex = 0;

      // Card not in player's hand
      final fakeCard = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      // Remove it if present to guarantee it is unowned
      provider.players[0].hand.remove(fakeCard);

      final result = await provider.playCard(provider.players[0], fakeCard);
      expect(result.success, isFalse);
      expect(provider.playedHistory, isEmpty);
      expect(provider.botMemory.playedCards, isEmpty);
    });

    test('3. playerIndex preserved in record', () {
      final rec = PlayedCardRecord(
        playerIndex: 2,
        card: PlayingCard(suit: Suit.hearts, rank: Rank.king),
        trickNumber: 3,
      );

      expect(rec.playerIndex, 2);
    });

    test('4. card preserved in record', () {
      final card = PlayingCard(suit: Suit.diamonds, rank: Rank.queen);
      final rec = PlayedCardRecord(
        playerIndex: 1,
        card: card,
        trickNumber: 0,
      );

      expect(rec.card, card);
      expect(rec.card.suit, Suit.diamonds);
      expect(rec.card.rank, Rank.queen);
    });

    test('5. trickNumber preserved in record', () {
      final rec = PlayedCardRecord(
        playerIndex: 3,
        card: PlayingCard(suit: Suit.clubs, rank: Rank.five),
        trickNumber: 7,
      );

      expect(rec.trickNumber, 7);
    });

    test('6. duplicate callback does not duplicate history', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTurnIndex = 0;
      final card = provider.players[0].hand.first;

      await provider.playCard(provider.players[0], card);
      expect(provider.playedHistory.length, 1);

      // Attempting to play the same card again fails validation
      final secondPlay = await provider.playCard(provider.players[0], card);
      expect(secondPlay.success, isFalse);
      expect(provider.playedHistory.length, 1);
    });

    test('7. fresh round clears history', () {
      final provider = GameProvider();
      provider.playedHistory.add(
        PlayedCardRecord(
          playerIndex: 0,
          card: PlayingCard(suit: Suit.spades, rank: Rank.ace),
          trickNumber: 0,
        ),
      );
      expect(provider.playedHistory, isNotEmpty);

      provider.startNewGame();
      expect(provider.playedHistory, isEmpty);
      expect(provider.botMemory.playedCards, isEmpty);
    });

    test('8. save round-trip preserves history', () async {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTurnIndex = 0;
      final card1 = provider.players[0].hand.first;

      await provider.playCard(provider.players[0], card1);
      expect(provider.playedHistory.length, 1);

      final model = provider.toSavedGameModel();
      expect(model.playedHistory.length, 1);
      expect(model.playedHistory.first.card, card1);

      final json = model.toJson();
      final restoredModel = SavedGameModel.fromJson(json);
      expect(restoredModel, isNotNull);
      expect(restoredModel!.playedHistory.length, 1);
      expect(restoredModel.playedHistory.first.card, card1);
      expect(restoredModel.playedHistory.first.playerIndex, 0);
      expect(restoredModel.playedHistory.first.trickNumber, 0);
    });

    test('9. legacy save without history loads safely', () {
      final provider = GameProvider();
      final model = provider.toSavedGameModel();
      final json = model.toJson();

      // Simulate legacy JSON that lacks 'playedHistory' field
      json.remove('playedHistory');

      final restoredModel = SavedGameModel.fromJson(json);
      expect(restoredModel, isNotNull);
      expect(restoredModel!.playedHistory, isEmpty);

      // Restoring from this legacy model should succeed cleanly
      final newProvider = GameProvider();
      newProvider.restoreFromSavedGame(restoredModel);
      expect(newProvider.playedHistory, isEmpty);
      expect(newProvider.botMemory.playedCards, isEmpty);
    });

    test('10. restore reconstructs BotMemory from history', () {
      final provider = GameProvider();
      final c1 = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      final c2 = PlayingCard(suit: Suit.clubs, rank: Rank.two); // player 1 off-suit -> void in hearts!
      final history = [
        PlayedCardRecord(playerIndex: 0, card: c1, trickNumber: 0),
        PlayedCardRecord(playerIndex: 1, card: c2, trickNumber: 0),
      ];

      provider.currentTrump = Suit.spades;
      provider.playedHistory = List.of(history);

      final savedModel = provider.toSavedGameModel();
      final newProvider = GameProvider();
      newProvider.restoreFromSavedGame(savedModel);

      // Verify BotMemory reconstructed from public history
      expect(newProvider.playedHistory.length, 2);
      expect(newProvider.botMemory.hasCardBeenPlayed(c1), isTrue);
      expect(newProvider.botMemory.hasCardBeenPlayed(c2), isTrue);
      expect(newProvider.botMemory.playedCountForSuit(Suit.hearts), 1);
      expect(newProvider.botMemory.playedCountForSuit(Suit.clubs), 1);
      expect(newProvider.botMemory.voidSuitsForPlayer(1).contains(Suit.hearts), isTrue);
    });
  });
}
