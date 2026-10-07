import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
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

class _BatakGameScreenState extends State<BatakGameScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (mounted) {
        final provider = Provider.of<GameProvider>(context, listen: false);
        provider.autoSaveCurrentGame();
      }
    }
  }

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
                  final validMoves = isMyTurn
                      ? gameProvider.getValidMovesForPlayer(myPlayer).toSet()
                      : const <PlayingCard>{};

                  bool showScoreOverlay = gameProvider.currentPhase == GamePhase.roundFinished ||
                      gameProvider.currentPhase == GamePhase.gameOver;

                  return Stack(
                    children: [
                      // Arka Plan Çuha & Ahşap Kenarlık (Seçilen renge göre)
                      _buildTableFeltBackground(gameProvider.tableColor),

                      // Üst Bar: Bilgi, Yazboz & Ayarlar (Kompakt, taşma yapmayan premium HUD)
                      Positioned(
                        top: 8,
                        left: 10,
                        right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Geri / Çıkış butonu
                            _buildTopBarButton(
                              icon: Icons.arrow_back_ios_new,
                              iconSize: 16,
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Çıkış',
                            ),

                            // Mod ve tur göstergesi
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2C2218), Color(0xFF1A140E)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFC9A04A), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Oyun Modu Etiketi
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: gameProvider.gameMode == BatakGameMode.partner
                                              ? const Color(0xFF1565C0)
                                              : (gameProvider.gameMode == BatakGameMode.kozMaca
                                                  ? const Color(0xFF5E35B1)
                                                  : const Color(0xFF2E7D32)),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          GameModeRules.forMode(gameProvider.gameMode).shortBadge,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        screenSize.width < 360
                                            ? "T:${gameProvider.currentRound}/${gameProvider.totalRounds}"
                                            : "Tur: ${gameProvider.currentRound}/${gameProvider.totalRounds}",
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Sağ butonlar: Yazboz & Ayarlar
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTopBarButton(
                                  icon: Icons.edit_note,
                                  iconSize: 22,
                                  color: const Color(0xFFC9A04A),
                                  onPressed: () => _showScoreboard(context, gameProvider),
                                  tooltip: 'Yazboz',
                                ),
                                const SizedBox(width: 4),
                                _buildTopBarButton(
                                  icon: Icons.settings,
                                  iconSize: 18,
                                  color: const Color(0xFFC9A04A),
                                  onPressed: () => _openSettings(context, gameProvider),
                                  tooltip: 'Ayarlar',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 1. ÜST OYUNCU (Arda / Eş)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 48.0),
                          child: _buildWoodPlayerPanel(
                            player: topPlayer,
                            playerIndex: 2,
                            gameProvider: gameProvider,
                            subtitle: gameProvider.gameMode == BatakGameMode.partner ? "EŞİNİZ (BİZ)" : null,
                          ),
                        ),
                      ),

                      // 2. SOL OYUNCU (Erol / Rakip)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: _buildWoodPlayerPanel(
                            player: leftPlayer,
                            playerIndex: 1,
                            gameProvider: gameProvider,
                            isVertical: true,
                            subtitle: gameProvider.gameMode == BatakGameMode.partner ? "RAKİP" : null,
                          ),
                        ),
                      ),

                      // 3. SAĞ OYUNCU (Uğur / Rakip)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: _buildWoodPlayerPanel(
                            player: rightPlayer,
                            playerIndex: 3,
                            gameProvider: gameProvider,
                            isVertical: true,
                            subtitle: gameProvider.gameMode == BatakGameMode.partner ? "RAKİP" : null,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1710).withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFC9A04A).withOpacity(0.6), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    gameProvider.statusMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFFE082),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            _buildWoodPlayerPanel(
                              player: myPlayer,
                              playerIndex: 0,
                              gameProvider: gameProvider,
                              isMe: true,
                              subtitle: gameProvider.gameMode == BatakGameMode.partner ? "BİZ" : null,
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
                                        return validMoves.contains(card);
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
                                        return validMoves.contains(card);
                                      },
                                      onPlayCard: (card) {
                                        gameProvider.playCard(myPlayer, card);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 10),
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

            // 2. REKLAM ALANI (Masanın dışında, Column en altında 50px - VIP ise gizli)
            Consumer<StoreProvider>(
              builder: (context, store, child) {
                if (store.isVip) {
                  return const SizedBox.shrink();
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zarif ahşap masa kenarlığı (Reklam alanı ile çuha masayı dengeler)
                    Container(
                      height: 3,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF381504),
                            Color(0xFFD4A373),
                            Color(0xFF381504),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 50,
                      width: double.infinity,
                      color: const Color(0xFF0D0D0D),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarButton({
    required IconData icon,
    required VoidCallback onPressed,
    double iconSize = 20,
    Color color = Colors.white,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1610).withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8B7355).withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }

  Widget _buildTableFeltBackground(TableColor color) {
    List<Color> gradientColors;
    switch (color) {
      case TableColor.blue:
        gradientColors = [
          const Color(0xFF1B4268),
          const Color(0xFF0F2B48),
          const Color(0xFF071524),
        ];
        break;
      case TableColor.red:
        gradientColors = [
          const Color(0xFF6E1824),
          const Color(0xFF450E16),
          const Color(0xFF22060A),
        ];
        break;
      case TableColor.dark:
        gradientColors = [
          const Color(0xFF2B2B2B),
          const Color(0xFF1A1A1A),
          const Color(0xFF0D0D0D),
        ];
        break;
      case TableColor.green:
        gradientColors = [
          const Color(0xFF1B5E3A),
          const Color(0xFF14492B),
          const Color(0xFF0B2416),
        ];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.15,
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
            color: const Color(0xFF16251C).withOpacity(0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC9A04A), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Color(0xFFC9A04A), strokeWidth: 2.2),
              ),
              const SizedBox(height: 10),
              Text(
                "${gameProvider.players[gameProvider.biddingTurnIndex].name} Düşünüyor...",
                style: const TextStyle(
                  color: Color(0xFFF6F1E4),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
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

    // Masadaki dev atılmış kartlar (Dinamik boyutlu, temiz ayrılmış yerleşim)
    double centerCardWidth = (screenSize.width * 0.19).clamp(76.0, 108.0);
    double centerCardHeight = centerCardWidth * 1.42;
    double boxWidth = centerCardWidth * 2.3;
    double boxHeight = centerCardHeight * 1.7;

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (gameProvider.playedCardsByPlayer.containsKey(2)) // Üst (Arda)
            Positioned(
              top: 0,
              left: (boxWidth - centerCardWidth) / 2,
              child: _buildCenterTrickCard(
                gameProvider.playedCardsByPlayer[2]!,
                centerCardWidth,
                centerCardHeight,
              ),
            ),
          if (gameProvider.playedCardsByPlayer.containsKey(1)) // Sol (Erol)
            Positioned(
              left: 0,
              top: (boxHeight - centerCardHeight) / 2,
              child: _buildCenterTrickCard(
                gameProvider.playedCardsByPlayer[1]!,
                centerCardWidth,
                centerCardHeight,
              ),
            ),
          if (gameProvider.playedCardsByPlayer.containsKey(3)) // Sağ (Uğur)
            Positioned(
              right: 0,
              top: (boxHeight - centerCardHeight) / 2,
              child: _buildCenterTrickCard(
                gameProvider.playedCardsByPlayer[3]!,
                centerCardWidth,
                centerCardHeight,
              ),
            ),
          if (gameProvider.playedCardsByPlayer.containsKey(0)) // Alt (Siz)
            Positioned(
              bottom: 0,
              left: (boxWidth - centerCardWidth) / 2,
              child: _buildCenterTrickCard(
                gameProvider.playedCardsByPlayer[0]!,
                centerCardWidth,
                centerCardHeight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterTrickCard(PlayingCard card, double width, double height) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 8,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: RealisticPlayingCardWidget(
        card: card,
        width: width,
        height: height,
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

    final isTeamPartner = subtitle != null && subtitle.contains("BİZ");
    final subtitleColor = isTeamPartner ? const Color(0xFF81D4FA) : const Color(0xFFFFAB91);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTurn
              ? const [Color(0xFF382918), Color(0xFF26190C)]
              : const [Color(0xFF221A14), Color(0xFF16100B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTurn ? const Color(0xFFC9A04A) : const Color(0xFF4A3728),
          width: isTurn ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isTurn ? const Color(0xFFC9A04A).withOpacity(0.3) : Colors.black45,
            blurRadius: isTurn ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aktif sıra gösterge noktası
          if (isTurn)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFC9A04A),
                boxShadow: [
                  BoxShadow(color: Color(0xFFFFD54F), blurRadius: 4, spreadRadius: 1),
                ],
              ),
            ),

          // İhaleci Yıldızı & Teklif Rozeti
          if (isBidder)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A04A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFC9A04A), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Color(0xFFD4AF37), size: 10),
                  const SizedBox(width: 2),
                  Text(
                    "${gameProvider.currentHighestBid}",
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

          // Oyuncu İsmi & Alt Başlık (Eş / Rakip)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name.toUpperCase(),
                style: TextStyle(
                  color: isTurn ? Colors.white : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Alınan El Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isTurn ? const Color(0xFFC9A04A).withOpacity(0.5) : Colors.white10,
                width: 0.8,
              ),
            ),
            child: Text(
              "${player.tricksWon}",
              style: TextStyle(
                color: isTurn ? const Color(0xFFFFD54F) : Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

