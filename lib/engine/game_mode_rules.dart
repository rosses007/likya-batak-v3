import '../models/card_model.dart';

enum BatakGameMode {
  single,   // Tekli İhaleli Batak (4 oyuncu, açık ihale, seçilebilir koz)
  partner,  // Eşli Batak (4 oyuncu, Takım A: 0+2 vs Takım B: 1+3, min 8 ihale)
  kozMaca,  // Koz Maça / İhalesiz Batak (4 oyuncu, ihalesiz, sabit Maça kozu)
  gommeli,  // Gömmeli Batak (GOMMELI_RULES_UNRESOLVED - Menüde YAKINDA)
}

/// Oyun modu kural konfigürasyonu ve davranış deklarasyonu.
///
/// Modlar arası devasa if/else bloklarını önler, kural motoruna tek
/// merkezden konfigürasyon sağlar.
class GameModeRules {
  final BatakGameMode mode;
  final String title;
  final String shortBadge;
  final int playerCount;
  final bool hasBidding;
  final int minBid;
  final int maxBid;
  final bool isFixedTrump;
  final Suit? fixedTrumpSuit;
  final bool isTeamMode;
  final bool isProductionReady;

  const GameModeRules({
    required this.mode,
    required this.title,
    required this.shortBadge,
    this.playerCount = 4,
    this.hasBidding = true,
    this.minBid = 5,
    this.maxBid = 13,
    this.isFixedTrump = false,
    this.fixedTrumpSuit,
    this.isTeamMode = false,
    this.isProductionReady = true,
  });

  static const GameModeRules single = GameModeRules(
    mode: BatakGameMode.single,
    title: "Tekli İhaleli Batak",
    shortBadge: "TEKLİ",
    playerCount: 4,
    hasBidding: true,
    minBid: 5,
    maxBid: 13,
    isFixedTrump: false,
    isTeamMode: false,
    isProductionReady: true,
  );

  static const GameModeRules partner = GameModeRules(
    mode: BatakGameMode.partner,
    title: "Eşli Batak",
    shortBadge: "EŞLİ",
    playerCount: 4,
    hasBidding: true,
    minBid: 8,
    maxBid: 13,
    isFixedTrump: false,
    isTeamMode: true,
    isProductionReady: true,
  );

  static const GameModeRules kozMaca = GameModeRules(
    mode: BatakGameMode.kozMaca,
    title: "Koz Maça (İhalesiz)",
    shortBadge: "KOZ MAÇA",
    playerCount: 4,
    hasBidding: false,
    minBid: 0,
    maxBid: 0,
    isFixedTrump: true,
    fixedTrumpSuit: Suit.spades,
    isTeamMode: false,
    isProductionReady: true,
  );

  static const GameModeRules gommeli = GameModeRules(
    mode: BatakGameMode.gommeli,
    title: "Gömmeli Batak",
    shortBadge: "GÖMMELİ",
    playerCount: 3,
    hasBidding: true,
    minBid: 0,
    maxBid: 13,
    isFixedTrump: false,
    isTeamMode: false,
    isProductionReady: false, // GOMMELI_RULES_UNRESOLVED - YAKINDA
  );

  static GameModeRules forMode(BatakGameMode mode) {
    switch (mode) {
      case BatakGameMode.single:
        return single;
      case BatakGameMode.partner:
        return partner;
      case BatakGameMode.kozMaca:
        return kozMaca;
      case BatakGameMode.gommeli:
        return gommeli;
    }
  }
}
