import 'card_model.dart';
import 'played_card_record.dart';
import '../engine/team_engine.dart'; // For TeamId if needed

/// BotMemory stores only public information about the game.
/// It never contains hidden opponent hands or future deck order.
class BotMemory {
  // Played cards set for quick duplicate detection.
  final Set<PlayingCard> _playedCards = {};

  // Mapping of player index to void suits (suits they could not follow).
  final Map<int, Set<Suit>> voidSuitsByPlayer = {};

  // Count of played cards per suit, used for trump counting.
  final Map<Suit, int> _playedCountBySuit = {
    Suit.spades: 0,
    Suit.hearts: 0,
    Suit.diamonds: 0,
    Suit.clubs: 0,
  };

  // Trick wins per player.
  final Map<int, int> tricksWonByPlayer = {};

  // Current trump suit, may be null until determined.
  Suit? trump;

  // Number of tricks that have been played in the current round.
  int tricksPlayed = 0;

  // Number of trump cards that have been played.
  int _trumpPlayedCount = 0;

  int get trumpPlayedCount => _trumpPlayedCount;
  int get remainingTrumpCount => (13 - _trumpPlayedCount).clamp(0, 13);

  // Set of resolved trick numbers to prevent double-counting.
  final Set<int> _resolvedTricks = {};

  // Public bidding state (optional, may be null if bidding not yet finished).
  int? bidderIndex; // player index that placed the final winning bid
  int? winningBid;
  TeamId? biddingTeam;

  /// Reset memory for a fresh round. Optional trump can be supplied when known.
  void resetForNewRound({required Suit? trump}) {
    _playedCards.clear();
    voidSuitsByPlayer.clear();
    _playedCountBySuit.updateAll((key, value) => 0);
    tricksWonByPlayer.clear();
    _resolvedTricks.clear();
    tricksPlayed = 0;
    _trumpPlayedCount = 0;
    this.trump = trump;
    bidderIndex = null;
    winningBid = null;
    biddingTeam = null;
  }

  /// Record a publicly played card.
  ///
  /// * [playerIndex] – index of the player who played the card.
  /// * [card] – the card that was played.
  /// * [leadSuit] – suit of the first card of the trick (null if this is the first card of the trick).
  /// * [trickNumber] – 0‑based number of the trick within the round.
  ///
  /// Duplicate plays are ignored.
  void recordPlay({
    required int playerIndex,
    required PlayingCard card,
    required Suit? leadSuit,
    required int trickNumber,
  }) {
    // Avoid duplicate entries.
    if (_playedCards.contains(card)) return;
    _playedCards.add(card);
    _playedCountBySuit.update(card.suit, (v) => v + 1);
    if (card.suit == trump) _trumpPlayedCount++;
    // Void‑suit inference: if player could have followed leadSuit but didn't, they are void in that suit.
    if (leadSuit != null && card.suit != leadSuit) {
      // Record that the player is void in the lead suit.
      voidSuitsByPlayer.putIfAbsent(playerIndex, () => <Suit>{}).add(leadSuit);
    }
  }

  /// Record the winner of a trick. Duplicate callbacks for the same trick are ignored.
  void recordTrickWinner(int winnerIndex, {int? trickNumber}) {
    final effectiveTrick = trickNumber ?? _resolvedTricks.length;
    if (_resolvedTricks.contains(effectiveTrick)) return;
    _resolvedTricks.add(effectiveTrick);
    tricksWonByPlayer.update(winnerIndex, (v) => v + 1, ifAbsent: () => 1);
    tricksPlayed = _resolvedTricks.length;
  }

  /// Store public bidding information after bidding ends.
  void setPublicBidState({
    required int? bidderIndex,
    required int? winningBid,
    required TeamId? biddingTeam,
    Suit? trump,
  }) {
    this.bidderIndex = bidderIndex;
    this.winningBid = winningBid;
    this.biddingTeam = biddingTeam;
    if (trump != null) {
      this.trump = trump;
    }
  }

  /// Reconstruct memory from a saved history of public plays.
  /// This is used when loading a saved game.
  void reconstructFromHistory(
    List<PlayedCardRecord> history, {
    required Suit? trump,
    int? bidderIdx,
    int? winBid,
    TeamId? bidTeam,
    Map<int, int>? tricksWon,
  }) {
    resetForNewRound(trump: trump);
    // Build map of trickNumber -> first card for lead suit inference.
    final Map<int, PlayedCardRecord> firstInTrick = {};
    for (final rec in history) {
      firstInTrick.putIfAbsent(rec.trickNumber, () => rec);
    }
    // Second pass to record plays with proper leadSuit.
    for (final rec in history) {
      final firstCard = firstInTrick[rec.trickNumber]?.card;
      final lead = (firstCard != null && rec.card != firstCard)
          ? firstCard.suit
          : null;
      recordPlay(
        playerIndex: rec.playerIndex,
        card: rec.card,
        leadSuit: lead,
        trickNumber: rec.trickNumber,
      );
    }

    // Reconstruct trick counts from completed tricks
    final Map<int, int> cardsPerTrick = {};
    for (final rec in history) {
      cardsPerTrick.update(rec.trickNumber, (v) => v + 1, ifAbsent: () => 1);
    }
    for (final entry in cardsPerTrick.entries) {
      if (entry.value == 4) {
        _resolvedTricks.add(entry.key);
      }
    }
    tricksPlayed = _resolvedTricks.length;

    if (tricksWon != null) {
      tricksWonByPlayer.addAll(tricksWon);
    }

    // Set bidding state if supplied.
    setPublicBidState(
      bidderIndex: bidderIdx,
      winningBid: winBid,
      biddingTeam: bidTeam,
      trump: trump,
    );
  }

  // Expose some read‑only views for AIEngine or tests.
  Set<PlayingCard> get playedCards => Set.unmodifiable(_playedCards);
  bool hasCardBeenPlayed(PlayingCard card) => _playedCards.contains(card);
  int playedCountForSuit(Suit suit) => _playedCountBySuit[suit] ?? 0;
  Set<Suit> voidSuitsForPlayer(int playerIdx) =>
      voidSuitsByPlayer[playerIdx] ?? const {};
}
