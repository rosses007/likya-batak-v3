import '../models/card_model.dart';
import '../models/player_model.dart';

// ============================================================
// TAKIM TANIMLAMALARI (LIKYA-V2-004)
// ============================================================
//
// Eşli Batak takım sabit ataması:
//   Takım A: Oyuncu 0 + Oyuncu 2  (Siz & Arda)
//   Takım B: Oyuncu 1 + Oyuncu 3  (Erol & Uğur)
//
// Takım kimliği her zaman oyuncu indeksinden türetilir.
// Ek mutable state saklanmaz.

enum TeamId { teamA, teamB }

/// Takım yardımcı fonksiyonları — saf ve yan etkisiz.
class TeamEngine {
  TeamEngine._(); // Instantiation engeli

  /// Oyuncunun ait olduğu takımı döner.
  static TeamId teamForPlayer(int playerIndex) {
    return (playerIndex % 2 == 0) ? TeamId.teamA : TeamId.teamB;
  }

  /// Oyuncunun ortak (partner) indeksini döner.
  /// 0 <-> 2, 1 <-> 3
  static int partnerIndexFor(int playerIndex) {
    return (playerIndex + 2) % 4;
  }

  /// İki oyuncunun aynı takımda olup olmadığını döner.
  static bool areSameTeam(int a, int b) {
    return teamForPlayer(a) == teamForPlayer(b);
  }

  /// Takımın toplam el sayısını hesaplar.
  static int teamTricks({
    required List<Player> players,
    required TeamId team,
  }) {
    assert(players.length == 4, 'Eşli batak 4 oyuncu gerektirir');
    int total = 0;
    for (int i = 0; i < 4; i++) {
      if (teamForPlayer(i) == team) {
        total += players[i].tricksWon;
      }
    }
    return total;
  }

  /// İhaleyi kazanan oyuncunun ait olduğu takımı döner.
  static TeamId biddingTeam(int bidderIndex) {
    return teamForPlayer(bidderIndex);
  }

  // ============================================================
  // PARTNER CURRENTLY WINNING DETECTION
  // ============================================================

  /// Mevcut elde masadaki kağıtlara bakarak partnerin şu an kazanıp
  /// kazanmadığını belirler.
  ///
  /// [tableCards]        — masadaki kartlar (boş olabilir)
  /// [playedCardsByPlayer] — {playerIndex: card} kimin ne attığını
  /// [leadPlayerIndex]   — bu elde ilk kart atan oyuncunun indeksi
  /// [myPlayerIndex]     — bu botun indeksi
  /// [trumpSuit]         — koz rengi
  ///
  /// Returns:
  ///   true  → partner şu an bu eli kazanıyor
  ///   false → partner kazanmıyor veya masada kart yok veya partner henüz oynamadı
  static bool isPartnerCurrentlyWinning({
    required List<PlayingCard> tableCards,
    required Map<int, PlayingCard> playedCardsByPlayer,
    required int leadPlayerIndex,
    required int myPlayerIndex,
    required Suit trumpSuit,
  }) {
    if (tableCards.isEmpty) return false;

    final int partnerIdx = partnerIndexFor(myPlayerIndex);

    // Partnerın attığı kart masada mı?
    final PlayingCard? partnerCard = playedCardsByPlayer[partnerIdx];
    if (partnerCard == null) return false; // partner henüz oynamadı

    // Mevcut el kazananını hesapla (1..4 kart arası)
    int winningCardIdx = 0;
    PlayingCard winningCard = tableCards[0];
    final Suit ledSuit = winningCard.suit;

    for (int i = 1; i < tableCards.length; i++) {
      final PlayingCard c = tableCards[i];
      if (c.suit == trumpSuit && winningCard.suit != trumpSuit) {
        winningCard = c;
        winningCardIdx = i;
      } else if (c.suit == trumpSuit && winningCard.suit == trumpSuit && c.power > winningCard.power) {
        winningCard = c;
        winningCardIdx = i;
      } else if (c.suit == ledSuit && winningCard.suit != trumpSuit && c.power > winningCard.power) {
        winningCard = c;
        winningCardIdx = i;
      }
    }

    final int currentWinnerPlayerIdx = (leadPlayerIndex + winningCardIdx) % 4;
    return currentWinnerPlayerIdx == partnerIdx;
  }
}
