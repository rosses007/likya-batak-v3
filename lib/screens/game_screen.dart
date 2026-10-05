import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../engine/game_engine.dart';
import '../providers/game_provider.dart';
import '../providers/store_provider.dart';
import '../widgets/realistic_playing_card.dart';
import '../widgets/two_row_hand_view.dart';
import '../widgets/fanned_hand_view.dart';
import '../widgets/game_action_panels.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/scoreboard_dialog.dart';

class BatakGameScreen extends StatefulWidget {
  const BatakGameScreen({super.key});

  @override
  State<BatakGameScreen> createState() => _BatakGameScreenState();
}

class _BatakGameScreenState extends State<BatakGameScreen> {
  void _openSettings(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        currentNames: [
          provider.players[0].name,
          provider.players[1].name,
          provider.players[2].name,
          provider.players[3].name,
        ],
        sortAscending: provider.sortAscending,
        gameSpeed: provider.gameSpeed,
        totalRounds: provider.totalRounds,
        gameMode: provider.gameMode,
        handLayoutMode: provider.handLayoutMode,
        tableColor: provider.tableColor,
        onSave: ({
          required names,
          required sortAscending,
          required speed,
          required rounds,
          required mode,
          required layout,
          required color,
        }) {
          provider.updateSettings(
            names: names,
            sortAsc: sortAscending,
            speed: speed,
            rounds: rounds,
            mode: mode,
            layout: layout,
            color: color,
          );
        },
      ),
    );
  }

  void _showScoreboard(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ScoreboardWidget(provider: provider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 1. MASA ALANI (EXPANDED - Ekranın büyük kısmını kaplar)
            Expanded(
              child: Consumer<GameProvider>(
                builder: (context, gameProvider, child) {
                  if (gameProvider.players.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    );
                  }

                  Player myPlayer = gameProvider.players[0];
                  Player leftPlayer = gameProvider.players[1];
                  Player topPlayer = gameProvider.players[2];
                  Player rightPlayer = gameProvider.players[3];

                  bool isMyTurn = (gameProvider.currentPhase == GamePhase.playing) &&
                      (gameProvider.currentTurnIndex == 0);

                  bool showScoreOverlay = gameProvider.currentPhase == GamePhase.roundFinished ||
                      gameProvider.currentPhase == GamePhase.gameOver;

                  return Stack(
                    children: [
                      // Arka Plan Çuha & Ahşap Kenarlık (Seçilen renge göre)
                      _buildTableFeltBackground(gameProvider.tableColor),

                      // Üst Bar: Bilgi, Yazboz & Ayarlar (Daha belirgin, büyük ve okunaklı)
                      Positioned(
                        top: 8,
                        left: 10,
                        right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Geri / Çıkış butonu
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                            ),

                            // Mod & Tur & Koz Göstergesi
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF5D2E15), Color(0xFF381504)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Oyun Modu Etiketi
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: gameProvider.gameMode == BatakGameMode.partner
                                          ? const Color(0xFF1565C0)
                                          : const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      gameProvider.gameMode == BatakGameMode.partner ? "EŞLİ" : "TEKLİ",
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Tur: ${gameProvider.currentRound}/${gameProvider.totalRounds}",
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("|", style: TextStyle(color: Colors.white38, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Koz: ",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _getSuitSymbol(gameProvider.currentTrump),
                                        style: TextStyle(
                                          color: _getSuitColor(gameProvider.currentTrump),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("|", style: TextStyle(color: Colors.white38, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${gameProvider.tricksPlayed}/13",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Yazboz Butonu
                                IconButton(
                                  icon: const Icon(Icons.edit_note, color: Colors.amber, size: 28),
                                  onPressed: () => _showScoreboard(context, gameProvider),
                                ),
                                // Ayarlar (Dişli Çark) Butonu
                                IconButton(
                                  icon: const Icon(Icons.settings, color: Colors.amber, size: 24),
                                  onPressed: () => _openSettings(context, gameProvider),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 1. ÜST OYUNCU (Arda)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 48.0),
                          child: _buildWoodPlayerPanel(
                            player: topPlayer,
                            playerIndex: 2,
                            gameProvider: gameProvider,
                            subtitle: gameProvider.gameMode == BatakGameMode.partner ? "EŞİNİZ" : null,
                          ),
                        ),
                      ),

                      // 2. SOL OYUNCU (Erol)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: _buildWoodPlayerPanel(
                            player: leftPlayer,
                            playerIndex: 1,
                            gameProvider: gameProvider,
                            isVertical: true,
                          ),
                        ),
                      ),

                      // 3. SAĞ OYUNCU (Uğur)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: _buildWoodPlayerPanel(
                            player: rightPlayer,
                            playerIndex: 3,
                            gameProvider: gameProvider,
                            isVertical: true,
                          ),
                        ),
                      ),

                      // 4. MASANIN ORTASI (İhale, Koz veya Atılan Dev Kartlar)
                      Center(
                        child: _buildCenterArea(context, gameProvider, screenSize),
                      ),

                      // 5. KULLANICI ALANI (Durum Mesajı + Siz Paneli + Dev Kartlar)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (gameProvider.statusMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                                  ),
                                  child: Text(
                                    gameProvider.statusMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            _buildWoodPlayerPanel(
                              player: myPlayer,
                              playerIndex: 0,
                              gameProvider: gameProvider,
                              isMe: true,
                            ),
                            const SizedBox(height: 2),

                            // KART DÜZENİ (Dev ve Gerçekçi Kartlar - Çapraz veya İki Sıra)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: gameProvider.handLayoutMode == HandLayoutMode.fanned
                                  ? FannedHandView(
                                      hand: myPlayer.hand,
                                      isMyTurn: isMyTurn,
                                      sortAscending: gameProvider.sortAscending,
                                      isCardValid: (card) {
                                        if (!isMyTurn) return false;
                                        return GameEngine.isValidPlay(
                                          cardToPlay: card,
                                          player: myPlayer,
                                          tableCards: gameProvider.tableCards,
                                          trumpSuit: gameProvider.currentTrump,
                                        );
                                      },
                                      onPlayCard: (card) {
                                        gameProvider.playCard(myPlayer, card);
                                      },
                                    )
                                  : TwoRowHandView(
                                      hand: myPlayer.hand,
                                      isMyTurn: isMyTurn,
                                      sortAscending: gameProvider.sortAscending,
                                      isCardValid: (card) {
                                        if (!isMyTurn) return false;
                                        return GameEngine.isValidPlay(
                                          cardToPlay: card,
                                          player: myPlayer,
                                          tableCards: gameProvider.tableCards,
                                          trumpSuit: gameProvider.currentTrump,
                                        );
                                      },
                                      onPlayCard: (card) {
                                        gameProvider.playCard(myPlayer, card);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),

                      // EL BİTTİĞİNDE VEYA OYUN BİTTİĞİNDE OTOMATİK YAZBOZ POPUP'I
                      if (showScoreOverlay)
                        Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: ScoreboardWidget(provider: gameProvider),
                        ),
                    ],
                  );
                },
              ),
            ),

            // 2. REKLAM ALANI (Masanın dışında, Column en altında 60px - VIP ise gizli)
            Consumer<StoreProvider>(
              builder: (context, store, child) {
                if (store.isVip) {
                  return const SizedBox.shrink();
                }
                return Container(
                  height: 60,
                  width: double.infinity,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text(
                    "REKLAM ALANI",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableFeltBackground(TableColor color) {
    List<Color> gradientColors;
    switch (color) {
      case TableColor.blue:
        gradientColors = [
          const Color(0xFF1E4C7A),
          const Color(0xFF102E4C),
          const Color(0xFF071524),
        ];
        break;
      case TableColor.red:
        gradientColors = [
          const Color(0xFF7A1E2B),
          const Color(0xFF4C1018),
          const Color(0xFF24070B),
        ];
        break;
      case TableColor.dark:
        gradientColors = [
          const Color(0xFF333333),
          const Color(0xFF1F1F1F),
          const Color(0xFF0A0A0A),
        ];
        break;
      case TableColor.green:
      default:
        gradientColors = [
          const Color(0xFF1E6B2C),
          const Color(0xFF124A1E),
          const Color(0xFF092910),
        ];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: gradientColors,
        ),
      ),
    );
  }

  Widget _buildCenterArea(BuildContext context, GameProvider gameProvider, Size screenSize) {
    if (gameProvider.currentPhase == GamePhase.bidding) {
      if (gameProvider.biddingTurnIndex == 0) {
        return BiddingKeypadWidget(
          currentHighestBid: gameProvider.currentHighestBid,
          onBidSelected: (bid) => gameProvider.userPlaceBid(bid),
          onPass: () => gameProvider.userPassBid(),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2.5),
              ),
              const SizedBox(height: 10),
              Text(
                "${gameProvider.players[gameProvider.biddingTurnIndex].name} Düşünüyor...",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }
    }

    if (gameProvider.currentPhase == GamePhase.trumpSelection) {
      return TrumpSelectorWidget(
        onTrumpSelected: (suit) => gameProvider.userSelectTrump(suit),
      );
    }

    // Masadaki dev atılmış kartlar (Dinamik boyutlu)
    double centerCardWidth = (screenSize.width * 0.18).clamp(78.0, 115.0);
    double centerCardHeight = centerCardWidth * 1.48;

    return SizedBox(
      width: centerCardWidth * 2.6,
      height: centerCardHeight * 1.9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (gameProvider.playedCardsByPlayer.containsKey(2)) // Üst (Arda)
            Positioned(
              top: 0,
              child: RealisticPlayingCardWidget(
                card: gameProvider.playedCardsByPlayer[2]!,
                width: centerCardWidth,
                height: centerCardHeight,
              ),
            ),
          if (gameProvider.playedCardsByPlayer.containsKey(1)) // Sol (Erol)
            Positioned(
              left: 0,
              child: RealisticPlayingCardWidget(
                card: gameProvider.playedCardsByPlayer[1]!,
                width: centerCardWidth,
                height: centerCardHeight,
              ),
            ),
          if (gameProvider.playedCardsByPlayer.containsKey(3)) // Sağ (Uğur)
            Positioned(
              right: 0,
              child: RealisticPlayingCardWidget(
                card: gameProvider.playedCardsByPlayer[3]!,
                width: centerCardWidth,
                height: centerCardHeight,
              ),
            ),
          if (gameProvider.playedCardsByPlayer.containsKey(0)) // Alt (Siz)
            Positioned(
              bottom: 0,
              child: RealisticPlayingCardWidget(
                card: gameProvider.playedCardsByPlayer[0]!,
                width: centerCardWidth,
                height: centerCardHeight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWoodPlayerPanel({
    required Player player,
    required int playerIndex,
    required GameProvider gameProvider,
    bool isVertical = false,
    bool isMe = false,
    String? subtitle,
  }) {
    bool isTurn = false;
    if (gameProvider.currentPhase == GamePhase.bidding) {
      isTurn = gameProvider.biddingTurnIndex == playerIndex;
    } else {
      isTurn = gameProvider.currentTurnIndex == playerIndex;
    }

    bool isBidder = gameProvider.bidderIndex == playerIndex &&
        gameProvider.currentPhase != GamePhase.bidding;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTurn
              ? [const Color(0xFFC47B2B), const Color(0xFF8B4715)]
              : [const Color(0xFF8D4925), const Color(0xFF5D2E15)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTurn ? Colors.amberAccent : const Color(0xFFD4A373),
          width: isTurn ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isTurn ? Colors.amber.withOpacity(0.4) : Colors.black45,
            blurRadius: isTurn ? 8 : 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBidder)
            const Padding(
              padding: EdgeInsets.only(right: 5.0),
              child: Icon(Icons.star, color: Colors.amberAccent, size: 14),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name.toUpperCase(),
                style: TextStyle(
                  color: isTurn ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${player.tricksWon}",
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSuitSymbol(Suit s) {
    switch (s) {
      case Suit.spades: return "Maça ♠";
      case Suit.hearts: return "Kupa ♥";
      case Suit.diamonds: return "Karo ♦";
      case Suit.clubs: return "Sinek ♣";
    }
  }

  Color _getSuitColor(Suit s) {
    if (s == Suit.hearts || s == Suit.diamonds) {
      return const Color(0xFFFF5252);
    }
    return Colors.white;
  }
}
