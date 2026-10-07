import 'package:flutter/widgets.dart';
import '../../models/card_model.dart';

/// LIKYA-V2-011B | Vektörel, cihazdan bağımsız iskambil sembolleri.
///
/// Font glifi (♠♥♦♣) yerine elle çizilmiş Path kullanılır; böylece her
/// Android cihazda aynı, keskin ve klasik baskı kalitesinde görünür.
/// Birim kutu: merkez (0,0), genişlik ≈ 1.0.
class SuitShapes {
  SuitShapes._();

  static final Path _heart = Path()
    ..moveTo(0, 0.46)
    ..cubicTo(-0.10, 0.34, -0.50, 0.10, -0.50, -0.15)
    ..cubicTo(-0.50, -0.36, -0.35, -0.47, -0.22, -0.47)
    ..cubicTo(-0.10, -0.47, -0.03, -0.40, 0, -0.29)
    ..cubicTo(0.03, -0.40, 0.10, -0.47, 0.22, -0.47)
    ..cubicTo(0.35, -0.47, 0.50, -0.36, 0.50, -0.15)
    ..cubicTo(0.50, 0.10, 0.10, 0.34, 0, 0.46)
    ..close();

  static final Path _diamond = Path()
    ..moveTo(0, -0.50)
    ..quadraticBezierTo(0.17, -0.22, 0.37, 0)
    ..quadraticBezierTo(0.17, 0.22, 0, 0.50)
    ..quadraticBezierTo(-0.17, 0.22, -0.37, 0)
    ..quadraticBezierTo(-0.17, -0.22, 0, -0.50)
    ..close();

  static final Path _spade = Path()
    ..moveTo(0, -0.50)
    ..cubicTo(0.10, -0.36, 0.50, -0.15, 0.50, 0.09)
    ..cubicTo(0.50, 0.28, 0.36, 0.37, 0.23, 0.37)
    ..cubicTo(0.13, 0.37, 0.06, 0.32, 0.035, 0.25)
    ..quadraticBezierTo(0.05, 0.42, 0.17, 0.50)
    ..lineTo(-0.17, 0.50)
    ..quadraticBezierTo(-0.05, 0.42, -0.035, 0.25)
    ..cubicTo(-0.06, 0.32, -0.13, 0.37, -0.23, 0.37)
    ..cubicTo(-0.36, 0.37, -0.50, 0.28, -0.50, 0.09)
    ..cubicTo(-0.50, -0.15, -0.10, -0.36, 0, -0.50)
    ..close();

  static final Path _club = Path()
    ..addOval(Rect.fromCircle(center: const Offset(0, -0.24), radius: 0.215))
    ..addOval(Rect.fromCircle(center: const Offset(-0.25, 0.08), radius: 0.215))
    ..addOval(Rect.fromCircle(center: const Offset(0.25, 0.08), radius: 0.215))
    ..addOval(Rect.fromCircle(center: const Offset(0, 0.0), radius: 0.14))
    ..moveTo(-0.035, 0.10)
    ..quadraticBezierTo(-0.05, 0.40, -0.17, 0.50)
    ..lineTo(0.17, 0.50)
    ..quadraticBezierTo(0.05, 0.40, 0.035, 0.10)
    ..close();

  static Path unit(Suit suit) {
    switch (suit) {
      case Suit.hearts:
        return _heart;
      case Suit.diamonds:
        return _diamond;
      case Suit.spades:
        return _spade;
      case Suit.clubs:
        return _club;
    }
  }

  /// [center] merkezli, [size] genişliğinde sembol. [flip] = 180° ters.
  static Path at(Suit suit, Offset center, double size, {bool flip = false}) {
    final double s = flip ? -size : size;
    final m = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(s, s);
    return unit(suit).transform(m.storage);
  }
}

/// Tek bir suit sembolünü çizen küçük painter (köşe indeksi için).
class SuitIconPainter extends CustomPainter {
  final Suit suit;
  final Color color;

  const SuitIconPainter({required this.suit, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      SuitShapes.at(suit, size.center(Offset.zero), size.width),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant SuitIconPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}
