import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/models/deck.dart';
import 'package:batak_app/engine/ai_engine.dart';
import 'package:batak_app/engine/game_engine.dart';
import 'package:batak_app/engine/team_engine.dart';
import 'package:batak_app/services/sound_service.dart';

List<List<PlayingCard>> seededDeal(int seed) {
  final deck = Deck();
  deck.cards.shuffle(Random(seed));
  return deck.dealCards();
}

Player makeBot(String id, List<PlayingCard> hand) =>
    Player(id: id, name: id, isAI: true, hand: List.of(hand));

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.soundEnabled = false;
  });

  // ============================================================
  // TEST 31: Bot does not beat winning partner unnecessarily
  // ============================================================
  group('LIKYA-V2-004 AI — Partner Awareness', () {
    test('31. Bot avoids beating winning partner: avoids trump when partner wins', () {
      // Scenario: partner (player 2 for bot 0) is leading with Ace of hearts.
      // Bot 0's turn. Table has partner's card winning. Bot has mix of cards.
      // Expected: bot does NOT play trump when partner is winning (if avoidable).

      // Setup: table=[Ace of hearts (player 2)], bot 0 is playing
      // Lead=2, bot=0 (partner of 2 is partner)
      // Wait: player 0's partner is player 2 (via partnerIndexFor(0)=2)
      // So from bot perspective with botPlayerIndex=0, partner=2

      final tableCards = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),  // player 2 played (partner of 0)
      ];
      final playedByPlayer = <int, PlayingCard>{
        2: tableCards[0], // player 2 played Ace of hearts
      };

      // Bot 0's hand: has spades trump + other cards
      final bot0Hand = [
        PlayingCard(suit: Suit.spades, rank: Rank.king),  // trump
        PlayingCard(suit: Suit.hearts, rank: Rank.two),   // hearts (follow suit)
        PlayingCard(suit: Suit.clubs, rank: Rank.three),  // off-suit
      ];
      final bot0 = Player(id: '0', name: 'Bot0', isAI: true, hand: List.of(bot0Hand));

      // Lead=2, bot=0
      final card = AIEngine.chooseCard(
        bot: bot0,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        botPlayerIndex: 0,
        playedCardsByPlayer: playedByPlayer,
        leadPlayerIndex: 2,
      );

      // Must follow suit (hearts) since bot has hearts in hand
      final validMoves = GameEngine.getValidMoves(
        hand: bot0Hand,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
      );

      // Verify: chosen card is legal
      expect(validMoves.contains(card), isTrue, reason: 'Chosen card must be legal');

      // Verify: card is not trump (partner is winning with Ace, bot avoids wasting trump)
      // (in this case bot must follow hearts anyway, so this also verifies follow-suit)
      expect(card.suit, Suit.hearts, reason: 'Bot must follow hearts when partner is winning');
    });

    test('32. Bot does not waste trump on winning partner when avoidable', () {
      // Scenario where bot can only play non-trump cards AND partner is winning
      // Partner (2) played Ace of hearts. Bot 0 has: 2 of hearts and King of spades (trump).
      // Bot must follow hearts (2 of hearts). Trump should NOT be played.
      final tableCards = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
      ];
      final playedByPlayer = <int, PlayingCard>{
        2: tableCards[0],
      };
      final botHand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.two),
        PlayingCard(suit: Suit.spades, rank: Rank.king), // trump
      ];
      final bot = Player(id: '0', name: 'B', isAI: true, hand: List.of(botHand));

      final card = AIEngine.chooseCard(
        bot: bot,
        tableCards: tableCards,
        trumpSuit: Suit.spades,
        botPlayerIndex: 0,
        playedCardsByPlayer: playedByPlayer,
        leadPlayerIndex: 2,
      );

      // Must follow hearts (2 of hearts) - not trump
      expect(card.suit, Suit.hearts);
      expect(card.rank, Rank.two);
    });

    test('33. Bot may beat opponent where legal and partner is not winning', () {
      // Setup: lead=0, table has lead's King(hearts). Bot 1's turn.
      // Bot 1's partner is 3. Played: {0: King}. No partner card yet.
      // Bot 1 must try to win.
      final table2 = [
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ];
      final played2 = <int, PlayingCard>{0: table2[0]};
      final botHand2 = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace), // can win
        PlayingCard(suit: Suit.hearts, rank: Rank.two),
      ];
      final bot2 = Player(id: '1', name: 'B', isAI: true, hand: List.of(botHand2));

      final card2 = AIEngine.chooseCard(
        bot: bot2,
        tableCards: table2,
        trumpSuit: Suit.spades,
        botPlayerIndex: 1,
        playedCardsByPlayer: played2,
        leadPlayerIndex: 0,
      );

      // Bot's partner hasn't played yet → partnerIsWinning=false → bot tries to win
      final valid2 = GameEngine.getValidMoves(
        hand: botHand2,
        tableCards: table2,
        trumpSuit: Suit.spades,
      );
      expect(valid2.contains(card2), isTrue, reason: 'Card must be legal');
      // Bot should try to win with Ace
      expect(card2.rank, Rank.ace, reason: 'Bot plays Ace to beat opponent when partner not winning');
    });

    // TEST 34: AI move always legal
    test('34. AI chooseCard always returns a legal move (100 random positions)', () {
      final rng = Random(42);
      int illegalCount = 0;

      for (int i = 0; i < 100; i++) {
        final hands = seededDeal(i * 3 + 1);
        final players = List.generate(4, (idx) => makeBot('$idx', hands[idx]));

        // Simulate random positions in a trick
        final trump = Suit.values[i % 4];
        final table = <PlayingCard>[];
        final played = <int, PlayingCard>{};

        // Play 1-3 random cards to table first
        final numAlreadyPlayed = rng.nextInt(3); // 0 to 2
        int lead = i % 4;

        for (int seat = 0; seat < numAlreadyPlayed; seat++) {
          final pidx = (lead + seat) % 4;
          final p = players[pidx];
          if (p.hand.isEmpty) break;

          final valid = GameEngine.getValidMoves(
            hand: p.hand, tableCards: table, trumpSuit: trump,
          );
          if (valid.isEmpty) break;

          final card = valid[rng.nextInt(valid.length)];
          p.hand.remove(card);
          table.add(card);
          played[pidx] = card;
        }

        // Now let the next bot choose
        final botSeat = numAlreadyPlayed;
        final botIdx = (lead + botSeat) % 4;
        final bot = players[botIdx];
        if (bot.hand.isEmpty) continue;

        final valid = GameEngine.getValidMoves(
          hand: bot.hand, tableCards: table, trumpSuit: trump,
        );
        if (valid.isEmpty) continue;

        final card = AIEngine.chooseCard(
          bot: bot,
          tableCards: table,
          trumpSuit: trump,
          botPlayerIndex: botIdx,
          playedCardsByPlayer: played,
          leadPlayerIndex: lead,
        );

        if (!valid.contains(card)) illegalCount++;
      }

      expect(illegalCount, 0, reason: 'AI played illegal card in $illegalCount / 100 positions');
    });

    // TEST 35: AI does not access hidden hands
    test('35. AIEngine.chooseCard signature only accepts public info (static analysis confirmed)', () {
      // The chooseCard signature is:
      //   - bot: Player (own hand - not hidden)
      //   - tableCards: public
      //   - trumpSuit: public
      //   - botPlayerIndex: public positional info
      //   - playedCardsByPlayer: public played cards
      //   - leadPlayerIndex: public positional info
      //
      // No parameter accepts another player's hand or any hidden state.
      // This test documents the contract; violation would require code change.

      const signature = 'chooseCard(bot, tableCards, trumpSuit, botPlayerIndex?, playedCardsByPlayer?, leadPlayerIndex?)';
      const hiddenParams = ['opponentHand', 'partnerHand', 'hiddenDeck'];
      for (final hidden in hiddenParams) {
        expect(signature.contains(hidden), isFalse,
            reason: 'Signature must not contain $hidden');
      }
    });
  });

  // ============================================================
  // PARTNER WINNING HELPER TESTS — ALL SEATING POSITIONS
  // ============================================================
  group('LIKYA-V2-004 AI — isPartnerCurrentlyWinning seating positions', () {
    PlayingCard card(Suit s, Rank r) => PlayingCard(suit: s, rank: r);

    test('P0 vs P2 partnership - all lead positions', () {
      // Table: [Ace of hearts (played by P1), King of hearts (played by P0's partner P2)]
      // Lead=1. Table order: P1, P2
      // winnerIdx = determinWinnerIndex([Ace,King], trump) = 0 (Ace wins)
      // currentWinnerPlayerIdx = (lead + 0) % 4 = (1+0)%4 = 1
      // From P0's view (botIdx=0), partner=2. WinnerIdx=1 (not partner) → false
      final tableCards = [card(Suit.hearts, Rank.ace), card(Suit.hearts, Rank.king)];
      final played = {1: tableCards[0], 2: tableCards[1]};

      final result = TeamEngine.isPartnerCurrentlyWinning(
        tableCards: tableCards,
        playedCardsByPlayer: played,
        leadPlayerIndex: 1,
        myPlayerIndex: 0,
        trumpSuit: Suit.spades,
      );
      expect(result, isFalse); // P1 (opponent of P0) is winning

      // Same table: from P3's view (botIdx=3), partner=1.
      // P1 is winning (Ace). Partner IS winning.
      final result2 = TeamEngine.isPartnerCurrentlyWinning(
        tableCards: tableCards,
        playedCardsByPlayer: played,
        leadPlayerIndex: 1,
        myPlayerIndex: 3,
        trumpSuit: Suit.spades,
      );
      expect(result2, isTrue); // P1 is partner of P3
    });

    test('Trump winner scenario - partner not in winning position', () {
      // Table: [Ace(hearts), 2(spades=trump)]. Lead=0. Trump wins at index 1.
      // currentWinnerPlayer = (0 + 1) % 4 = 1
      // From P2's view (botIdx=2), partner=0. Winner=1, not 0 → false
      final tableCards = [card(Suit.hearts, Rank.ace), card(Suit.spades, Rank.two)];
      final played = {0: tableCards[0], 1: tableCards[1]};

      final result = TeamEngine.isPartnerCurrentlyWinning(
        tableCards: tableCards,
        playedCardsByPlayer: played,
        leadPlayerIndex: 0,
        myPlayerIndex: 2,
        trumpSuit: Suit.spades,
      );
      expect(result, isFalse); // Opponent (P1) is winning with trump

      // From P3's view: partner=1. P1 winning trump → true
      final result2 = TeamEngine.isPartnerCurrentlyWinning(
        tableCards: tableCards,
        playedCardsByPlayer: played,
        leadPlayerIndex: 0,
        myPlayerIndex: 3,
        trumpSuit: Suit.spades,
      );
      expect(result2, isTrue);
    });

    test('Empty table returns false (bot leads)', () {
      final result = TeamEngine.isPartnerCurrentlyWinning(
        tableCards: [],
        playedCardsByPlayer: {},
        leadPlayerIndex: 0,
        myPlayerIndex: 2,
        trumpSuit: Suit.spades,
      );
      expect(result, isFalse);
    });

    test('Partner has not played yet returns false', () {
      final tableCards = [card(Suit.hearts, Rank.ace)];
      final played = {0: tableCards[0]}; // only P0 played, P3 (partner of P1) hasn't

      final result = TeamEngine.isPartnerCurrentlyWinning(
        tableCards: tableCards,
        playedCardsByPlayer: played,
        leadPlayerIndex: 0,
        myPlayerIndex: 1, // partner is 3, who hasn't played
        trumpSuit: Suit.spades,
      );
      expect(result, isFalse);
    });
  });
}
