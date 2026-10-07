# LIKYA-V2-007B: AI Memory Foundation (Public Information Only)

## 1. Overview
LIKYA-V2-007B introduces the authoritative public AI memory foundation for Likya Batak.
The memory system adheres strictly to the **Anti-Cheat Structural Guarantee**:
bot decision systems and memory representations are mathematically and architecturally restricted to **public information only**. Under no circumstances can bot memory store, inspect, or reconstruct hidden opponent hands, hidden partner hands, or future/undealt deck ordering.

---

## 2. Core Components

### 2.1 `PlayedCardRecord` (`lib/models/played_card_record.dart`)
An immutable record capturing a single publicly played card:
- `int playerIndex`: Seat index (0..3) of the player who played the card.
- `PlayingCard card`: The card played.
- `int trickNumber`: Trick sequence number (0..12).
- `int? sequenceIndex`: Optional play order sequence index.
- Serialization: `toJson()` / `fromJson()` using direct string enum conversions (`suit.name`, `rank.name`) without circular dependencies.

### 2.2 `BotMemory` (`lib/models/bot_memory.dart`)
Purely derived, public-information state memory:
- `Set<PlayingCard> playedCards`: Read-only view of publicly played cards.
- `Map<int, Set<Suit>> voidSuitsByPlayer`: Tracks inferred void suits per player.
- `Map<Suit, int> _playedCountBySuit`: Count of cards played per suit.
- `int _trumpPlayedCount` & `remainingTrumpCount`: Authoritative count of trumps played vs. remaining in play (13 - played).
- `Map<int, int> tricksWonByPlayer`: Public scoreboard count of tricks taken per player.
- `int tricksPlayed`: Total tricks completed in the active round.
- Public Bidding Metadata:
  - `int? bidderIndex`: Player index of the winning bidder.
  - `int? winningBid`: Final auction contract.
  - `TeamId? biddingTeam`: Bidding team for Eşli Batak (derived from bidder index).
  - `Suit? trump`: Active trump suit.

---

## 3. Public Information Definition & Anti-Cheat Guarantees

### What BotMemory STORES:
1. Cards played to the table in full public view.
2. Order and trick association of played cards.
3. Inferred void suits (players unable to follow lead suit).
4. Public scoreboard metrics: tricks won, current trick number, active round.
5. Public auction outcome: bidder index, winning bid value, bidding team.
6. Selected trump suit.

### What BotMemory NEVER Stores:
1. Opponent hand contents.
2. Partner hand contents.
3. Undealt deck cards or card distribution.
4. Probabilistic hidden hand guesses violating public bounds.

---

## 4. Void-Suit Inference Algorithm
- When a trick begins (first card led), `leadSuit` is `null`. No void inference is made.
- For all subsequent cards in that trick:
  - If a player legally plays a card whose suit differs from the `leadSuit`:
    `voidSuitsByPlayer[playerIndex].add(leadSuit)`
- When a player follows the lead suit, no void is inferred.
- The inference is strictly idempotent (`Set<Suit>`).

---

## 5. Trump Counting
- `trumpPlayedCount` increments whenever a publicly played card matches `trump`.
- `remainingTrumpCount` is dynamically evaluated as `(13 - trumpPlayedCount).clamp(0, 13)`.
- Reconstructed deterministically from public play history.

---

## 6. Duplicate Protection
- `recordPlay`: Checks `_playedCards.contains(card)` before modifying any state. Double-invocations are safely ignored.
- `recordTrickWinner`: Tracks `_resolvedTricks` set by trick number. Duplicate resolution callbacks for the same trick do not double-count tricks.

---

## 7. Round Lifecycle & Reset
- In `GameProvider._startRound()`:
  - `playedHistory.clear()`
  - `botMemory.resetForNewRound(trump: rules.isFixedTrump ? currentTrump : null)`
- Cleared once per fresh deal. Does not clear on widget rebuilds or settings changes.

---

## 8. Save & Resume Compatibility (Schema-v1)
- **Persisted State**: `playedHistory` is persisted in `SavedGameModel` as `List<PlayedCardRecord>`.
- **Derived State**: `BotMemory` itself is NOT serialized. It is deterministically reconstructed upon game load via `botMemory.reconstructFromHistory(...)`.
- **Backward Compatibility**: Schema-v1 saves lacking `playedHistory` load cleanly with an empty list (`[]`). `BotMemory` safely initializes without errors or data quarantine.

---

## 9. Current Status
- **AI Memory Foundation**: READY
- **Advanced Difficulty AI (Easy/Normal/Hard)**: NOT IMPLEMENTED (Scheduled for subsequent patches)
- **Hidden Hand Access**: NONE
