enum Suit {
  spades,   // Maça (İhalesiz batakta değişmez koz)
  hearts,   // Kupa
  diamonds, // Karo
  clubs     // Sinek
}

// Değerleri sıralı veriyoruz ki index üzerinden güç kıyaslaması kolay olsun
enum Rank {
  two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace
}

class PlayingCard {
  final Suit suit;
  final Rank rank;

  PlayingCard({required this.suit, required this.rank});

  // Kartın oyundaki gücünü index üzerinden alıyoruz. (Örn: As = 12, 2 = 0)
  // Bu sayede "kart1.power > kart2.power" mantığıyla eli kimin aldığını bulabileceğiz.
  int get power => rank.index;

  // Ekranda veya loglarda test ederken okunaklı görmek için
  @override
  String toString() => '${suit.name}-${rank.name}';
}
