import 'card_model.dart';

class Player {
  final String id;
  String name;
  final bool isAI; // Bot mu gerçek oyuncu mu?
  
  List<PlayingCard> hand;
  int bid; // Girdiği ihale
  int tricksWon; // Aldığı el sayısı

  Player({
    required this.id,
    required this.name,
    this.isAI = false,
    required this.hand,
    this.bid = 0,
    this.tricksWon = 0,
  }) {
    // Oyuncu nesnesi oluşturulur oluşturulmaz (kartlar dağıtıldığında) sıralama başlar
    sortHand();
  }

  // Kartları önce sembolüne, sonra değerine göre (büyükten küçüğe) sıralar
  void sortHand() {
    hand.sort((a, b) {
      // 1. Kriter: Sembol (Suit) sırası 
      // Enum sırasına göre dizecek: Maça (0), Kupa (1), Karo (2), Sinek (3)
      int suitComparison = a.suit.index.compareTo(b.suit.index);
      
      // Eğer semboller farklıysa sadece sembole göre sırala
      if (suitComparison != 0) {
        return suitComparison;
      } 
      
      // 2. Kriter: Eğer semboller aynıysa (örneğin ikisi de Kupa ise), büyükten küçüğe sırala
      // Not: Normalde a.compareTo(b) küçükten büyüğe sıralar. 
      // b.power.compareTo(a.power) diyerek azalan (descending) sıralama elde ediyoruz. (As -> Papaz -> ... -> 2)
      return b.power.compareTo(a.power);
    });
  }
}
