import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../screens/multiplayer_game_screen.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_game_provider.dart';

class MatchmakingScreen extends StatefulWidget {
  final String playerName;

  const MatchmakingScreen({super.key, required this.playerName});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final WebSocketService _wsService = WebSocketService();
  String _statusMessage = "Sunucuya bağlanılıyor...";

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  void _startMatchmaking() {
    // 1. WebSocket'e bağlan. Şimdilik isim + timestamp ile ID üret
    String myClientId = "${widget.playerName}_${DateTime.now().millisecondsSinceEpoch}";
    _wsService.connect(myClientId);

    setState(() {
      _statusMessage = "Rakipler aranıyor (1/4)...";
    });

    // 2. Sunucudan gelen mesajları dinle
    _wsService.onMessageReceived = (data) {
      String type = data["type"];

      if (type == "match_found") {
        setState(() {
          _statusMessage = "Maç bulundu! Masaya bağlanılıyor...";
        });

        String matchId = data["match_id"];
        int myPosition = data["position"];
        debugPrint("Maç ID: $matchId, Koltuk Numaram: $myPosition");

        // TODO: 1 saniye sonra çok oyunculu oyun ekranına yönlendir
        // Future.delayed(const Duration(seconds: 1), () {
        //   Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => MultiplayerGameScreen(matchId: matchId, myPosition: myPosition),
        //     ),
        //   );
        // });
      }
if (type == "game_start") {
  Provider.of<MultiplayerGameProvider>(context, listen: false).initializeGame(data);
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const MultiplayerGameScreen()),
  );
}
    };
  }

  @override
  void dispose() {
    // Kullanıcı ekranı kapatırsa ya da geri giderse lobiden çık
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 24),
            const Text(
              "LOBİ",
              style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: () {
                Navigator.pop(context); // İptal edip ana menüye dön
              },
              child: const Text("İptal Et"),
            ),
          ],
        ),
      ),
    );
  }
}
