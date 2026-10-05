import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../services/websocket_service.dart';
import 'package:flutter/services.dart'; // Haptics
import 'package:audioplayers/audioplayers.dart'; // Audio effects

class MultiplayerGameProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final WebSocketService _wsService = WebSocketService();
  
  List<Player> players = [];
  List<PlayingCard> tableCards = [];
  Suit currentTrump = Suit.spades;
  int currentTurnIndex = 0;
  int myPosition = 0;
  String matchId = "";
  bool isGameOver = false;
  List<int> finalTricks = [];
  VoidCallback? onGameFinished;
  int? collectingWinnerIndex; // New: tracks who is currently collecting cards

  /// Sunucudan gelen başlangıç JSON verisini okur ve masayı kurar
  void initializeGame(Map<String, dynamic> data) {
    matchId = data["match_id"];
    myPosition = data["position"];
    currentTurnIndex = data["turn_index"];
    
    // Sunucudan gelen JSON kartları Dart nesnesine çevir
    List<dynamic> jsonHand = data["hand"];
    List<PlayingCard> myHand = jsonHand.map((c) => PlayingCard(
      suit: Suit.values[c["suit"]],
      rank: Rank.values[c["rank"]]
    )).toList();

    // 4 Oyuncuyu masaya yerleştir (Şimdilik diğerlerinin elini boş liste tutuyoruz, çünkü kapalı)
    List<dynamic> playerIds = data["players"];
    players = List.generate(4, (index) {
      return Player(
        id: playerIds[index],
        name: index == myPosition ? "Ben" : "Oyuncu ${index + 1}",
        hand: index == myPosition ? myHand : [], // Sadece kendi elimizi doldurduk
        isAI: false,
      );
    });

    // Oyuncunun kendi elini sırala (Daha önce yazdığımız sort algoritması)
    players[myPosition].sortHand();

    // Sunucudan anlık gelecek hamleleri dinlemeye başla
    _listenToServer();
    
    notifyListeners();
  }

  void _listenToServer() {
    _wsService.onMessageReceived = (data) {
      String type = data["type"];

      if (type == "card_played") {
        // Haptic and sound for card play
        HapticFeedback.lightImpact();
        _audioPlayer.play(AssetSource('sounds/card_slide.mp3'));

        // Başka biri (veya biz) kart attığında sunucu bunu herkese yayınlar
        int playerIndex = data["player_index"];
        PlayingCard playedCard = PlayingCard(
          suit: Suit.values[data["card"]["suit"]],
          rank: Rank.values[data["card"]["rank"]]
        );

        tableCards.add(playedCard);
        
        // Eğer kartı atan ben değilsem, rakibin görsel (kapalı) elinden 1 kart eksilt
        if (playerIndex != myPosition && players[playerIndex].hand.isNotEmpty) {
           players[playerIndex].hand.removeLast(); 
        }

        // Sırayı sonrakine geçir
        currentTurnIndex = (currentTurnIndex + 1) % 4;
        notifyListeners();
      }
      
      if (type == "round_winner") {
        int winnerIndex = data["winner_index"];
        List<dynamic> tricksWonArray = data["tricks_won"];

        if (winnerIndex == myPosition) {
          HapticFeedback.mediumImpact();
          _audioPlayer.play(AssetSource('sounds/chips_collect.mp3'));
        }

        // 1. Store winner index for animation
        collectingWinnerIndex = winnerIndex;
        notifyListeners();

        // 2. After animation delay, update state
        Future.delayed(const Duration(milliseconds: 600), () {
          // Update each player's trick count
          for (int i = 0; i < 4; i++) {
            players[i].tricksWon = tricksWonArray[i];
          }

          // Clear table cards
          tableCards.clear();

          // Reset animation flag
          collectingWinnerIndex = null;

          // Set turn to winner
          currentTurnIndex = winnerIndex;

          notifyListeners();
        });
      }

      if (type == "game_over") {
        isGameOver = true;
        if (data["tricks_won"] != null) {
          finalTricks = List<int>.from(data["tricks_won"]);
        }
        _wsService.disconnect();
        if (onGameFinished != null) {
          onGameFinished!();
        }
        notifyListeners();
      }
    };
  }

  /// Kullanıcı UI üzerinden kartı sürükleyip bıraktığında çalışır
  void sendCardPlayAction(PlayingCard card) {
    // 1. Kendi elimizden sil (Hızlı UI tepkisi - Optimistic UI update)
    players[myPosition].hand.remove(card);
    notifyListeners();

    // 2. Sunucuya JSON olarak gönder
    _wsService.sendAction({
      "type": "play_card",
      "match_id": matchId,
      "player_index": myPosition,
      "card": {
        "suit": card.suit.index,
        "rank": card.rank.index
      }
    });
  }
}
