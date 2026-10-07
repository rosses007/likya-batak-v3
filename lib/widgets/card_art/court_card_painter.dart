import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../../models/card_model.dart';
import 'suit_shapes.dart';

/// LIKYA-V2-011B / 011D | Klasik çift başlı (ayna simetrik) saray kartı çizimi.
///
/// Orijinal Likya Batak tasarımı: Avrupa/Anglo-Amerikan saray kartı
/// geleneğinden esinlenir (taç, ermin pelerin, brokar kumaş, kılıç/asa/gül),
/// ancak herhangi bir ticari destenin kopyası değildir.
/// Figür üst yarıda çizilir; alt yarı 180° döndürülerek elde edilir ve
/// iki yarı hafif çapraz bir çizgiyle ayrılır.
///
/// 011D: dar omuzlu doğal gövde, gravür tarzı ince çizgili yüz/saç/sakal,
/// katmanlı giysi ve takımlara göre değişen taç/şapka/nesne/desen.
class CourtCardPainter extends CustomPainter {
  final Rank rank;
  final Suit suit;

  const CourtCardPainter({required this.rank, required this.suit});

  static const Color ink = Color(0xFF231F20);
  static const Color red = Color(0xFFA51F2A);
  static const Color navy = Color(0xFF1F2C4E);
  static const Color gold = Color(0xFFCDA349);
  static const Color goldDeep = Color(0xFF8E6B22);
  static const Color cream = Color(0xFFF7EEDB);
  static const Color ivory = Color(0xFFFFFBF1);
  static const Color skin = Color(0xFFEFD2B2);
  static const Color steel = Color(0xFFD8DCE1);
  static const Color steelDark = Color(0xFF8E959D);
  static const Color wood = Color(0xFF6B4423);
  static const Color leafGreen = Color(0xFF3F6A3B);

  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;
  Color get suitInk => isRed ? const Color(0xFFA51C28) : const Color(0xFF1E1D1F);

  /// Takım indeksi: 0 maça, 1 kupa, 2 karo, 3 sinek.
  int get sv {
    switch (suit) {
      case Suit.spades:
        return 0;
      case Suit.hearts:
        return 1;
      case Suit.diamonds:
        return 2;
      default:
        return 3;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final frame = Offset.zero & size;

    canvas.drawRect(frame, Paint()..color = cream);

    final upper = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.47)
      ..lineTo(0, h * 0.53)
      ..close();

    for (int i = 0; i < 2; i++) {
      canvas.save();
      if (i == 1) {
        canvas.translate(w, h);
        canvas.rotate(math.pi);
      }
      canvas.clipPath(upper);
      _drawFigure(_Pen(canvas, w, h));
      canvas.restore();
    }

    // Yarıları ayıran ince çapraz çizgi
    canvas.drawLine(
      Offset(0, h * 0.53),
      Offset(w, h * 0.47),
      Paint()
        ..color = ink.withOpacity(0.85)
        ..strokeWidth = math.max(0.5, w * 0.010),
    );

    // Basılı çerçeve
    canvas.drawRect(
      frame.deflate(math.max(0.4, w * 0.008)),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = suitInk
        ..strokeWidth = math.max(0.7, w * 0.016),
    );
  }

  void _drawFigure(_Pen p) {
    final Color main = isRed ? red : navy;
    final Color accent = isRed ? navy : red;
    switch (rank) {
      case Rank.king:
        _king(p, main, accent);
        break;
      case Rank.queen:
        _queen(p, main, accent);
        break;
      default:
        _jack(p, main, accent);
    }
  }

  // ---------------------------------------------------------------------------
  // ORTAK PARÇALAR
  // ---------------------------------------------------------------------------

  /// Baş grubunu (saç, yüz, taç) büyütür; yüz detayları mobilde okunur kalır.
  void _headBegin(_Pen p) {
    final a = p.p(0.5, 0.31);
    p.c.save();
    p.c.translate(a.dx, a.dy + p.h * 0.03);
    p.c.scale(1.18);
    p.c.translate(-a.dx, -a.dy);
  }

  void _headEnd(_Pen p) => p.c.restore();

  /// Geleneksel oranlı, gravür tarzı taramalı yüz.
  void _face(
    _Pen p, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    bool lips = false,
    bool lashes = false,
    bool mouth = true,
  }) {
    final face = p.fp()
        .m(cx - rx, cy - ry * 0.25)
        .c(cx - rx, cy - ry * 1.15, cx + rx, cy - ry * 1.15, cx + rx,
            cy - ry * 0.25)
        .c(cx + rx * 0.98, cy + ry * 0.55, cx + rx * 0.38, cy + ry * 1.0, cx,
            cy + ry * 1.06)
        .c(cx - rx * 0.38, cy + ry * 1.0, cx - rx * 0.98, cy + ry * 0.55,
            cx - rx, cy - ry * 0.25)
        .z();
    p.fs(face, skin, k: 0.8);

    // Gravür taraması (sağ yanak / çene gölgesi)
    p.c.save();
    p.c.clipPath(face);
    for (int i = 0; i < 6; i++) {
      p.st(
        p.fp()
            .m(cx + rx * (0.42 + 0.11 * i), cy + ry * 0.02)
            .l(cx + rx * (0.34 + 0.11 * i), cy + ry * 1.0)
            .open,
        ink.withOpacity(0.28),
        k: 0.3,
      );
    }
    // Çene altı taraması
    for (int i = 0; i < 4; i++) {
      p.st(
        p.fp()
            .m(cx - rx * 0.5 + rx * 0.25 * i, cy + ry * 0.86)
            .l(cx - rx * 0.38 + rx * 0.25 * i, cy + ry * 1.1)
            .open,
        ink.withOpacity(0.22),
        k: 0.3,
      );
    }
    p.c.restore();

    // Kaşlar (ince)
    for (final s in [-1.0, 1.0]) {
      p.st(
        p.fp()
            .m(cx + s * rx * 0.74, cy - ry * 0.34)
            .q(cx + s * rx * 0.46, cy - ry * 0.56, cx + s * rx * 0.13,
                cy - ry * 0.38)
            .open,
        ink,
        k: 0.6,
      );
    }

    // Gözler (küçük, üst kapak vurgulu)
    for (final s in [-1.0, 1.0]) {
      final ex = cx + s * rx * 0.41, ey = cy - ry * 0.12;
      final ew = rx * 0.23, eh = ry * 0.075;
      final eye = p.fp()
          .m(ex - ew, ey)
          .q(ex, ey - eh * 2.2, ex + ew, ey)
          .q(ex, ey + eh * 1.3, ex - ew, ey)
          .z();
      p.c.drawPath(eye, Paint()..color = ivory);
      p.c.drawCircle(p.p(ex + s * rx * 0.02, ey),
          math.max(0.4, eh * p.h * 0.85), Paint()..color = const Color(0xFF2B2018));
      p.st(eye, ink, k: 0.5);
      p.st(
        p.fp()
            .m(ex - ew * 1.05, ey)
            .q(ex, ey - eh * 2.5, ex + ew * 1.05, ey)
            .open,
        ink,
        k: 0.85,
      );
      if (lashes) {
        p.st(
            p.fp()
                .m(ex + s * ew, ey)
                .l(ex + s * (ew + rx * 0.10), ey - eh * 1.8)
                .open,
            ink,
            k: 0.5);
      }
    }

    // Burun
    p.st(
      p.fp()
          .m(cx + rx * 0.05, cy - ry * 0.10)
          .q(cx - rx * 0.09, cy + ry * 0.26, cx - rx * 0.07, cy + ry * 0.34)
          .q(cx + rx * 0.03, cy + ry * 0.40, cx + rx * 0.13, cy + ry * 0.33)
          .open,
      ink,
      k: 0.55,
    );
    p.st(
      p.fp()
          .m(cx - rx * 0.16, cy + ry * 0.40)
          .q(cx, cy + ry * 0.50, cx + rx * 0.16, cy + ry * 0.40)
          .open,
      ink.withOpacity(0.35),
      k: 0.35,
    );

    // Ağız
    if (lips) {
      final lipsPath = p.fp()
          .m(cx - rx * 0.24, cy + ry * 0.66)
          .q(cx - rx * 0.10, cy + ry * 0.58, cx, cy + ry * 0.63)
          .q(cx + rx * 0.10, cy + ry * 0.58, cx + rx * 0.24, cy + ry * 0.66)
          .q(cx, cy + ry * 0.82, cx - rx * 0.24, cy + ry * 0.66)
          .z();
      p.fs(lipsPath, const Color(0xFFA8323A), k: 0.4);
    } else if (mouth) {
      p.st(
        p.fp()
            .m(cx - rx * 0.20, cy + ry * 0.66)
            .q(cx, cy + ry * 0.72, cx + rx * 0.20, cy + ry * 0.66)
            .open,
        const Color(0xFF7A2A2A),
        k: 0.65,
      );
    }
  }

  void _lattice(_Pen p, Path clip, Color color, double step) {
    p.c.save();
    p.c.clipPath(clip);
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(0.3, p.lw * 0.5);
    for (double x = -1.0; x < 2.0; x += step) {
      p.c.drawLine(p.p(x, 0), p.p(x + 0.6, 0.6), paint);
      p.c.drawLine(p.p(x + 0.6, 0), p.p(x, 0.6), paint);
    }
    p.c.restore();
  }

  /// Takıma göre değişen kumaş deseni.
  void _pattern(_Pen p, Path clip, Color c) {
    p.c.save();
    p.c.clipPath(clip);
    final paint = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.3, p.lw * 0.5);
    final fill = Paint()..color = c;
    switch (sv) {
      case 0: // harlequin ağı
        for (double x = 0.0; x < 1.0; x += 0.08) {
          p.c.drawLine(p.p(x, 0.3), p.p(x + 0.22, 0.65), paint);
          p.c.drawLine(p.p(x + 0.22, 0.3), p.p(x, 0.65), paint);
        }
        break;
      case 1: // dikey şeritler + noktalar
        for (double x = 0.10; x < 0.92; x += 0.065) {
          p.c.drawLine(p.p(x, 0.3), p.p(x, 0.65), paint);
        }
        for (double y = 0.34; y < 0.62; y += 0.05) {
          for (double x = 0.13; x < 0.9; x += 0.13) {
            p.c.drawCircle(p.p(x, y), math.max(0.3, p.w * 0.006), fill);
          }
        }
        break;
      case 2: // pul / yay deseni
        int row = 0;
        for (double y = 0.34; y < 0.66; y += 0.04, row++) {
          for (double x = row.isEven ? 0.1 : 0.15; x < 0.95; x += 0.1) {
            p.c.drawArc(
              Rect.fromCenter(
                  center: p.p(x, y), width: p.w * 0.09, height: p.h * 0.05),
              0,
              math.pi,
              false,
              paint,
            );
          }
        }
        break;
      default: // zikzak şeritler
        for (double y = 0.34; y < 0.66; y += 0.05) {
          final zz = Path()..moveTo(p.p(0.05, y).dx, p.p(0.05, y).dy);
          bool up = true;
          for (double x = 0.05; x < 0.97; x += 0.045) {
            final o = p.p(x + 0.045, y + (up ? -0.014 : 0.0));
            zz.lineTo(o.dx, o.dy);
            up = !up;
          }
          p.c.drawPath(zz, paint);
        }
    }
    p.c.restore();
  }

  void _pip(_Pen p, double x, double y, double size) {
    p.c.drawPath(
      SuitShapes.at(suit, p.p(x, y), size * p.w),
      Paint()..color = suitInk,
    );
  }

  Offset _quadPt(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + c * (t * t);
  }

  Offset _cubicPt(Offset a, Offset b, Offset c, Offset d, double t) {
    final u = 1 - t;
    return a * (u * u * u) +
        b * (3 * u * u * t) +
        c * (3 * u * t * t) +
        d * (t * t * t);
  }

  /// Omuzlarda geniş, bölme çizgisine doğru daralan doğal gövde.
  Path _torso(_Pen p) => p.fp()
      .m(0.27, 0.68)
      .c(0.23, 0.58, 0.15, 0.53, 0.16, 0.45)
      .c(0.165, 0.42, 0.19, 0.40, 0.22, 0.39)
      .c(0.29, 0.35, 0.39, 0.33, 0.44, 0.312)
      .l(0.56, 0.312)
      .c(0.61, 0.33, 0.71, 0.35, 0.78, 0.39)
      .c(0.81, 0.40, 0.835, 0.42, 0.84, 0.45)
      .c(0.85, 0.53, 0.77, 0.58, 0.73, 0.68)
      .z();

  /// Kollar: omuzdan manşete, iç kenar altın şerit ve takıma göre süsleme.
  void _sleeves(_Pen p, Color color, {int style = 0}) {
    for (final s in [0, 1]) {
      double X(double x) => s == 0 ? x : 1 - x;
      final sl = p.fp()
          .m(X(0.22), 0.385)
          .c(X(0.16), 0.40, X(0.132), 0.43, X(0.132), 0.462)
          .l(X(0.252), 0.478)
          .c(X(0.262), 0.44, X(0.285), 0.41, X(0.262), 0.378)
          .z();
      p.fs(sl, color, k: 0.85);
      p.c.save();
      p.c.clipPath(sl);
      if (style == 0) {
        for (final dx in [0.17, 0.205]) {
          p.st(p.fp().m(X(dx), 0.40).q(X(dx - 0.012), 0.44, X(dx + 0.01), 0.48).open,
              ink.withOpacity(0.4), k: 0.4);
        }
      } else if (style == 1) {
        for (final y in [0.415, 0.44]) {
          p.st(p.fp().m(X(0.13), y + 0.01).q(X(0.20), y + 0.04, X(0.27), y - 0.02).open,
              gold, k: 1.2);
        }
      } else {
        for (double y = 0.38; y < 0.5; y += 0.03) {
          p.st(p.fp().m(X(0.13), y + 0.03).l(X(0.28), y - 0.02).open,
              gold.withOpacity(0.85), k: 0.9);
        }
      }
      p.c.restore();
      p.st(
          p.fp()
              .m(X(0.262), 0.378)
              .c(X(0.285), 0.41, X(0.262), 0.44, X(0.252), 0.478)
              .open,
          gold,
          k: 1.4);
      // Manşet
      p.fs(
          p.fp()
              .m(X(0.133), 0.444)
              .l(X(0.255), 0.458)
              .l(X(0.252), 0.480)
              .l(X(0.132), 0.466)
              .z(),
          gold,
          k: 0.6);
      p.st(p.fp().m(X(0.133), 0.455).l(X(0.254), 0.469).open, goldDeep, k: 0.4);
    }
  }
  void _hand(_Pen p, double x, double y) {
    p.fs(p.oval(x, y, 0.040, 0.024), skin, k: 0.75);
    for (final dy in [-0.009, 0.0, 0.009]) {
      p.st(p.fp().m(x - 0.03, y + dy).l(x + 0.005, y + dy).open, ink, k: 0.4);
    }
  }

  void _ermine(_Pen p, Path clip) {
    p.c.save();
    p.c.clipPath(clip);
    final paint = Paint()..color = ink;
    int row = 0;
    for (double y = 0.325; y < 0.47; y += 0.028, row++) {
      for (double x = row.isEven ? 0.2 : 0.225; x < 0.8; x += 0.05) {
        p.c.drawOval(
            Rect.fromCenter(
                center: p.p(x, y), width: p.w * 0.010, height: p.h * 0.013),
            paint);
        p.c.drawCircle(p.p(x - 0.008, y + 0.013), math.max(0.25, p.w * 0.0035), paint);
        p.c.drawCircle(p.p(x + 0.008, y + 0.013), math.max(0.25, p.w * 0.0035), paint);
      }
    }
    p.c.restore();
  }

  /// Omuz pelerini (ermin): omuzlara düşen, V açıklıklı, yaka bandı değil.
  void _mantle(_Pen p) {
    for (final s in [0, 1]) {
      double X(double x) => s == 0 ? x : 1 - x;
      final cape = p.fp()
          .m(X(0.44), 0.309)
          .c(X(0.38), 0.322, X(0.30), 0.343, X(0.225), 0.386)
          .l(X(0.200), 0.435)
          .c(X(0.25), 0.485, X(0.38), 0.47, X(0.47), 0.388)
          .z();
      p.fs(cape, ivory, k: 0.8);
      _ermine(p, cape);
      p.st(cape, ink, k: 0.8);
    }
  }

  // ---------------------------------------------------------------------------
  // PAPAZ (KING)
  // ---------------------------------------------------------------------------
  void _king(_Pen p, Color main, Color accent) {
    final Color beard = const [
      Color(0xFF6E6359),
      Color(0xFF5A3B22),
      Color(0xFF8A5A2B),
      Color(0xFF3A3532),
    ][sv];

    // Gövde
    final torso = _torso(p);
    p.fs(torso, main, k: 0.9);
    _pattern(p, torso, gold.withOpacity(0.5));

    // Ön altın panel (altta tunik)
    final panel = p.fp().m(0.44, 0.312).l(0.56, 0.312).l(0.62, 0.66)
        .l(0.38, 0.66).z();
    p.fs(panel, gold, k: 0.7);
    _lattice(p, panel, goldDeep, 0.05);
    for (final y in [0.43, 0.48]) {
      p.fs(p.oval(0.5, y, 0.017, 0.0095), accent, k: 0.5);
    }

    _sleeves(p, accent, style: sv == 1 || sv == 3 ? 0 : 2);

    // Boyun
    p.fs(p.fp().m(0.455, 0.24).l(0.545, 0.24).l(0.552, 0.315).l(0.448, 0.315)
        .z(), skin, k: 0.7);
    p.st(p.fp().m(0.46, 0.285).q(0.5, 0.30, 0.54, 0.285).open,
        ink.withOpacity(0.35), k: 0.35);

    _mantle(p);

    // Zincir + kolye
    p.st(p.fp().m(0.47, 0.388).q(0.5, 0.445, 0.53, 0.388).open, goldDeep, k: 1.1);
    p.fs(p.oval(0.5, 0.455, 0.020, 0.012), accent, k: 0.55);

    _headBegin(p);
    // Arka saç
    p.fs(
      p.fp()
          .m(0.41, 0.15)
          .c(0.37, 0.20, 0.37, 0.25, 0.40, 0.29)
          .l(0.60, 0.29)
          .c(0.63, 0.25, 0.63, 0.20, 0.59, 0.15)
          .z(),
      beard,
      k: 0.8,
    );
    for (final s in [-1.0, 1.0]) {
      for (final dy in [0.17, 0.205, 0.24]) {
        p.st(
            p.fp()
                .m(0.5 + s * 0.095, dy)
                .q(0.5 + s * 0.115, dy + 0.02, 0.5 + s * 0.105, dy + 0.045)
                .open,
            Color.lerp(beard, ivory, 0.45)!,
            k: 0.4);
      }
    }

    _face(p, cx: 0.5, cy: 0.196, rx: 0.080, ry: 0.066, mouth: false);

    _kingBeard(p, beard);
    _kingCrown(p);
    _headEnd(p);

    // Takıma özgü saltanat nesnesi
    switch (sv) {
      case 0:
        _sword(p, 0.17, accent);
        break;
      case 1:
        _sceptreFleur(p, 0.17);
        break;
      case 2:
        _axe(p, 0.17);
        break;
      default:
        _sceptreOrb(p, 0.17);
    }
    _hand(p, 0.17, 0.494);_hand(p, 0.83, 0.494);

    _pip(p, 0.845, 0.075, 0.12);
  }

  void _kingBeard(_Pen p, Color beard) {
    final double by = const [0.312, 0.322, 0.336, 0.314][sv];
    final double n = const [0.0, 0.0, 0.022, -0.006][sv];
    final beardPath = p.fp()
        .m(0.416, 0.205)
        .c(0.412 + n, 0.255, 0.45 + n * 0.5, by - 0.025, 0.5, by)
        .c(0.55 - n * 0.5, by - 0.025, 0.588 - n, 0.255, 0.584, 0.205)
        .l(0.566, 0.212)
        .c(0.56, 0.236, 0.535, 0.232, 0.5, 0.238)
        .c(0.465, 0.232, 0.44, 0.236, 0.434, 0.212)
        .z();
    p.fs(beardPath, beard, k: 0.75);
    final strand = Color.lerp(beard, ivory, 0.45)!;
    for (final x in [0.44, 0.465, 0.49, 0.51, 0.535, 0.56]) {
      p.st(
          p.fp()
              .m(x, 0.247)
              .q(x - (0.5 - x) * 0.2, 0.28, x + (0.5 - x) * 0.45, by - 0.012)
              .open,
          strand,
          k: 0.38);
    }
    if (sv == 1) {
      // çatallı sakal
      p.st(p.fp().m(0.5, by - 0.05).l(0.5, by).open, ink, k: 0.6);
    }
    if (sv == 3) {
      // kıvırcık uçlar
      for (final s in [-1.0, 1.0]) {
        for (final y in [0.235, 0.265, 0.292]) {
          p.c.drawCircle(
              p.p(0.5 + s * (0.088 - (y - 0.235) * 0.6), y),
              p.w * 0.011,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = ink
                ..strokeWidth = p.lw * 0.45);
        }
      }
    }
    // Bıyık
    p.fs(
      p.fp()
          .m(0.5, 0.224)
          .q(0.47, 0.217, 0.434, 0.240)
          .q(0.470, 0.238, 0.5, 0.231)
          .q(0.530, 0.238, 0.566, 0.240)
          .q(0.53, 0.217, 0.5, 0.224)
          .z(),
      beard,
      k: 0.55,
    );
  }

  void _kingCrown(_Pen p) {
    // Kadife başlık
    p.fs(p.oval(0.5, 0.100, 0.10, 0.046), isRed ? navy : red, k: 0.8);
    switch (sv) {
      case 0: // zambaklı taç
        final cp = p.fp().m(0.5, 0.122).c(0.466, 0.095, 0.466, 0.055, 0.5, 0.022)
            .c(0.534, 0.055, 0.534, 0.095, 0.5, 0.122).z();
        p.fs(cp, gold, k: 0.8);
        for (final s in [-1.0, 1.0]) {
          final sp = p.fp()
              .m(0.5 + s * 0.108, 0.125)
              .c(0.5 + s * 0.128, 0.098, 0.5 + s * 0.118, 0.068, 0.5 + s * 0.092, 0.050)
              .c(0.5 + s * 0.078, 0.078, 0.5 + s * 0.082, 0.098, 0.5 + s * 0.068, 0.125)
              .z();
          p.fs(sp, gold, k: 0.8);
        }
        p.st(p.fp().m(0.5, 0.040).l(0.5, 0.118).open, goldDeep, k: 0.4);
        break;
      case 1: // kemerli kapalı taç + küre/haç
        final arch = p.fp().m(0.398, 0.124).c(0.400, 0.062, 0.46, 0.04, 0.5, 0.04)
            .c(0.54, 0.04, 0.60, 0.062, 0.602, 0.124).open;
        p.st(arch, ink, k: 3.6);
        p.st(arch, gold, k: 2.4);
        p.fs(p.oval(0.5, 0.036, 0.016, 0.0095), gold, k: 0.6);
        p.st(p.fp().m(0.5, 0.027).l(0.5, 0.004).open, ink, k: 1.9);
        p.st(p.fp().m(0.5, 0.027).l(0.5, 0.004).open, gold, k: 1.1);
        p.st(p.fp().m(0.488, 0.015).l(0.512, 0.015).open, ink, k: 1.9);
        p.st(p.fp().m(0.488, 0.015).l(0.512, 0.015).open, gold, k: 1.1);
        break;
      case 2: // ışınsal taç
        final crown = p.fp()
            .m(0.392, 0.124)
            .l(0.388, 0.050)
            .l(0.425, 0.092)
            .l(0.445, 0.034)
            .l(0.474, 0.088)
            .l(0.5, 0.016)
            .l(0.526, 0.088)
            .l(0.555, 0.034)
            .l(0.575, 0.092)
            .l(0.612, 0.050)
            .l(0.608, 0.124)
            .z();
        p.fs(crown, gold, k: 0.75);
        for (final t in [
          [0.388, 0.050], [0.445, 0.034], [0.5, 0.016], [0.555, 0.034], [0.612, 0.050]
        ]) {
          p.c.drawCircle(p.p(t[0], t[1]), p.w * 0.011, Paint()..color = ivory);
          p.c.drawCircle(
              p.p(t[0], t[1]),
              p.w * 0.011,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = ink
                ..strokeWidth = p.lw * 0.5);
        }
        break;
      default: // yonca (trefoil) taç
        for (final t in [
          [0.425, 0.08, 0.024], [0.5, 0.052, 0.030], [0.575, 0.08, 0.024]
        ]) {
          p.fs(p.oval(t[0], t[1], t[2], t[2] * 0.62), gold, k: 0.75);
          p.st(p.fp().m(t[0], t[1] + t[2] * 0.4).l(t[0], 0.125).open, goldDeep, k: 0.9);
        }
        p.fs(p.oval(0.5, 0.085, 0.020, 0.012), gold, k: 0.6);
    }
    // Taç bandı
    final band = p.fp().m(0.392, 0.118).l(0.608, 0.118).l(0.606, 0.147)
        .l(0.394, 0.147).z();
    p.fs(band, gold, k: 0.8);
    p.st(p.fp().m(0.396, 0.140).l(0.604, 0.140).open, goldDeep, k: 0.5);
    p.fs(p.oval(0.44, 0.1295, 0.015, 0.0075), red, k: 0.5);
    p.fs(p.oval(0.5, 0.1295, 0.017, 0.0085), navy, k: 0.5);
    p.fs(p.oval(0.56, 0.1295, 0.015, 0.0075), red, k: 0.5);
  }

  // Kralın nesneleri (sol elde, x merkezi)
  void _sword(_Pen p, double x, Color grip) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.17, 0.016).l(0.181, 0.05).l(0.182, 0.37).l(0.158, 0.37)
        .l(0.159, 0.05).z(), steel, k: 0.75);
    p.st(p.fp().m(0.17, 0.045).l(0.17, 0.365).open, steelDark, k: 0.5);
    p.fs(p.fp().m(0.11, 0.366).q(0.17, 0.358, 0.23, 0.366).l(0.23, 0.384)
        .q(0.17, 0.377, 0.11, 0.384).z(), gold, k: 0.75);
    p.fs(p.fp().m(0.162, 0.384).l(0.178, 0.384).l(0.178, 0.44).l(0.162, 0.44)
        .z(), grip, k: 0.65);
    p.fs(p.oval(0.17, 0.446, 0.017, 0.010), gold, k: 0.65);
    p.c.restore();
  }

  void _sceptreFleur(_Pen p, double x) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.162, 0.08).l(0.178, 0.08).l(0.178, 0.45).l(0.162, 0.45).z(),
        gold, k: 0.8);
    for (final y in [0.2, 0.3, 0.4]) {
      p.st(p.fp().m(0.162, y).l(0.178, y).open, goldDeep, k: 0.6);
    }
    final f = p.fp().m(0.17, 0.085).c(0.140, 0.06, 0.140, 0.025, 0.17, 0.004)
        .c(0.200, 0.025, 0.200, 0.06, 0.17, 0.085).z();
    p.fs(f, gold, k: 0.75);
    for (final s in [-1.0, 1.0]) {
      p.fs(
          p.fp()
              .m(0.17 + s * 0.008, 0.088)
              .c(0.17 + s * 0.045, 0.085, 0.17 + s * 0.06, 0.05,
                  0.17 + s * 0.045, 0.032)
              .c(0.17 + s * 0.03, 0.05, 0.17 + s * 0.02, 0.07,
                  0.17 + s * 0.008, 0.088)
              .z(),
          gold,
          k: 0.75);
    }
    p.fs(p.oval(0.17, 0.095, 0.03, 0.008), goldDeep, k: 0.6);
    p.c.restore();
  }

  void _axe(_Pen p, double x) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.162, 0.03).l(0.178, 0.03).l(0.178, 0.45).l(0.162, 0.45).z(),
        wood, k: 0.7);
    p.fs(
        p.fp()
            .m(0.178, 0.06)
            .c(0.27, 0.03, 0.31, 0.10, 0.285, 0.18)
            .c(0.25, 0.205, 0.21, 0.185, 0.178, 0.165)
            .z(),
        steel,
        k: 0.8);
    p.st(p.fp().m(0.19, 0.075).c(0.25, 0.06, 0.28, 0.11, 0.268, 0.168).open,
        steelDark, k: 0.5);
    p.fs(p.fp().m(0.162, 0.07).l(0.122, 0.10).l(0.162, 0.13).z(), steel, k: 0.7);
    p.fs(p.fp().m(0.166, 0.0).l(0.178, 0.034).l(0.162, 0.034).z(), steel, k: 0.6);
    p.fs(p.fp().m(0.158, 0.16).l(0.182, 0.16).l(0.182, 0.176).l(0.158, 0.176).z(),
        gold, k: 0.6);
    p.c.restore();
  }

  void _sceptreOrb(_Pen p, double x) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.163, 0.12).l(0.177, 0.12).l(0.177, 0.45).l(0.163, 0.45).z(),
        wood, k: 0.7);
    for (final y in [0.2, 0.28, 0.36]) {
      p.fs(p.oval(0.17, y, 0.014, 0.008), gold, k: 0.5);
    }
    p.fs(p.oval(0.17, 0.088, 0.038, 0.026), gold, k: 0.8);
    p.st(p.fp().m(0.132, 0.088).q(0.17, 0.104, 0.208, 0.088).open, goldDeep, k: 0.6);
    p.st(p.fp().m(0.17, 0.062).q(0.158, 0.088, 0.17, 0.114).open, goldDeep, k: 0.5);
    p.st(p.fp().m(0.17, 0.062).l(0.17, 0.018).open, ink, k: 1.9);
    p.st(p.fp().m(0.17, 0.062).l(0.17, 0.018).open, gold, k: 1.1);
    p.st(p.fp().m(0.153, 0.035).l(0.187, 0.035).open, ink, k: 1.9);
    p.st(p.fp().m(0.153, 0.035).l(0.187, 0.035).open, gold, k: 1.1);
    p.c.restore();
  }

  // ---------------------------------------------------------------------------
  // KIZ (QUEEN)
  // ---------------------------------------------------------------------------
  void _queen(_Pen p, Color main, Color accent) {
    final Color hair = const [
      Color(0xFF4A3322),
      Color(0xFF94642C),
      Color(0xFFB48A3E),
      Color(0xFF2E2420),
    ][sv];
    final Color hairLight = Color.lerp(hair, ivory, 0.35)!;

    // Arka saç / duvak
    _headBegin(p);
    if (sv == 3) {
      final veil = p.fp()
          .m(0.41, 0.14)
          .c(0.33, 0.21, 0.32, 0.32, 0.29, 0.40)
          .l(0.71, 0.40)
          .c(0.68, 0.32, 0.67, 0.21, 0.59, 0.14)
          .z();
      p.c.drawPath(veil, Paint()..color = ivory.withOpacity(0.75));
      p.st(veil, ink.withOpacity(0.7), k: 0.5);
      for (final x in [0.36, 0.42, 0.58, 0.64]) {
        p.st(p.fp().m(x, 0.2).l(x + (x - 0.5) * 0.25, 0.39).open,
            ink.withOpacity(0.25), k: 0.3);
      }
    }
    p.fs(
      p.fp()
          .m(0.40, 0.16)
          .c(0.34, 0.22, 0.35, 0.31, 0.38, 0.345)
          .l(0.62, 0.345)
          .c(0.65, 0.31, 0.66, 0.22, 0.60, 0.16)
          .q(0.5, 0.10, 0.40, 0.16)
          .z(),
      hair,
      k: 0.75,
    );
    if (sv == 2) {
      // topuz
      p.fs(p.oval(0.5, 0.095, 0.075, 0.034), hair, k: 0.7);
      for (int i = -2; i <= 2; i++) {
        p.st(p.fp().m(0.5 + i * 0.025, 0.07).q(0.5 + i * 0.03, 0.095, 0.5 + i * 0.022, 0.12).open,
            hairLight, k: 0.4);
      }
    }
    _headEnd(p);

    // Elbise gövdesi
    final gown = _torso(p);
    p.fs(gown, main, k: 0.9);
    _pattern(p, gown, gold.withOpacity(0.6));

    // Korsaj (stomacher)
    final bodice = p.fp().m(0.405, 0.335).l(0.595, 0.335).l(0.55, 0.66)
        .l(0.45, 0.66).z();
    p.fs(bodice, gold, k: 0.75);
    _lattice(p, bodice, goldDeep, 0.045);
    for (double t = 0.1; t <= 1.0; t += 0.18) {
      for (final s in [-1.0, 1.0]) {
        final o = Offset.lerp(p.p(0.5 + s * 0.085, 0.34), p.p(0.5 + s * 0.045, 0.64), t)!;
        p.c.drawCircle(o, math.max(0.35, p.w * 0.009), Paint()..color = ivory);
        p.c.drawCircle(
            o,
            math.max(0.35, p.w * 0.009),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = ink
              ..strokeWidth = p.lw * 0.4);
      }
    }

    _sleeves(p, accent, style: sv == 0 ? 1 : (sv == 2 ? 2 : 0));

    // Boyun ve dekolte
    p.fs(
      p.fp().m(0.455, 0.24).l(0.545, 0.24).l(0.575, 0.31)
          .q(0.5, 0.36, 0.425, 0.31).z(),
      skin,
      k: 0.7,
    );
    p.st(p.fp().m(0.46, 0.285).q(0.5, 0.30, 0.54, 0.285).open,
        ink.withOpacity(0.3), k: 0.35);

    // Dantel yaka (kupa ve karo)
    if (sv == 1 || sv == 2) {
      for (final s in [-1.0, 1.0]) {
        final lace = p.fp()
            .m(0.5 + s * 0.06, 0.32)
            .c(0.5 + s * 0.10, 0.27, 0.5 + s * 0.13, 0.22, 0.5 + s * 0.115, 0.19)
            .c(0.5 + s * 0.15, 0.24, 0.5 + s * 0.17, 0.30, 0.5 + s * 0.15, 0.345)
            .q(0.5 + s * 0.10, 0.33, 0.5 + s * 0.06, 0.32)
            .z();
        p.fs(lace, ivory, k: 0.6);
        for (final t in [0.25, 0.5, 0.75]) {
          p.c.drawCircle(
              Offset.lerp(p.p(0.5 + s * 0.12, 0.215), p.p(0.5 + s * 0.15, 0.335), t)!,
              math.max(0.3, p.w * 0.005),
              Paint()..color = ink.withOpacity(0.6));
        }
      }
    }

    // İnci kolye
    final a = p.p(0.436, 0.31), b = p.p(0.5, 0.348), c = p.p(0.564, 0.31);
    for (int i = 0; i <= 10; i++) {
      final o = _quadPt(a, b, c, i / 10);
      p.c.drawCircle(o, math.max(0.4, p.w * 0.0082), Paint()..color = ivory);
      p.c.drawCircle(
          o,
          math.max(0.4, p.w * 0.0082),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = ink.withOpacity(0.7)
            ..strokeWidth = p.lw * 0.35);
    }
    p.fs(p.oval(0.5, 0.350, 0.014, 0.010), accent, k: 0.5);

    // Yan perçemler + yüz
    _headBegin(p);
    for (final s in [-1.0, 1.0]) {
      final lock = p.fp()
          .m(0.5 + s * 0.085, 0.20)
          .c(0.5 + s * 0.125, 0.25, 0.5 + s * 0.115, 0.31, 0.5 + s * 0.09, 0.352)
          .q(0.5 + s * 0.072, 0.30, 0.5 + s * 0.068, 0.22)
          .z();
      p.fs(lock, hair, k: 0.65);
      for (final dx in [0.082, 0.098, 0.112]) {
        p.st(
            p.fp()
                .m(0.5 + s * dx, 0.215)
                .q(0.5 + s * (dx + 0.012), 0.28, 0.5 + s * (dx - 0.014), 0.335)
                .open,
            hairLight,
            k: 0.35);
      }
      if (sv == 1) {
        // bukleler
        for (final y in [0.26, 0.30]) {
          p.c.drawCircle(
              p.p(0.5 + s * 0.112, y),
              p.w * 0.013,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = ink
                ..strokeWidth = p.lw * 0.45);
        }
      }
    }

    _face(p, cx: 0.5, cy: 0.196, rx: 0.074, ry: 0.062, lips: true, lashes: true);

    // Alın saçı (ortadan ayrık)
    p.fs(
      p.fp()
          .m(0.424, 0.185)
          .c(0.424, 0.145, 0.47, 0.132, 0.5, 0.150)
          .c(0.53, 0.132, 0.576, 0.145, 0.576, 0.185)
          .c(0.56, 0.160, 0.53, 0.158, 0.5, 0.166)
          .c(0.47, 0.158, 0.44, 0.160, 0.424, 0.185)
          .z(),
      hair,
      k: 0.6,
    );
    for (final s in [-1.0, 1.0]) {
      p.st(p.fp().m(0.5 + s * 0.01, 0.152).q(0.5 + s * 0.045, 0.145, 0.5 + s * 0.07, 0.178).open,
          hairLight, k: 0.35);
    }

    _queenCrown(p, accent);
    _headEnd(p);

    _queenObject(p, accent);
    _hand(p, 0.83, 0.494);_hand(p, 0.17, 0.494);

    _pip(p, 0.155, 0.075, 0.12);
  }

  void _queenCrown(_Pen p, Color accent) {
    switch (sv) {
      case 0: // sivri diadem
        final tiara = p.fp()
            .m(0.410, 0.144)
            .l(0.420, 0.094)
            .l(0.452, 0.120)
            .l(0.478, 0.066)
            .l(0.5, 0.036)
            .l(0.522, 0.066)
            .l(0.548, 0.120)
            .l(0.580, 0.094)
            .l(0.590, 0.144)
            .q(0.5, 0.130, 0.410, 0.144)
            .z();
        p.fs(tiara, gold, k: 0.75);
        for (final t in [
          [0.420, 0.094], [0.478, 0.066], [0.5, 0.036], [0.522, 0.066], [0.580, 0.094]
        ]) {
          p.fs(p.oval(t[0], t[1], 0.011, 0.0075), ivory, k: 0.45);
        }
        p.fs(p.oval(0.5, 0.126, 0.016, 0.010), accent, k: 0.5);
        break;
      case 1: // inci kemeri
        final band = p.fp().m(0.412, 0.145).q(0.5, 0.132, 0.588, 0.145)
            .l(0.586, 0.158).q(0.5, 0.146, 0.414, 0.158).z();
        p.fs(band, gold, k: 0.7);
        final a = p.p(0.414, 0.140), b = p.p(0.5, 0.040), c = p.p(0.586, 0.140);
        for (int i = 0; i <= 8; i++) {
          final o = _quadPt(a, b, c, i / 8);
          p.c.drawCircle(o, math.max(0.45, p.w * 0.0105), Paint()..color = ivory);
          p.c.drawCircle(
              o,
              math.max(0.45, p.w * 0.0105),
              Paint()
                ..style = PaintingStyle.stroke
                ..color = ink
                ..strokeWidth = p.lw * 0.45);
        }
        p.st(p.fp().m(0.414, 0.140).q(0.5, 0.040, 0.586, 0.140).open, goldDeep, k: 0.6);
        p.fs(p.oval(0.5, 0.036, 0.015, 0.011), accent, k: 0.5);
        break;
      case 2: // kokoşnik (yelpaze) taç
        final fan = p.fp()
            .m(0.402, 0.148)
            .c(0.392, 0.07, 0.45, 0.045, 0.5, 0.045)
            .c(0.55, 0.045, 0.608, 0.07, 0.598, 0.148)
            .q(0.5, 0.132, 0.402, 0.148)
            .z();
        p.fs(fan, gold, k: 0.75);
        p.c.save();
        p.c.clipPath(fan);
        for (int i = -4; i <= 4; i++) {
          p.st(p.fp().m(0.5, 0.15).l(0.5 + i * 0.026, 0.03).open, goldDeep, k: 0.4);
        }
        p.c.restore();
        for (int i = -3; i <= 3; i++) {
          final x = 0.5 + i * 0.03;
          p.c.drawCircle(p.p(x, 0.047 + i * i * 0.0036), math.max(0.4, p.w * 0.0085),
              Paint()..color = ivory);
        }
        p.fs(p.oval(0.5, 0.118, 0.017, 0.011), accent, k: 0.5);
        break;
      default: // üç yapraklı taç
        for (final t in [
          [0.44, 0.092, 0.020], [0.5, 0.062, 0.025], [0.56, 0.092, 0.020]
        ]) {
          p.fs(p.oval(t[0], t[1], t[2], t[2] * 0.75), gold, k: 0.7);
          p.st(p.fp().m(t[0], t[1] + t[2] * 0.5).l(t[0], 0.138).open, goldDeep, k: 0.8);
        }
        final band = p.fp().m(0.412, 0.130).l(0.588, 0.130).l(0.586, 0.158)
            .l(0.414, 0.158).z();
        p.fs(band, gold, k: 0.7);
        p.fs(p.oval(0.5, 0.144, 0.017, 0.010), accent, k: 0.5);
        for (final x in [0.445, 0.555]) {
          p.c.drawCircle(p.p(x, 0.144), math.max(0.4, p.w * 0.007),
              Paint()..color = ivory);
        }
    }
  }

  void _queenObject(_Pen p, Color accent) {
    switch (sv) {
      case 0: // zambak
        p.st(p.fp().m(0.83, 0.47).q(0.865, 0.34, 0.80, 0.22).open, leafGreen, k: 1.8);
        p.fs(p.fp().m(0.835, 0.36).q(0.89, 0.32, 0.905, 0.355).q(0.87, 0.385, 0.835, 0.36).z(),
            leafGreen, k: 0.6);
        final lc = p.p(0.80, 0.19);
        for (final ang in [-math.pi / 2, -math.pi / 2 - 0.9, -math.pi / 2 + 0.9]) {
          final tip = lc + Offset(math.cos(ang) * p.w * 0.075, math.sin(ang) * p.h * 0.055);
          final petal = Path()
            ..moveTo(lc.dx, lc.dy + p.h * 0.02)
            ..quadraticBezierTo(
                lc.dx + (tip.dx - lc.dx) * 0.9 + p.w * 0.03, lc.dy + (tip.dy - lc.dy) * 0.5,
                tip.dx, tip.dy)
            ..quadraticBezierTo(
                lc.dx + (tip.dx - lc.dx) * 0.9 - p.w * 0.03, lc.dy + (tip.dy - lc.dy) * 0.5,
                lc.dx, lc.dy + p.h * 0.02)
            ..close();
          p.c.drawPath(petal, Paint()..color = ivory);
          p.st(petal, ink, k: 0.55);
        }
        p.c.drawCircle(lc + Offset(0, p.h * 0.012), p.w * 0.012,
            Paint()..color = gold);
        break;
      case 1: // gül
        _rose(p, 0.795, 0.195);
        break;
      case 2: // asa + mücevher
        p.fs(p.fp().m(0.822, 0.12).l(0.838, 0.12).l(0.838, 0.46).l(0.822, 0.46).z(),
            gold, k: 0.8);
        for (final y in [0.2, 0.3, 0.4]) {
          p.st(p.fp().m(0.822, y).l(0.838, y).open, goldDeep, k: 0.55);
        }
        p.fs(p.oval(0.83, 0.088, 0.038, 0.026), gold, k: 0.8);
        p.fs(p.oval(0.83, 0.088, 0.022, 0.015), accent, k: 0.55);
        for (final s in [-1.0, 1.0]) {
          p.fs(p.oval(0.83 + s * 0.046, 0.088, 0.008, 0.006), ivory, k: 0.4);
        }
        p.fs(p.oval(0.83, 0.052, 0.009, 0.007), ivory, k: 0.4);
        break;
      default: // yelpaze
        p.st(p.fp().m(0.83, 0.47).l(0.81, 0.27).open, goldDeep, k: 2.0);
        final fanC = p.p(0.81, 0.27);
        final fan = Path()..moveTo(fanC.dx, fanC.dy);
        for (int i = 0; i <= 6; i++) {
          final ang = -math.pi / 2 - 0.95 + i * 1.9 / 6;
          fan.lineTo(fanC.dx + math.cos(ang) * p.w * 0.16,
              fanC.dy + math.sin(ang) * p.h * 0.16);
        }
        fan.close();
        p.c.drawPath(fan, Paint()..color = ivory);
        p.st(fan, ink, k: 0.8);
        for (int i = 1; i < 6; i++) {
          final ang = -math.pi / 2 - 0.95 + i * 1.9 / 6;
          p.c.drawLine(
              fanC,
              fanC + Offset(math.cos(ang) * p.w * 0.16, math.sin(ang) * p.h * 0.16),
              Paint()
                ..color = i.isOdd ? gold : ink.withOpacity(0.5)
                ..strokeWidth = p.lw * 0.45);
        }
        p.c.drawCircle(fanC, p.w * 0.014, Paint()..color = gold);
    }
  }

  void _rose(_Pen p, double x, double y) {
    p.st(p.fp().m(0.83, 0.47).q(0.865, 0.34, x - 0.01, y + 0.02).open, leafGreen, k: 1.8);
    p.fs(p.fp().m(0.835, 0.35).q(0.89, 0.31, 0.905, 0.345).q(0.87, 0.375, 0.835, 0.35).z(),
        leafGreen, k: 0.6);
    p.fs(p.fp().m(x, 0.29).q(x - 0.06, 0.26, x - 0.075, 0.29).q(x - 0.04, 0.315, x, 0.29).z(),
        leafGreen, k: 0.6);
    final rc = p.p(x, y);
    final petal = Paint()..color = const Color(0xFFB42A35);
    for (int i = 0; i < 6; i++) {
      final ang = i * math.pi / 3;
      final o = rc + Offset(math.cos(ang) * p.w * 0.028, math.sin(ang) * p.h * 0.020);
      p.c.drawCircle(o, p.w * 0.028, petal);
    }
    p.c.drawCircle(rc, p.w * 0.034, Paint()..color = const Color(0xFF8E1C26));
    p.st(
        p.fp().m(x - 0.01, y - 0.003).q(x, y - 0.015, x + 0.012, y).q(x, y + 0.015, x - 0.012, y + 0.003).open,
        const Color(0xFFE07A80),
        k: 0.6);
    p.c.drawCircle(
        rc,
        p.w * 0.058,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ink.withOpacity(0.6)
          ..strokeWidth = p.lw * 0.5);
  }

  // ---------------------------------------------------------------------------
  // VALE (JACK)
  // ---------------------------------------------------------------------------
  void _jack(_Pen p, Color main, Color accent) {
    final Color hair = const [
      Color(0xFF7A5230),
      Color(0xFF3B2A1C),
      Color(0xFFB08A45),
      Color(0xFF2E2420),
    ][sv];
    final Color hairLight = Color.lerp(hair, ivory, 0.4)!;

    // Duble (gövde)
    final tunic = _torso(p);
    p.fs(tunic, main, k: 0.9);
    _pattern(p, tunic, gold.withOpacity(0.45));

    // Çapraz kuşak (baldric)
    p.c.save();
    p.c.clipPath(tunic);
    final sashDir = sv.isEven ? 1.0 : -1.0;
    final sash = p.fp()
        .m(0.5 - sashDir * 0.20, 0.33)
        .l(0.5 - sashDir * 0.11, 0.33)
        .l(0.5 + sashDir * 0.30, 0.66)
        .l(0.5 + sashDir * 0.19, 0.66)
        .z();
    p.fs(sash, accent, k: 0.7);
    p.st(
        p.fp()
            .m(0.5 - sashDir * 0.185, 0.33)
            .l(0.5 + sashDir * 0.205, 0.66)
            .open,
        gold,
        k: 0.9);
    p.c.restore();
    // Düğme sırası
    p.st(p.fp().m(0.5, 0.325).l(0.5, 0.66).open, ink.withOpacity(0.5), k: 0.45);
    for (final y in [0.36, 0.40, 0.44, 0.48, 0.52]) {
      p.fs(p.oval(0.5, y, 0.011, 0.0075), gold, k: 0.5);
    }

    _sleeves(p, accent, style: sv == 0 || sv == 2 ? 1 : 2);

    // Boyun
    p.fs(p.fp().m(0.46, 0.24).l(0.54, 0.24).l(0.545, 0.315).l(0.455, 0.315).z(),
        skin, k: 0.7);
    p.st(p.fp().m(0.465, 0.285).q(0.5, 0.298, 0.535, 0.285).open,
        ink.withOpacity(0.3), k: 0.35);

    // Fırfırlı yaka (ruff)
    const int n = 16;
    double baseY(double x) => 0.306 + 0.7 * (x - 0.5) * (x - 0.5);
    final ruff = Path();
    for (int i = 0; i <= n; i++) {
      final x = 0.355 + 0.29 * i / n;
      final y = baseY(x) - (i.isOdd ? 0.022 : 0.006);
      i == 0 ? ruff.moveTo(x * p.w, y * p.h) : ruff.lineTo(x * p.w, y * p.h);
    }
    for (int i = n; i >= 0; i--) {
      final x = 0.355 + 0.29 * i / n;
      final y = baseY(x) + (i.isOdd ? 0.022 : 0.008);
      ruff.lineTo(x * p.w, y * p.h);
    }
    ruff.close();
    p.fs(ruff, ivory, k: 0.65);
    for (int i = 1; i < n; i += 2) {
      final x = 0.355 + 0.29 * i / n;
      p.st(p.fp().m(x, baseY(x) - 0.018).l(x, baseY(x) + 0.018).open,
          ink.withOpacity(0.45), k: 0.35);
    }

    // Saç ve yüz
    _headBegin(p);
    final hairCap = p.fp()
        .m(0.405, 0.205)
        .c(0.395, 0.12, 0.45, 0.10, 0.5, 0.10)
        .c(0.55, 0.10, 0.605, 0.12, 0.595, 0.205)
        .c(0.60, 0.23, 0.60, 0.25, 0.585, 0.262)
        .c(0.58, 0.22, 0.57, 0.17, 0.5, 0.165)
        .c(0.43, 0.17, 0.42, 0.22, 0.415, 0.262)
        .c(0.40, 0.25, 0.40, 0.23, 0.405, 0.205)
        .z();
    p.fs(hairCap, hair, k: 0.75);
    for (final s in [-1.0, 1.0]) {
      for (final dy in [0.21, 0.235]) {
        p.st(
            p.fp()
                .m(0.5 + s * 0.092, dy)
                .q(0.5 + s * 0.10, dy + 0.02, 0.5 + s * 0.088, dy + 0.035)
                .open,
            hairLight,
            k: 0.35);
      }
    }

    _face(p, cx: 0.5, cy: 0.200, rx: 0.072, ry: 0.060);

    // İnce bıyık (sinekte yok: temiz yüz)
    if (sv != 3) {
      p.st(p.fp().m(0.476, 0.228).q(0.5, 0.222, 0.524, 0.228).open, hair, k: 0.85);
    }
    // Perçem
    p.fs(
      p.fp()
          .m(0.428, 0.185)
          .c(0.43, 0.15, 0.47, 0.138, 0.5, 0.142)
          .c(0.54, 0.138, 0.57, 0.15, 0.572, 0.185)
          .c(0.55, 0.162, 0.52, 0.158, 0.5, 0.166)
          .c(0.48, 0.158, 0.45, 0.162, 0.428, 0.185)
          .z(),
      hair,
      k: 0.6,
    );

    _jackHat(p, accent, hair);
    _headEnd(p);

    // Takıma özgü silah / nesne
    switch (sv) {
      case 0:
        _halberd(p, 0.17);
        break;
      case 1:
        _sword(p, 0.17, red);
        break;
      case 2:
        _pike(p, 0.17, accent);
        break;
      default:
        _staff(p, 0.17);
    }
    _hand(p, 0.17, 0.494);_hand(p, 0.83, 0.494);

    _pip(p, 0.855, 0.27, 0.11);
  }

  void _jackHat(_Pen p, Color accent, Color hair) {
    switch (sv) {
      case 0: // Bere + tüy
        p.fs(p.oval(0.48, 0.112, 0.122, 0.040), accent, k: 0.85);
        final brim = p.fp().m(0.40, 0.128).q(0.5, 0.114, 0.60, 0.128)
            .l(0.60, 0.148).q(0.5, 0.134, 0.40, 0.148).z();
        p.fs(brim, gold, k: 0.7);
        p.fs(p.oval(0.5, 0.135, 0.012, 0.0075), red, k: 0.5);
        _plume(p, 1.0);
        break;
      case 1: // Düz şapka + sol tüy
        p.fs(p.oval(0.5, 0.115, 0.118, 0.034), accent, k: 0.85);
        final brim = p.fp().m(0.395, 0.130).q(0.5, 0.118, 0.605, 0.130)
            .l(0.607, 0.150).q(0.5, 0.138, 0.393, 0.150).z();
        p.fs(brim, gold, k: 0.7);
        p.fs(p.oval(0.44, 0.138, 0.012, 0.0075), red, k: 0.5);
        _plume(p, -1.0);
        break;
      case 2: // Yüksek şapka (toque)
        final body = p.fp().m(0.408, 0.136).l(0.424, 0.046)
            .q(0.5, 0.034, 0.576, 0.046).l(0.592, 0.136).z();
        p.fs(body, accent, k: 0.85);
        p.st(p.fp().m(0.424, 0.046).q(0.5, 0.062, 0.576, 0.046).open, ink, k: 0.6);
        for (final x in [0.45, 0.5, 0.55]) {
          p.st(p.fp().m(x, 0.06).l(x + (x - 0.5) * 0.15, 0.125).open,
              gold.withOpacity(0.7), k: 0.5);
        }
        final band = p.fp().m(0.407, 0.118).l(0.593, 0.118).l(0.592, 0.140)
            .l(0.408, 0.140).z();
        p.fs(band, gold, k: 0.7);
        p.fs(p.oval(0.5, 0.129, 0.013, 0.009), red, k: 0.5);
        final brim = p.fp().m(0.385, 0.140).q(0.5, 0.130, 0.615, 0.140)
            .q(0.5, 0.158, 0.385, 0.140).z();
        p.fs(brim, goldDeep, k: 0.7);
        break;
      default: // Defne çelengi
        for (int i = 0; i <= 8; i++) {
          final t = i / 8;
          final o = _quadPt(p.p(0.405, 0.165), p.p(0.5, 0.062), p.p(0.595, 0.165), t);
          for (final side in [-1.0, 1.0]) {
            final leaf = Path()
              ..addOval(Rect.fromCenter(
                  center: o + Offset(side * p.w * 0.008, -p.h * 0.006),
                  width: p.w * 0.032,
                  height: p.h * 0.014));
            p.c.save();
            p.c.translate(o.dx, o.dy);
            p.c.rotate((t - 0.5) * 1.9 + side * 0.35);
            p.c.translate(-o.dx, -o.dy);
            p.c.drawPath(leaf, Paint()..color = leafGreen);
            p.st(leaf, ink, k: 0.4);
            p.c.restore();
          }
        }
        p.fs(p.oval(0.5, 0.071, 0.010, 0.007), red, k: 0.5);
        // kurdele uçları
        for (final s in [-1.0, 1.0]) {
          p.fs(
              p.fp()
                  .m(0.5 + s * 0.092, 0.168)
                  .l(0.5 + s * 0.118, 0.205)
                  .l(0.5 + s * 0.100, 0.20)
                  .l(0.5 + s * 0.098, 0.232)
                  .l(0.5 + s * 0.082, 0.190)
                  .z(),
              gold,
              k: 0.5);
        }
    }
  }

  /// Şapka tüyü. s=+1 sağa, s=-1 sola doğru uzanır.
  void _plume(_Pen p, double s) {
    double X(double x) => s > 0 ? x : 1 - x;
    final b0 = p.p(X(0.565), 0.108), b3 = p.p(X(0.87), 0.176);
    final o1 = p.p(X(0.62), 0.02), o2 = p.p(X(0.78), 0.0);
    final i1 = p.p(X(0.78), 0.08), i2 = p.p(X(0.66), 0.07);
    final plume = Path()
      ..moveTo(b0.dx, b0.dy)
      ..cubicTo(o1.dx, o1.dy, o2.dx, o2.dy, b3.dx, b3.dy)
      ..cubicTo(i1.dx, i1.dy, i2.dx, i2.dy, b0.dx, b0.dy)
      ..close();
    p.c.drawPath(plume, Paint()..color = const Color(0xFFF3E6C2));
    final r1 = p.p(X(0.64), 0.05), r2 = p.p(X(0.78), 0.04);
    for (int k = 1; k < 11; k++) {
      final t = k / 11;
      final rib = _cubicPt(b0, r1, r2, b3, t);
      final out = _cubicPt(b0, o1, o2, b3, t);
      p.c.drawLine(rib, Offset.lerp(rib, out, 0.92)!,
          Paint()
            ..color = goldDeep.withOpacity(0.7)
            ..strokeWidth = p.lw * 0.4);
    }
    p.c.drawPath(
        Path()
          ..moveTo(b0.dx, b0.dy)
          ..cubicTo(r1.dx, r1.dy, r2.dx, r2.dy, b3.dx, b3.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = goldDeep
          ..strokeWidth = p.lw * 0.65);
    p.st(plume, ink, k: 0.65);
  }

  // Vale nesneleri
  void _halberd(_Pen p, double x) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.162, 0.03).l(0.178, 0.03).l(0.178, 0.49).l(0.162, 0.49).z(),
        wood, k: 0.65);
    p.fs(p.fp().m(0.17, 0.0).l(0.183, 0.048).l(0.157, 0.048).z(), steel, k: 0.65);
    p.fs(p.fp().m(0.178, 0.056).q(0.262, 0.05, 0.284, 0.124)
        .q(0.234, 0.104, 0.178, 0.12).z(), steel, k: 0.75);
    p.st(p.fp().m(0.19, 0.067).q(0.245, 0.07, 0.267, 0.11).open, steelDark, k: 0.45);
    p.fs(p.fp().m(0.162, 0.07).l(0.114, 0.088).l(0.162, 0.104).z(), steel, k: 0.65);
    p.fs(p.fp().m(0.157, 0.12).l(0.183, 0.12).l(0.183, 0.134).l(0.157, 0.134).z(),
        gold, k: 0.55);
    p.c.restore();
  }

  void _pike(_Pen p, double x, Color flag) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.163, 0.06).l(0.177, 0.06).l(0.177, 0.49).l(0.163, 0.49).z(),
        wood, k: 0.65);
    p.fs(
        p.fp()
            .m(0.17, 0.0)
            .c(0.195, 0.03, 0.195, 0.05, 0.185, 0.07)
            .l(0.155, 0.07)
            .c(0.145, 0.05, 0.145, 0.03, 0.17, 0.0)
            .z(),
        steel,
        k: 0.7);
    p.st(p.fp().m(0.17, 0.012).l(0.17, 0.068).open, steelDark, k: 0.4);
    p.fs(p.fp().m(0.154, 0.070).l(0.186, 0.070).l(0.186, 0.082).l(0.154, 0.082).z(),
        gold, k: 0.55);
    // Flama
    final pen = p.fp()
        .m(0.178, 0.09)
        .c(0.22, 0.075, 0.26, 0.11, 0.30, 0.095)
        .l(0.28, 0.125)
        .l(0.30, 0.15)
        .c(0.26, 0.165, 0.22, 0.130, 0.178, 0.15)
        .z();
    p.fs(pen, flag, k: 0.7);
    p.st(p.fp().m(0.19, 0.12).q(0.24, 0.115, 0.285, 0.122).open, gold, k: 0.7);
    p.c.restore();
  }

  void _staff(_Pen p, double x) {
    final dx = x - 0.17;
    p.c.save();
    p.c.translate(dx * p.w, 0);
    p.fs(p.fp().m(0.164, 0.09).l(0.176, 0.09).l(0.176, 0.49).l(0.164, 0.49).z(),
        wood, k: 0.65);
    p.fs(p.oval(0.17, 0.065, 0.026, 0.017), gold, k: 0.75);
    p.st(p.fp().m(0.145, 0.065).q(0.17, 0.078, 0.195, 0.065).open, goldDeep, k: 0.45);
    p.fs(p.oval(0.17, 0.034, 0.014, 0.010), gold, k: 0.6);
    // Püskül
    p.st(p.fp().m(0.176, 0.12).q(0.215, 0.14, 0.205, 0.20).open, red, k: 1.6);
    p.st(p.fp().m(0.176, 0.12).q(0.195, 0.15, 0.185, 0.20).open, gold, k: 1.2);
    p.fs(p.oval(0.205, 0.205, 0.012, 0.009), gold, k: 0.5);
    p.c.restore();
  }

  @override
  bool shouldRepaint(covariant CourtCardPainter oldDelegate) =>
      oldDelegate.rank != rank || oldDelegate.suit != suit;
}

/// Kesirli koordinatlarla çizim yardımcısı.
class _Pen {
  final Canvas c;
  final double w, h, lw;

  _Pen(this.c, this.w, this.h) : lw = math.max(0.4, w * 0.011);

  Offset p(double x, double y) => Offset(x * w, y * h);

  _FP fp() => _FP(w, h);

  Path oval(double cx, double cy, double rx, double ry) => Path()
    ..addOval(Rect.fromCenter(
        center: p(cx, cy), width: rx * 2 * w, height: ry * 2 * h));

  void fs(Path path, Color fill, {double k = 1}) {
    if (k <= 0) return;
    c.drawPath(path, Paint()
      ..color = fill
      ..isAntiAlias = true);
    // 011D: daha ince, gravür tarzı kontur
    st(path, CourtCardPainter.ink, k: k * 0.85);
  }

  void st(Path path, Color color, {double k = 1}) {
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = lw * k
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }
}

class _FP {
  final Path path = Path();
  final double w, h;

  _FP(this.w, this.h);

  _FP m(double x, double y) {
    path.moveTo(x * w, y * h);
    return this;
  }

  _FP l(double x, double y) {
    path.lineTo(x * w, y * h);
    return this;
  }

  _FP q(double x1, double y1, double x, double y) {
    path.quadraticBezierTo(x1 * w, y1 * h, x * w, y * h);
    return this;
  }

  _FP c(double x1, double y1, double x2, double y2, double x, double y) {
    path.cubicTo(x1 * w, y1 * h, x2 * w, y2 * h, x * w, y * h);
    return this;
  }

  Path z() {
    path.close();
    return path;
  }

  Path get open => path;
}
