import 'package:flutter/material.dart';
import '../models/card_model.dart';

/// DEV VE GERÇEKÇİ KART TASARIMI
/// - 52 adet yüksek çözünürlüklü gerçek kâğıt kart görseli (assets/cards/)
/// - As (A), Papaz (K), Kız (Q), Vale (J) için orijinal resimli tasarımlar
/// - Dinamik dev boyut (MediaQuery genişliğinin %18'i)
/// - Gerçekçi BoxShadow ve seçim animasyonu
class RealisticPlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final double? width;
  final double? height;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;

  const RealisticPlayingCardWidget({
    super.key,
    required this.card,
    this.width,
    this.height,
    this.isSelected = false,
    this.isPlayable = true,
    this.onTap,
  });

  String get assetPath => 'assets/cards/${card.suit.name}_${card.rank.name}.png';

  String get symbol {
    switch (card.suit) {
      case Suit.spades: return '♠';
      case Suit.hearts: return '♥';
      case Suit.diamonds: return '♦';
      case Suit.clubs: return '♣';
    }
  }

  String get rankStr {
    switch (card.rank) {
      case Rank.ace: return 'A';
      case Rank.king: return 'P';
      case Rank.queen: return 'K';
      case Rank.jack: return 'V';
      default: return (card.rank.index + 2).toString();
    }
  }

  bool get isRed => card.suit == Suit.hearts || card.suit == Suit.diamonds;
  Color get suitColor => isRed ? const Color(0xFFD32F2F) : const Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    // Kart genişliği MediaQuery genişliğinin %18'i olacak şekilde dev boyut
    double finalWidth = width ?? (screenSize.width * 0.18).clamp(78.0, 115.0);
    double finalHeight = height ?? (finalWidth * 1.38);

    double scale = finalWidth / 75.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: finalWidth,
        height: finalHeight,
        transform: isSelected
            ? Matrix4.translationValues(0, -14, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.amberAccent
                : (isPlayable ? const Color(0xFFB0B0B0) : const Color(0xFFDCDCDC)),
            width: isSelected ? 2.5 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.amber.withOpacity(0.65)
                  : Colors.black.withOpacity(0.40),
              blurRadius: isSelected ? 16 : 8,
              spreadRadius: isSelected ? 2 : 1,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gerçek Kart Görseli (Orijinal As, Papaz, Kız, Vale ve Numaralı Kart Çizimleri)
              Image.asset(
                assetPath,
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackCard(scale);
                },
              ),

              // Oynanamazsa solukluk filtresi
              if (!isPlayable)
                Container(
                  color: Colors.black.withOpacity(0.32),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Görsel yüklenemezse devreye giren şık vektörel yedek tasarım
  Widget _buildFallbackCard(double scale) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF7F7F7),
            Color(0xFFEDEDED),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 5,
            left: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rankStr,
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w900,
                    color: suitColor,
                    height: 1.0,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                    color: suitColor,
                    height: 1.0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 5,
            right: 6,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rankStr,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.bold,
                      color: suitColor,
                      height: 1.0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    symbol,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: suitColor,
                      height: 1.0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Text(
              symbol,
              style: TextStyle(
                fontSize: 50 * scale,
                color: suitColor.withOpacity(0.88),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
