import 'package:flutter_test/flutter_test.dart';
import 'package:batak_app/models/card_model.dart';
import 'package:batak_app/providers/game_provider.dart';
import 'package:batak_app/services/sound_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SoundService.soundEnabled = false;
  });

  group('GameProvider - Authoritative State & Validation', () {
    test('Initial phase is bidding and cannot playCard during bidding', () async {
      final provider = GameProvider();
      expect(provider.currentPhase, GamePhase.bidding);

      final player0 = provider.players[0];
      final cardToPlay = player0.hand.first;

      // Snapshot state
      final handLengthBefore = player0.hand.length;
      final tableLengthBefore = provider.tableCards.length;
      final turnBefore = provider.currentTurnIndex;
      final phaseBefore = provider.currentPhase;

      // Attempt to play card during bidding
      final result = await provider.playCard(player0, cardToPlay);

      expect(result.success, isFalse);
      expect(result.message, contains("aşamasında değil"));

      // Assert state remains completely identical (zero mutation)
      expect(player0.hand.length, handLengthBefore);
      expect(player0.hand.contains(cardToPlay), isTrue);
      expect(provider.tableCards.length, tableLengthBefore);
      expect(provider.currentTurnIndex, turnBefore);
      expect(provider.currentPhase, phaseBefore);
    });

    test('Bidding validation: rejecting invalid bids without state mutation', () {
      final provider = GameProvider();
      expect(provider.currentPhase, GamePhase.bidding);

      // Force human turn for testing bidding rules
      provider.biddingTurnIndex = 0;
      final initialHighestBid = provider.currentHighestBid;

      // 1. Bid equal to or lower than current highest bid
      final resLow = provider.userPlaceBid(initialHighestBid);
      expect(resLow.success, isFalse);
      expect(provider.currentHighestBid, initialHighestBid);
      expect(provider.highestBidderIndex, isNull);

      // 2. Bid > 13
      final resExcess = provider.userPlaceBid(14);
      expect(resExcess.success, isFalse);
      expect(provider.currentHighestBid, initialHighestBid);

      // 3. Valid bid
      final resValid = provider.userPlaceBid(initialHighestBid + 1);
      expect(resValid.success, isTrue);
      expect(provider.currentHighestBid, initialHighestBid + 1);
      expect(provider.highestBidderIndex, 0);
    });

    test('Trump selection validation: cannot select trump outside trumpSelection phase', () {
      final provider = GameProvider();
      expect(provider.currentPhase, GamePhase.bidding);

      final res = provider.userSelectTrump(Suit.hearts);
      expect(res.success, isFalse);
      expect(res.message, contains("aşamasında değilsiniz"));
      expect(provider.currentTrump, Suit.spades); // default unchanged
    });

    test('Authoritative playCard: reject wrong player, unowned card, and illegal move', () async {
      final provider = GameProvider();

      // Set up playing phase deterministically
      provider.currentPhase = GamePhase.playing;
      provider.currentTrump = Suit.spades;
      provider.currentTurnIndex = 0;
      provider.tableCards.clear();
      provider.playedCardsByPlayer.clear();

      final p0 = provider.players[0];
      final p1 = provider.players[1];

      // Give players controlled hands
      p0.hand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.ace),
        PlayingCard(suit: Suit.spades, rank: Rank.ten),
      ];
      p1.hand = [
        PlayingCard(suit: Suit.hearts, rank: Rank.jack),
        PlayingCard(suit: Suit.clubs, rank: Rank.king),
      ];

      // 1. Wrong player attempts to play (p1 plays when it is p0's turn)
      final wrongPlayerResult = await provider.playCard(p1, p1.hand.first);
      expect(wrongPlayerResult.success, isFalse);
      expect(wrongPlayerResult.message, contains("Sıra bu oyuncuda değil"));
      expect(p1.hand.length, 2);
      expect(provider.tableCards.isEmpty, isTrue);
      expect(provider.currentTurnIndex, 0);

      // 2. Player attempts to play a card NOT in hand
      final unownedCard = PlayingCard(suit: Suit.diamonds, rank: Rank.two);
      final unownedResult = await provider.playCard(p0, unownedCard);
      expect(unownedResult.success, isFalse);
      expect(unownedResult.message, contains("elinde bulunmuyor"));
      expect(p0.hand.length, 2);
      expect(provider.tableCards.isEmpty, isTrue);

      // 3. P0 plays a valid lead card
      final validCard = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      final validResult = await provider.playCard(p0, validCard);
      expect(validResult.success, isTrue);
      expect(p0.hand.length, 1);
      expect(provider.tableCards.length, 1);
      expect(provider.tableCards.first, equals(validCard));
      expect(provider.currentTurnIndex, 1); // Turn advanced to p1

      // 4. P1 tries to play Clubs King when Hearts was led and P1 has Hearts Jack (Illegal move)
      final illegalCard = PlayingCard(suit: Suit.clubs, rank: Rank.king);
      final illegalResult = await provider.playCard(p1, illegalCard);
      expect(illegalResult.success, isFalse);
      expect(illegalResult.message, contains("Kurallara aykırı"));
      // Assert state untouched
      expect(p1.hand.length, 2);
      expect(provider.tableCards.length, 1);
      expect(provider.currentTurnIndex, 1); // Turn did NOT advance

      // 5. P1 plays legal card (Hearts Jack)
      final p1Legal = PlayingCard(suit: Suit.hearts, rank: Rank.jack);
      final p1LegalResult = await provider.playCard(p1, p1Legal);
      expect(p1LegalResult.success, isTrue);
      expect(p1.hand.length, 1);
      expect(provider.tableCards.length, 2);
      expect(provider.currentTurnIndex, 2); // Turn advanced to p2
    });

    test('getValidMovesForPlayer helper returns empty when not that player turn', () {
      final provider = GameProvider();
      provider.currentPhase = GamePhase.playing;
      provider.currentTurnIndex = 0;

      final p0Valid = provider.getValidMovesForPlayer(provider.players[0]);
      final p1Valid = provider.getValidMovesForPlayer(provider.players[1]);

      expect(p0Valid.isNotEmpty, isTrue);
      expect(p1Valid.isEmpty, isTrue);
    });
  });
}
