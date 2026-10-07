import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../../models/card_model.dart';
import 'suit_shapes.dart';

/// LIKYA-V2-011B | Sayı kartı pip yerleşimi (geleneksel deste düzeni).
class PipLayoutPainter extends CustomPainter {
  final Suit suit;
  final Rank rank;
  final Color color;

  const PipLayoutPainter({
    required this.suit,
    required this.rank,
    required this.color,
  });

  /// [sütun (0 sol, 1 orta, 2 sağ), dikey konum t ∈ [0,1]]
  static List<List<double>> layout(Rank rank) {
    const double a = 1 / 3, b = 2 / 3;
    switch (rank) {
      case Rank.two:
        return const [[1, 0], [1, 1]];
      case Rank.three:
        return const [[1, 0], [1, 0.5], [1, 1]];
      case Rank.four:
        return const [[0, 0], [2, 0], [0, 1], [2, 1]];
      case Rank.five:
        return const [[0, 0], [2, 0], [1, 0.5], [0, 1], [2, 1]];
      case Rank.six:
        return const [[0, 0], [2, 0], [0, 0.5], [2, 0.5], [0, 1], [2, 1]];
      case Rank.seven:
        return const [
          [0, 0], [2, 0], [1, 0.25], [0, 0.5], [2, 0.5], [0, 1], [2, 1]
        ];
      case Rank.eight:
        return const [
          [0, 0], [2, 0], [1, 0.25], [0, 0.5], [2, 0.5], [1, 0.75],
          [0, 1], [2, 1]
        ];
      case Rank.nine:
        return const [
          [0, 0], [2, 0], [0, a], [2, a], [1, 0.5], [0, b], [2, b],
          [0, 1], [2, 1]
        ];
      case Rank.ten:
        return const [
          [0, 0], [2, 0], [1, 1 / 6], [0, a], [2, a], [0, b], [2, b],
          [1, 5 / 6], [0, 1], [2, 1]
        ];
      default:
        return const [];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bool dense = rank == Rank.nine || rank == Rank.ten;
    final double pipW = w * (dense ? 0.168 : 0.186);
    final List<double> cols =
        dense ? const [0.305, 0.5, 0.695] : const [0.315, 0.5, 0.685];
    final double yTop = h * 0.19;
    final double yBot = h * 0.81;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    for (final p in layout(rank)) {
      final c = Offset(cols[p[0].toInt()] * w, yTop + p[1] * (yBot - yTop));
      canvas.drawPath(
        SuitShapes.at(suit, c, pipW, flip: p[1] > 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PipLayoutPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.rank != rank || oldDelegate.color != color;
}

/// LIKYA-V2-011B | As kartları. Maça As'ı destenin imza kartıdır.
class AcePainter extends CustomPainter {
  final Suit suit;
  final Color color;

  const AcePainter({required this.suit, required this.color});

  static const Color _gold = Color(0xFFB8923F);
  static const Color _goldDeep = Color(0xFF8C6A26);
  static const Color _ivory = Color(0xFFFBF6EA);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    if (suit != Suit.spades) {
      final double s = w * (suit == Suit.diamonds ? 0.40 : 0.42);
      canvas.drawPath(SuitShapes.at(suit, c, s), fill);
      return;
    }

    // ---- MAÇA ASI: Likya imza amblemi ----
    final double r = w * 0.355;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = _gold
      ..strokeWidth = math.max(0.6, w * 0.009)
      ..isAntiAlias = true;
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r - w * 0.03, ring..strokeWidth = math.max(0.4, w * 0.005));

    // Boncuk dizisi (Akdeniz süsleme)
    final bead = Paint()..color = _gold;
    const int beads = 40;
    for (int i = 0; i < beads; i++) {
      final a = i * 2 * math.pi / beads;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r - w * 0.015),
        math.max(0.35, w * 0.0055),
        bead,
      );
    }

    // Defne dalları (sol ve sağ)
    final leaf = Paint()..color = _goldDeep;
    void branch(double fromDeg, double toDeg) {
      const int n = 7;
      for (int i = 0; i < n; i++) {
        final double deg = fromDeg + (toDeg - fromDeg) * i / (n - 1);
        final double a = deg * math.pi / 180;
        final Offset pos = c + Offset(math.cos(a), math.sin(a)) * (r + w * 0.045);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + math.pi / 2 + (toDeg > fromDeg ? 0.5 : -0.5));
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: w * 0.028, height: w * 0.07),
          leaf,
        );
        canvas.restore();
      }
    }

    branch(105, 205); // sol
    branch(75, -25); // sağ

    // Büyük süslü maça
    final double s = w * 0.47;
    final Offset sc = c + Offset(0, -w * 0.01);
    canvas.drawPath(SuitShapes.at(Suit.spades, sc, s), fill);

    // Gravür iç kontur
    canvas.drawPath(
      SuitShapes.at(Suit.spades, sc + Offset(0, -w * 0.012), s * 0.80),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _ivory
        ..strokeWidth = math.max(0.5, w * 0.007)
        ..isAntiAlias = true,
    );

    // Palmet (Likya / Akdeniz motifi)
    final orn = Paint()
      ..color = _ivory
      ..isAntiAlias = true;
    final Offset base = sc + Offset(0, w * 0.04);
    for (int i = -2; i <= 2; i++) {
      final double a = -math.pi / 2 + i * 0.36;
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(a + math.pi / 2);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -w * 0.075),
            width: w * 0.026,
            height: w * (i == 0 ? 0.095 : 0.075)),
        orn,
      );
      canvas.restore();
    }
    canvas.drawCircle(base, w * 0.02, orn);
    canvas.drawCircle(base, w * 0.011, Paint()..color = _gold);

    // İnce imza yazısı
    final tp = TextPainter(
      text: TextSpan(
        text: 'LİKYA BATAK',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: w * 0.048,
          letterSpacing: w * 0.012,
          fontWeight: FontWeight.w500,
          color: color.withOpacity(0.72),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + r + w * 0.085));
  }

  @override
  bool shouldRepaint(covariant AcePainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

/// LIKYA-V2-011B | Çok hafif kart kâğıdı dokusu (deterministik).
class PaperGrainPainter extends CustomPainter {
  const PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    int seed = 1013904223;
    double rnd() {
      seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final dark = Paint()..color = const Color(0x0C6B5A3A);
    final light = Paint()..color = const Color(0x14FFFFFF);
    final int n = (size.width * size.height / 55).clamp(80, 260).toInt();
    for (int i = 0; i < n; i++) {
      final o = Offset(rnd() * size.width, rnd() * size.height);
      canvas.drawCircle(o, 0.25 + rnd() * 0.45, i.isEven ? dark : light);
    }
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter oldDelegate) => false;
}
