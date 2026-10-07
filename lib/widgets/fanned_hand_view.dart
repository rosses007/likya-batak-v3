import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'realistic_playing_card.dart';

/// LIKYA-V2-010 | İki Katmanlı Çapraz Yelpaze Kart Düzeni (8 + 8 Stacked Hand View)
///
/// Kart sayısı > 8 ise: 2 katmanlı üst üste binen çapraz yelpaze (Üst katmanda en fazla 8, alt katmanda kalanlar).
/// Kart sayısı <= 8 ise: Tek sıra zarif çapraz yelpaze.
class FannedHandView extends StatelessWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final bool Function(PlayingCard card) isCardValid;
  final Function(PlayingCard card) onPlayCard;
  final bool sortAscending;

  const FannedHandView({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.isCardValid,
    required this.onPlayCard,
    this.sortAscending = true,
  });

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) {
      return const SizedBox(height: 150);
    }

    List<PlayingCard> sortedHand = List.from(hand);
    sortedHand.sort((a, b) {
      if (a.suit != b.suit) {
        return a.suit.index.compareTo(b.suit.index);
      }
      return sortAscending
          ? a.power.compareTo(b.power)
          : b.power.compareTo(a.power);
    });

    int count = sortedHand.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;

        // Kart sayısı <= 8 ise tek sıra zarif yelpaze
        if (count <= 8) {
          return _buildSingleRowFan(
            context: context,
            sortedHand: sortedHand,
            maxWidth: maxWidth,
          );
        }

        // Kart sayısı > 8 ise 2 katmanlı çapraz yelpaze (8 + 8 Stacked)
        return _buildTwoLayerStackedFan(
          context: context,
          sortedHand: sortedHand,
          maxWidth: maxWidth,
        );
      },
    );
  }

  /// TEK SIRA ZARİF YELPAZE (Elde 8 veya daha az kart kaldığında)
  Widget _buildSingleRowFan({
    required BuildContext context,
    required List<PlayingCard> sortedHand,
    required double maxWidth,
  }) {
    int count = sortedHand.length;
    double cardWidth = (maxWidth * 0.23).clamp(84.0, 120.0);
    double cardHeight = cardWidth * 1.42;

    double availableWidth = maxWidth - cardWidth - 12;
    double spacing = (count > 1) ? (availableWidth / (count - 1)) : 0;
    double maxSpacing = cardWidth * 0.65;
    if (spacing > maxSpacing) spacing = maxSpacing;
    if (spacing < 26) spacing = 26;

    double totalFanWidth =
        (count == 1) ? cardWidth : ((count - 1) * spacing + cardWidth);
    double startX = (maxWidth - totalFanWidth) / 2;

    double maxAngle = math.min(0.09, 0.010 * (count - 1));
    double angleStep = (count > 1) ? (2 * maxAngle / (count - 1)) : 0;

    List<Widget> cards = [];

    for (int index = 0; index < count; index++) {
      final card = sortedHand[index];

      double centerOffset =
          (count > 1) ? (index - (count - 1) / 2.0) : 0;
      double angle = centerOffset * angleStep;
      double curveY = (centerOffset * centerOffset) * 0.18;

      double leftPos = startX + index * spacing;
      double bottomPos = 12 - curveY;

      final cardWidget = Positioned(
        key: ValueKey('single_${card.suit.name}_${card.rank.name}'),
        left: leftPos,
        bottom: bottomPos,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: _buildCardWidget(context, card, cardWidth, cardHeight),
        ),
      );

      cards.add(cardWidget);
    }

    return SizedBox(
      height: cardHeight + 38,
      width: maxWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          ...cards,
        ],
      ),
    );
  }

  /// İKİ KATMANLI ÇAPRAZ YELPAZE (8 + 8 STACKED)
  ///
  /// Üst katman: En fazla 8 kart (Arka katmanda hafif yüksekte)
  /// Alt katman: Kalan kartlar (Ön katmanda hafif altta)
  /// Her iki katman da düz ızgara değil, zarif çapraz yelpaze açısına ve kavis derinliğine sahiptir.
  Widget _buildTwoLayerStackedFan({
    required BuildContext context,
    required List<PlayingCard> sortedHand,
    required double maxWidth,
  }) {
    int count = sortedHand.length;

    // Üst katman kart adedi (13 kart için 8 üst, 5 alt; 9-12 kart için dengeli dağılım)
    int topCount = (count >= 13) ? 8 : ((count + 1) ~/ 2);
    int bottomCount = count - topCount;

    List<PlayingCard> topCards = sortedHand.sublist(0, topCount);
    List<PlayingCard> bottomCards = sortedHand.sublist(topCount);

    // Kart boyutlandırması
    double cardWidth = (maxWidth * 0.215).clamp(72.0, 100.0);
    double cardHeight = cardWidth * 1.42;

    // Katmanlar arası dikey kayma: Üst sıranın üst ~45 pikseli (köşe indeksi + simgeler) tamamen görünür kalır
    double layerOffsetY = (cardHeight * 0.40).clamp(42.0, 50.0);
    double totalHeight = cardHeight + layerOffsetY + 30.0;

    // 1. Üst sıra yatay aralık & başlangıç konumu
    double availableWidthTop = maxWidth - cardWidth - 10;
    double topSpacing = (topCount > 1) ? (availableWidthTop / (topCount - 1)) : 0;
    double maxSpacingTop = cardWidth * 0.62;
    if (topSpacing > maxSpacingTop) topSpacing = maxSpacingTop;
    if (topSpacing < 28.0) topSpacing = 28.0;

    double totalTopWidth =
        (topCount == 1) ? cardWidth : ((topCount - 1) * topSpacing + cardWidth);
    double startXTop = (maxWidth - totalTopWidth) / 2;

    double maxAngleTop = math.min(0.07, 0.009 * (topCount - 1));
    double angleStepTop = (topCount > 1) ? (2 * maxAngleTop / (topCount - 1)) : 0;

    // 2. Alt sıra yatay aralık & başlangıç konumu
    double availableWidthBottom = maxWidth - cardWidth - 10;
    double bottomSpacing = (bottomCount > 1) ? (availableWidthBottom / (bottomCount - 1)) : 0;
    double maxSpacingBottom = cardWidth * 0.65;
    if (bottomSpacing > maxSpacingBottom) bottomSpacing = maxSpacingBottom;
    if (bottomSpacing < 30.0) bottomSpacing = 30.0;

    double totalBottomWidth =
        (bottomCount == 1) ? cardWidth : ((bottomCount - 1) * bottomSpacing + cardWidth);
    double startXBottom = (maxWidth - totalBottomWidth) / 2;

    double maxAngleBottom = math.min(0.07, 0.010 * (bottomCount - 1));
    double angleStepBottom = (bottomCount > 1) ? (2 * maxAngleBottom / (bottomCount - 1)) : 0;

    List<Widget> topLayerWidgets = [];
    List<Widget> bottomLayerWidgets = [];

    // Üst katman kartlarını konumlandır (Arka sıra)
    for (int i = 0; i < topCount; i++) {
      final card = topCards[i];

      double centerOffset = (topCount > 1) ? (i - (topCount - 1) / 2.0) : 0;
      double angle = centerOffset * angleStepTop;
      double curveY = (centerOffset * centerOffset) * 0.16;

      double leftPos = startXTop + i * topSpacing;
      double bottomPos = layerOffsetY + 4.0 - curveY;

      final widgetItem = Positioned(
        key: ValueKey('top_${card.suit.name}_${card.rank.name}'),
        left: leftPos,
        bottom: bottomPos,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: _buildCardWidget(context, card, cardWidth, cardHeight),
        ),
      );

      topLayerWidgets.add(widgetItem);
    }

    // Alt katman kartlarını konumlandır (Ön sıra)
    for (int i = 0; i < bottomCount; i++) {
      final card = bottomCards[i];

      double centerOffset = (bottomCount > 1) ? (i - (bottomCount - 1) / 2.0) : 0;
      double angle = centerOffset * angleStepBottom;
      double curveY = (centerOffset * centerOffset) * 0.18;

      double leftPos = startXBottom + i * bottomSpacing;
      double bottomPos = 4.0 - curveY;

      final widgetItem = Positioned(
        key: ValueKey('bottom_${card.suit.name}_${card.rank.name}'),
        left: leftPos,
        bottom: bottomPos,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: _buildCardWidget(context, card, cardWidth, cardHeight),
        ),
      );

      bottomLayerWidgets.add(widgetItem);
    }

    return SizedBox(
      height: totalHeight,
      width: maxWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Üst katman (Arka)
          ...topLayerWidgets,
          // 2. Alt katman (Ön)
          ...bottomLayerWidgets,
        ],
      ),
    );
  }

  /// Ortak Kart Bileşeni ve Dokunma Geri Bildirimi
  Widget _buildCardWidget(
    BuildContext context,
    PlayingCard card,
    double width,
    double height,
  ) {
    final isValid = isCardValid(card);

    return RealisticPlayingCardWidget(
      card: card,
      width: width,
      height: height,
      isPlayable: !isMyTurn || isValid,
      onTap: () {
        if (!isMyTurn) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sıra sizde değil!"),
              backgroundColor: Colors.orange,
              duration: Duration(milliseconds: 900),
            ),
          );
          return;
        }

        if (!isValid) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Geçersiz Hamle! Yerdeki renge uymalı veya koz atmalısınız."),
              backgroundColor: Colors.redAccent,
              duration: Duration(milliseconds: 1100),
            ),
          );
          return;
        }

        onPlayCard(card);
      },
    );
  }
}
