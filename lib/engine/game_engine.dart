import '../models/card_model.dart';
import '../models/player_model.dart';

/// Oyun içi hamle ve komutların sonuç nesnesi.
/// Hata durumunda exception fırlatmadan yapısal ve güvenli durum bilgisi döner.
class GameActionResult {
  final bool success;
  final String message;

  const GameActionResult.success([this.message = '']) : success = true;
  const GameActionResult.failure(this.message) : success = false;

  @override
  String toString() => success ? 'Success($message)' : 'Failure($message)';
}

class GameEngine {
  /// Saf (Pure) Kural API'si:
  /// Verilen el, masa kartları ve koza göre oynanabilecek TÜM yasal kartları döner.
  /// Hiçbir UI, Context, ses veya yan etki içermez; deterministiktir.
  static List<PlayingCard> getValidMoves({
    required List<PlayingCard> hand,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
  }) {
    if (hand.isEmpty) return const [];

    // KURAL 0: Elin ilk kartı atılıyorsa (masa boşsa), oyuncu elindeki istediği kartı atabilir.
    if (tableCards.isEmpty) {
      return List<PlayingCard>.unmodifiable(hand);
    }

    final Suit ledSuit = tableCards.first.suit;
    final List<PlayingCard> ledSuitCards =
        hand.where((c) => c.suit == ledSuit).toList();

    // KURAL 1: RENGE UYMA ZORUNLULUĞU
    if (ledSuitCards.isNotEmpty) {
      // Eğer oynanan renk KOZ ise, koz büyütme zorunluluğu vardır!
      if (ledSuit == trumpSuit) {
        return List<PlayingCard>.unmodifiable(
          _filterOvertrumpCards(ledSuitCards, tableCards, trumpSuit),
        );
      }
      // Koz değilse sadece o rengi vermek yeterlidir.
      return List<PlayingCard>.unmodifiable(ledSuitCards);
    }

    // KURAL 2: KOZ ATMA ZORUNLULUĞU
    // Oyuncunun elinde yerdeki renkten yoksa koz atmak zorundadır.
    final List<PlayingCard> trumpCards =
        hand.where((c) => c.suit == trumpSuit).toList();
    if (trumpCards.isNotEmpty) {
      // KURAL 3: KOZ BÜYÜTME ZORUNLULUĞU (Overtrumping)
      return List<PlayingCard>.unmodifiable(
        _filterOvertrumpCards(trumpCards, tableCards, trumpSuit),
      );
    }

    // KURAL 4: ÇÖP ATMA
    // Oyuncuda ne yerdeki renkten ne de kozdan var. İstediği herhangi bir kartı atabilir.
    return List<PlayingCard>.unmodifiable(hand);
  }

  /// Masadaki en büyük kozu tespit eder ve oyuncunun elindeki kozlarla onu geçmeye zorlar.
  static List<PlayingCard> _filterOvertrumpCards(
    List<PlayingCard> playerTrumpCards,
    List<PlayingCard> tableCards,
    Suit trumpSuit,
  ) {
    final List<PlayingCard> tableTrumps =
        tableCards.where((c) => c.suit == trumpSuit).toList();

    // Masada henüz koz yoksa eldeki tüm kozlar geçerlidir.
    if (tableTrumps.isEmpty) return playerTrumpCards;

    int highestTableTrumpPower = -1;
    for (final c in tableTrumps) {
      if (c.power > highestTableTrumpPower) {
        highestTableTrumpPower = c.power;
      }
    }

    final List<PlayingCard> higherTrumps =
        playerTrumpCards.where((c) => c.power > highestTableTrumpPower).toList();

    // Geçebiliyorsa sadece o büyük kozları atabilir.
    if (higherTrumps.isNotEmpty) {
      return higherTrumps;
    }

    // Geçemiyorsa (elindeki tüm kozlar yerdekilerden küçükse) herhangi bir kozu atabilir (ezilir).
    return playerTrumpCards;
  }

  /// Oyuncunun atmak istediği kartın geçerli olup olmadığını saf kural API'si ile denetler.
  static bool isValidPlay({
    required PlayingCard cardToPlay,
    required Player player,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
  }) {
    if (!player.hand.contains(cardToPlay)) return false;
    final validMoves = getValidMoves(
      hand: player.hand,
      tableCards: tableCards,
      trumpSuit: trumpSuit,
    );
    return validMoves.contains(cardToPlay);
  }

  /// Kapsamlı Hamle Doğrulayıcı:
  /// Hamlenin faz, sıra, mülkiyet ve kural koşullarını tek noktadan doğrular.
  static GameActionResult validatePlay({
    required PlayingCard cardToPlay,
    required Player player,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    required bool isCurrentTurn,
    required bool isPlayingPhase,
  }) {
    if (!isPlayingPhase) {
      return const GameActionResult.failure("Oyun kart atma aşamasında değil.");
    }
    if (!isCurrentTurn) {
      return const GameActionResult.failure("Sıra bu oyuncuda değil.");
    }
    if (!player.hand.contains(cardToPlay)) {
      return const GameActionResult.failure("Kart oyuncunun elinde bulunmuyor.");
    }
    if (tableCards.contains(cardToPlay)) {
      return const GameActionResult.failure("Bu kart bu elde zaten masaya atılmış.");
    }

    final validMoves = getValidMoves(
      hand: player.hand,
      tableCards: tableCards,
      trumpSuit: trumpSuit,
    );

    if (!validMoves.contains(cardToPlay)) {
      return const GameActionResult.failure("Kurallara aykırı kart hamlesi.");
    }

    return const GameActionResult.success();
  }

  /// Yere atılan 4 karta ve belirlenen koza bakarak, eli kazanan kartın indeksini (0, 1, 2, 3) döndürür.
  static int determineWinnerIndex(List<PlayingCard> tableCards, Suit trumpSuit) {
    if (tableCards.length != 4) {
      throw ArgumentError("Eli değerlendirmek için yerde 4 kart olmalıdır.");
    }

    int winningIndex = 0;
    PlayingCard winningCard = tableCards[0];
    Suit ledSuit = winningCard.suit;

    for (int i = 1; i < 4; i++) {
      PlayingCard currentCard = tableCards[i];

      if (currentCard.suit == trumpSuit) {
        if (winningCard.suit != trumpSuit) {
          winningIndex = i;
          winningCard = currentCard;
        } else if (currentCard.power > winningCard.power) {
          winningIndex = i;
          winningCard = currentCard;
        }
      } else if (currentCard.suit == ledSuit) {
        if (winningCard.suit != trumpSuit && currentCard.power > winningCard.power) {
          winningIndex = i;
          winningCard = currentCard;
        }
      }
    }

    return winningIndex;
  }

  /// Yere ilk kartı atan oyuncu (leadPlayerIndex) ve masa kartlarına göre kazanan oyuncunun indeksini döndürür.
  static int determineTrickWinnerPlayerIndex({
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    required int leadPlayerIndex,
  }) {
    final winningCardIndex = determineWinnerIndex(tableCards, trumpSuit);
    return (leadPlayerIndex + winningCardIndex) % 4;
  }

  /// Batak puanlama hesaplayıcı
  ///
  /// @Deprecated LIKYA-V2-004: Lütfen ScoringEngine.calculateSinglePlayerDelta kullanın.
  /// Bu metot geriye dönük uyumluluk (game_engine_test) için korunmaktadır.
  /// İki formül arasında tutarsızlık olmaması için ScoringEngine'e delege eder.
  static int calculateScore(Player player, bool isBidder) {
    // ScoringEngine'e delege et (tek kaynak of truth)
    return _computeLegacyScore(player, isBidder);
  }

  /// Internal legacy delegation - ScoringEngine içerikleriyle özdeş.
  static int _computeLegacyScore(Player player, bool isBidder) {
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
