import 'package:flutter/material.dart';
import '../providers/game_provider.dart';

class ScoreboardWidget extends StatelessWidget {
  final GameProvider provider;

  const ScoreboardWidget({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    bool isMatchOver = provider.currentPhase == GamePhase.gameOver;

    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4020).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isMatchOver ? Icons.emoji_events : Icons.edit_note, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                isMatchOver ? "MAÇ SONUCU - ŞAMPİYON" : "YAZBOZ (Tur ${provider.currentRound} / ${provider.totalRounds})",
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Puan Tablosu Başlığı
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B3212),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44, child: Text("Tur", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                for (int i = 0; i < 4; i++)
                  Expanded(
                    child: Text(
                      provider.players[i].name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: i == 0 ? Colors.cyanAccent : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Turların Puan Listesi
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: provider.roundScoresHistory.length,
              itemBuilder: (context, rIdx) {
                final scores = provider.roundScoresHistory[rIdx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          "${rIdx + 1}. El",
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ),
                      for (int pIdx = 0; pIdx < 4; pIdx++)
                        Expanded(
                          child: Text(
                            "${scores[pIdx]}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scores[pIdx] >= 0 ? Colors.white : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.amber, thickness: 1.2),

          // TOPLAM PUAN SATIRI
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 44,
                  child: Text(
                    "TOPLAM",
                    style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                for (int pIdx = 0; pIdx < 4; pIdx++)
                  Expanded(
                    child: Text(
                      "${provider.cumulativeScores[pIdx]}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Alt Buton veya Geri Sayım
          if (!isMatchOver)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${provider.roundCountdown} saniye sonra yeni el başlıyor...",
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B3212),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => provider.startNextRoundImmediately(),
                  child: const Text("Hemen Başlat", style: TextStyle(fontSize: 11)),
                ),
              ],
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => provider.startNewGame(),
              child: const Text("YENİ MAÇ BAŞLAT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
    );
  }
}
