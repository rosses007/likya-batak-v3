import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'realistic_playing_card.dart';

class FannedHandView extends StatefulWidget {
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
  State<FannedHandView> createState() => _FannedHandViewState();
}

class _FannedHandViewState extends State<FannedHandView> {
  PlayingCard? _selectedCard;

  @override
  Widget build(BuildContext context) {
    if (widget.hand.isEmpty) {
      return const SizedBox(height: 150);
    }

    List<PlayingCard> sortedHand = List.from(widget.hand);
    sortedHand.sort((a, b) {
      if (a.suit != b.suit) {
        return a.suit.index.compareTo(b.suit.index);
      }
      return widget.sortAscending
          ? a.power.compareTo(b.power)
          : b.power.compareTo(a.power);
    });

    int count = sortedHand.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        // Dinamik dev kart boyutları (ekranın %18'i)
        double cardWidth = (maxWidth * 0.18).clamp(78.0, 115.0);
        double cardHeight = cardWidth * 1.48;

        double availableWidth = maxWidth - cardWidth - 12;
        double spacing = (count > 1) ? (availableWidth / (count - 1)) : 0;
        if (spacing > 30) spacing = 30; // Kartlar arasında ferah ve geniş boşluk

        double totalFanWidth = (count == 1) ? cardWidth : ((count - 1) * spacing + cardWidth);
        double startX = (maxWidth - totalFanWidth) / 2;

        double maxAngle = math.min(0.32, 0.045 * (count - 1));
        double angleStep = (count > 1) ? (2 * maxAngle / (count - 1)) : 0;

        return SizedBox(
          height: cardHeight + 35,
          width: maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: List.generate(count, (index) {
              final card = sortedHand[index];
              final isValid = widget.isCardValid(card);
              final isSelected = _selectedCard == card;

              double centerOffset = (count > 1) ? (index - (count - 1) / 2.0) : 0;
              double angle = centerOffset * angleStep;
              double curveY = (centerOffset.abs() * centerOffset.abs()) * 1.5;

              double leftPos = startX + index * spacing;
              double bottomPos = 10 - curveY + (isSelected ? 20 : 0);

              return Positioned(
                left: leftPos,
                bottom: bottomPos,
                child: Transform.rotate(
                  angle: angle,
                  alignment: Alignment.bottomCenter,
                  child: RealisticPlayingCardWidget(
                    card: card,
                    width: cardWidth,
                    height: cardHeight,
                    isSelected: isSelected,
                    isPlayable: !widget.isMyTurn || isValid,
                    onTap: () {
                      if (!widget.isMyTurn) {
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
                            content: Text("Geçersiz Hamle! Yerdeki renge uymalı veya koz atmalısınız."),
                            backgroundColor: Colors.redAccent,
                            duration: Duration(milliseconds: 1100),
                          ),
                        );
                        return;
                      }

                      widget.onPlayCard(card);
                    },
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
