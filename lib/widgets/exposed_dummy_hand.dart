import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'realistic_playing_card.dart';

/// Compact face-up hand placed next to the dummy's seat.
class ExposedDummyHand extends StatelessWidget {
  final List<PlayingCard> hand;
  final bool isActive;
  final bool sideSeat;
  final Set<PlayingCard> validMoves;
  final ValueChanged<PlayingCard> onPlayCard;

  const ExposedDummyHand({
    super.key,
    required this.hand,
    required this.isActive,
    required this.sideSeat,
    required this.validMoves,
    required this.onPlayCard,
  });

  @override
  Widget build(BuildContext context) {
    final cards = List<PlayingCard>.of(hand)
      ..sort((a, b) {
        final suit = a.suit.index.compareTo(b.suit.index);
        return suit != 0 ? suit : a.power.compareTo(b.power);
      });
    final cardWidth = sideSeat ? 32.0 : 46.0;
    final cardHeight = sideSeat ? 46.0 : 65.0;
    final face = sideSeat
        ? Wrap(
            spacing: 1,
            runSpacing: 2,
            children: cards
                .map((card) => _card(card, cardWidth, cardHeight))
                .toList(),
          )
        : LayoutBuilder(builder: (context, constraints) {
            final step = cards.length <= 1
                ? 0.0
                : ((constraints.maxWidth - cardWidth) / (cards.length - 1))
                    .clamp(0.0, 25.0);
            final usedWidth = cardWidth + step * (cards.length - 1);
            return SizedBox(
              height: cardHeight,
              child: Stack(children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: (constraints.maxWidth - usedWidth) / 2 + i * step,
                    child: _card(cards[i], cardWidth, cardHeight),
                  ),
              ]),
            );
          });

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 5),
      decoration: BoxDecoration(
        color: const Color(0xE6221A14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color:
                isActive ? const Color(0xFFFFD54F) : const Color(0xFFC9A04A)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('AÇIK EL',
            style: TextStyle(
              fontSize: sideSeat ? 9 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: const Color(0xFFFFD54F),
            )),
        const SizedBox(height: 3),
        face,
      ]),
    );
  }

  Widget _card(PlayingCard card, double width, double height) {
    final playable = isActive && validMoves.contains(card);
    return RealisticPlayingCardWidget(
      card: card,
      width: width,
      height: height,
      isPlayable: playable,
      onTap: playable ? () => onPlayCard(card) : null,
    );
  }
}
