import '../models/card_model.dart';
import '../models/player_model.dart';
import 'game_engine.dart';

class AIEngine {
  /// Botun hile yapmadan, sadece kendi eline ve yere bakarak kart seçmesini sağlar.
  static PlayingCard chooseCard({
    required Player bot,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
  }) {
    // 1. ADIM: Kurallara göre OYNANABİLİR tüm kartları filtrele.
    // Bu sayede bot asla kural dışı bir kart atamaz (renge uymamazlık yapamaz).
    List<PlayingCard> validCards = bot.hand.where((card) =>
      GameEngine.isValidPlay(
        cardToPlay: card, 
        player: bot, 
        tableCards: tableCards, 
        trumpSuit: trumpSuit
      )
    ).toList();

    // İşlem kolaylığı için geçerli kartları GÜCÜNE GÖRE küçükten büyüğe sıralayalım.
    validCards.sort((a, b) => a.power.compareTo(b.power));

    // DURUM 1: Bot eli başlatıyor (Masa boş)
    if (tableCards.isEmpty) {
      // Strateji: Elindeki koz olmayan yüksek kartları (Papaz, As gibi) tahsil etmeye çalış.
      var safeHighCards = validCards.where((c) => c.suit != trumpSuit && c.power >= Rank.jack.index).toList();
      
      if (safeHighCards.isNotEmpty) {
        return safeHighCards.last; // Bulduğu en büyük kartı atar (Örn: As)
      }
      
      // Elinde güvenli büyük kart yoksa, koz olmayan en küçük kartını atarak ondan kurtulur (Çöp atma).
      var nonTrumps = validCards.where((c) => c.suit != trumpSuit).toList();
      if (nonTrumps.isNotEmpty) return nonTrumps.first;

      // Mecbur kaldıysa en küçük kozunu atar.
      return validCards.first;
    }

    // DURUM 2: Bot karşılık veriyor (Masada kart var)
    Suit ledSuit = tableCards.first.suit;

    // Masadaki "O Anki Kazanan" kartı bul
    PlayingCard currentWinner = tableCards[0];
    for (int i = 1; i < tableCards.length; i++) {
      PlayingCard c = tableCards[i];
      if (c.suit == trumpSuit && currentWinner.suit != trumpSuit) {
        currentWinner = c;
      } else if (c.suit == trumpSuit && currentWinner.suit == trumpSuit && c.power > currentWinner.power) {
        currentWinner = c;
      } else if (c.suit == ledSuit && currentWinner.suit != trumpSuit && c.power > currentWinner.power) {
        currentWinner = c;
      }
    }

    // Botun 'geçerli' kartları arasında masadaki o anki kazananı YENEBİLECEK olanları filtrele.
    List<PlayingCard> winningOptions = validCards.where((card) {
      if (card.suit == trumpSuit && currentWinner.suit != trumpSuit) return true; // Koz çakarak yener
      if (card.suit == trumpSuit && currentWinner.suit == trumpSuit && card.power > currentWinner.power) return true; // Koz büyütür
      if (card.suit == ledSuit && currentWinner.suit != trumpSuit && card.power > currentWinner.power) return true; // Aynı renkten daha büyüğünü atar
      return false;
    }).toList();

    if (winningOptions.isNotEmpty) {
      // STRATEJİ: Minimum Eforla Kazan!
      // Botun birden fazla kazanan kartı varsa, en büyüğünü israf etmez. En KÜÇÜK kazananı atar.
      // (Örn: Yerde 5 var. Botta 10 ve As var. 10'u atar, As'ı saklar.)
      return winningOptions.first; 
    } else {
      // STRATEJİ: Hasar Kontrolü (Sloughing)
      // Bot masadaki kartı geçemiyor. Bu yüzden mecburen elindeki en KÜÇÜK (en değersiz) kartı feda eder.
      return validCards.first; 
    }
  }

  /// Botun eline bakarak gireceği ihale sayısını tahmin eder.
  static int calculateBid(Player bot) {
    int expectedTricks = 0;

    // Her semboldeki kartları grupla (Örn: Maçalar, Kupalar...)
    Map<Suit, List<PlayingCard>> suitsMap = {
      Suit.spades: [], Suit.hearts: [], Suit.diamonds: [], Suit.clubs: [],
    };

    for (var card in bot.hand) {
      suitsMap[card.suit]!.add(card);
    }

    // Her bir renk (sembol) için değerlendirme yap
    for (var suit in Suit.values) {
      List<PlayingCard> cardsInSuit = suitsMap[suit]!;
      
      bool hasAce = cardsInSuit.any((c) => c.rank == Rank.ace);
      bool hasKing = cardsInSuit.any((c) => c.rank == Rank.king);
      bool hasQueen = cardsInSuit.any((c) => c.rank == Rank.queen);

      // As varsa 1 el say
      if (hasAce) expectedTricks++;

      // Papaz varsa VE As kendisindeyse YA DA o renkten en az 2 kart daha varsa (korumalı Papaz)
      if (hasKing && (hasAce || cardsInSuit.length >= 2)) {
        expectedTricks++;
      }

      // Kız varsa VE (As ve Papaz kendisindeyse) YA DA o renkten en az 3 kart daha varsa
      if (hasQueen && ((hasAce && hasKing) || cardsInSuit.length >= 3)) {
        expectedTricks++;
      }

      // Renk uzunluğu (Uzun renkler koz yapıldığında el getirir)
      // Eğer bir renkten 5 veya daha fazla varsa, ekstra 1 el potansiyeli ekle
      if (cardsInSuit.length >= 5) {
        expectedTricks++;
      }
    }

    // İhaleler Batak'ta genellikle 5'ten başlar. Eğer botun eli çok kötüyse 'Pas' (0) geçer.
    // Şimdilik minimum ihale kuralını arayüzde yöneteceğiz, burada sadece ham potansiyeli döndürüyoruz.
    return expectedTricks;
  }

  /// Bot ihaleyi aldığında elindeki en mantıklı kozu seçer.
  static Suit chooseTrump(Player bot) {
    Map<Suit, int> suitWeights = {
      Suit.spades: 0, Suit.hearts: 0, Suit.diamonds: 0, Suit.clubs: 0,
    };

    // Her bir renk için puanlama yap (Uzunluk ve As/Papaz gücü)
    for (var card in bot.hand) {
      suitWeights[card.suit] = (suitWeights[card.suit] ?? 0) + card.power; 
      // Sadece sayısına değil, o renkteki kartların büyüklüğüne de bakıyoruz.
    }

    // En yüksek ağırlığa sahip rengi bul
    Suit bestSuit = Suit.spades; // Varsayılan
    int maxWeight = -1;

    suitWeights.forEach((suit, weight) {
      if (weight > maxWeight) {
        maxWeight = weight;
        bestSuit = suit;
      }
    });

    return bestSuit;
  }
}
