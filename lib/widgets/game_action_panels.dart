import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'card_art/suit_shapes.dart';

/// LIKYA-V2-013 | Zarif İhale Seçim Paneli (5'ten 13'e ve Pas butonu)
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

  static const Color _gold = Color(0xFFC9A04A);
  static const Color _ivory = Color(0xFFF6F1E4);
  static const Color _ink = Color(0xFF1E1D1F);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16251C).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20, height: 1, color: _gold.withOpacity(0.5)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "İHALE VER",
                  style: TextStyle(
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(width: 20, height: 1, color: _gold.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 10),
          // 3x3 Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: List.generate(9, (index) {
              int bidValue = 5 + index; // 5'ten 13'e
              bool isEnabled = bidValue > currentHighestBid;

              return _buildBidButton(
                text: "$bidValue",
                isEnabled: isEnabled,
                onTap: () => onBidSelected(bidValue),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Pas Butonu
          SizedBox(
            width: double.infinity,
            height: 40,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPass,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E1F18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B4715), width: 1.2),
                  ),
                  child: const Center(
                    child: Text(
                      "PAS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidButton({
    required String text,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: isEnabled ? _ivory : Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled ? _gold : Colors.white12,
              width: isEnabled ? 1.2 : 0.8,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isEnabled ? _ink : Colors.white24,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// LIKYA-V2-013 | 4'lü Orijinal Vektör Koz Seçim Paneli (♠, ♥, ♦, ♣)
class TrumpSelectorWidget extends StatelessWidget {
  final Function(Suit selectedTrump) onTrumpSelected;

  const TrumpSelectorWidget({
    super.key,
    required this.onTrumpSelected,
  });

  static const Color _gold = Color(0xFFC9A04A);
  static const Color _ivory = Color(0xFFF6F1E4);
  static const Color _ink = Color(0xFF1E1D1F);
  static const Color _red = Color(0xFFA51C28);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16251C).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 20, height: 1, color: _gold.withOpacity(0.5)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "KOZ SEÇİNİZ",
                  style: TextStyle(
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(width: 20, height: 1, color: _gold.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSuitCardButton(suit: Suit.spades, color: _ink),
              const SizedBox(width: 10),
              _buildSuitCardButton(suit: Suit.hearts, color: _red),
              const SizedBox(width: 10),
              _buildSuitCardButton(suit: Suit.diamonds, color: _red),
              const SizedBox(width: 10),
              _buildSuitCardButton(suit: Suit.clubs, color: _ink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuitCardButton({
    required Suit suit,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTrumpSelected(suit),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 50,
          height: 58,
          decoration: BoxDecoration(
            color: _ivory,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(26, 26),
              painter: SuitIconPainter(suit: suit, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
