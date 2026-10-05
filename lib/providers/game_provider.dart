import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../models/deck.dart';
import '../engine/game_engine.dart';
import '../engine/ai_engine.dart';
import '../services/sound_service.dart';
import '../services/api_service.dart';

enum GamePhase {
  bidding,         // İhale Aşaması
  trumpSelection,  // Koz Seçimi
  playing,         // Kart Atma Aşaması
  trickFinished,   // El bitti (4 kart atıldı)
  roundFinished,   // Tur bitti (13 el bitti, puanlar hesaplandı)
  gameOver         // Tüm maç bitti (Örn: 5 turun 5'i de tamamlandı)
}

enum BatakGameMode {
  single,   // Tekli İhaleli Batak (Herkes tek)
  partner   // Eşli Batak (Siz & Arda vs Erol & Uğur)
}

enum HandLayoutMode {
  fanned,   // Çapraz / Yelpaze (2. Görseldeki gibi)
  twoRow    // İki Sıra (1. Görseldeki gibi)
}

enum TableColor {
  green,    // Zümrüt Yeşil Çuha
  blue,     // Kraliyet Mavisi
  red,      // Bordo Çuha
  dark      // Kömür Siyahı
}

class GameProvider extends ChangeNotifier {
  List<Player> players = [];
  List<PlayingCard> tableCards = [];
  Map<int, PlayingCard> playedCardsByPlayer = {};
  Suit currentTrump = Suit.spades;

  GamePhase currentPhase = GamePhase.bidding;
  BatakGameMode gameMode = BatakGameMode.single;
  HandLayoutMode handLayoutMode = HandLayoutMode.fanned;
  TableColor tableColor = TableColor.green;

  int currentTurnIndex = 0;
  int bidderIndex = 0;
  int tricksPlayed = 0; // 0..13

  // Tur & Maç Yönetimi (1 elden 7 ele kadar)
  int totalRounds = 5;
  int currentRound = 1;
  List<List<int>> roundScoresHistory = [];
  List<int> cumulativeScores = [0, 0, 0, 0];
  int roundCountdown = 3;

  // İhale Durumu
  int biddingTurnIndex = 0;
  int currentHighestBid = 4;
  int? highestBidderIndex;
  Set<int> passedPlayers = {};
  String statusMessage = "İhale Başladı!";

  // Ayarlar & İsimler
  String currentPlayerName = "Siz";
  List<String> botNames = ["Erol", "Arda", "Uğur"];
  bool sortAscending = true;
  double gameSpeed = 1.2; // Hızlı ve seri akış

  // Hızlı bot gecikmesi (300ms - 400ms civarı)
  int get delayBase => (380 / gameSpeed).round();

  GameProvider() {
    _initializeMatch();
  }

  void _initializeMatch({String? playerName}) {
    if (playerName != null && playerName.trim().isNotEmpty) {
      currentPlayerName = playerName.trim();
    }
    currentRound = 1;
    cumulativeScores = [0, 0, 0, 0];
    roundScoresHistory.clear();
    _startRound();
  }

  void _startRound() {
    Deck deck = Deck();
    deck.shuffle();
    List<List<PlayingCard>> hands = deck.dealCards();

    players = [
      Player(id: "1", name: currentPlayerName, isAI: false, hand: hands[0]),
      Player(id: "2", name: botNames[0], isAI: true, hand: hands[1]),
      Player(id: "3", name: botNames[1], isAI: true, hand: hands[2]),
      Player(id: "4", name: botNames[2], isAI: true, hand: hands[3]),
    ];

    tableCards.clear();
    playedCardsByPlayer.clear();
    tricksPlayed = 0;

    // Eşli batakta minimum ihale 8'dir, tekli batakta 4'tür (ilk teklif 5 veya 8)
    currentHighestBid = (gameMode == BatakGameMode.partner) ? 7 : 4;
    highestBidderIndex = null;
    passedPlayers.clear();

    // Kart dağıtanın solundaki oyuncudan ihale başlar
    biddingTurnIndex = (currentRound - 1) % 4;
    currentPhase = GamePhase.bidding;
    statusMessage = "Tur $currentRound / $totalRounds - İhale Başladı!";

    // Kart dağıtma sesi çal
    SoundService.playCardDeal();

    notifyListeners();

    if (players[biddingTurnIndex].isAI) {
      _processAIBid();
    }
  }

  void startNewGame({String? playerName}) {
    _initializeMatch(playerName: playerName);
  }

  void updateSettings({
    required List<String> names,
    required bool sortAsc,
    required double speed,
    required int rounds,
    required BatakGameMode mode,
    required HandLayoutMode layout,
    required TableColor color,
  }) {
    if (names.isNotEmpty && names[0].isNotEmpty) {
      currentPlayerName = names[0];
      players[0].name = currentPlayerName;
    }
    if (names.length >= 4) {
      botNames = [names[1], names[2], names[3]];
      for (int i = 1; i < 4; i++) {
        players[i].name = names[i];
      }
    }
    sortAscending = sortAsc;
    gameSpeed = speed;
    totalRounds = rounds.clamp(1, 7);
    gameMode = mode;
    handLayoutMode = layout;
    tableColor = color;
    notifyListeners();
  }

  // --- İHALE AŞAMASI METOTLARI ---

  void userPlaceBid(int bid) {
    if (currentPhase != GamePhase.bidding || biddingTurnIndex != 0) return;
    if (bid <= currentHighestBid) return;

    currentHighestBid = bid;
    highestBidderIndex = 0;
    statusMessage = "$currentPlayerName $bid dedi.";
    _advanceBidding();
  }

  void userPassBid() {
    if (currentPhase != GamePhase.bidding || biddingTurnIndex != 0) return;

    passedPlayers.add(0);
    statusMessage = "$currentPlayerName Pas dedi.";
    _advanceBidding();
  }

  void _advanceBidding() {
    if (passedPlayers.length >= 3 && highestBidderIndex != null) {
      _concludeBidding();
      return;
    }
    if (passedPlayers.length == 4) {
      // Herkes pas dediyse dağıtıcıya veya ilk oyuncuya zorunlu kalır
      highestBidderIndex = (currentRound - 1) % 4;
      currentHighestBid = (gameMode == BatakGameMode.partner) ? 8 : 5;
      _concludeBidding();
      return;
    }

    do {
      biddingTurnIndex = (biddingTurnIndex + 1) % 4;
    } while (passedPlayers.contains(biddingTurnIndex));

    notifyListeners();
    _processAIBid();
  }

  Future<void> _processAIBid() async {
    if (currentPhase != GamePhase.bidding) return;
    Player currentBot = players[biddingTurnIndex];
    if (!currentBot.isAI) return;

    await Future.delayed(Duration(milliseconds: delayBase));

    int maxSuitCount = 0;
    for (var suit in Suit.values) {
      int count = currentBot.hand.where((c) => c.suit == suit).length;
      if (count > maxSuitCount) maxSuitCount = count;
    }
    int highCards = currentBot.hand.where((c) => c.power >= Rank.jack.index).length;

    int maxBidLimit = (gameMode == BatakGameMode.partner) ? 9 : 7;
    bool willBid = (maxSuitCount >= 5 || highCards >= 4) && currentHighestBid < maxBidLimit;

    if (willBid) {
      int newBid = currentHighestBid + 1;
      currentHighestBid = newBid;
      highestBidderIndex = biddingTurnIndex;
      statusMessage = "${currentBot.name} $newBid dedi.";
    } else {
      passedPlayers.add(biddingTurnIndex);
      statusMessage = "${currentBot.name} Pas dedi.";
    }

    _advanceBidding();
  }

  void _concludeBidding() {
    bidderIndex = highestBidderIndex ?? 0;
    players[bidderIndex].bid = currentHighestBid;

    if (bidderIndex == 0) {
      currentPhase = GamePhase.trumpSelection;
      statusMessage = "İhaleyi $currentHighestBid ile kazandınız! Koz seçin.";
      notifyListeners();
    } else {
      Player winningBot = players[bidderIndex];
      Suit bestSuit = Suit.spades;
      int maxCount = -1;
      for (var s in Suit.values) {
        int cnt = winningBot.hand.where((c) => c.suit == s).length;
        if (cnt > maxCount) {
          maxCount = cnt;
          bestSuit = s;
        }
      }
      currentTrump = bestSuit;
      currentPhase = GamePhase.playing;
      currentTurnIndex = bidderIndex;
      statusMessage = "${winningBot.name} $currentHighestBid ile ihaleyi aldı. Koz: ${_suitName(currentTrump)}";
      notifyListeners();
      _checkBotTurn();
    }
  }

  void userSelectTrump(Suit suit) {
    if (currentPhase != GamePhase.trumpSelection) return;
    currentTrump = suit;
    currentPhase = GamePhase.playing;
    currentTurnIndex = bidderIndex;
    statusMessage = "Koz: ${_suitName(currentTrump)}. Oyun başladı!";
    notifyListeners();
  }

  String _suitName(Suit s) {
    switch (s) {
      case Suit.spades: return "Maça ♠";
      case Suit.hearts: return "Kupa ♥";
      case Suit.diamonds: return "Karo ♦";
      case Suit.clubs: return "Sinek ♣";
    }
  }

  // --- KART OYNAMA METOTLARI ---

  Future<void> playCard(Player player, PlayingCard card) async {
    player.hand.remove(card);
    tableCards.add(card);
    playedCardsByPlayer[currentTurnIndex] = card;

    // Gerçekçi kart atma sesi
    await SoundService.playCardThrow();

    notifyListeners();

    if (tableCards.length == 4) {
      currentPhase = GamePhase.trickFinished;
      notifyListeners();

      await Future.delayed(Duration(milliseconds: (delayBase * 1.6).round()));

      int roundWinnerIdx = GameEngine.determineWinnerIndex(tableCards, currentTrump);
      int actualWinnerIdx = (currentTurnIndex - 3 + roundWinnerIdx) % 4;
      if (actualWinnerIdx < 0) actualWinnerIdx += 4;

      players[actualWinnerIdx].tricksWon++;

      await SoundService.playChipsCollect();

      statusMessage = "Eli ${players[actualWinnerIdx].name} aldı!";
      tableCards.clear();
      playedCardsByPlayer.clear();

      currentTurnIndex = actualWinnerIdx;
      tricksPlayed++;

      if (tricksPlayed == 13) {
        await _finishRound();
      } else {
        currentPhase = GamePhase.playing;
        notifyListeners();
        _checkBotTurn();
      }
    } else {
      currentTurnIndex = (currentTurnIndex + 1) % 4;
      notifyListeners();
      _checkBotTurn();
    }
  }

  void _checkBotTurn() async {
    if (currentPhase != GamePhase.playing) return;
    Player currentPlayer = players[currentTurnIndex];
    if (currentPlayer.isAI) {
      await Future.delayed(Duration(milliseconds: delayBase));
      PlayingCard cardToPlay = AIEngine.chooseCard(
        bot: currentPlayer,
        tableCards: tableCards,
        trumpSuit: currentTrump,
      );
      await playCard(currentPlayer, cardToPlay);
    }
  }

  // --- TUR & PUAN HESAPLAMA METOTLARI ---

  Future<void> _finishRound() async {
    currentPhase = GamePhase.roundFinished;

    List<int> roundScores = [0, 0, 0, 0];

    if (gameMode == BatakGameMode.single) {
      // Tekli Batak Puanı
      for (int i = 0; i < 4; i++) {
        int score = GameEngine.calculateScore(players[i], i == bidderIndex);
        roundScores[i] = score;
        cumulativeScores[i] += score;
      }
    } else {
      // Eşli Batak Puanı (Takım 1: Siz [0] & Arda [2] vs Takım 2: Erol [1] & Uğur [3])
      int team1Tricks = players[0].tricksWon + players[2].tricksWon;
      int team2Tricks = players[1].tricksWon + players[3].tricksWon;

      bool team1Bidder = (bidderIndex == 0 || bidderIndex == 2);
      int bid = players[bidderIndex].bid;

      int team1Score = 0;
      int team2Score = 0;

      if (team1Bidder) {
        if (team1Tricks >= bid) {
          team1Score = (bid * 10) + (team1Tricks - bid);
        } else {
          team1Score = -(bid * 10);
        }
        team2Score = team2Tricks * 10;
      } else {
        if (team2Tricks >= bid) {
          team2Score = (bid * 10) + (team2Tricks - bid);
        } else {
          team2Score = -(bid * 10);
        }
        team1Score = team1Tricks * 10;
      }

      roundScores = [team1Score, team2Score, team1Score, team2Score];
      for (int i = 0; i < 4; i++) {
        cumulativeScores[i] += roundScores[i];
      }
    }

    roundScoresHistory.add(roundScores);
    statusMessage = "Tur $currentRound tamamlandı! Puanlar hesaplandı.";
    notifyListeners();

    // 2. Eli / Sonraki eli otomatik başlatma akışı
    if (currentRound < totalRounds) {
      // 3.5 saniye yazboz puanlarını göster, sonra otomatik yeni eli başlat
      for (int sec = 3; sec > 0; sec--) {
        roundCountdown = sec;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 1));
      }
      currentRound++;
      _startRound();
    } else {
      // Tüm eller tamamlandı -> Şampiyonluk Ekranı
      currentPhase = GamePhase.gameOver;
      statusMessage = "Tüm turlar tamamlandı! Şampiyon belli oldu.";
      notifyListeners();

      int highest = -9999;
      int winner = 0;
      for (int i = 0; i < 4; i++) {
        if (cumulativeScores[i] > highest) {
          highest = cumulativeScores[i];
          winner = i;
        }
      }
      try {
        await ApiService.saveMatchScore(
          isMultiplayer: false,
          players: players,
          winnerIndex: winner,
        );
      } catch (_) {}
    }
  }

  void startNextRoundImmediately() {
    if (currentPhase == GamePhase.roundFinished && currentRound < totalRounds) {
      currentRound++;
      _startRound();
    }
  }
}
