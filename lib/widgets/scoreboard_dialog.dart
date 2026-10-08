import 'package:flutter/material.dart';
import '../providers/game_provider.dart';

/// LIKYA-V2-013 | Zarif Yazboz ve Tur/Maç Sonu Tablosu
class ScoreboardWidget extends StatelessWidget {
  final GameProvider provider;

  const ScoreboardWidget({super.key, required this.provider});

  static const Color _gold = Color(0xFFC9A04A);
  static const Color _ink = Color(0xFF1E1D1F);

  @override
  Widget build(BuildContext context) {
    final bool isMatchOver = provider.currentPhase == GamePhase.gameOver;
    final bool isPartnerMode = provider.gameMode == BatakGameMode.partner;

    String? winnerName;
    if (isMatchOver && provider.players.isNotEmpty) {
      int bestIdx = 0;
      int bestScore = provider.cumulativeScores[0];
      for (int i = 1; i < provider.cumulativeScores.length; i++) {
        if (provider.cumulativeScores[i] > bestScore) {
          bestScore = provider.cumulativeScores[i];
          bestIdx = i;
        }
      }
      if (isPartnerMode) {
        winnerName = (bestIdx == 0 || bestIdx == 2)
            ? "BİZ (${provider.players[0].name} & ${provider.players[2].name})"
            : "RAKİPLER (${provider.players[1].name} & ${provider.players[3].name})";
      } else {
        winnerName = provider.players[bestIdx].name;
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF142E1F).withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.75),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMatchOver ? Icons.emoji_events : Icons.article,
                color: _gold,
                size: 22,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isMatchOver
                        ? "MAÇ SONUCU"
                        : "YAZBOZ · Tur ${provider.currentRound}/${provider.totalRounds}",
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isMatchOver && winnerName != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _gold.withOpacity(0.5)),
              ),
              child: Text(
                "🏆 Şampiyon: $winnerName",
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Puan Tablosu Başlığı (Oyuncu İsimleri ve Takım Bilgisi)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 50,
                  child: Text(
                    "Tur",
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                for (int i = 0; i < provider.players.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.players[i].name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == 0 ? const Color(0xFF64B5F6) : Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isPartnerMode)
                          Text(
                            (i == 0 || i == 2) ? "Biz" : "Rakip",
                            style: TextStyle(
                              color: (i == 0 || i == 2) ? const Color(0xFF81C784) : Colors.white38,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Turların Puan Listesi
          if (provider.roundScoresHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "Henüz tamamlanan el yok.",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.roundScoresHistory.length,
                itemBuilder: (context, rIdx) {
                  final scores = provider.roundScoresHistory[rIdx];
                  final bool isEvenRow = rIdx.isEven;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isEvenRow ? Colors.white.withOpacity(0.03) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            "${rIdx + 1}. El",
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ),
                        for (int pIdx = 0; pIdx < provider.players.length; pIdx++)
                          Expanded(
                            child: Text(
                              pIdx < scores.length ? "${scores[pIdx]}" : "-",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: (pIdx < scores.length && scores[pIdx] < 0)
                                    ? const Color(0xFFEF5350)
                                    : Colors.white,
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

          const SizedBox(height: 6),
          Container(height: 1, color: _gold.withOpacity(0.4)),
          const SizedBox(height: 6),

          // TOPLAM PUAN SATIRI
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 50,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "TOPLAM",
                      style: TextStyle(color: _gold, fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                for (int pIdx = 0; pIdx < provider.players.length; pIdx++)
                  Expanded(
                    child: Text(
                      "${provider.cumulativeScores[pIdx]}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: provider.cumulativeScores[pIdx] < 0 ? const Color(0xFFEF5350) : _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Alt Buton / Geri Sayım
          if (!isMatchOver)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "${provider.roundCountdown}s sonra yeni el...",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 3,
                  ),
                  onPressed: () => provider.startNextRoundImmediately(),
                  child: const Text(
                    "Sonraki El",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 4,
              ),
              onPressed: () => provider.startNewGame(),
              child: const Text(
                "YENİ MAÇ BAŞLAT",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}
