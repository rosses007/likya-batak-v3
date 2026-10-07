import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/providers/game_provider.dart';

Future<Map<String, dynamic>> legacyJson() async =>
    jsonDecode(await File('test/fixtures/closed_test_1_2_0_v1.json').readAsString())
        as Map<String, dynamic>;

Future<SavedGameModel?> loadJson(Map<String, dynamic> json) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(GameSaveService.saveKey, jsonEncode(json));
  return GameSaveService.loadGame();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('1.2.0+3 v1 fixture without playedHistory opens in bidding', () async {
    final save = await loadJson(await legacyJson());
    expect(save, isNotNull);
    expect(save!.playedHistory, isEmpty);
    expect(save.schemaVersion, 1);
    final provider = GameProvider();
    provider.restoreFromSavedGame(save);
    expect(provider.currentPhase, GamePhase.bidding);
    provider.dispose();
  });
  for (final mode in ['single', 'partner', 'kozMaca']) {
    test('1.2.0+3 $mode playing save opens', () async {
      final json = await legacyJson();
      json['gameMode'] = mode;
      json['currentPhase'] = 'playing';
      json['currentTurnIndex'] = mode == 'partner' ? 2 : 0;
      final save = await loadJson(json);
      expect(save, isNotNull);
      final provider = GameProvider();
      provider.restoreFromSavedGame(save!);
      expect(provider.currentPhase, GamePhase.playing);
      if (mode == 'partner') {
        expect(provider.partnerDeclarerIndex, 0);
        expect(provider.partnerDummyIndex, 2);
        expect(provider.isHumanControllerForPlayer(2), isTrue);
      }
      provider.dispose();
    });
  }
  for (final count in [1, 2, 3]) {
    test('partial trick with $count cards restores', () async {
      final json = await legacyJson();
      json['currentPhase'] = 'playing';
      json['currentTurnIndex'] = count;
      final players = json['players'] as List<dynamic>;
      final table = <dynamic>[];
      final byPlayer = <String, dynamic>{};
      for (var i = 0; i < count; i++) {
        final hand = (players[i] as Map<String, dynamic>)['hand'] as List<dynamic>;
        final card = hand.removeAt(0);
        table.add(card);
        byPlayer['$i'] = card;
      }
      json['tableCards'] = table;
      json['playedCardsByPlayer'] = byPlayer;
      final save = await loadJson(json);
      expect(save, isNotNull);
      final provider = GameProvider();
      provider.restoreFromSavedGame(save!);
      expect(provider.tableCards.length, count);
      expect(provider.playedCardsByPlayer.length, count);
      provider.dispose();
    });
  }
  test('roundScored flag survives restore without applying score again', () async {
    final json = await legacyJson();
    json['currentPhase'] = 'roundFinished';
    json['roundScored'] = true;
    json['cumulativeScores'] = [50, 0, 0, 0];
    final save = await loadJson(json);
    expect(save, isNotNull);
    final provider = GameProvider();
    provider.restoreFromSavedGame(save!);
    expect(provider.cumulativeScores, [50, 0, 0, 0]);
    expect(provider.toSavedGameModel().roundScored, isTrue);
    provider.dispose();
  });
  test('corrupted and unsupported schema saves are deleted', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(GameSaveService.saveKey, '{bad json');
    expect(await GameSaveService.loadGame(), isNull);
    expect(await GameSaveService.hasSavedGame(), isFalse);
    final json = await legacyJson()..['schemaVersion'] = 99;
    expect(await loadJson(json), isNull);
    expect(await GameSaveService.hasSavedGame(), isFalse);
  });
  test('duplicate card is rejected and deleted', () async {
    final json = await legacyJson();
    final players = json['players'] as List<dynamic>;
    (players[1] as Map<String, dynamic>)['hand'] =
        (players[0] as Map<String, dynamic>)['hand'];
    expect(await loadJson(json), isNull);
    expect(await GameSaveService.hasSavedGame(), isFalse);
  });
  test('gameOver save is removed', () async {
    final json = await legacyJson();
    json['currentPhase'] = 'gameOver';
    final save = SavedGameModel.fromJson(json)!;
    expect(await GameSaveService.saveGame(save), isFalse);
    expect(await GameSaveService.hasSavedGame(), isFalse);
    expect(await loadJson(json), isNull);
    expect(await GameSaveService.hasSavedGame(), isFalse);
  });
}
