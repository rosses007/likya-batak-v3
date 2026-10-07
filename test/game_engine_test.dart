import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/models/player_model.dart';
import 'package:batak_app/engine/game_engine.dart';

void main() {
  group('GameEngine - Pure Legal Moves & Rule Enforcement', () {
    const trump = Suit.spades;

    final cardClubs10 = PlayingCard(suit: Suit.clubs, rank: Rank.ten);
    final cardClubsAce = PlayingCard(suit: Suit.clubs, rank: Rank.ace);
    final cardHearts7 = PlayingCard(suit: Suit.hearts, rank: Rank.seven);
    final cardHeartsKing = PlayingCard(suit: Suit.hearts, rank: Rank.king);
    final cardSpades3 = PlayingCard(suit: Suit.spades, rank: Rank.three);
    final cardSpadesJack = PlayingCard(suit: Suit.spades, rank: Rank.jack);
    final cardSpadesAce = PlayingCard(suit: Suit.spades, rank: Rank.ace);
    final cardDiamonds5 = PlayingCard(suit: Suit.diamonds, rank: Rank.five);

    test('Table empty (lead card): any card in hand is valid', () {
      final hand = [cardClubs10, cardHearts7, cardSpades3];
      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: [],
        trumpSuit: trump,
      );

      expect(validMoves.length, 3);
      expect(validMoves, containsAll(hand));
    });

    test('Follow suit: player has led suit -> MUST follow led suit only', () {
      final hand = [cardClubs10, cardClubsAce, cardHearts7, cardSpades3];
      final table = [PlayingCard(suit: Suit.clubs, rank: Rank.eight)];

      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: trump,
      );

      expect(validMoves.length, 2);
      expect(validMoves, containsAll([cardClubs10, cardClubsAce]));
      expect(validMoves.contains(cardHearts7), isFalse);
      expect(validMoves.contains(cardSpades3), isFalse);

      final player = Player(id: '1', name: 'Test', hand: List.of(hand));
      expect(
        GameEngine.isValidPlay(
          cardToPlay: cardClubsAce,
          player: player,
          tableCards: table,
          trumpSuit: trump,
        ),
        isTrue,
      );
      expect(
        GameEngine.isValidPlay(
          cardToPlay: cardSpades3,
          player: player,
          tableCards: table,
          trumpSuit: trump,
        ),
        isFalse,
      );
    });

    test('Follow suit on trump: led suit is trump -> must follow and overtrump if possible', () {
      // Table has Spades 8
      final table = [PlayingCard(suit: Suit.spades, rank: Rank.eight)];
      // Hand has Spades 3 (lower) and Spades Jack (higher)
      final hand = [cardSpades3, cardSpadesJack, cardHeartsKing];

      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: trump,
      );

      // Must overtrump with Spades Jack
      expect(validMoves.length, 1);
      expect(validMoves.first, equals(cardSpadesJack));
    });

    test('Follow suit on trump: cannot overtrump -> any trump in hand allowed', () {
      // Table has Spades Ace
      final table = [cardSpadesAce];
      // Hand only has Spades 3 and Spades Jack (both lower than Ace)
      final hand = [cardSpades3, cardSpadesJack, cardHeartsKing];

      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: trump,
      );

      expect(validMoves.length, 2);
      expect(validMoves, containsAll([cardSpades3, cardSpadesJack]));
      expect(validMoves.contains(cardHeartsKing), isFalse);
    });

    test('Trump play (çakma): player lacks led suit but has trump -> MUST play trump', () {
      // Led suit is Clubs
      final table = [PlayingCard(suit: Suit.clubs, rank: Rank.nine)];
      // Player has NO Clubs, but has Spades and Hearts
      final hand = [cardHearts7, cardHeartsKing, cardSpades3, cardSpadesJack];

      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: trump,
      );

      // Must play trump
      expect(validMoves.length, 2);
      expect(validMoves, containsAll([cardSpades3, cardSpadesJack]));
      expect(validMoves.contains(cardHearts7), isFalse);
    });

    test('Overtrumping: player lacks led suit, table already has trump -> must overtrump if able', () {
      // Led suit is Clubs, but a previous player already trumped with Spades 8
      final table = [
        PlayingCard(suit: Suit.clubs, rank: Rank.nine),
        PlayingCard(suit: Suit.spades, rank: Rank.eight),
      ];
      // Player has Spades 3 and Spades Jack
      final hand = [cardHeartsKing, cardSpades3, cardSpadesJack];

      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: trump,
      );

      // Only Spades Jack can overtrump Spades 8
      expect(validMoves.length, 1);
      expect(validMoves.first, equals(cardSpadesJack));
    });

    test('Discard (çöp): player lacks both led suit and trump -> any card allowed', () {
      final table = [PlayingCard(suit: Suit.clubs, rank: Rank.nine)];
      // Hand has only Hearts and Diamonds
      final hand = [cardHearts7, cardHeartsKing, cardDiamonds5];

      final validMoves = GameEngine.getValidMoves(
        hand: hand,
        tableCards: table,
        trumpSuit: trump,
      );

      expect(validMoves.length, 3);
      expect(validMoves, containsAll(hand));
    });
  });

  group('GameEngine - Trick Winner Determination', () {
    const trump = Suit.spades;

    test('Lead suit winner: no trumps played, highest card of lead suit wins', () {
      final table = [
        PlayingCard(suit: Suit.hearts, rank: Rank.nine),  // lead
        PlayingCard(suit: Suit.hearts, rank: Rank.jack),
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),   // winner
        PlayingCard(suit: Suit.hearts, rank: Rank.king),
      ];

      expect(GameEngine.determineWinnerIndex(table, trump), 2);
      expect(
        GameEngine.determineTrickWinnerPlayerIndex(
          tableCards: table,
          trumpSuit: trump,
          leadPlayerIndex: 1,
        ),
        3, // (1 + 2) % 4 = 3
      );
    });

    test('Trump beats lead suit: even a low trump beats lead suit Ace', () {
      final table = [
        PlayingCard(suit: Suit.diamonds, rank: Rank.ace), // lead Ace
        PlayingCard(suit: Suit.diamonds, rank: Rank.king),
        PlayingCard(suit: Suit.spades, rank: Rank.two),   // trump (winner)
        PlayingCard(suit: Suit.diamonds, rank: Rank.three),
      ];

      expect(GameEngine.determineWinnerIndex(table, trump), 2);
      expect(
        GameEngine.determineTrickWinnerPlayerIndex(
          tableCards: table,
          trumpSuit: trump,
          leadPlayerIndex: 0,
        ),
        2,
      );
    });

    test('Higher trump beats lower trump', () {
      final table = [
        PlayingCard(suit: Suit.clubs, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.five),  // first trump
        PlayingCard(suit: Suit.spades, rank: Rank.jack),  // higher trump (winner)
        PlayingCard(suit: Suit.spades, rank: Rank.six),
      ];

      expect(GameEngine.determineWinnerIndex(table, trump), 2);
    });

    test('Off-suit non-trump cannot win even with Ace', () {
      final table = [
        PlayingCard(suit: Suit.clubs, rank: Rank.seven), // lead
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),  // discarded Ace (off-suit)
        PlayingCard(suit: Suit.clubs, rank: Rank.eight), // higher led suit (winner)
        PlayingCard(suit: Suit.diamonds, rank: Rank.ace),// discarded Ace
      ];

      expect(GameEngine.determineWinnerIndex(table, trump), 2);
    });
  });

  group('GameEngine - Scoring', () {
    test('Bidder makes bid with overtricks', () {
      final player = Player(
        id: '1',
        name: 'Bidder',
        hand: [],
        bid: 5,
        tricksWon: 7,
      );
      // 5 * 10 + (7 - 5) = 52
      expect(GameEngine.calculateScore(player, true), 52);
    });

    test('Bidder makes exact bid', () {
      final player = Player(
        id: '1',
        name: 'Bidder',
        hand: [],
        bid: 5,
        tricksWon: 5,
      );
      // 5 * 10 = 50
      expect(GameEngine.calculateScore(player, true), 50);
    });

    test('Bidder goes down (batar)', () {
      final player = Player(
        id: '1',
        name: 'Bidder',
        hand: [],
        bid: 6,
        tricksWon: 5,
      );
      // -6 * 10 = -60
      expect(GameEngine.calculateScore(player, true), -60);
    });

    test('Non-bidder scores tricks directly', () {
      final player = Player(
        id: '2',
        name: 'Defender',
        hand: [],
        bid: 0,
        tricksWon: 4,
      );
      expect(GameEngine.calculateScore(player, false), 4);
    });
  });

  group('GameEngine - validatePlay Structured Guard', () {
    const trump = Suit.spades;
    final cardA = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
    final cardB = PlayingCard(suit: Suit.hearts, rank: Rank.ten);
    final cardC = PlayingCard(suit: Suit.spades, rank: Rank.king);

    test('Rejects if not playing phase', () {
      final player = Player(id: '1', name: 'P1', hand: [cardA]);
      final res = GameEngine.validatePlay(
        cardToPlay: cardA,
        player: player,
        tableCards: [],
        trumpSuit: trump,
        isCurrentTurn: true,
        isPlayingPhase: false,
      );
      expect(res.success, isFalse);
      expect(res.message, contains("aşamasında değil"));
    });

    test('Rejects if not player turn', () {
      final player = Player(id: '1', name: 'P1', hand: [cardA]);
      final res = GameEngine.validatePlay(
        cardToPlay: cardA,
        player: player,
        tableCards: [],
        trumpSuit: trump,
        isCurrentTurn: false,
        isPlayingPhase: true,
      );
      expect(res.success, isFalse);
      expect(res.message, contains("Sıra bu oyuncuda değil"));
    });

    test('Rejects if player does not own card', () {
      final player = Player(id: '1', name: 'P1', hand: [cardA]);
      final res = GameEngine.validatePlay(
        cardToPlay: cardB, // not in hand
        player: player,
        tableCards: [],
        trumpSuit: trump,
        isCurrentTurn: true,
        isPlayingPhase: true,
      );
      expect(res.success, isFalse);
      expect(res.message, contains("elinde bulunmuyor"));
    });

    test('Rejects if card is already on the table', () {
      final player = Player(id: '1', name: 'P1', hand: [cardA]);
      final res = GameEngine.validatePlay(
        cardToPlay: cardA,
        player: player,
        tableCards: [cardA], // already on table
        trumpSuit: trump,
        isCurrentTurn: true,
        isPlayingPhase: true,
      );
      expect(res.success, isFalse);
      expect(res.message, contains("zaten masaya atılmış"));
    });

    test('Rejects illegal rule play (fails to follow suit)', () {
      final player = Player(id: '1', name: 'P1', hand: [cardA, cardC]);
      final res = GameEngine.validatePlay(
        cardToPlay: cardC, // Spades
        player: player,
        tableCards: [cardB], // Hearts led -> player has cardA Hearts
        trumpSuit: trump,
        isCurrentTurn: true,
        isPlayingPhase: true,
      );
      expect(res.success, isFalse);
      expect(res.message, contains("Kurallara aykırı"));
    });

    test('Accepts perfectly legal play', () {
      final player = Player(id: '1', name: 'P1', hand: [cardA, cardC]);
      final res = GameEngine.validatePlay(
        cardToPlay: cardA,
        player: player,
        tableCards: [cardB],
        trumpSuit: trump,
        isCurrentTurn: true,
        isPlayingPhase: true,
      );
      expect(res.success, isTrue);
    });
  });
}
