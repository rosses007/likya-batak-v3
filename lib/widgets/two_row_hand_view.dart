import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'realistic_playing_card.dart';

class TwoRowHandView extends StatefulWidget {
  final List<PlayingCard> hand;
  final bool isMyTurn;
  final bool Function(PlayingCard card) isCardValid;
  final Function(PlayingCard card) onPlayCard;
  final bool sortAscending;

  const TwoRowHandView({
    super.key,
    required this.hand,
    required this.isMyTurn,
    required this.isCardValid,
    required this.onPlayCard,
    this.sortAscending = true,
  });

  @override
  State<TwoRowHandView> createState() => _TwoRowHandViewState();
}

class _TwoRowHandViewState extends State<TwoRowHandView> {
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

    int total = sortedHand.length;
    int topRowCount = (total > 6) ? ((total + 1) ~/ 2) : total;
    List<PlayingCard> topRowCards = sortedHand.sublist(0, topRowCount);
    List<PlayingCard> bottomRowCards =
        (total > 6) ? sortedHand.sublist(topRowCount) : [];

    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        // Dinamik dev kart boyutları
        double cardWidth = (maxWidth * 0.18).clamp(76.0, 115.0);
        double cardHeight = cardWidth * 1.48;

        return SizedBox(
          height: bottomRowCards.isNotEmpty ? (cardHeight + cardHeight * 0.48 + 14) : (cardHeight + 14),
          width: maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. ÜST SIRA (Arka Sıra)
              _buildRow(
                cards: topRowCards,
                maxWidth: maxWidth,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                topOffset: 0,
              ),

              // 2. ALT SIRA (Ön Sıra)
              if (bottomRowCards.isNotEmpty)
                _buildRow(
                  cards: bottomRowCards,
                  maxWidth: maxWidth,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                  topOffset: cardHeight * 0.48,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow({
    required List<PlayingCard> cards,
    required double maxWidth,
    required double cardWidth,
    required double cardHeight,
    required double topOffset,
  }) {
    int count = cards.length;
    if (count == 0) return const SizedBox.shrink();

    double availableWidth = maxWidth - 20;
    double spacing = cardWidth;
    if (count > 1) {
      spacing = (availableWidth - cardWidth) / (count - 1);
      if (spacing > cardWidth * 0.95) spacing = cardWidth * 0.95;
    }

    double rowTotalWidth = (count == 1) ? cardWidth : ((count - 1) * spacing + cardWidth);
    double startX = (maxWidth - rowTotalWidth) / 2;

    return Positioned(
      top: topOffset,
      left: startX,
      width: rowTotalWidth,
      height: cardHeight + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(count, (index) {
          final card = cards[index];
          final isValid = widget.isCardValid(card);
          final isSelected = _selectedCard == card;

          return Positioned(
            left: index * spacing,
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
          );
        }),
      ),
    );
  }
}
