import 'card_model.dart';

class Deck {
  List<PlayingCard> cards = [];

  Deck() {
    _initializeDeck();
  }

  // Oyun başladığında 52'lik desteyi sıfırdan kurar
  void _initializeDeck() {
    for (var suit in Suit.values) {
      for (var rank in Rank.values) {
        cards.add(PlayingCard(suit: suit, rank: rank));
      }
    }
  }

  // Desteyi rastgele karıştırır
  void shuffle() {
    cards.shuffle();
  }

  // Kartları 4 oyuncuya 13'erli paylaştırır
  List<List<PlayingCard>> dealCards() {
    List<List<PlayingCard>> hands = [[], [], [], []];
    int playerIndex = 0;

    for (var card in cards) {
      hands[playerIndex].add(card);
      playerIndex = (playerIndex + 1) % 4; // 0, 1, 2, 3 döngüsü yaratır
    }
    
    return hands;
  }
}
