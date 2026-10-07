import '../models/card_model.dart';
import '../models/player_model.dart';

/// İhaleli ve Eşli Batak tur sonucunu temsil eden veri yapısı.
/// Puan tablosu ve yazboz geçmişi bu nesneden beslenebilir.
class RoundResult {
  final int roundNumber;
  final int bidderIndex;
  final int bid;
  final Suit trump;
  final String gameMode;            // 'single' veya 'partner'
  final List<int> tricksByPlayer;       // Her oyuncunun aldığı el sayısı [p0,p1,p2,p3]
  final List<int> scoreDeltaByPlayer;   // Bu turdaki puan değişimi [p0,p1,p2,p3]
  final List<int> cumulativeScores;     // Tur sonrası kümülatif puan [p0,p1,p2,p3]

  const RoundResult({
    required this.roundNumber,
    required this.bidderIndex,
    required this.bid,
    required this.trump,
    this.gameMode = 'single',
    required this.tricksByPlayer,
    required this.scoreDeltaByPlayer,
    required this.cumulativeScores,
  });

  @override
  String toString() {
    return 'RoundResult(round:$roundNumber mode:$gameMode bidder:$bidderIndex bid:$bid '
        'tricks:$tricksByPlayer delta:$scoreDeltaByPlayer cumulative:$cumulativeScores)';
  }
}

/// Batak puanlama motoru - saf ve yan etkisiz.
///
/// Tüm puan hesapları UI'dan, widget'lardan ve servislerden bağımsız olarak
/// bu sınıf üzerinden yapılmalıdır.
class ScoringEngine {
  ScoringEngine._(); // Instantiation engeli

  // ============================================================
  // TEKLİ İHALELİ BATAK PUANLAMA KURALLARI
  // ============================================================
  //
  // İHALECİ (Bidder):
  //   - tricksWon >= bid  → +bid*10 + (tricksWon - bid)  (başarı + fazlalık)
  //   - tricksWon < bid   → -(bid*10)                     (ceza / batar)
  //
  // DİĞER OYUNCULAR (Non-bidders):
  //   - Her alınan el için: +1 puan (tricksWon * 1)
  //
  // NOT: Mevcut implementasyonda fazlalık ellerin her biri için yalnızca +1
  //      hesaplanmaktadır. Bu, Likya Batak'ın seçilen kuralıdır.
  //      Farklı Batak varyantlarındaki 10 puan/fazla kural KULLANILMAMAKTADIR.

  /// Tek bir oyuncu için tek turluk puan deltasını hesaplar.
  /// Kullanılan kural: Tekli İhaleli Batak
  static int calculateSinglePlayerDelta({
    required Player player,
    required bool isBidder,
  }) {
    if (isBidder) {
      if (player.tricksWon >= player.bid) {
        // Başarılı ihale: bid*10 + fazlalık
        return player.bid * 10 + (player.tricksWon - player.bid);
      } else {
        // Batar: -bid*10
        return -player.bid * 10;
      }
    } else {
      // İhaleci olmayan: her el için 1 puan
      return player.tricksWon;
    }
  }

  /// Tekli İhaleli Batak için tam bir tur sonucunu hesaplar.
  ///
  /// [players] — 4 oyuncunun güncel durumu (tricksWon, bid dolu olmalı)
  /// [bidderIndex] — ihaleyi kazanan oyuncunun indeksi
  /// [bid] — kazanılan ihale miktarı
  /// [trump] — bu turdaki koz
  /// [roundNumber] — tur numarası
  /// [prevCumulativeScores] — önceki kümülatif puanlar (4-elemanlı liste)
  static RoundResult computeSingleModeRound({
    required List<Player> players,
    required int bidderIndex,
    required int bid,
    required Suit trump,
    required int roundNumber,
    required List<int> prevCumulativeScores,
  }) {
    assert(players.length == 4, 'Tekli batak 4 oyuncu gerektirir');
    assert(prevCumulativeScores.length == 4, 'Kümülatif puan listesi 4 elemanlı olmalı');

    final List<int> deltas = List.filled(4, 0);
    final List<int> tricksByPlayer = List.filled(4, 0);

    for (int i = 0; i < 4; i++) {
      tricksByPlayer[i] = players[i].tricksWon;
      deltas[i] = calculateSinglePlayerDelta(
        player: players[i],
        isBidder: i == bidderIndex,
      );
    }

    final List<int> cumulative = List.generate(
      4,
      (i) => prevCumulativeScores[i] + deltas[i],
    );

    return RoundResult(
      roundNumber: roundNumber,
      bidderIndex: bidderIndex,
      bid: bid,
      trump: trump,
      gameMode: 'single',
      tricksByPlayer: tricksByPlayer,
      scoreDeltaByPlayer: deltas,
      cumulativeScores: cumulative,
    );
  }

  /// Eşli Batak için tam bir tur sonucunu hesaplar.
  ///
  /// Takım 1: oyuncu 0 ve 2 (Siz & Arda)
  /// Takım 2: oyuncu 1 ve 3 (Erol & Uğur)
  ///
  /// EŞLİ BATAK KURALLARI:
  ///   İhale takımı yeterli el toplarsa: bid*10 + fazlalık
  ///   İhale takımı yeterli el toplamazsa: -(bid*10)
  ///   Diğer takım: topladığı el * 10 puan
  static RoundResult computePartnerModeRound({
    required List<Player> players,
    required int bidderIndex,
    required int bid,
    required Suit trump,
    required int roundNumber,
    required List<int> prevCumulativeScores,
  }) {
    assert(players.length == 4, 'Eşli batak 4 oyuncu gerektirir');

    final bool team1Bidder = (bidderIndex == 0 || bidderIndex == 2);
    final int team1Tricks = players[0].tricksWon + players[2].tricksWon;
    final int team2Tricks = players[1].tricksWon + players[3].tricksWon;

    int team1Score;
    int team2Score;

    if (team1Bidder) {
      team1Score = (team1Tricks >= bid)
          ? (bid * 10) + (team1Tricks - bid)
          : -(bid * 10);
      team2Score = team2Tricks * 10;
    } else {
      team2Score = (team2Tricks >= bid)
          ? (bid * 10) + (team2Tricks - bid)
          : -(bid * 10);
      team1Score = team1Tricks * 10;
    }

    final List<int> deltas = [team1Score, team2Score, team1Score, team2Score];
    final List<int> tricksByPlayer = List.generate(4, (i) => players[i].tricksWon);
    final List<int> cumulative = List.generate(
      4,
      (i) => prevCumulativeScores[i] + deltas[i],
    );

    return RoundResult(
      roundNumber: roundNumber,
      bidderIndex: bidderIndex,
      bid: bid,
      trump: trump,
      gameMode: 'partner',
      tricksByPlayer: tricksByPlayer,
      scoreDeltaByPlayer: deltas,
      cumulativeScores: cumulative,
    );
  }

  // ============================================================
  // KOZ MAÇA (İHALESİZ BATAK) PUANLAMA KURALLARI (LIKYA-V2-005)
  // ============================================================
  //
  // İhale ve batma yoktur. Bütün oyuncular aldıkları el sayısına
  // göre pozitif puan kazanır:
  //   Delta = player.tricksWon * 10

  /// Tek bir oyuncu için Koz Maça tek tur puanını hesaplar.
  static int calculateKozMacaPlayerDelta({required Player player}) {
    return player.tricksWon * 10;
  }

  /// Koz Maça (İhalesiz Batak) için tam bir tur sonucunu hesaplar.
  static RoundResult computeKozMacaRound({
    required List<Player> players,
    required int roundNumber,
    required List<int> prevCumulativeScores,
  }) {
    assert(players.length == 4, 'Koz Maça 4 oyuncu gerektirir');
    assert(prevCumulativeScores.length == 4, 'Kümülatif puan listesi 4 elemanlı olmalı');

    final List<int> deltas = List.filled(4, 0);
    final List<int> tricksByPlayer = List.filled(4, 0);

    for (int i = 0; i < 4; i++) {
      tricksByPlayer[i] = players[i].tricksWon;
      deltas[i] = calculateKozMacaPlayerDelta(player: players[i]);
    }

    final List<int> cumulative = List.generate(
      4,
      (i) => prevCumulativeScores[i] + deltas[i],
    );

    return RoundResult(
      roundNumber: roundNumber,
      bidderIndex: -1, // İhale yok
      bid: 0,          // İhale yok
      trump: Suit.spades, // Koz her zaman Maça ♠
      gameMode: 'kozMaca',
      tricksByPlayer: tricksByPlayer,
      scoreDeltaByPlayer: deltas,
      cumulativeScores: cumulative,
    );
  }

  /// Desteden gelen 4 ele bakarak deste bütünlüğünü doğrular.
  ///
  /// Returns: boş liste = geçerli; dolu liste = hata mesajları
  static List<String> validateDeal(List<List<PlayingCard>> hands) {
    final errors = <String>[];

    if (hands.length != 4) {
      errors.add('Oyuncu sayısı 4 değil: ${hands.length}');
      return errors;
    }

    int totalCards = 0;
    for (int i = 0; i < 4; i++) {
      totalCards += hands[i].length;
      if (hands[i].length != 13) {
        errors.add('Oyuncu $i: beklenen 13 kart, var olan ${hands[i].length}');
      }
    }

    if (totalCards != 52) {
      errors.add('Toplam kart sayısı 52 değil: $totalCards');
    }

    // Mükerrer kart kontrolü
    final seen = <PlayingCard>{};
    for (int i = 0; i < 4; i++) {
      for (final card in hands[i]) {
        if (!seen.add(card)) {
          errors.add('Mükerrer kart: $card (oyuncu $i)');
        }
      }
    }

    if (seen.length != 52) {
      errors.add('Benzersiz kart sayısı 52 değil: ${seen.length}');
    }

    return errors;
  }

  /// Oyuncu listesinden el toplamının 13 olup olmadığını doğrular.
  static List<String> validateTrickTotals(List<Player> players) {
    final errors = <String>[];
    int total = 0;
    for (final p in players) {
      total += p.tricksWon;
    }
    if (total != 13) {
      errors.add('Toplam el sayısı 13 değil: $total');
    }
    return errors;
  }

  /// Tüm oyuncuların elleri boş mu? (13. el bittikten sonra beklenen durum)
  static bool allHandsEmpty(List<Player> players) {
    return players.every((p) => p.hand.isEmpty);
  }

  /// Belirli bir turun en yüksek kümülatif puana sahip oyuncusunun indeksini döner.
  /// Birden fazla eşit kazanan varsa, ilkini (en düşük indeksi) döner.
  static int determineWinnerIndex(List<int> cumulativeScores) {
    int best = -999999;
    int winnerIdx = 0;
    for (int i = 0; i < cumulativeScores.length; i++) {
      if (cumulativeScores[i] > best) {
        best = cumulativeScores[i];
        winnerIdx = i;
      }
    }
    return winnerIdx;
  }

  // ============================================================
  // EŞLİ BATAK YARDIMCI METOTLARI (LIKYA-V2-004)
  // ============================================================

  /// Eşli Batak'ta iki takımın el sayılarını döner.
  /// Returns: (team1Tricks, team2Tricks) — Takım A: 0+2, Takım B: 1+3
  static (int, int) partnerTrickTotals(List<Player> players) {
    assert(players.length == 4);
    final team1 = players[0].tricksWon + players[2].tricksWon;
    final team2 = players[1].tricksWon + players[3].tricksWon;
    return (team1, team2);
  }

  /// Eşli Batak'ta ihale takımının başarılı olup olmadığını döner.
  static bool isPartnerBidSuccess({
    required int bidderIndex,
    required int bid,
    required List<Player> players,
  }) {
    final bool team1Bidder = (bidderIndex == 0 || bidderIndex == 2);
    final (int team1Tricks, int team2Tricks) = partnerTrickTotals(players);
    return team1Bidder ? (team1Tricks >= bid) : (team2Tricks >= bid);
  }
}

