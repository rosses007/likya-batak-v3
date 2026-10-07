import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_game_provider.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../services/ad_service.dart';
import '../screens/main_menu_screen.dart';
import '../providers/store_provider.dart';
import '../widgets/consent_banner.dart';

class MultiplayerGameScreen extends StatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  StoreProvider? _store;
  
  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_tryLoadInterstitial);
    // Load interstitial ad when the user sits at the table

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _store = context.read<StoreProvider>();
      _store!.addListener(_tryLoadInterstitial);
      _tryLoadInterstitial();
      final provider = Provider.of<MultiplayerGameProvider>(context, listen: false);
      provider.onGameFinished = () {
        if (mounted) {
          _showGameOverDialog();
        }
      };
    });
  }

  void _tryLoadInterstitial() {
    if (!mounted) return;
    final store = context.read<StoreProvider>();
    AdService.instance.loadInterstitialAd(isVip: !store.vipStatusLoaded || store.isVip);
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_tryLoadInterstitial);
    _store?.removeListener(_tryLoadInterstitial);
    super.dispose();
  }

  void _returnToMainMenu() {
    Navigator.of(context).pop(); // Diyaloğu kapat
    
    // VIP durumunu kontrol et
    bool isUserVip = Provider.of<StoreProvider>(context, listen: false).isVip;

    if (isUserVip) {
      // VIP ise reklam göstermeden direkt menüye dön
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        (Route<dynamic> route) => false,
      );
    } else {
      // VIP değilse reklam göster
      AdService.instance.showInterstitialAd(
        isVip: false,
        onAdDismissed: () {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainMenuScreen()),
            (Route<dynamic> route) => false,
          );
        },
      );
    }
  }

  void _showGameOverDialog() {
    final provider = Provider.of<MultiplayerGameProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Oyun Bitti!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Skor Tablosu", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 12),
              ...List.generate(provider.players.length, (index) {
                final player = provider.players[index];
                final tricks = provider.finalTricks.isNotEmpty && index < provider.finalTricks.length
                    ? provider.finalTricks[index]
                    : player.tricksWon;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(player.name, style: const TextStyle(color: Colors.white)),
                      Text("$tricks El", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _returnToMainMenu,
              child: const Text("Ana Menüye Dön", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black, // Ekranın en alt katmanı
      body: SafeArea(
        child: Column(
          children: [
            // 1. MASA ALANI (EXPANDED - Ekranın büyük kısmını kaplar)
            Expanded(
              child: Consumer<MultiplayerGameProvider>(
                builder: (context, provider, child) {
                  if (provider.players.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }

                  int myIndex = provider.myPosition;
                  bool isMyTurn = provider.currentTurnIndex == myIndex;
                  
                  Player me = provider.players[myIndex];
                  Player leftPlayer = provider.players[(myIndex + 1) % 4];
                  Player topPlayer = provider.players[(myIndex + 2) % 4];
                  Player rightPlayer = provider.players[(myIndex + 3) % 4];

                  double targetDiameter = screenSize.width * 0.45;

                  return Container(
                    // CASINO MASASI ARKA PLANI (Spot ışığı ve deri kenarlık efekti)
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF3E2723), width: 12), // Koyu maun ahşap kenarlık
                      borderRadius: BorderRadius.circular(30),
                      gradient: const RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Color(0xFF2E7D32), // Ortaya vuran parlak spot ışığı (Parlak yeşil çuha)
                          Color(0xFF1B5E20), // Orta-kenar geçişi
                          Color(0xFF002200), // Kenarlardaki karanlık (Vignette) efekti
                        ],
                        stops: [0.2, 0.6, 1.0],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // SOL OYUNCU
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: _buildPlayerAvatar(player: leftPlayer, isTurn: provider.currentTurnIndex == (myIndex + 1) % 4),
                          ),
                        ),

                        // ÜST OYUNCU
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: _buildPlayerAvatar(player: topPlayer, isTurn: provider.currentTurnIndex == (myIndex + 2) % 4),
                          ),
                        ),

                        // SAĞ OYUNCU
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildPlayerAvatar(player: rightPlayer, isTurn: provider.currentTurnIndex == (myIndex + 3) % 4),
                          ),
                        ),

                        // MASANIN ORTASI: DRAG TARGET (Küçültülmüş boyut: size.width * 0.45)
                        Align(
                          alignment: Alignment.center,
                          child: DragTarget<PlayingCard>(
                            onWillAcceptWithDetails: (details) { return true; },
                            onAcceptWithDetails: (details) { provider.sendCardPlayAction(details.data); },
                            builder: (context, candidateData, rejectedData) {
                              bool isHovering = candidateData.isNotEmpty;
                              return Container(
                                width: targetDiameter,
                                height: targetDiameter,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isHovering ? Colors.amberAccent : Colors.amber.withOpacity(0.2),
                                    width: isHovering ? 3 : 1,
                                  ),
                                  color: isHovering ? Colors.white.withOpacity(0.05) : Colors.transparent,
                                  boxShadow: isHovering ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 20)] : [],
                                ),
                                child: Center(
                                  child: provider.collectingWinnerIndex != null
                                      ? const SizedBox()
                                      : Text(
                                          isMyTurn ? "SIRA SİZDE" : "BEKLENİYOR...",
                                          style: TextStyle(
                                            color: isMyTurn ? Colors.amber.withOpacity(0.8) : Colors.white24,
                                            fontSize: 14,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),

                        // UÇAN KARTLAR (ANIMATED ALIGN)
                        ...provider.tableCards.asMap().entries.map((entry) {
                          int cardIndex = entry.key;
                          PlayingCard card = entry.value;

                          Alignment targetAlignment = Alignment.center;
                          if (provider.collectingWinnerIndex != null) {
                            int winner = provider.collectingWinnerIndex!;
                            if (winner == myIndex) {
                              targetAlignment = Alignment.bottomCenter;
                            } else if (winner == (myIndex + 1) % 4) {
                              targetAlignment = Alignment.centerLeft;
                            } else if (winner == (myIndex + 2) % 4) {
                              targetAlignment = Alignment.topCenter;
                            } else if (winner == (myIndex + 3) % 4) {
                              targetAlignment = Alignment.centerRight;
                            }
                          }

                          return AnimatedAlign(
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeInBack,
                            alignment: targetAlignment,
                            child: Padding(
                              padding: provider.collectingWinnerIndex == null
                                  ? EdgeInsets.only(left: cardIndex * 25.0, top: cardIndex * 15.0)
                                  : EdgeInsets.zero,
                              child: AnimatedScale(
                                scale: provider.collectingWinnerIndex == null ? 1.0 : 0.3,
                                duration: const Duration(milliseconds: 550),
                                child: _buildCardUI(card, scale: 0.85, isOnTable: true),
                              ),
                            ),
                          );
                        }),

                        // KULLANICI ELİ VE PROFİLİ
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPlayerAvatar(player: me, isTurn: isMyTurn, isMe: true),
                              const SizedBox(height: 12),
                              // Eldeki kartlar alanı (Dev kartlara uyumlu)
                              Container(
                                height: (screenSize.width * 0.18 * 1.48 + 25).clamp(130.0, 185.0),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: me.hand.map((card) {
                                      return Draggable<PlayingCard>(
                                        data: card,
                                        maxSimultaneousDrags: isMyTurn ? 1 : 0,
                                        feedback: Material(color: Colors.transparent, child: _buildCardUI(card, isDragging: true)),
                                        childWhenDragging: Opacity(opacity: 0.2, child: _buildCardUI(card)),
                                        child: _buildCardUI(card),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 2. REKLAM ALANI (Column en altında, masanın dışında 60px - VIP ise tamamen gizlenir)
            Consumer<StoreProvider>(
              builder: (context, store, child) {
                if (store.isVip) {
                  return const SizedBox.shrink();
                }
                return const ConsentBanner();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// PREMIUM OYUNCU AVATARI (Altın Çerçeveli, Parlayan ve VIP Taçlı)
  Widget _buildPlayerAvatar({required Player player, required bool isTurn, bool isMe = false, bool isVip = false}) {
    bool playerIsVip = isMe ? Provider.of<StoreProvider>(context).isVip : isVip;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isTurn 
                      ? [Colors.yellowAccent, Colors.orange.shade700] 
                      : [Colors.grey.shade700, Colors.black87],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: isTurn 
                    ? [BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 15, spreadRadius: 3)] 
                    : [const BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(2, 2))],
              ),
              child: CircleAvatar(
                radius: isMe ? 26 : 22,
                backgroundColor: const Color(0xFF1E1E1E),
                child: Icon(isMe ? Icons.person : Icons.smart_toy, color: isTurn ? Colors.white : Colors.white70, size: isMe ? 28 : 24),
              ),
            ),
            
            if (playerIsVip)
              const Positioned(
                top: -12,
                child: Icon(
                  Icons.workspace_premium,
                  color: Colors.cyanAccent,
                  size: 24,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          player.name,
          style: TextStyle(
            color: isTurn ? Colors.amber : Colors.white, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            shadows: const [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))]
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            border: Border.all(color: Colors.white24, width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${player.tricksWon} El | ${player.hand.length} Kart",
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        )
      ],
    );
  }

  /// DEV VE GERÇEKÇİ KART TASARIMI (Büyük Boyutlar, Kâğıt Dokusu Gradyanı, Okunaklı Sayı/Semboller)
  Widget _buildCardUI(PlayingCard card, {bool isDragging = false, double scale = 1.0, bool isOnTable = false}) {
    Size screenSize = MediaQuery.of(context).size;
    // Dinamik dev kart boyutları (ekran genişliğinin en az %18'i kadar)
    double baseWidth = (screenSize.width * 0.18).clamp(78.0, 115.0);
    double cardWidth = baseWidth * scale;
    double cardHeight = cardWidth * 1.38;

    return Transform.rotate(
      angle: isOnTable ? (card.suit.index * 0.1) - 0.15 : (isDragging ? 0.1 : 0),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: EdgeInsets.only(right: isOnTable ? 0 : 8), // Kartlar arası ferah boşluk
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCFCFCF), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDragging ? 0.65 : 0.4),
              blurRadius: isDragging ? 18 : 8,
              spreadRadius: isDragging ? 3 : 1,
              offset: isDragging ? const Offset(6, 12) : const Offset(3, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.2),
          child: Image.asset(
            'assets/cards/${card.suit.name}_${card.rank.name}.png',
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}
