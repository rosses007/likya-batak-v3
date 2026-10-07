import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'card_art/card_face_painters.dart';
import 'card_art/court_card_painter.dart';
import 'card_art/suit_shapes.dart';

/// LIKYA BATAK — PREMIUM KLASİK İSKAMBİL KARTI (V2-011B)
///
/// - Fildişi kart kâğıdı, çok hafif doku, ince sıcak gri baskı kenarı
/// - İnce köşe yuvarlaklığı, kart kalınlığı hissi veren alt kenar çizgisi
/// - Vektörel (fonttan bağımsız) suit sembolleri
/// - Geleneksel pip yerleşimi, alt yarıda ters pipler
/// - Orijinal çift başlı saray kartları (J/Q/K)
/// - Maça Ası: Likya imza amblemi
/// - Seçili kart: yalnızca çok ince altın kenar + doğal gölge
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

  static const Color _paper = Color(0xFFFCF9F1);
  static const Color _paperLow = Color(0xFFF6F1E4);
  static const Color _edge = Color(0xFFC9C2B3);
  static const Color _edgeThickness = Color(0xFFB3AA97);
  static const Color _inkBlack = Color(0xFF1E1D1F);
  static const Color _inkRed = Color(0xFFA51C28);
  static const Color _selectGold = Color(0xFFC9A04A);

  String get symbol {
    switch (card.suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  String get rankStr {
    switch (card.rank) {
      case Rank.ace:
        return 'A';
      case Rank.king:
        return 'K';
      case Rank.queen:
        return 'Q';
      case Rank.jack:
        return 'J';
      case Rank.ten:
        return '10';
      case Rank.nine:
        return '9';
      case Rank.eight:
        return '8';
      case Rank.seven:
        return '7';
      case Rank.six:
        return '6';
      case Rank.five:
        return '5';
      case Rank.four:
        return '4';
      case Rank.three:
        return '3';
      case Rank.two:
        return '2';
    }
  }

  bool get isRed => card.suit == Suit.hearts || card.suit == Suit.diamonds;

  Color get suitColor => isRed ? _inkRed : _inkBlack;

  bool get _isCourt =>
      card.rank == Rank.king ||
      card.rank == Rank.queen ||
      card.rank == Rank.jack;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double w = width ?? (screenSize.width * 0.22).clamp(84.0, 120.0);
    final double h = height ?? (w * 1.40);
    final double scale = w / 85.0;
    final double radius = (4.2 * scale).clamp(3.2, 5.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isSelected ? _selectGold : _edge,
            width: isSelected ? 1.3 : 0.7,
          ),
          boxShadow: [
            // Kart kalınlığı izlenimi
            BoxShadow(
              color: _edgeThickness,
              offset: Offset(0, 0.6 * scale.clamp(1.0, 1.4)),
            ),
            // Doğal masa gölgesi
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.30 : 0.22),
              blurRadius: (isSelected ? 7.0 : 4.0) * scale,
              offset: Offset(0.4 * scale, (isSelected ? 4.0 : 1.8) * scale),
            ),
            if (isSelected)
              BoxShadow(
                color: _selectGold.withOpacity(0.22),
                blurRadius: 3 * scale,
                spreadRadius: 0.4,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 0.6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_paper, _paperLow],
                  ),
                ),
              ),
              const CustomPaint(painter: PaperGrainPainter()),

              // Orta alan
              if (_isCourt)
                Positioned(
                  left: w * 0.195,
                  right: w * 0.195,
                  top: h * 0.07,
                  bottom: h * 0.07,
                  child: CustomPaint(
                    painter: CourtCardPainter(rank: card.rank, suit: card.suit),
                  ),
                )
              else if (card.rank == Rank.ace)
                CustomPaint(
                  painter: AcePainter(suit: card.suit, color: suitColor),
                )
              else
                CustomPaint(
                  painter: PipLayoutPainter(
                    suit: card.suit,
                    rank: card.rank,
                    color: suitColor,
                  ),
                ),

              // Köşe indeksleri
              Positioned(
                top: 3.0 * scale,
                left: 2.0 * scale,
                child: _buildIndex(scale),
              ),
              Positioned(
                bottom: 3.0 * scale,
                right: 2.0 * scale,
                child: RotatedBox(quarterTurns: 2, child: _buildIndex(scale)),
              ),

              if (!isPlayable)
                Container(color: const Color(0xFF0F172A).withOpacity(0.30)),
            ],
          ),
        ),
      ),
    );
  }

  /// Dar, sıkı gruplanmış klasik köşe indeksi (rank üstte, suit altında).
  Widget _buildIndex(double scale) {
    final bool isTen = card.rank == Rank.ten;
    return SizedBox(
      width: 15.0 * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(isTen ? 0.78 : 0.88, 1, 1),
            child: Text(
              rankStr,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (isTen ? 13.5 : 14.5) * scale,
                fontWeight: FontWeight.w600,
                color: suitColor,
                height: 1.0,
                letterSpacing: isTen ? -0.8 * scale : 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          SizedBox(height: 1.2 * scale),
          CustomPaint(
            size: Size(9.0 * scale, 9.0 * scale),
            painter: SuitIconPainter(suit: card.suit, color: suitColor),
          ),
        ],
      ),
    );
  }
}
