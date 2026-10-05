import 'package:flutter/material.dart';
import '../models/card_model.dart';

/// 3x3 Ahşap İhale Seçim Paneli (5'ten 13'e ve Pas butonu)
class BiddingKeypadWidget extends StatelessWidget {
  final int currentHighestBid;
  final Function(int bid) onBidSelected;
  final VoidCallback onPass;

  const BiddingKeypadWidget({
    super.key,
    required this.currentHighestBid,
    required this.onBidSelected,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "İHALE SEÇİMİ",
            style: TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // 3x3 Grid
          SizedBox(
            width: 220,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: List.generate(9, (index) {
                int bidValue = 5 + index; // 5'ten 13'e
                bool isEnabled = bidValue > currentHighestBid;

                return _buildWoodButton(
                  text: "$bidValue",
                  isEnabled: isEnabled,
                  onTap: () => onBidSelected(bidValue),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Pas Butonu
          SizedBox(
            width: 220,
            height: 42,
            child: _buildWoodButton(
              text: "Pas",
              isEnabled: true,
              onTap: onPass,
              isWide: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoodButton({
    required String text,
    required bool isEnabled,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: isEnabled
                  ? [const Color(0xFF9E5429), const Color(0xFF632E11)]
                  : [const Color(0xFF555555), const Color(0xFF333333)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: isEnabled ? const Color(0xFFD4A373) : Colors.black45,
              width: 1.2,
            ),
            boxShadow: isEnabled
                ? [
                    const BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(1, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isEnabled ? Colors.white : Colors.white38,
                fontSize: isWide ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 4'lü Ahşap Koz Seçim Paneli (♠, ♥, ♣, ♦)
class TrumpSelectorWidget extends StatelessWidget {
  final Function(Suit selectedTrump) onTrumpSelected;

  const TrumpSelectorWidget({
    super.key,
    required this.onTrumpSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.7), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "KOZ SEÇİNİZ",
            style: TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTrumpButton(suit: Suit.spades, symbol: "♠", color: Colors.black),
              const SizedBox(width: 10),
              _buildTrumpButton(suit: Suit.hearts, symbol: "♥", color: const Color(0xFFD32F2F)),
              const SizedBox(width: 10),
              _buildTrumpButton(suit: Suit.clubs, symbol: "♣", color: Colors.black),
              const SizedBox(width: 10),
              _buildTrumpButton(suit: Suit.diamonds, symbol: "♦", color: const Color(0xFFD32F2F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrumpButton({
    required Suit suit,
    required String symbol,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTrumpSelected(suit),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8A838), Color(0xFFB56A15)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: Colors.white70, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(1, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
