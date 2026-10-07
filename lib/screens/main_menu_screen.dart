import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../models/card_model.dart';
import '../widgets/card_art/suit_shapes.dart';
import '../widgets/settings_dialog.dart';
import 'game_screen.dart';
import '../providers/store_provider.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final TextEditingController _nameController = TextEditingController();
  SavedGameModel? _savedGame;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
    _checkForSavedGame();
  }

  Future<void> _checkForSavedGame() async {
    final saved = await GameSaveService.loadGame();
    if (mounted) {
      setState(() {
        _savedGame = saved;
      });
    }
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('player_name');
    if (savedName != null && savedName.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _nameController.text = savedName;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _nameController.text = "Oyuncu";
        });
      }
    }
  }

  Future<void> _savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
  }

  int _selectedRounds = 5;

  void _resumeGame() async {
    if (_savedGame == null) return;
    final provider = Provider.of<GameProvider>(context, listen: false);
    provider.restoreFromSavedGame(_savedGame!);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BatakGameScreen()),
    );

    if (mounted) {
      _checkForSavedGame();
    }
  }

  void _onGameModeSelected(BatakGameMode mode) {
    if (_savedGame != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E272C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text(
                "Devam Eden Oyun Var",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "Devam eden oyununuz silinecek. Yeni oyuna başlamak istiyor musunuz?",
            style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("İPTAL", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _startGame(mode: mode);
              },
              child: const Text("YENİ OYUN", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      _startGame(mode: mode);
    }
  }

  void _startGame({BatakGameMode mode = BatakGameMode.single}) async {
    String playerName = _nameController.text.trim();
    if (playerName.isEmpty) playerName = "Oyuncu";
    await _savePlayerName(playerName);

    if (!mounted) return;
    final provider = Provider.of<GameProvider>(context, listen: false);
    provider.gameMode = mode;
    provider.totalRounds = _selectedRounds;
    provider.startNewGame(playerName: playerName);

    // Oyun ekranına geçiş
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BatakGameScreen()),
    );

    if (mounted) {
      _checkForSavedGame();
    }
  }

  // --- LIKYA-V2-012: ANA MENÜ TASARIMI ---
  static const Color _gold = Color(0xFFC9A04A);
  static const Color _ivory = Color(0xFFF6F1E4);
  static const Color _ink = Color(0xFF1E1D1F);

  void _showSoonDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E272C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.hourglass_top, color: _gold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          body,
          style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANLADIM", style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    final provider = Provider.of<GameProvider>(context, listen: false);
    final name = _nameController.text.trim().isEmpty ? "Oyuncu" : _nameController.text.trim();
    final bots = provider.botNames.length >= 3 ? provider.botNames : ["Erol", "Arda", "Uğur"];
    final mode = provider.gameMode == BatakGameMode.gommeli ? BatakGameMode.single : provider.gameMode;
    showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(
        currentNames: [name, bots[0], bots[1], bots[2]],
        sortAscending: provider.sortAscending,
        gameSpeed: provider.gameSpeed,
        totalRounds: _selectedRounds,
        gameMode: mode,
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
          if (names.isNotEmpty && names[0].trim().isNotEmpty && mounted) {
            _savePlayerName(names[0].trim());
            setState(() {
              _nameController.text = names[0].trim();
              if ([1, 3, 5, 7].contains(rounds)) _selectedRounds = rounds;
            });
          }
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _gold.withOpacity(0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: const TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: _gold.withOpacity(0.35))),
        ],
      ),
    );
  }

  Widget _suit(Suit suit, double size, Color color) {
    return CustomPaint(
      size: Size(size, size),
      painter: SuitIconPainter(suit: suit, color: color),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Likya Batak",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                  letterSpacing: 1,
                  height: 1.1,
                  shadows: [Shadow(color: Colors.black54, offset: Offset(1, 2), blurRadius: 3)],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _suit(Suit.spades, 13, _ivory),
                  const SizedBox(width: 10),
                  _suit(Suit.hearts, 13, const Color(0xFFD9534F)),
                  const SizedBox(width: 10),
                  _suit(Suit.diamonds, 13, const Color(0xFFD9534F)),
                  const SizedBox(width: 10),
                  _suit(Suit.clubs, 13, _ivory),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                tooltip: "Ayarlar",
                onPressed: _openSettings,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.settings, color: _gold, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withOpacity(0.45), width: 1),
      ),
      child: TextField(
        controller: _nameController,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        cursorColor: _gold,
        decoration: InputDecoration(
          isDense: true,
          hintText: "Oyuncu Adın",
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.person, color: _gold, size: 20),
          suffixIcon: Icon(Icons.edit, color: Colors.white.withOpacity(0.45), size: 16),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _roundsSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          const Text("Tur Sayısı", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
          for (final r in [1, 3, 5, 7])
            ChoiceChip(
              label: Text("$r El", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _selectedRounds == r ? _ink : Colors.white)),
              selected: _selectedRounds == r,
              selectedColor: _gold,
              backgroundColor: Colors.black.withOpacity(0.25),
              side: BorderSide(color: _gold.withOpacity(0.35)),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                if (selected) setState(() => _selectedRounds = r);
              },
            ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required Key key,
    required Suit suit,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final bool red = suit == Suit.hearts || suit == Suit.diamonds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: key,
        color: _ivory,
        elevation: 3,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: _gold, width: 4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _suit(suit, 28, red ? const Color(0xFFA51C28) : _ink),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _ink.withOpacity(0.62), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF8E6B22), size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _soonCard({required Key key, required String title, required IconData icon, required VoidCallback onTap}) {
    return Material(
      key: key,
      color: Colors.black.withOpacity(0.22),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: Colors.white38),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "YAKINDA",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _ink, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vipButton() {
    return Consumer<StoreProvider>(
      builder: (context, store, child) {
        if (store.isVip) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, color: _gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  "VIP üyelik aktif · Reklamsız",
                  style: TextStyle(color: _gold.withOpacity(0.95), fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Fiyat yalnızca Google Play Billing'den geldiyse gösterilir.
        final String? price = store.products.isNotEmpty ? store.products.first.price : null;

        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _gold,
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: _gold.withOpacity(0.7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: store.isPurchasePending ? null : () {
            if (store.products.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Mağaza şu anda kullanılamıyor. Lütfen daha sonra tekrar dene.")),
              );
              return;
            }
            store.buyVip();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium, size: 22),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price == null ? "VIP Ol" : "VIP Ol · $price",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    "Reklamları Kaldır",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14492B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.25,
            colors: [Color(0xFF217047), Color(0xFF14492B), Color(0xFF0C2F1C)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                child: IntrinsicHeight(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 10),
                    _nameField(),
                    _roundsSelector(),

                    // DEVAM ET (kayıtlı oyun varsa)
                    if (_savedGame != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _ink,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 4,
                        ),
                        onPressed: _resumeGame,
                        icon: const Icon(Icons.play_circle_fill, size: 24),
                        label: Text(
                          "DEVAM ET (${GameModeRules.forMode(_savedGame!.gameMode).shortBadge} - ${_savedGame!.currentRound}. Tur)",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],

                    _sectionLabel("OYNA"),
                    _modeCard(
                      key: const ValueKey('mode_ihaleli'),
                      suit: Suit.diamonds,
                      title: "İhaleli Batak",
                      subtitle: "Tekli · açık ihale",
                      onTap: () => _onGameModeSelected(BatakGameMode.single),
                    ),
                    _modeCard(
                      key: const ValueKey('mode_esli'),
                      suit: Suit.hearts,
                      title: "Eşli Batak",
                      subtitle: "Ortaklı · 2'ye 2",
                      onTap: () => _onGameModeSelected(BatakGameMode.partner),
                    ),
                    _modeCard(
                      key: const ValueKey('mode_koz_maca'),
                      suit: Suit.spades,
                      title: "Koz Maça",
                      subtitle: "İhalesiz · koz her zaman maça",
                      onTap: () => _onGameModeSelected(BatakGameMode.kozMaca),
                    ),

                    _sectionLabel("YAKINDA"),
                    Row(
                      children: [
                        Expanded(
                          child: _soonCard(
                            key: const ValueKey('mode_gommeli'),
                            title: "Gömmeli Batak",
                            icon: Icons.lock_clock,
                            onTap: () => _showSoonDialog(
                              "Gömmeli Batak (Yakında)",
                              "Gömmeli Batak, sonraki güncellemelerde eklenecek.\n\nŞu anda İhaleli Batak, Eşli Batak ve Koz Maça modlarını oynayabilirsiniz.",
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _soonCard(
                            key: const ValueKey('mode_online'),
                            title: "Çevrimiçi Batak",
                            icon: Icons.cloud_queue,
                            onTap: () => _showSoonDialog(
                              "Çevrimiçi Batak (Yakında)",
                              "Çevrimiçi mod hazırlanıyor ve sonraki güncellemelerde eklenecek.\n\nŞu anda İhaleli Batak, Eşli Batak ve Koz Maça modlarını oynayabilirsiniz.",
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _vipButton(),
                    Consumer<StoreProvider>(builder: (context, store, _) => Column(
                      children: [
                        TextButton.icon(
                          onPressed: store.isRestoring ? null : () => store.restorePurchases(),
                          icon: store.isRestoring
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.restore),
                          label: const Text('Satın Alımları Geri Yükle'),
                        ),
                        if (store.isPurchasePending) const Text('Satın alma beklemede', style: TextStyle(color: Colors.white70)),
                        if (store.feedback != null)
                          Text(store.feedback!, style: const TextStyle(color: Colors.white70)),
                      ],
                    )),
                    const Spacer(),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/images/likya_logo.png',
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Likya Studios • E & A",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
