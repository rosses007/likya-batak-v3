import 'card_model.dart';

/// Immutable record of a publicly played card.
class PlayedCardRecord {
  final int playerIndex; // 0..3
  final PlayingCard card;
  final int trickNumber; // 0..12
  final int? sequenceIndex; // optional for future ordering

  const PlayedCardRecord({
    required this.playerIndex,
    required this.card,
    required this.trickNumber,
    this.sequenceIndex,
  })  : assert(playerIndex >= 0, 'playerIndex must be >= 0'),
        assert(trickNumber >= 0, 'trickNumber must be >= 0');

  /// JSON serialization using enum names directly.
  Map<String, dynamic> toJson() => {
        'playerIndex': playerIndex,
        'card': {'suit': card.suit.name, 'rank': card.rank.name},
        'trickNumber': trickNumber,
        if (sequenceIndex != null) 'sequenceIndex': sequenceIndex,
      };

  static PlayedCardRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final playerIdx = json['playerIndex'] as int?;
    final trickNum = json['trickNumber'] as int?;
    final cardJson = json['card'] as Map<String, dynamic>?;
    if (playerIdx == null || trickNum == null || cardJson == null) return null;

    final suitStr = cardJson['suit'] as String?;
    final rankStr = cardJson['rank'] as String?;
    if (suitStr == null || rankStr == null) return null;

    final suit = Suit.values.where((s) => s.name == suitStr).firstOrNull;
    final rank = Rank.values.where((r) => r.name == rankStr).firstOrNull;
    if (suit == null || rank == null) return null;

    final card = PlayingCard(suit: suit, rank: rank);
    final seq = json['sequenceIndex'] as int?;
    return PlayedCardRecord(
      playerIndex: playerIdx,
      card: card,
      trickNumber: trickNum,
      sequenceIndex: seq,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayedCardRecord &&
          playerIndex == other.playerIndex &&
          card == other.card &&
          trickNumber == other.trickNumber &&
          sequenceIndex == other.sequenceIndex;

  @override
  int get hashCode =>
      playerIndex.hashCode ^
      card.hashCode ^
      trickNumber.hashCode ^
      (sequenceIndex ?? 0).hashCode;
}
