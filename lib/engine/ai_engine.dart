import 'dart:math';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../models/bot_memory.dart';
import '../models/ai_difficulty.dart';
import 'game_engine.dart';
import 'team_engine.dart';
import 'game_mode_rules.dart';

class AIEngine {
  /// Botun hile yapmadan kart seçmesini sağlar.
  ///
  /// [bot]                — kart seçecek bot oyuncusu
  /// [tableCards]         — masadaki kartlar (public bilgi)
  /// [trumpSuit]          — koz rengi (public bilgi)
  /// [botPlayerIndex]     — Eşli mod için botun oturum indeksi (0-3); null ise tekli mod davranışı
  /// [playedCardsByPlayer]— Eşli mod için {playerIndex: card} haritası (public bilgi); null ise devre dışı
  /// [leadPlayerIndex]    — Eşli mod için bu eldeki ilk oyuncunun indeksi; null ise devre dışı
  /// [memory]             — Genel kamuya açık bot hafızası (public bilgi; V2-007B temeli)
  /// [difficulty]         — Yapay zeka zorluk seviyesi (Easy / Normal / Hard)
  /// [random]             — Deterministik testler için enjekte edilebilir rastgele sayı üreteci
  ///
  /// Botun kendi elindeki gizli kartlara erişimi dışında hiçbir gizli bilgiye erişmez.
  static PlayingCard chooseCard({
    required Player bot,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    int? botPlayerIndex,
    Map<int, PlayingCard>? playedCardsByPlayer,
    int? leadPlayerIndex,
    BotMemory? memory,
    AIDifficulty difficulty = AIDifficulty.normal,
    Random? random,
  }) {
    // 1. ADIM: Saf kural motorundan oynanabilir tüm kartları çek.
    List<PlayingCard> validCards = List.of(
      GameEngine.getValidMoves(
        hand: bot.hand,
        tableCards: tableCards,
        trumpSuit: trumpSuit,
      ),
    );

    // Kural motorunun belirlediği geçerli hamleler kural dışına çıkamaz.
    if (validCards.isEmpty) {
      return bot.hand.first;
    }

    // İşlem kolaylığı için geçerli kartları GÜCÜNE GÖRE küçükten büyüğe sıralayalım.
    validCards.sort((a, b) => a.power.compareTo(b.power));

    // Tek bir yasal seçenek varsa, zorluk seviyesinden bağımsız olarak onu oyna.
    if (validCards.length == 1) {
      return validCards.first;
    }

    // Eşli Batak: Partner şu an kazanıyor mu? (Kamu bilgisi)
    final bool partnerIsWinning = (botPlayerIndex != null &&
            playedCardsByPlayer != null &&
            leadPlayerIndex != null)
        ? TeamEngine.isPartnerCurrentlyWinning(
            tableCards: tableCards,
            playedCardsByPlayer: playedCardsByPlayer,
            leadPlayerIndex: leadPlayerIndex,
            myPlayerIndex: botPlayerIndex,
            trumpSuit: trumpSuit,
          )
        : false;

    switch (difficulty) {
      case AIDifficulty.easy:
        return _chooseCardEasy(
          validCards: validCards,
          tableCards: tableCards,
          trumpSuit: trumpSuit,
          random: random,
        );
      case AIDifficulty.normal:
        return _chooseCardNormal(
          validCards: validCards,
          tableCards: tableCards,
          trumpSuit: trumpSuit,
          partnerIsWinning: partnerIsWinning,
        );
      case AIDifficulty.hard:
        return _chooseCardHard(
          bot: bot,
          validCards: validCards,
          tableCards: tableCards,
          trumpSuit: trumpSuit,
          botPlayerIndex: botPlayerIndex,
          partnerIsWinning: partnerIsWinning,
          memory: memory,
        );
    }
  }

  // ============================================================
  // EASY AI STRATEGY (KOLAY SEVİYE)
  // ============================================================
  /// Kolay bot: Minimum strateji, düşük kartları tercih eder, zaman zaman
  /// rastgele/alt-optimal yasal hamleler yapar. BotMemory kullanmaz.
  static PlayingCard _chooseCardEasy({
    required List<PlayingCard> validCards,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    Random? random,
  }) {
    final rng = random ?? Random();

    // %35 ihtimalle geçerli hamleler arasından rastgele bir seçim yapar (acemice hamle).
    if (validCards.length > 1 && rng.nextDouble() < 0.35) {
      return validCards[rng.nextInt(validCards.length)];
    }

    // Aksi halde geçerli en küçük kartı tercih eder.
    return validCards.first;
  }

  // ============================================================
  // NORMAL AI STRATEGY (NORMAL SEVİYE - MEVCUT BASELINE)
  // ============================================================
  /// Normal bot: Mevcut doğrulanmış baseline kuralı. Masadaki durumu,
  /// o anki kazananı, en küçük kazanan kartı ve ortak kontrolünü kullanır.
  static PlayingCard _chooseCardNormal({
    required List<PlayingCard> validCards,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    required bool partnerIsWinning,
  }) {
    // DURUM 1: Bot eli başlatıyor (Masa boş)
    if (tableCards.isEmpty) {
      // Elindeki koz olmayan yüksek kartları (Papaz, As gibi) tahsil etmeye çalış.
      var safeHighCards = validCards
          .where((c) => c.suit != trumpSuit && c.power >= Rank.jack.index)
          .toList();

      if (safeHighCards.isNotEmpty) {
        return safeHighCards.last; // En büyük kartı atar (Örn: As)
      }

      // Güvenli büyük kart yoksa, koz olmayan en küçük kartı atar (Çöp atma).
      var nonTrumps = validCards.where((c) => c.suit != trumpSuit).toList();
      if (nonTrumps.isNotEmpty) return nonTrumps.first;

      // Mecbur kaldıysa en küçük kozunu atar.
      return validCards.first;
    }

    // DURUM 2: Bot karşılık veriyor (Masada kart var)
    final Suit ledSuit = tableCards.first.suit;
    final PlayingCard currentWinner = currentWinningCard(tableCards, trumpSuit)!;

    // Eşli Batak: Partner zaten kazanıyorsa gereksiz yüksek kart/koz harcama
    if (partnerIsWinning) {
      final nonWinningOptions = validCards.where((c) => c.suit != trumpSuit).toList();
      if (nonWinningOptions.isNotEmpty) {
        return nonWinningOptions.first; // En küçük zararsız kart
      }
      return validCards.first;
    }

    // Kazanan seçenekleri filtrele
    List<PlayingCard> winningOptions = validCards
        .where((c) => canCardBeat(c, currentWinner, ledSuit, trumpSuit))
        .toList();

    if (winningOptions.isNotEmpty) {
      // Minimum eforla kazan: En küçük kazananı at
      return winningOptions.first;
    } else {
      // Hasar kontrolü: En değersiz kartı feda et
      return validCards.first;
    }
  }

  // ============================================================
  // HARD AI STRATEGY (ZOR SEVİYE - BOTMEMORY GÜCÜ)
  // ============================================================
  /// Zor bot: Kamuya açık BotMemory bilgilerini (çıkan büyük kartlar,
  /// kalan koz sayısı, oyuncu boşlukları, ihale hedefi ve ortaklık) kullanır.
  /// Asla gizli ellere bakmaz.
  static PlayingCard _chooseCardHard({
    required Player bot,
    required List<PlayingCard> validCards,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    required int? botPlayerIndex,
    required bool partnerIsWinning,
    required BotMemory? memory,
  }) {
    // 1. Masa boş (Eli başlatıyor)
    if (tableCards.isEmpty) {
      return _chooseHardLead(
        validCards: validCards,
        trumpSuit: trumpSuit,
        botPlayerIndex: botPlayerIndex,
        memory: memory,
      );
    }

    // 2. Masada kart var (Karşılık veriyor)
    return _chooseHardResponse(
      validCards: validCards,
      tableCards: tableCards,
      trumpSuit: trumpSuit,
      botPlayerIndex: botPlayerIndex,
      partnerIsWinning: partnerIsWinning,
      memory: memory,
      bot: bot,
    );
  }

  /// Hard AI el başlatma taktiği:
  /// - Master kartları (As veya As'ı çıkmış Papaz/Kız) tespit eder.
  /// - Rakiplerin o renkte boşluğu (void) varsa ve kozları bitmemişse, o renge girmekten kaçınır (çakılmayı önler).
  /// - İhaleciyse ve yüksek kozları varsa, yan renkleri sağlama almak için koz çeker.
  static PlayingCard _chooseHardLead({
    required List<PlayingCard> validCards,
    required Suit trumpSuit,
    required int? botPlayerIndex,
    required BotMemory? memory,
  }) {
    final masters = validCards.where((c) => isMasterCard(c, memory)).toList();
    final nonTrumpMasters = masters.where((c) => c.suit != trumpSuit).toList();

    // 1. İhale sahibi bot ise ve yüksek koz master'ları varsa, rakiplerin kozunu eritmek için koz çekebilir
    if (memory != null && botPlayerIndex != null && memory.bidderIndex == botPlayerIndex) {
      final trumpMasters = masters.where((c) => c.suit == trumpSuit).toList();
      if (trumpMasters.isNotEmpty && memory.remainingTrumpCount > trumpMasters.length) {
        return trumpMasters.last; // En yüksek kozla koz çek
      }
    }

    // 2. Koz olmayan master kartlar: Rakiplerin çakma tehlikesi yoksa tahsil et
    if (nonTrumpMasters.isNotEmpty) {
      final safeMasters = nonTrumpMasters.where((m) {
        // Kalan koz yoksa, tüm master'lar %100 güvenlidir!
        if (memory == null || memory.remainingTrumpCount == 0) return true;

        // Herhangi bir rakip bu renkte boş (void) ise, bu master çakılabilir!
        for (int p = 0; p < 4; p++) {
          if (botPlayerIndex != null && TeamEngine.areSameTeam(botPlayerIndex, p)) continue;
          if (memory.voidSuitsForPlayer(p).contains(m.suit)) return false;
        }
        return true;
      }).toList();

      if (safeMasters.isNotEmpty) {
        return safeMasters.last; // Güvenli master'ı çek (Örn: As veya As'ı çıkmış Papaz)
      }

      // Kalan koz sayısı çok azsa (<= 2) yine de master'ı tahsil etmeyi dene
      if (memory != null && memory.remainingTrumpCount <= 2) {
        return nonTrumpMasters.last;
      }
    }

    // 3. Güvenli master yoksa: Master olmayan en küçük kartla eli aç (Güvenli çıkış)
    final nonTrumps = validCards.where((c) => c.suit != trumpSuit).toList();
    if (nonTrumps.isNotEmpty) {
      final nonMasters = nonTrumps.where((c) => !isMasterCard(c, memory)).toList();
      if (nonMasters.isNotEmpty) return nonMasters.first;
      return nonTrumps.first;
    }

    // Sadece koz kaldıysa en küçük kozu at
    return validCards.first;
  }

  /// Hard AI karşılık verme taktiği:
  static PlayingCard _chooseHardResponse({
    required List<PlayingCard> validCards,
    required List<PlayingCard> tableCards,
    required Suit trumpSuit,
    required int? botPlayerIndex,
    required bool partnerIsWinning,
    required BotMemory? memory,
    required Player bot,
  }) {
    final Suit ledSuit = tableCards.first.suit;
    final PlayingCard currentWinner = currentWinningCard(tableCards, trumpSuit)!;

    // 1. Partner kazanıyorsa: ASLA ortağın elini ezme, gelecekte iş yapacak master'ı atma
    if (partnerIsWinning) {
      return _chooseHardDiscard(validCards, trumpSuit, memory);
    }

    // 2. Rakip kazanıyorsa: Eli alabilecek yasal kartları belirle
    final winningOptions = validCards
        .where((c) => canCardBeat(c, currentWinner, ledSuit, trumpSuit))
        .toList();

    if (winningOptions.isNotEmpty) {
      // Aynı renkten kazanabiliyorsak en küçük kazananı at (israf etme)
      final ledWinners = winningOptions.where((c) => c.suit == ledSuit).toList();
      if (ledWinners.isNotEmpty) {
        return ledWinners.first;
      }

      // Çakmak gerekiyorsa: Masadaki kozu yenecek EN KÜÇÜK kozu at (Büyük kozu sakla!)
      final trumpWinners = winningOptions.where((c) => c.suit == trumpSuit).toList();
      if (trumpWinners.isNotEmpty) {
        return trumpWinners.first;
      }

      return winningOptions.first;
    }

    // 3. Eli alamıyorsak: Stratejik defos (discard)
    return _chooseHardDiscard(validCards, trumpSuit, memory);
  }

  /// Hard AI defos (ıskarta) taktiği:
  /// - Master kartları (As veya As'ı çıkmış Papaz) çöpe atmaz, saklar.
  /// - Kozları çöpe atmaz, saklar.
  /// - Öncelikli olarak en zayıf renkten en küçük kartı defos eder.
  static PlayingCard _chooseHardDiscard(
    List<PlayingCard> validCards,
    Suit trumpSuit,
    BotMemory? memory,
  ) {
    final nonTrumps = validCards.where((c) => c.suit != trumpSuit).toList();

    if (nonTrumps.isNotEmpty) {
      // Master olmayan kartlar arasından en küçüğünü feda et
      final nonMasters = nonTrumps.where((c) => !isMasterCard(c, memory)).toList();
      if (nonMasters.isNotEmpty) {
        return nonMasters.first;
      }
      // Tüm non-trumps master ise en küçük non-trump'ı feda et
      return nonTrumps.first;
    }

    // Sadece koz kaldıysa mecburen en küçüğünü at
    return validCards.first;
  }

  // ============================================================
  // YARDIMCI ANALİZ FONKSİYONLARI (PURE & PUBLIC HELPERS)
  // ============================================================

  /// Bir kartın o an kendi renginde çıkmamış en büyük kart (Master) olup olmadığını belirler.
  /// Örneğin As her zaman master'dır. As oynandıysa Papaz master olur; As ve Papaz oynandıysa Kız master olur.
  static bool isMasterCard(PlayingCard card, BotMemory? memory) {
    if (card.rank == Rank.ace) return true;
    if (memory == null) return false;

    // Kendisinden daha büyük tüm kartların çıkıp çıkmadığını kontrol et
    for (int p = card.power + 1; p <= Rank.ace.index; p++) {
      final higherCard = PlayingCard(suit: card.suit, rank: Rank.values[p]);
      if (!memory.hasCardBeenPlayed(higherCard)) {
        return false;
      }
    }
    return true;
  }

  /// Masadaki kartlar arasından o anki kazanan kartı tespit eder.
  static PlayingCard? currentWinningCard(List<PlayingCard> tableCards, Suit trumpSuit) {
    if (tableCards.isEmpty) return null;
    final Suit ledSuit = tableCards.first.suit;
    PlayingCard winner = tableCards[0];
    for (int i = 1; i < tableCards.length; i++) {
      final c = tableCards[i];
      if (c.suit == trumpSuit && winner.suit != trumpSuit) {
        winner = c;
      } else if (c.suit == trumpSuit && winner.suit == trumpSuit && c.power > winner.power) {
        winner = c;
      } else if (c.suit == ledSuit && winner.suit != trumpSuit && c.power > winner.power) {
        winner = c;
      }
    }
    return winner;
  }

  /// [candidate] kartının [currentWinner] kartını yenip yenemeyeceğini hesaplar.
  static bool canCardBeat(
    PlayingCard candidate,
    PlayingCard currentWinner,
    Suit ledSuit,
    Suit trumpSuit,
  ) {
    if (candidate.suit == trumpSuit && currentWinner.suit != trumpSuit) return true;
    if (candidate.suit == trumpSuit && currentWinner.suit == trumpSuit && candidate.power > currentWinner.power) return true;
    if (candidate.suit == ledSuit && currentWinner.suit != trumpSuit && candidate.power > currentWinner.power) return true;
    return false;
  }

  // ============================================================
  // İHALE STRATEJİSİ (BIDDING AI - LIKYA-V2-007C2)
  // ============================================================

  /// Botun eline, mevcut en yüksek teklife, oyun moduna ve zorluk seviyesine
  /// göre yasal bir teklif önerir veya pas geçer (null).
  ///
  /// YALNIZCA botun kendi elindeki kartları (`hand`) inceler; rakiplerin
  /// veya ortağın kapalı kartlarına ASLA erişemez (Anti-Cheat Invariance).
  static int? recommendBid({
    required List<PlayingCard> hand,
    required int currentHighestBid,
    required BatakGameMode gameMode,
    AIDifficulty difficulty = AIDifficulty.normal,
    Random? random,
  }) {
    final rules = GameModeRules.forMode(gameMode);
    if (!rules.hasBidding) {
      return null; // Koz Maça gibi ihalesiz modlarda ihale verilemez
    }

    final int minAllowedBid = max(rules.minBid, currentHighestBid + 1);
    if (minAllowedBid > rules.maxBid) {
      return null; // 13'ün üstüne çıkılamaz
    }

    switch (difficulty) {
      case AIDifficulty.easy:
        return _recommendBidEasy(
          hand: hand,
          minAllowedBid: minAllowedBid,
          maxBid: rules.maxBid,
          gameMode: gameMode,
          random: random,
        );
      case AIDifficulty.normal:
        return _recommendBidNormal(
          hand: hand,
          minAllowedBid: minAllowedBid,
          maxBid: rules.maxBid,
          gameMode: gameMode,
        );
      case AIDifficulty.hard:
        return _recommendBidHard(
          hand: hand,
          minAllowedBid: minAllowedBid,
          maxBid: rules.maxBid,
          gameMode: gameMode,
        );
    }
  }

  /// Kolay İhale: Kaba el kuvveti hesabı, tohumlu rastgelelik, zaman zaman
  /// kuvvetli elleri pas geçme veya 1 eksik hesaplama eğilimi.
  static int? _recommendBidEasy({
    required List<PlayingCard> hand,
    required int minAllowedBid,
    required int maxBid,
    required BatakGameMode gameMode,
    Random? random,
  }) {
    double coarseStrength = 0.0;
    final Map<Suit, int> counts = {for (var s in Suit.values) s: 0};
    for (final c in hand) {
      counts[c.suit] = (counts[c.suit] ?? 0) + 1;
      if (c.rank == Rank.ace) {
        coarseStrength += 1.0;
      } else if (c.rank == Rank.king) {
        coarseStrength += 0.75;
      } else if (c.rank == Rank.queen) {
        coarseStrength += 0.5;
      }
    }
    for (final count in counts.values) {
      if (count >= 5) {
        coarseStrength += 1.0;
      }
    }

    int evaluatedTricks = coarseStrength.floor();
    if (gameMode == BatakGameMode.partner) {
      evaluatedTricks += 3; // Partner ortalama katkısı
    }

    if (random != null) {
      if (random.nextDouble() < 0.25) {
        evaluatedTricks -= 1;
      }
      if (evaluatedTricks >= minAllowedBid && random.nextDouble() < 0.20) {
        return null; // Çekingen davranıp pas geçer
      }
    }

    if (evaluatedTricks >= minAllowedBid && minAllowedBid <= maxBid) {
      return minAllowedBid;
    }
    return null;
  }

  /// Normal İhale: Standart onör-el tablosu ve dağılım hesabı ile dengeli teklif.
  static int? _recommendBidNormal({
    required List<PlayingCard> hand,
    required int minAllowedBid,
    required int maxBid,
    required BatakGameMode gameMode,
  }) {
    final Map<Suit, List<PlayingCard>> suits = {
      for (var s in Suit.values) s: <PlayingCard>[]
    };
    for (final c in hand) {
      suits[c.suit]!.add(c);
    }

    double trickPoints = 0.0;
    for (final entry in suits.entries) {
      final list = entry.value;
      final int len = list.length;
      final bool hasAce = list.any((c) => c.rank == Rank.ace);
      final bool hasKing = list.any((c) => c.rank == Rank.king);
      final bool hasQueen = list.any((c) => c.rank == Rank.queen);

      if (hasAce) {
        trickPoints += 1.0;
      }
      if (hasKing) {
        if (hasAce || len >= 2) {
          trickPoints += 0.85;
        } else {
          trickPoints += 0.3; // Tek kalmış Papaz
        }
      }
      if (hasQueen) {
        if ((hasAce && hasKing) || len >= 3) {
          trickPoints += 0.5;
        }
      }
      if (len >= 5) {
        trickPoints += 0.75;
      }
      if (len >= 6) {
        trickPoints += 0.75;
      }
    }

    int evaluatedTricks = (trickPoints + 0.1).floor();
    if (gameMode == BatakGameMode.partner) {
      evaluatedTricks += 3;
    }

    if (evaluatedTricks >= minAllowedBid && minAllowedBid <= maxBid) {
      return minAllowedBid;
    }
    return null;
  }

  /// Hard İhale: Yalnızca kendi elini kullanarak onör sekansları, uzun renk
  /// hakimiyeti, yan renk kısalıkları ve ruff potansiyelini değerlendirir.
  static int? _recommendBidHard({
    required List<PlayingCard> hand,
    required int minAllowedBid,
    required int maxBid,
    required BatakGameMode gameMode,
  }) {
    final Map<Suit, List<PlayingCard>> suits = {
      for (var s in Suit.values) s: <PlayingCard>[]
    };
    for (final c in hand) {
      suits[c.suit]!.add(c);
    }

    int maxSuitLen = 0;
    for (final list in suits.values) {
      if (list.length > maxSuitLen) maxSuitLen = list.length;
    }

    double trickPoints = 0.0;
    int shortSuitsCount = 0;

    for (final entry in suits.entries) {
      final list = entry.value;
      final int len = list.length;
      final bool hasAce = list.any((c) => c.rank == Rank.ace);
      final bool hasKing = list.any((c) => c.rank == Rank.king);
      final bool hasQueen = list.any((c) => c.rank == Rank.queen);
      final bool hasJack = list.any((c) => c.rank == Rank.jack);

      // Onör kombinasyonları
      if (hasAce && hasKing && hasQueen) {
        trickPoints += 3.2;
      } else if (hasAce && hasKing) {
        trickPoints += 2.1;
      } else if (hasKing && hasQueen && len >= 3) {
        trickPoints += 1.6;
      } else {
        if (hasAce) trickPoints += 1.0;
        if (hasKing && len >= 2) trickPoints += 0.8;
        if (hasQueen && len >= 3) trickPoints += 0.4;
      }
      if (hasJack && (hasAce || hasKing) && len >= 4) {
        trickPoints += 0.25;
      }

      // Uzunluk katkısı
      if (len >= 5) trickPoints += 1.0;
      if (len >= 6) trickPoints += 1.2;

      // Yan renk kısalığı
      if (len == 0) {
        shortSuitsCount += 2; // Boşluk
      } else if (len == 1 && !hasAce && !hasKing) {
        shortSuitsCount += 1; // Tek kart
      }
    }

    // Sağlam koz (>= 5 kart) varsa yan renk kısalıkları ekstra çakma potansiyelidir
    if (maxSuitLen >= 5) {
      trickPoints += shortSuitsCount * 0.8;
    } else if (maxSuitLen <= 4 && shortSuitsCount > 0) {
      trickPoints -= 0.5;
    }

    // Düz dağılım cezası (4-3-3-3)
    final lengths = suits.values.map((l) => l.length).toList()..sort();
    if (lengths.length == 4 && lengths[0] == 3 && lengths[1] == 3 && lengths[2] == 3 && lengths[3] == 4) {
      trickPoints -= 0.8;
    }

    int evaluatedTricks = (trickPoints + 0.1).floor();
    if (gameMode == BatakGameMode.partner) {
      evaluatedTricks += 3;
    }

    if (evaluatedTricks >= minAllowedBid && minAllowedBid <= maxBid) {
      return minAllowedBid;
    }
    return null;
  }

  // ============================================================
  // KOZ SEÇİMİ (TRUMP SELECTION AI - LIKYA-V2-007C2)
  // ============================================================

  /// Bot ihaleyi aldığında elindeki en mantıklı kozu seçer.
  /// Geriye uyumluluk için varsayılan zorluk Normal'dir.
  static Suit chooseTrump(
    Player bot, {
    AIDifficulty difficulty = AIDifficulty.normal,
    Random? random,
    int? winningBid,
  }) {
    return chooseTrumpForHand(
      bot.hand,
      difficulty: difficulty,
      random: random,
      winningBid: winningBid,
    );
  }

  /// Doğrudan kart listesi üzerinden koz seçimi (saf kural ve anti-cheat testleri için).
  static Suit chooseTrumpForHand(
    List<PlayingCard> hand, {
    AIDifficulty difficulty = AIDifficulty.normal,
    Random? random,
    int? winningBid,
  }) {
    if (hand.isEmpty) return Suit.spades;

    switch (difficulty) {
      case AIDifficulty.easy:
        return _chooseTrumpEasy(hand, random);
      case AIDifficulty.normal:
        return _chooseTrumpNormal(hand);
      case AIDifficulty.hard:
        return _chooseTrumpHard(hand, winningBid);
    }
  }

  /// Kolay Koz Seçimi: Basit kart sayısı sayımı, tohumlu rastgelelik ile
  /// en çok olan veya ikinci en çok olan renk arasında tercih yapabilir.
  static Suit _chooseTrumpEasy(List<PlayingCard> hand, Random? random) {
    final Map<Suit, int> counts = {for (var s in Suit.values) s: 0};
    final Map<Suit, int> powers = {for (var s in Suit.values) s: 0};

    for (final c in hand) {
      counts[c.suit] = (counts[c.suit] ?? 0) + 1;
      powers[c.suit] = (powers[c.suit] ?? 0) + c.power;
    }

    final sortedSuits = Suit.values.toList()
      ..sort((a, b) {
        final cCmp = counts[b]!.compareTo(counts[a]!);
        if (cCmp != 0) return cCmp;
        return powers[b]!.compareTo(powers[a]!);
      });

    // En az 1 kart olan renkler arasından seç
    final validSuits = sortedSuits.where((s) => counts[s]! > 0).toList();
    if (validSuits.isEmpty) return Suit.spades;

    if (random != null && validSuits.length >= 2) {
      // 2. en uzun renk de en az 3 karta sahipse ve 1. renge yakınsa %30 ihtimalle onu seç
      if (counts[validSuits[1]]! >= 3 &&
          (counts[validSuits[0]]! - counts[validSuits[1]]!) <= 1) {
        if (random.nextDouble() < 0.30) {
          return validSuits[1];
        }
      }
    }

    return validSuits.first;
  }

  /// Normal Koz Seçimi: Renk uzunluğu, As/Papaz/Kız varlığı ve kart gücü konsantrasyonu.
  static Suit _chooseTrumpNormal(List<PlayingCard> hand) {
    Suit bestSuit = Suit.spades;
    double maxScore = -1.0;

    for (final suit in Suit.values) {
      final suitCards = hand.where((c) => c.suit == suit).toList();
      if (suitCards.isEmpty) continue;

      double score = suitCards.length * 3.0;
      if (suitCards.any((c) => c.rank == Rank.ace)) score += 4.0;
      if (suitCards.any((c) => c.rank == Rank.king) && suitCards.length >= 2) score += 3.0;
      if (suitCards.any((c) => c.rank == Rank.queen) && suitCards.length >= 3) score += 2.0;

      final int totalPower = suitCards.fold<int>(0, (sum, c) => sum + c.power);
      score += totalPower / 10.0;

      if (score > maxScore) {
        maxScore = score;
        bestSuit = suit;
      }
    }

    return bestSuit;
  }

  /// Hard Koz Seçimi: Stratejik uzunluk kontrolü, A-K onör sekansı, yan renk
  /// kısalıkları (çakma gücü) ve ihale büyüklüğü katsayısı.
  static Suit _chooseTrumpHard(List<PlayingCard> hand, int? winningBid) {
    Suit bestSuit = Suit.spades;
    double maxScore = -1.0;

    for (final candidate in Suit.values) {
      final candidateCards = hand.where((c) => c.suit == candidate).toList();
      if (candidateCards.isEmpty) continue;

      final int len = candidateCards.length;
      // Uzunluk gücü: 5 ve üzeri kartlarda kontrol katlanarak artar
      double score = len * 4.0 + (len >= 5 ? (len - 4) * 3.0 : 0.0);

      // Yüksek ihale kontratlarında koz uzunluğu hayati önemdedir
      if (winningBid != null && winningBid >= 8 && len >= 5) {
        score += 4.0;
      }

      final bool hasAce = candidateCards.any((c) => c.rank == Rank.ace);
      final bool hasKing = candidateCards.any((c) => c.rank == Rank.king);
      final bool hasQueen = candidateCards.any((c) => c.rank == Rank.queen);

      if (hasAce && hasKing && hasQueen) {
        score += 8.0;
      } else if (hasAce && hasKing) {
        score += 5.0;
      } else {
        if (hasAce) score += 2.5;
        if (hasKing && len >= 2) score += 1.5;
        if (hasQueen && len >= 3) score += 0.8;
      }

      // Bu renk koz seçilirse yan renklerdeki çakma potansiyeli
      for (final otherSuit in Suit.values) {
        if (otherSuit == candidate) continue;
        final int otherLen = hand.where((c) => c.suit == otherSuit).length;
        if (otherLen == 0) {
          score += 3.0; // Yan renkte boşluk
        } else if (otherLen == 1) {
          score += 1.5; // Yan renkte tek kart
        }
      }

      final int totalPower = candidateCards.fold<int>(0, (sum, c) => sum + c.power);
      score += totalPower / 12.0;

      if (score > maxScore) {
        maxScore = score;
        bestSuit = candidate;
      }
    }

    return bestSuit;
  }

  /// Botun eline bakarak gireceği ihale sayısını tahmin eder (Geriye uyumluluk için).
  static int calculateBid(Player bot) {
    int expectedTricks = 0;

    Map<Suit, List<PlayingCard>> suitsMap = {
      Suit.spades: [], Suit.hearts: [], Suit.diamonds: [], Suit.clubs: [],
    };

    for (var card in bot.hand) {
      suitsMap[card.suit]!.add(card);
    }

    for (var suit in Suit.values) {
      List<PlayingCard> cardsInSuit = suitsMap[suit]!;
      
      bool hasAce = cardsInSuit.any((c) => c.rank == Rank.ace);
      bool hasKing = cardsInSuit.any((c) => c.rank == Rank.king);
      bool hasQueen = cardsInSuit.any((c) => c.rank == Rank.queen);

      if (hasAce) expectedTricks++;

      if (hasKing && (hasAce || cardsInSuit.length >= 2)) {
        expectedTricks++;
      }

      if (hasQueen && ((hasAce && hasKing) || cardsInSuit.length >= 3)) {
        expectedTricks++;
      }

      if (cardsInSuit.length >= 5) {
        expectedTricks++;
      }
    }

    return expectedTricks;
  }
}
