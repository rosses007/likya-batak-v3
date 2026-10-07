import 'dart:convert';
import 'card_model.dart';
import 'player_model.dart';
import '../engine/scoring_engine.dart';
import '../providers/game_provider.dart';
import 'played_card_record.dart';

/// Yetkili kayıtlı oyun veri modeli (LIKYA-V2-006).
///
/// Yalnızca mantıksal oyun durumunu serileştirir. Zamanlayıcılar, kilitler,
/// BuildContext veya servis referansları içermez.
class SavedGameModel {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String savedAt;
  final BatakGameMode gameMode;
  final GamePhase currentPhase;
  final int totalRounds;
  final int currentRound;
  final int currentTurnIndex;
  final int biddingTurnIndex;
  final int currentHighestBid;
  final int? highestBidderIndex;
  final List<PlayedCardRecord> playedHistory;

  final int bidderIndex;
  final List<int> passedPlayers;
  final Suit currentTrump;
  final int tricksPlayed;
  final List<Player> players;
  final List<PlayingCard> tableCards;
  final Map<int, PlayingCard> playedCardsByPlayer;
  final List<int> cumulativeScores;
  final List<List<int>> roundScoresHistory;
  final List<RoundResult> roundResults;
  final bool roundScored;
  final String statusMessage;

  const SavedGameModel({
    this.schemaVersion = currentSchemaVersion,
    required this.savedAt,
    required this.gameMode,
    required this.currentPhase,
    required this.totalRounds,
    required this.currentRound,
    required this.currentTurnIndex,
    required this.biddingTurnIndex,
    required this.currentHighestBid,
    required this.highestBidderIndex,
    this.playedHistory = const [],
    required this.bidderIndex,
    required this.passedPlayers,
    required this.currentTrump,
    required this.tricksPlayed,
    required this.players,
    required this.tableCards,
    required this.playedCardsByPlayer,
    required this.cumulativeScores,
    required this.roundScoresHistory,
    required this.roundResults,
    required this.roundScored,
    required this.statusMessage,
  });

  // ============================================================
  // JSON SERİLEŞTİRME
  // ============================================================

  static Map<String, dynamic> cardToJson(PlayingCard card) {
    return {
      'suit': card.suit.name,
      'rank': card.rank.name,
    };
  }

  static PlayingCard? cardFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final suitStr = json['suit'] as String?;
    final rankStr = json['rank'] as String?;
    if (suitStr == null || rankStr == null) return null;

    final suit = Suit.values.where((s) => s.name == suitStr).firstOrNull;
    final rank = Rank.values.where((r) => r.name == rankStr).firstOrNull;
    if (suit == null || rank == null) return null;

    return PlayingCard(suit: suit, rank: rank);
  }

  static Map<String, dynamic> playerToJson(Player player) {
    return {
      'id': player.id,
      'name': player.name,
      'isAI': player.isAI,
      'bid': player.bid,
      'tricksWon': player.tricksWon,
      'hand': player.hand.map(cardToJson).toList(),
    };
  }

  static Player? playerFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final isAI = json['isAI'] as bool? ?? false;
    final bid = json['bid'] as int? ?? 0;
    final tricksWon = json['tricksWon'] as int? ?? 0;
    final handRaw = json['hand'] as List<dynamic>?;

    if (id == null || name == null || handRaw == null) return null;

    final hand = <PlayingCard>[];
    for (final item in handRaw) {
      if (item is Map<String, dynamic>) {
        final card = cardFromJson(item);
        if (card == null) return null;
        hand.add(card);
      } else {
        return null;
      }
    }

    return Player(
      id: id,
      name: name,
      isAI: isAI,
      hand: hand,
      bid: bid,
      tricksWon: tricksWon,
    );
  }

  static Map<String, dynamic> roundResultToJson(RoundResult r) {
    return {
      'roundNumber': r.roundNumber,
      'bidderIndex': r.bidderIndex,
      'bid': r.bid,
      'trump': r.trump.name,
      'gameMode': r.gameMode,
      'tricksByPlayer': r.tricksByPlayer,
      'scoreDeltaByPlayer': r.scoreDeltaByPlayer,
      'cumulativeScores': r.cumulativeScores,
    };
  }

  static RoundResult? roundResultFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final roundNumber = json['roundNumber'] as int?;
    final bidderIndex = json['bidderIndex'] as int?;
    final bid = json['bid'] as int?;
    final trumpStr = json['trump'] as String?;
    final gameMode = json['gameMode'] as String? ?? 'single';
    final tricksRaw = json['tricksByPlayer'] as List<dynamic>?;
    final scoreDeltaRaw = json['scoreDeltaByPlayer'] as List<dynamic>?;
    final cumulativeRaw = json['cumulativeScores'] as List<dynamic>?;

    if (roundNumber == null ||
        bidderIndex == null ||
        bid == null ||
        trumpStr == null ||
        tricksRaw == null ||
        scoreDeltaRaw == null ||
        cumulativeRaw == null) {
      return null;
    }

    final trump = Suit.values.where((s) => s.name == trumpStr).firstOrNull;
    if (trump == null) return null;

    return RoundResult(
      roundNumber: roundNumber,
      bidderIndex: bidderIndex,
      bid: bid,
      trump: trump,
      gameMode: gameMode,
      tricksByPlayer: tricksRaw.map((e) => e as int).toList(),
      scoreDeltaByPlayer: scoreDeltaRaw.map((e) => e as int).toList(),
      cumulativeScores: cumulativeRaw.map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'savedAt': savedAt,
      'gameMode': gameMode.name,
      'currentPhase': currentPhase.name,
      'totalRounds': totalRounds,
      'currentRound': currentRound,
      'currentTurnIndex': currentTurnIndex,
      'biddingTurnIndex': biddingTurnIndex,
      'currentHighestBid': currentHighestBid,
      'highestBidderIndex': highestBidderIndex,
      'bidderIndex': bidderIndex,
      'passedPlayers': passedPlayers,
      'currentTrump': currentTrump.name,
      'tricksPlayed': tricksPlayed,
      'players': players.map(playerToJson).toList(),
      'tableCards': tableCards.map(cardToJson).toList(),
      'playedCardsByPlayer': playedCardsByPlayer.map((k, v) => MapEntry(k.toString(), cardToJson(v))),
      'playedHistory': playedHistory.map((r) => r.toJson()).toList(),
      'cumulativeScores': cumulativeScores,
      'roundScoresHistory': roundScoresHistory,
      'roundResults': roundResults.map(roundResultToJson).toList(),
      'roundScored': roundScored,
      'statusMessage': statusMessage,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SavedGameModel? fromJson(Map<String, dynamic> json) {
    final schemaVer = json['schemaVersion'] as int?;
    if (schemaVer != currentSchemaVersion) return null;

    final savedAt = json['savedAt'] as String?;
    final gameModeStr = json['gameMode'] as String?;
    final currentPhaseStr = json['currentPhase'] as String?;
    final totalRounds = json['totalRounds'] as int?;
    final currentRound = json['currentRound'] as int?;
    final currentTurnIndex = json['currentTurnIndex'] as int?;
    final biddingTurnIndex = json['biddingTurnIndex'] as int?;
    final currentHighestBid = json['currentHighestBid'] as int?;
    final highestBidderIndex = json['highestBidderIndex'] as int?;
    final bidderIndex = json['bidderIndex'] as int?;
    final passedPlayersRaw = json['passedPlayers'] as List<dynamic>?;
    final currentTrumpStr = json['currentTrump'] as String?;
    final tricksPlayed = json['tricksPlayed'] as int?;
    final playersRaw = json['players'] as List<dynamic>?;
    final tableCardsRaw = json['tableCards'] as List<dynamic>?;
    final playedCardsRaw = json['playedCardsByPlayer'] as Map<String, dynamic>?;
    final cumulativeRaw = json['cumulativeScores'] as List<dynamic>?;
    final historyRaw = json['roundScoresHistory'] as List<dynamic>?;
    final roundResultsRaw = json['roundResults'] as List<dynamic>?;
    final roundScored = json['roundScored'] as bool? ?? false;
    final statusMessage = json['statusMessage'] as String? ?? '';

    if (savedAt == null ||
        gameModeStr == null ||
        currentPhaseStr == null ||
        totalRounds == null ||
        currentRound == null ||
        currentTurnIndex == null ||
        biddingTurnIndex == null ||
        currentHighestBid == null ||
        bidderIndex == null ||
        passedPlayersRaw == null ||
        currentTrumpStr == null ||
        tricksPlayed == null ||
        playersRaw == null ||
        tableCardsRaw == null ||
        playedCardsRaw == null ||
        cumulativeRaw == null ||
        historyRaw == null ||
        roundResultsRaw == null) {
      return null;
    }

    final gameMode = BatakGameMode.values.where((m) => m.name == gameModeStr).firstOrNull;
    final currentPhase = GamePhase.values.where((p) => p.name == currentPhaseStr).firstOrNull;
    final currentTrump = Suit.values.where((s) => s.name == currentTrumpStr).firstOrNull;

    if (gameMode == null || currentPhase == null || currentTrump == null) return null;

    final players = <Player>[];
    for (final pItem in playersRaw) {
      if (pItem is Map<String, dynamic>) {
        final p = playerFromJson(pItem);
        if (p == null) return null;
        players.add(p);
      } else {
        return null;
      }
    }

    final tableCards = <PlayingCard>[];
    for (final cItem in tableCardsRaw) {
      if (cItem is Map<String, dynamic>) {
        final c = cardFromJson(cItem);
        if (c == null) return null;
        tableCards.add(c);
      } else {
        return null;
      }
    }

    final playedCardsByPlayer = <int, PlayingCard>{};
    for (final entry in playedCardsRaw.entries) {
      final pIndex = int.tryParse(entry.key);
      if (pIndex == null) return null;
      if (entry.value is Map<String, dynamic>) {
        final c = cardFromJson(entry.value as Map<String, dynamic>);
        if (c == null) return null;
        playedCardsByPlayer[pIndex] = c;
      } else {
        return null;
      }
    }

    final roundResults = <RoundResult>[];
    for (final rItem in roundResultsRaw) {
      if (rItem is Map<String, dynamic>) {
        final r = roundResultFromJson(rItem);
        if (r == null) return null;
        roundResults.add(r);
      } else {
        return null;
      }
    }

    final roundScoresHistory = <List<int>>[];
    for (final hItem in historyRaw) {
      if (hItem is List<dynamic>) {
        roundScoresHistory.add(hItem.map((e) => e as int).toList());
      } else {
        return null;
      }
    }

    // V2-007B: Parse playedHistory (backward-compatible: missing => empty list)
    final playedHistoryRaw = json['playedHistory'] as List<dynamic>?;
    final playedHistory = <PlayedCardRecord>[];
    if (playedHistoryRaw != null) {
      for (final phItem in playedHistoryRaw) {
        if (phItem is Map<String, dynamic>) {
          final rec = PlayedCardRecord.fromJson(phItem);
          if (rec != null) playedHistory.add(rec);
        }
      }
    }

    return SavedGameModel(
      schemaVersion: schemaVer ?? currentSchemaVersion,
      savedAt: savedAt,
      gameMode: gameMode,
      currentPhase: currentPhase,
      totalRounds: totalRounds,
      currentRound: currentRound,
      currentTurnIndex: currentTurnIndex,
      biddingTurnIndex: biddingTurnIndex,
      currentHighestBid: currentHighestBid,
      highestBidderIndex: highestBidderIndex,
      bidderIndex: bidderIndex,
      passedPlayers: passedPlayersRaw.map((e) => e as int).toList(),
      currentTrump: currentTrump,
      tricksPlayed: tricksPlayed,
      players: players,
      tableCards: tableCards,
      playedCardsByPlayer: playedCardsByPlayer,
      playedHistory: playedHistory,
      cumulativeScores: cumulativeRaw.map((e) => e as int).toList(),
      roundScoresHistory: roundScoresHistory,
      roundResults: roundResults,
      roundScored: roundScored,
      statusMessage: statusMessage,
    );
  }

  static SavedGameModel? fromJsonString(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // KART VE DURUM BÜTÜNLÜĞÜ DOĞRULAMASI (STEP 5 & 14)
  // ============================================================

  /// Kaydın geçerliliğini ve kart korunumu ilkelerini doğrular.
  /// Boş liste dönerse kayıt geçerlidir, dolu liste hata detaylarını içerir.
  List<String> validateIntegrity() {
    final errors = <String>[];

    if (schemaVersion != currentSchemaVersion) {
      errors.add("Desteklenmeyen şema versiyonu: $schemaVersion");
    }

    if (players.length != 4) {
      errors.add("Oyuncu sayısı 4 olmalı, var olan: ${players.length}");
    }

    if (cumulativeScores.length != 4) {
      errors.add("Kümülatif puanlar 4 elemanlı olmalı");
    }

    if (currentTurnIndex < 0 || currentTurnIndex > 3) {
      errors.add("Geçersiz sıra indeksi: $currentTurnIndex");
    }

    if (biddingTurnIndex < 0 || biddingTurnIndex > 3) {
      errors.add("Geçersiz ihale sırası: $biddingTurnIndex");
    }

    if (tableCards.length > 4) {
      errors.add("Masada 4'ten fazla kart olamaz: ${tableCards.length}");
    }

    if (tricksPlayed < 0 || tricksPlayed > 13) {
      errors.add("Geçersiz oynanan el sayısı: $tricksPlayed");
    }

    if (currentRound < 1 || currentRound > totalRounds) {
      errors.add("Geçersiz tur: $currentRound / $totalRounds");
    }

    // Kart tekilliği kontrolü (Duplicate card validation)
    final seenCards = <String>{};
    for (int pIdx = 0; pIdx < players.length; pIdx++) {
      final hand = players[pIdx].hand;
      if (hand.length > 13) {
        errors.add("Oyuncu $pIdx elinde 13'ten fazla kart var: ${hand.length}");
      }
      for (final card in hand) {
        final key = card.toString();
        if (seenCards.contains(key)) {
          errors.add("Mükerrer kart tespit edildi: $key (Oyuncu $pIdx)");
        }
        seenCards.add(key);
      }
    }

    for (final card in tableCards) {
      final key = card.toString();
      if (seenCards.contains(key)) {
        errors.add("Masada mükerrer/eldeki kart tespit edildi: $key");
      }
      seenCards.add(key);
    }

    // Masadaki kart sayısı ile playedCardsByPlayer boyutu eşleşmeli
    if (playedCardsByPlayer.length != tableCards.length) {
      errors.add("Masadaki kart sayısı (${tableCards.length}) ile oyuncu kart haritası (${playedCardsByPlayer.length}) uyuşmuyor");
    }

    return errors;
  }
}
