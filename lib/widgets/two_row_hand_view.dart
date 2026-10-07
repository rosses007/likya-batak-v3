import 'package:flutter/material.dart';
import '../models/card_model.dart';
import 'fanned_hand_view.dart';

/// LIKYA-V2-010 | İki Sıra Katmanlı Kart Düzeni (8 + 8 Stacked Hand View)
///
/// Çapraz yelpaze geometrisini ve 8+8 üst üste katmanlı yapıyı FannedHandView ile
/// birebir uyumlu şekilde sunar.
class TwoRowHandView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FannedHandView(
      hand: hand,
      isMyTurn: isMyTurn,
      isCardValid: isCardValid,
      onPlayCard: onPlayCard,
      sortAscending: sortAscending,
    );
  }
}
