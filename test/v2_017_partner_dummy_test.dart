import 'package:batak_app/engine/scoring_engine.dart';
import 'package:batak_app/engine/team_engine.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit: suit, rank: rank);

GameProvider partner(int bidder, int turn) {
  final p = GameProvider();
  p.gameMode = BatakGameMode.partner;
  p.currentPhase = GamePhase.playing;
  p.bidderIndex = bidder;
  p.currentTurnIndex = turn;
  p.currentTrump = Suit.spades;
  p.tableCards.clear();
  p.playedCardsByPlayer.clear();
  return p;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundService.soundEnabled = false;
  });

  for (final pair in [(0, 2), (2, 0), (1, 3), (3, 1)]) {
    test('bidder ${pair.$1} exposes dummy ${pair.$2}', () {
      final p = partner(pair.$1, pair.$2);
      expect(p.partnerDeclarerIndex, pair.$1);
      expect(p.partnerDummyIndex, pair.$2);
      expect(p.isDummyPlayer(pair.$2), isTrue);
      expect(TeamEngine.areSameTeam(pair.$1, pair.$2), isTrue);
      p.dispose();
    });
  }

  test('human bidder leads first after trump selection', () {
    final p = partner(0, 3);
    p.currentPhase = GamePhase.trumpSelection;
    expect(p.userSelectTrump(Suit.clubs).success, isTrue);
    expect(p.currentTurnIndex, 0);
    expect(p.partnerDummyIndex, 2);
    p.dispose();
  });

  test('AI bidder leads first after bidding concludes', () {
    final p = GameProvider();
    p.gameMode = BatakGameMode.partner;
    p.highestBidderIndex = 2;
    p.currentHighestBid = 8;
    p.passedPlayers = {1, 3};
    p.biddingTurnIndex = 0;
    expect(p.userPassBid().success, isTrue);
    expect(p.currentPhase, GamePhase.playing);
    expect(p.currentTurnIndex, 2);
    expect(p.partnerDummyIndex, 0);
    p.dispose();
  });

  test('human declarer controls AI dummy; no bot plays for dummy', () async {
    final p = partner(0, 2);
    expect(p.players[2].isAI, isTrue);
    expect(p.isHumanControllerForPlayer(2), isTrue);
    expect(p.shouldAIControlPlayer(2), isFalse);
    await Future<void>.delayed(Duration(milliseconds: p.delayBase + 60));
    expect(p.tableCards, isEmpty);
    final card = p.getValidMovesForPlayer(p.players[2]).first;
    expect((await p.playCard(p.players[2], card)).success, isTrue);
    expect(p.playedCardsByPlayer[2], card);
    p.dispose();
  });

  test('AI declarer controls human dummy; human tap rejected', () async {
    final p = partner(2, 0);
    expect(p.players[0].isAI, isFalse);
    expect(p.shouldAIControlPlayer(0), isTrue);
    expect(p.isHumanControllerForPlayer(0), isFalse);
    final card = p.players[0].hand.first;
    expect((await p.playCard(p.players[0], card)).success, isFalse);
    expect(p.players[0].hand, contains(card));
    expect(p.tableCards, isEmpty);
    p.dispose();
  });

  test('dummy legal moves use dummy hand and follow suit', () async {
    final p = partner(0, 2);
    p.tableCards = [c(Suit.hearts, Rank.two), c(Suit.hearts, Rank.king)];
    p.players[2].hand = [c(Suit.hearts, Rank.ace), c(Suit.spades, Rank.jack)];
    p.players[0].hand = [c(Suit.spades, Rank.ace)];
    expect(p.getValidMovesForPlayer(p.players[2]), [c(Suit.hearts, Rank.ace)]);
    expect((await p.playCard(p.players[2], c(Suit.spades, Rank.jack))).success, isFalse);
    expect((await p.playCard(p.players[2], c(Suit.hearts, Rank.ace))).success, isTrue);
    p.dispose();
  });

  test('dummy must overtrump when authoritative rules require it', () async {
    final p = partner(0, 2);
    p.tableCards = [c(Suit.hearts, Rank.two), c(Suit.spades, Rank.seven)];
    p.players[2].hand = [c(Suit.spades, Rank.jack), c(Suit.clubs, Rank.ace)];
    expect(p.getValidMovesForPlayer(p.players[2]), [c(Suit.spades, Rank.jack)]);
    expect((await p.playCard(p.players[2], c(Suit.clubs, Rank.ace))).success, isFalse);
    p.dispose();
  });

  test('rapid duplicate dummy tap mutates hand once', () async {
    final p = partner(0, 2);
    final card = p.players[2].hand.first;
    final before = p.players[2].hand.length;
    final results = await Future.wait([
      p.playCard(p.players[2], card),
      p.playCard(p.players[2], card),
    ]);
    expect(results.where((r) => r.success).length, 1);
    expect(p.players[2].hand.length, before - 1);
    expect(p.tableCards.length, 1);
    p.dispose();
  });

  test('trick winner remains next lead, including dummy winner', () async {
    final p = partner(0, 0);
    p.players[1] = Player(id: '2', name: 'Test 1', hand: [c(Suit.hearts, Rank.king)]);
    p.players[3] = Player(id: '4', name: 'Test 3', hand: [c(Suit.hearts, Rank.three)]);
    p.players[0].hand = [c(Suit.hearts, Rank.two)];
    p.players[2].hand = [c(Suit.hearts, Rank.ace)];
    expect((await p.playCard(p.players[0], c(Suit.hearts, Rank.two))).success, isTrue);
    expect((await p.playCard(p.players[1], c(Suit.hearts, Rank.king))).success, isTrue);
    expect((await p.playCard(p.players[2], c(Suit.hearts, Rank.ace))).success, isTrue);
    expect((await p.playCard(p.players[3], c(Suit.hearts, Rank.three))).success, isTrue);
    await Future<void>.delayed(Duration(milliseconds: (p.delayBase * 1.5).round() + 80));
    expect(p.players[2].tricksWon, 1);
    expect(p.currentTurnIndex, 2);
    expect(p.currentPhase, GamePhase.playing);
    p.dispose();
  });

  test('team scoring remains 0+2 and 1+3', () {
    final p = partner(0, 0);
    p.players[0].tricksWon = 3;
    p.players[2].tricksWon = 5;
    p.players[1].tricksWon = 2;
    p.players[3].tricksWon = 3;
    final score = ScoringEngine.computePartnerModeRound(
      players: p.players, bidderIndex: 0, bid: 8, trump: Suit.spades,
      roundNumber: 1, prevCumulativeScores: [0, 0, 0, 0],
    );
    expect(score.scoreDeltaByPlayer, [80, 50, 80, 50]);
    p.dispose();
  });

  test('restore human declarer at AI dummy turn does not schedule bot', () async {
    final original = partner(0, 2);
    final restored = GameProvider();
    restored.restoreFromSavedGame(original.toSavedGameModel());
    expect(restored.partnerDummyIndex, 2);
    expect(restored.isHumanControllerForPlayer(2), isTrue);
    await Future<void>.delayed(Duration(milliseconds: restored.delayBase + 80));
    expect(restored.tableCards, isEmpty);
    original.dispose();
    restored.dispose();
  });

  test('restore AI declarer at human dummy turn schedules AI', () async {
    final original = partner(2, 0);
    final restored = GameProvider();
    restored.restoreFromSavedGame(original.toSavedGameModel());
    expect(restored.partnerDummyIndex, 0);
    expect(restored.shouldAIControlPlayer(0), isTrue);
    await Future<void>.delayed(Duration(milliseconds: restored.delayBase + 100));
    expect(restored.tableCards.length, 1);
    expect(restored.playedCardsByPlayer.keys, contains(0));
    original.dispose();
    restored.dispose();
  });

  for (final mode in [BatakGameMode.single, BatakGameMode.kozMaca]) {
    test('$mode retains independent seat control', () {
      final p = GameProvider();
      p.gameMode = mode;
      p.startNewGame();
      expect(p.partnerDeclarerIndex, isNull);
      expect(p.partnerDummyIndex, isNull);
      expect(p.isHumanControllerForPlayer(0), isTrue);
      expect(p.shouldAIControlPlayer(1), isTrue);
      p.dispose();
    });
  }
}
