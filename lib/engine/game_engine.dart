import '../models/card_model.dart';
import '../models/player_model.dart';

class GameEngine {
  /// Oyuncunun yere atmak istediği kartın kurallara uygun olup olmadığını denetler.
  /// [tableCards]: O el boyunca yere atılmış olan kartlar (boş ise eli başlatan kişidir)
  /// [trumpSuit]: O oyunun kozu (İhalecinin belirlediği veya standart Maça)
  static bool isValidPlay({
    required PlayingCard cardToPlay,
    required Player player,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
  }) {
    // KURAL 0: Elin ilk kartı atılıyorsa, oyuncu elindeki İSTEDİĞİ kartı atabilir.
    if (tableCards.isEmpty) return true;

    Suit ledSuit = tableCards.first.suit; // Yere ilk atılan kartın rengi
    bool hasLedSuit = player.hand.any((c) => c.suit == ledSuit);

    // KURAL 1: RENGE UYMA ZORUNLULUĞU
    if (hasLedSuit) {
      if (cardToPlay.suit != ledSuit) return false; // Elinde varsa o rengi atmak ZORUNDA
      
      // Eğer oynanan renk KOZ ise, koz büyütme zorunluluğu vardır!
      if (ledSuit == trumpSuit) {
        return _checkOvertrump(cardToPlay, player, tableCards, trumpSuit);
      }
      
      // Koz değilse sadece rengi vermesi yeterli, büyütme zorunluluğu yok (Standart Batak kuralı)
      return true; 
    }

    // KURAL 2: KOZ ATMA ZORUNLULUĞU
    // Oyuncunun elinde yerdeki renkten yok, peki koz var mı?
    bool hasTrump = player.hand.any((c) => c.suit == trumpSuit);
    if (hasTrump) {
      if (cardToPlay.suit != trumpSuit) return false; // Kozu varsa koz atmak ZORUNDA
      
      // KURAL 3: KOZ BÜYÜTME ZORUNLULUĞU (Overtrumping)
      return _checkOvertrump(cardToPlay, player, tableCards, trumpSuit);
    }

    // KURAL 4: ÇÖP ATMA
    // Oyuncuda ne yerdeki renkten ne de kozdan var. İstediği herhangi bir kartı atabilir.
    return true;
  }

  /// Yerdeki en büyük kozu bulup, oyuncunun elindeki kozla onu geçmeye çalışmasını denetler.
  static bool _checkOvertrump(
    PlayingCard cardToPlay, 
    Player player, 
    List<PlayingCard> tableCards, 
    Suit trumpSuit,
  ) {
    // Yerdeki kozları filtrele
    List<PlayingCard> tableTrumps = tableCards.where((c) => c.suit == trumpSuit).toList();
    
    // Yerde hiç koz yoksa, attığı ilk koz geçerlidir.
    if (tableTrumps.isEmpty) return true;

    // Yerdeki en büyük kozun gücünü bul
    int highestTableTrumpPower = -1;
    for (var c in tableTrumps) {
      if (c.power > highestTableTrumpPower) highestTableTrumpPower = c.power;
    }

    // Oyuncunun elinde yerdeki en büyük kozu geçebilecek daha büyük bir koz var mı?
    bool canOvertrump = player.hand.any((c) => c.suit == trumpSuit && c.power > highestTableTrumpPower);

    if (canOvertrump) {
      // Eğer geçebiliyorsa, atmak istediği kart kesinlikle o büyük kozlardan biri olmak ZORUNDA
      return cardToPlay.power > highestTableTrumpPower;
    }

    // Eğer geçemiyorsa (elindeki tüm kozlar yerdekinden küçükse), elindeki herhangi bir kozu atabilir (ezilir)
    return true;
  }

  /// Yere atılan 4 karta ve belirlenen koza bakarak, eli kazanan kartın indeksini (0, 1, 2, 3) döndürür.
  static int determineWinnerIndex(List<PlayingCard> tableCards, Suit trumpSuit) {
    // Güvenlik kontrolü: Elin bitmesi için tam 4 kart atılmış olması gerekir
    if (tableCards.length != 4) {
      throw Exception("Eli değerlendirmek için yerde 4 kart olmalıdır.");
    }

    // İlk atılan kartı başlangıçta "kazanan" olarak kabul ediyoruz
    int winningIndex = 0;
    PlayingCard winningCard = tableCards[0];
    Suit ledSuit = winningCard.suit; // Yerde dönen renk

    // Kalan 3 kartı sırasıyla şu anki kazananla kıyaslıyoruz
    for (int i = 1; i < 4; i++) {
      PlayingCard currentCard = tableCards[i];

      // DURUM 1: Atılan kart KOZ ise
      if (currentCard.suit == trumpSuit) {
        // Eğer masadaki mevcut kazanan kart koz değilse (ilk koz düşmüşse)
        if (winningCard.suit != trumpSuit) {
          winningIndex = i;
          winningCard = currentCard;
        } 
        // Eğer masadaki mevcut kazanan da kozsa, gücü (power) büyük olan alır
        else if (currentCard.power > winningCard.power) {
          winningIndex = i;
          winningCard = currentCard;
        }
      }
      
      // DURUM 2: Atılan kart koz değil ama YERDEKİ İLK RENK (Led Suit) ise
      else if (currentCard.suit == ledSuit) {
        // Eğer masadaki mevcut kazanan kart koz değilse (yani kimse koz çakmamışsa) 
        // ve atılan kart mevcut kazanandan büyükse
        if (winningCard.suit != trumpSuit && currentCard.power > winningCard.power) {
          winningIndex = i;
          winningCard = currentCard;
        }
      }
      
      // DURUM 3: Atılan kart ne koz, ne de yerdeki ilk renk. (Çöp atılmış)
      // Bu durumda mevcut kazanan (winningCard) değişmez. Hiçbir işlem yapmıyoruz.
    }

    return winningIndex;
  }

  /// Batak puanlama hesaplayıcı
  static int calculateScore(Player player, bool isBidder) {
    if (isBidder) {
      if (player.tricksWon >= player.bid) {
        return player.bid * 10 + (player.tricksWon - player.bid);
      } else {
        return -player.bid * 10;
      }
    } else {
      return player.tricksWon;
    }
  }
}

