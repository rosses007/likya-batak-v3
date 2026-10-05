import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../services/api_service.dart';
import '../models/leaderboard_user.dart';
import 'game_screen.dart';
import '../providers/store_provider.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final TextEditingController _nameController = TextEditingController();
  late Future<List<LeaderboardUser>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
    _leaderboardFuture = ApiService.getLeaderboard();
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BatakGameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                "LİKYA BATAK",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Player name input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Oyuncu Adın",
                    prefixIcon: Icon(Icons.person, color: Colors.green),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Oyun Tur Sayısı Seçimi (1'den 7'ye kadar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Tur Sayısı: ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  for (int r in [1, 3, 5, 7])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: ChoiceChip(
                        label: Text("$r El", style: TextStyle(fontSize: 12, color: _selectedRounds == r ? Colors.black : Colors.white)),
                        selected: _selectedRounds == r,
                        selectedColor: Colors.amber,
                        backgroundColor: const Color(0xFF2E7D32),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRounds = r);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. TEKLİ İHALELİ BATAK
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: () => _startGame(mode: BatakGameMode.single),
                icon: const Icon(Icons.person_pin, size: 20),
                label: const Text(
                  "İHALELİ BATAK (TEKLİ)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              // 2. EŞLİ BATAK (ORTAKLI)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: () => _startGame(mode: BatakGameMode.partner),
                icon: const Icon(Icons.handshake, size: 20),
                label: const Text(
                  "EŞLİ BATAK (ORTAKLI)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              // 3. ÇEVRİMİÇİ OYNA (KAPALI BETA: YAKINDA)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF263238),
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.amber, width: 1),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E272C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.amber, size: 28),
                          SizedBox(width: 10),
                          Text(
                            "Online Batak (Yakında)",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      content: const Text(
                        "Çok oyunculu online altyapımız, hilesiz ve merkezi yetkili sunucu mimarisiyle hazırlanmaktadır.\n\nBatak 1.0 Kapalı Beta offline sürümümüzün ardından çok yakında gerçek rakiplerle kesintisiz online maç deneyimi sizlerle olacak!",
                        style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("ANLADIM", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_queue, size: 20, color: Colors.amber),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "ÇEVRİMİÇİ BATAK",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "YAKINDA",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Consumer<StoreProvider>(
                builder: (context, store, child) {
                  if (store.isVip) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "💎 VIP ÜYE AKTİF (REKLAMSIZ)",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    );
                  }

                  String priceText = store.products.isNotEmpty ? store.products.first.price : "100 TL";

                  return TextButton.icon(
                    onPressed: () => store.buyVip(),
                    icon: const Icon(Icons.workspace_premium, color: Colors.cyanAccent),
                    label: Text(
                      "VIP OL REKLAMLARI KALDIR ($priceText)",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "🏆 EN İYİLER (TOP 10)",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.white54, thickness: 1),
              // Leaderboard list
              Expanded(
                child: FutureBuilder<List<LeaderboardUser>>(
                  future: _leaderboardFuture,
                  builder: (context, snapshot) {
                    List<LeaderboardUser> users = [];
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      users = snapshot.data!;
                    } else {
                      // Sunucuya erişilemediğinde gösterilecek şampiyonlar tablosu
                      users = [
                        LeaderboardUser(username: "Caner Demir", totalWins: 84, totalGames: 102, eloRating: 2850),
                        LeaderboardUser(username: "Selin Yılmaz", totalWins: 79, totalGames: 98, eloRating: 2720),
                        LeaderboardUser(username: "Arda Kara", totalWins: 71, totalGames: 90, eloRating: 2590),
                        LeaderboardUser(username: "Erol Keskin", totalWins: 65, totalGames: 88, eloRating: 2430),
                        LeaderboardUser(username: "Uğur Şahin", totalWins: 61, totalGames: 82, eloRating: 2310),
                        LeaderboardUser(username: "Burak Tunç", totalWins: 55, totalGames: 76, eloRating: 2180),
                        LeaderboardUser(username: "Merve Aydın", totalWins: 49, totalGames: 70, eloRating: 2050),
                        LeaderboardUser(username: "Onur Sönmez", totalWins: 42, totalGames: 64, eloRating: 1920),
                      ];
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index == 0
                                  ? Colors.amber
                                  : (index == 1 ? Colors.grey.shade300 : (index == 2 ? Colors.orange.shade300 : Colors.black45)),
                              child: Text(
                                "${index + 1}",
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(user.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text("${user.totalWins} Galibiyet - ${user.totalGames} Maç", style: const TextStyle(color: Colors.white70)),
                            trailing: Text("${user.eloRating} Puan", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
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
                    "LİKYA STUDIOS — E ✦ A",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
