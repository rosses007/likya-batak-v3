import 'dart:async';
import 'package:flutter/material.dart';

import '../models/card_model.dart';
import '../models/player_model.dart';
import '../engine/ai_engine.dart';
import '../engine/game_engine.dart';

/// GameState manages the entire match lifecycle.
/// It holds players, table cards, trump suit and the turn order.
/// The UI can listen to this class via [ChangeNotifier] (e.g. Provider)
/// to rebuild when the state changes.
class GameState extends ChangeNotifier {
  // ---------- Configuration ----------
  final List<Player> players; // 4 players – mix of AI & human
  final Suit trumpSuit;

  // ---------- Runtime state ----------
  int _currentPlayerIndex = 0; // whose turn is it now?
  final List<PlayingCard> _tableCards = [];

  GameState({
    required this.players,
    required this.trumpSuit,
  });

  // ----- Getters -----
  int get currentPlayerIndex => _currentPlayerIndex;
  Player get currentPlayer => players[_currentPlayerIndex];
  List<PlayingCard> get tableCards => List.unmodifiable(_tableCards);

  /// Starts a new round (clears table, resets turn to the player who won the previous trick).
  void startNewRound({int startingPlayerIndex = 0}) {
    _tableCards.clear();
    _currentPlayerIndex = startingPlayerIndex % players.length;
    notifyListeners();
  }

  /// Called by UI when a player (human) attempts to play a card.
  /// Returns true if the play was accepted.
  bool tryPlayCard(PlayingCard card) {
    // Validate with GameEngine rules.
    if (!GameEngine.isValidPlay(
      cardToPlay: card,
      player: currentPlayer,
      tableCards: _tableCards,
      trumpSuit: trumpSuit,
    )) {
      return false;
    }
    // Remove from hand and add to table.
    currentPlayer.hand.remove(card);
    _tableCards.add(card);
    // If four cards are on the table, resolve the trick.
    if (_tableCards.length == 4) {
      _resolveTrick();
    } else {
      _advanceTurn();
    }
    notifyListeners();
    return true;
  }

  /// Internal: move the turn to the next player.
  void _advanceTurn() {
    _currentPlayerIndex = (_currentPlayerIndex + 1) % players.length;
    // If the next player is a bot, trigger its move.
    if (players[_currentPlayerIndex].isAI) {
      _handleAIMove();
    }
  }

  /// Internal: resolve a trick and award it to the winner.
  void _resolveTrick() {
    int winningIdx = GameEngine.determineWinnerIndex(_tableCards, trumpSuit);
    // winningIdx is relative to the order of play in this trick.
    // Convert to absolute player index.
    int absoluteWinner = (_currentPlayerIndex + winningIdx) % players.length;
    players[absoluteWinner].tricksWon++;
    // Start next round with the winner leading.
    startNewRound(startingPlayerIndex: absoluteWinner);
  }

  /// Handles a bot's move with a 1‑second artificial delay.
  Future<void> _handleAIMove() async {
    // Artificial delay for realism.
    await Future.delayed(const Duration(seconds: 1));
    Player bot = currentPlayer;
    // Bot selects a legal card.
    PlayingCard chosen = AIEngine.chooseCard(
      bot: bot,
      tableCards: _tableCards,
      trumpSuit: trumpSuit,
    );
    // Play the chosen card.
    tryPlayCard(chosen);
  }
}
