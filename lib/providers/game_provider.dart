import 'dart:async';
import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../models/deck.dart';
import '../engine/game_engine.dart';
import '../engine/ai_engine.dart';
import '../services/sound_service.dart';
import '../services/api_service.dart';
import '../engine/scoring_engine.dart';
import '../engine/game_mode_rules.dart';
import '../engine/team_engine.dart';
import '../models/saved_game_model.dart';
import '../models/bot_memory.dart';
import '../models/played_card_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_difficulty.dart';
import '../services/game_save_service.dart';

export '../models/ai_difficulty.dart';
export '../engine/game_mode_rules.dart';
export '../models/saved_game_model.dart';
export '../services/game_save_service.dart';

enum GamePhase {
  bidding,         // İhale Aşaması
  trumpSelection,  // Koz Seçimi
  playing,         // Kart Atma Aşaması
  trickFinished,   // El bitti (4 kart atıldı)
  roundFinished,   // Tur bitti (13 el bitti, puanlar hesaplandı)
  gameOver         // Tüm maç bitti (Örn: 5 turun 5'i de tamamlandı)
}

enum HandLayoutMode {
  fanned,   // Çapraz / Yelpaze
  twoRow    // İki Sıra
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
  List<PlayedCardRecord> playedHistory = [];
  BotMemory botMemory = BotMemory();

  static const String aiDifficultyKey = 'likya_batak_ai_difficulty';
  AIDifficulty aiDifficulty = AIDifficulty.normal;

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

  /// Yapısal tur sonuçları geçmişi (LIKYA-V2-003)
  List<RoundResult> roundResults = [];

  /// Tur puanlama zaten uygulandıysa true; mükerrer puanlama koruması.
  bool _roundScored = false;

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

  // Kısa, okunabilir bot ritmi; hız ayarı korunur.
  int get delayBase => (240 / gameSpeed).round().clamp(120, 400);

  // --- LIKYA-V2-002: ASYNC YAŞAM DÖNGÜSÜ & KİLİT KORUMASI ---
  int _gameGeneration = 0;
  int get gameGeneration => _gameGeneration;
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;
  bool _isBotActionRunning = false;
  bool get isBotActionRunning => _isBotActionRunning;
  bool _isHumanActionLocked = false;
  bool get isHumanActionLocked => _isHumanActionLocked;
  bool _isResolvingTrick = false;
  bool _isAdvancingRound = false;

  Timer? _botTurnTimer;
  Timer? _biddingTimer;
  Timer? _trickResolutionTimer;

  GameProvider() {
    _initializeMatch(autoSave: false);
    unawaited(loadAIDifficulty());
  }

  Future<void> setAIDifficulty(AIDifficulty difficulty) async {
    aiDifficulty = difficulty;
    _safeNotifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(aiDifficultyKey, difficulty.name);
    } catch (_) {}
  }

  Future<void> loadAIDifficulty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(aiDifficultyKey);
      aiDifficulty = AIDifficulty.fromString(val);
      _safeNotifyListeners();
    } catch (_) {}
  }

  void _cancelTimers() {
    _botTurnTimer?.cancel();
    _botTurnTimer = null;
    _biddingTimer?.cancel();
    _biddingTimer = null;
    _trickResolutionTimer?.cancel();
    _trickResolutionTimer = null;
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _gameGeneration++;
    _cancelTimers();
    super.dispose();
  }

  void leaveMatch() {
    _gameGeneration++;
    _cancelTimers();
    _isBotActionRunning = false;
    _isHumanActionLocked = false;
    _isResolvingTrick = false;
    _isAdvancingRound = false;
    tableCards.clear();
    playedCardsByPlayer.clear();
    currentPhase = GamePhase.gameOver;
    statusMessage = "Masadan ayrıldınız.";
    _safeNotifyListeners();
    unawaited(deleteSavedGame());
  }

  void _initializeMatch({String? playerName, bool autoSave = false}) {
    _cancelTimers();
    if (playerName != null && playerName.trim().isNotEmpty) {
      currentPlayerName = playerName.trim();
    }
    currentRound = 1;
    cumulativeScores = [0, 0, 0, 0];
    roundScoresHistory.clear();
    roundResults.clear();
    _startRound(autoSave: autoSave);
  }

  void _startRound({bool autoSave = true}) {
    _cancelTimers();
    _isBotActionRunning = false;
    _isHumanActionLocked = false;
    _isResolvingTrick = false;
    _isAdvancingRound = false;
    _roundScored = false;

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
    playedHistory.clear();
    tricksPlayed = 0;

    final rules = GameModeRules.forMode(gameMode);

    if (rules.isFixedTrump) {
      currentTrump = rules.fixedTrumpSuit ?? Suit.spades;
    }

    botMemory.resetForNewRound(
      trump: rules.isFixedTrump ? currentTrump : null,
    );

    if (!rules.hasBidding) {
      // Koz Maça (İhalesiz) — İhale aşaması yoktur, doğrudan oyun başlar
      currentHighestBid = 0;
      highestBidderIndex = null;
      bidderIndex = -1;
      passedPlayers.clear();

      // İlk eli dağıtanın solundaki oyuncu başlatır
      currentTurnIndex = (currentRound - 1) % 4;
      currentPhase = GamePhase.playing;
      statusMessage = "Tur $currentRound / $totalRounds - Koz Maça başladı! (Koz: ${_suitName(currentTrump)})";

      SoundService.playCardDeal();
      _safeNotifyListeners();
      if (autoSave) {
        unawaited(autoSaveCurrentGame());
      }

      if (players[currentTurnIndex].isAI) {
        _scheduleBotTurn();
      }
    } else {
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
      _safeNotifyListeners();
      if (autoSave) {
        unawaited(autoSaveCurrentGame());
      }

      if (players[biddingTurnIndex].isAI) {
        _scheduleBotBid();
      }
    }
  }

  void startNewGame({String? playerName}) {
    _gameGeneration++;
    _cancelTimers();
    _isBotActionRunning = false;
    _isHumanActionLocked = false;
    _isResolvingTrick = false;
    _isAdvancingRound = false;
    unawaited(deleteSavedGame());
    _initializeMatch(playerName: playerName, autoSave: true);
  }

  void updateSettings({
    required List<String> names,
    required bool sortAsc,
    required double speed,
    required int rounds,
    required BatakGameMode mode,
    required HandLayoutMode layout,
    required TableColor color,
    AIDifficulty? difficulty,
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
    totalRounds = rounds;
    gameMode = mode;
    handLayoutMode = layout;
    tableColor = color;
    if (difficulty != null) {
      unawaited(setAIDifficulty(difficulty));
    } else {
      _safeNotifyListeners();
    }
  }

  // --- İHALE AŞAMASI METOTLARI ---

  GameActionResult userPlaceBid(int bid) {
    if (_isHumanActionLocked) {
      return const GameActionResult.failure("İşlem devam ediyor, lütfen bekleyin.");
    }
    _isHumanActionLocked = true;
    try {
      if (!GameModeRules.forMode(gameMode).hasBidding) {
        return const GameActionResult.failure("Bu oyun modunda ihale aşaması yoktur.");
      }
      if (currentPhase != GamePhase.bidding) {
        return const GameActionResult.failure("İhale aşamasında değilsiniz.");
      }
      if (biddingTurnIndex != 0) {
        return const GameActionResult.failure("İhale sırası sizde değil.");
      }
      if (passedPlayers.contains(0)) {
        return const GameActionResult.failure("Zaten pas dediniz.");
      }
      if (bid <= currentHighestBid) {
        return const GameActionResult.failure("Teklif mevcut en yüksek tekliften büyük olmalıdır.");
      }
      if (bid > 13) {
        return const GameActionResult.failure("Batakta maksimum 13 teklif edilebilir.");
      }

      currentHighestBid = bid;
      highestBidderIndex = 0;
      statusMessage = "$currentPlayerName $bid dedi.";
      _advanceBidding();
      unawaited(autoSaveCurrentGame());
      return const GameActionResult.success();
    } finally {
      _isHumanActionLocked = false;
    }
  }

  GameActionResult userPassBid() {
    if (_isHumanActionLocked) {
      return const GameActionResult.failure("İşlem devam ediyor, lütfen bekleyin.");
    }
    _isHumanActionLocked = true;
    try {
      if (!GameModeRules.forMode(gameMode).hasBidding) {
        return const GameActionResult.failure("Bu oyun modunda ihale aşaması yoktur.");
      }
      if (currentPhase != GamePhase.bidding) {
        return const GameActionResult.failure("İhale aşamasında değilsiniz.");
      }
      if (biddingTurnIndex != 0) {
        return const GameActionResult.failure("İhale sırası sizde değil.");
      }
      if (passedPlayers.contains(0)) {
        return const GameActionResult.failure("Zaten pas dediniz.");
      }

      passedPlayers.add(0);
      statusMessage = "$currentPlayerName Pas dedi.";
      _advanceBidding();
      unawaited(autoSaveCurrentGame());
      return const GameActionResult.success();
    } finally {
      _isHumanActionLocked = false;
    }
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

    _safeNotifyListeners();
    unawaited(autoSaveCurrentGame());
    _scheduleBotBid();
  }

  void _scheduleBotBid() {
    if (_isDisposed || currentPhase != GamePhase.bidding) return;
    if (players.isEmpty || biddingTurnIndex >= players.length) return;
    if (!players[biddingTurnIndex].isAI) return;

    _biddingTimer?.cancel();
    final int generation = _gameGeneration;

    _biddingTimer = Timer(Duration(milliseconds: delayBase), () {
      _executeBotBid(generation);
    });
  }

  void _executeBotBid(int generation) {
    if (_isDisposed || generation != _gameGeneration) return;
    if (currentPhase != GamePhase.bidding) return;
    if (players.isEmpty || biddingTurnIndex >= players.length) return;
    final Player currentBot = players[biddingTurnIndex];
    if (!currentBot.isAI) return;

    final int? recommendedBid = AIEngine.recommendBid(
      hand: currentBot.hand,
      currentHighestBid: currentHighestBid,
      gameMode: gameMode,
      difficulty: aiDifficulty,
    );

    if (recommendedBid != null &&
        recommendedBid > currentHighestBid &&
        recommendedBid <= 13) {
      currentHighestBid = recommendedBid;
      highestBidderIndex = biddingTurnIndex;
      statusMessage = "${currentBot.name} $recommendedBid dedi.";
    } else {
      passedPlayers.add(biddingTurnIndex);
      statusMessage = "${currentBot.name} Pas dedi.";
    }

    _advanceBidding();
    unawaited(autoSaveCurrentGame());
  }

  void _concludeBidding() {
    bidderIndex = highestBidderIndex ?? 0;
    players[bidderIndex].bid = currentHighestBid;

    final TeamId? bidTeam = (gameMode == BatakGameMode.partner)
        ? TeamEngine.teamForPlayer(bidderIndex)
        : null;

    if (bidderIndex == 0) {
      currentPhase = GamePhase.trumpSelection;
      statusMessage = "İhaleyi $currentHighestBid ile kazandınız! Koz seçin.";
      botMemory.setPublicBidState(
        bidderIndex: bidderIndex,
        winningBid: currentHighestBid,
        biddingTeam: bidTeam,
        trump: null,
      );
      _safeNotifyListeners();
      unawaited(autoSaveCurrentGame());
    } else {
      Player winningBot = players[bidderIndex];
      currentTrump = AIEngine.chooseTrump(
        winningBot,
        difficulty: aiDifficulty,
        winningBid: currentHighestBid,
      );
      currentPhase = GamePhase.playing;
      currentTurnIndex = bidderIndex;
      botMemory.setPublicBidState(
        bidderIndex: bidderIndex,
        winningBid: currentHighestBid,
        biddingTeam: bidTeam,
        trump: currentTrump,
      );
      statusMessage = "${winningBot.name} $currentHighestBid ile ihaleyi aldı. Koz: ${_suitName(currentTrump)}";
      _safeNotifyListeners();
      unawaited(autoSaveCurrentGame());
      _scheduleBotTurn();
    }
  }

  GameActionResult userSelectTrump(Suit suit) {
    if (_isHumanActionLocked) {
      return const GameActionResult.failure("İşlem devam ediyor, lütfen bekleyin.");
    }
    _isHumanActionLocked = true;
    try {
      if (GameModeRules.forMode(gameMode).isFixedTrump) {
        return const GameActionResult.failure("Bu oyun modunda koz sabittir ve değiştirilemez.");
      }
      if (currentPhase != GamePhase.trumpSelection) {
        return const GameActionResult.failure("Koz seçim aşamasında değilsiniz.");
      }
      if (bidderIndex != 0) {
        return const GameActionResult.failure("Kozu yalnızca ihaleyi kazanan oyuncu seçebilir.");
      }

      currentTrump = suit;
      botMemory.trump = suit;
      currentPhase = GamePhase.playing;
      currentTurnIndex = bidderIndex;
      statusMessage = "Koz: ${_suitName(currentTrump)}. Oyun başladı!";
      _safeNotifyListeners();
      unawaited(autoSaveCurrentGame());
      return const GameActionResult.success();
    } finally {
      _isHumanActionLocked = false;
    }
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

  /// Oyuncunun kurallara uygun olarak oynayabileceği geçerli kartları döner.
  List<PlayingCard> getValidMovesForPlayer(Player player) {
    if (currentPhase != GamePhase.playing || players.isEmpty || players[currentTurnIndex] != player) {
      return const [];
    }
    return GameEngine.getValidMoves(
      hand: player.hand,
      tableCards: tableCards,
      trumpSuit: currentTrump,
    );
  }

  Future<GameActionResult> playCard(Player player, PlayingCard card) async {
    if (!player.isAI) {
      if (_isHumanActionLocked) {
        return const GameActionResult.failure("İşlem devam ediyor, lütfen bekleyin.");
      }
      _isHumanActionLocked = true;
    }
    try {
      return await _playCardInternal(player, card, _gameGeneration);
    } finally {
      if (!player.isAI) {
        _isHumanActionLocked = false;
      }
    }
  }

  Future<GameActionResult> _playCardInternal(Player player, PlayingCard card, int generation) async {
    if (_isDisposed || generation != _gameGeneration) {
      return const GameActionResult.failure("Oyun oturumu geçerli değil.");
    }
    if (_isResolvingTrick) {
      return const GameActionResult.failure("Önceki el toplanıyor, lütfen bekleyin.");
    }

    // 1. Durum / Yetki / Kural Kontrolleri (Mutation öncesi mutlak doğrulama)
    final validation = GameEngine.validatePlay(
      cardToPlay: card,
      player: player,
      tableCards: tableCards,
      trumpSuit: currentTrump,
      isCurrentTurn: players.isNotEmpty && players[currentTurnIndex] == player,
      isPlayingPhase: currentPhase == GamePhase.playing,
    );

    if (!validation.success) {
      return validation;
    }

    // Eldeki kart sayısı kontrolü (kart elde tam 1 kez bulunmalı)
    if (player.hand.where((c) => c == card).length != 1) {
      return const GameActionResult.failure("Kart elinizde tutarlı değil.");
    }

    // 2. Geçerli hamle: State mutasyonu
    final Suit? leadSuit = tableCards.isEmpty ? null : tableCards.first.suit;
    final int trickNumber = tricksPlayed;
    final int playerIndex = currentTurnIndex;

    final int leadPlayerIndex = (tableCards.isEmpty)
        ? currentTurnIndex
        : (currentTurnIndex - tableCards.length + 4) % 4;

    player.hand.remove(card);
    tableCards.add(card);
    playedCardsByPlayer[currentTurnIndex] = card;

    final record = PlayedCardRecord(
      playerIndex: playerIndex,
      card: card,
      trickNumber: trickNumber,
    );
    if (!playedHistory.any((r) => r.card == card && r.trickNumber == trickNumber)) {
      playedHistory.add(record);
    }
    botMemory.recordPlay(
      playerIndex: playerIndex,
      card: card,
      leadSuit: leadSuit,
      trickNumber: trickNumber,
    );

    // Ses kartın masada görünmesini ve sıranın ilerlemesini bekletmez.
    unawaited(SoundService.playCardThrow());

    if (tableCards.length == 4) {
      currentPhase = GamePhase.trickFinished;
      _isResolvingTrick = true;
      _safeNotifyListeners();

      _trickResolutionTimer?.cancel();
      _trickResolutionTimer = Timer(Duration(milliseconds: (delayBase * 1.5).round()), () async {
        if (_isDisposed || generation != _gameGeneration) return;
        try {
          int actualWinnerIdx = GameEngine.determineTrickWinnerPlayerIndex(
            tableCards: tableCards,
            trumpSuit: currentTrump,
            leadPlayerIndex: leadPlayerIndex,
          );

          players[actualWinnerIdx].tricksWon++;

          unawaited(SoundService.playChipsCollect());

          if (_isDisposed || generation != _gameGeneration) return;

          botMemory.recordTrickWinner(actualWinnerIdx, trickNumber: tricksPlayed);

          statusMessage = "Eli ${players[actualWinnerIdx].name} aldı!";
          tableCards.clear();
          playedCardsByPlayer.clear();

          currentTurnIndex = actualWinnerIdx;
          tricksPlayed++;
          _isResolvingTrick = false;
          unawaited(autoSaveCurrentGame());

          if (tricksPlayed == 13) {
            await _finishRound(generation);
          } else {
            currentPhase = GamePhase.playing;
            _safeNotifyListeners();
            _scheduleBotTurn();
          }
        } finally {
          _isResolvingTrick = false;
        }
      });
    } else {
      currentTurnIndex = (currentTurnIndex + 1) % 4;
      _safeNotifyListeners();
      unawaited(autoSaveCurrentGame());
      _scheduleBotTurn();
    }

    return const GameActionResult.success();
  }

  void _scheduleBotTurn() {
    if (_isDisposed || currentPhase != GamePhase.playing) return;
    if (players.isEmpty || currentTurnIndex >= players.length) return;
    if (!players[currentTurnIndex].isAI) return;
    if (_isResolvingTrick) return;

    _botTurnTimer?.cancel();
    final int generation = _gameGeneration;

    _botTurnTimer = Timer(Duration(milliseconds: delayBase), () {
      _executeBotTurn(generation);
    });
  }

  Future<void> _executeBotTurn(int generation) async {
    if (_isDisposed || generation != _gameGeneration) return;
    if (_isBotActionRunning || _isResolvingTrick) return;

    _isBotActionRunning = true;
    try {
      if (_isDisposed || generation != _gameGeneration) return;
      if (currentPhase != GamePhase.playing) return;
      if (players.isEmpty || currentTurnIndex >= players.length) return;

      final Player currentBot = players[currentTurnIndex];
      if (!currentBot.isAI) return;
      if (currentBot.hand.isEmpty) return;

      // STEP 7: Select card AFTER delay and revalidation
      // Eşli modda partner bilgisi iletilir (LIKYA-V2-004)
      final int? leadIdx = tableCards.isEmpty
          ? null
          : (currentTurnIndex - tableCards.length + 4) % 4;
      final PlayingCard cardToPlay = AIEngine.chooseCard(
        bot: currentBot,
        tableCards: tableCards,
        trumpSuit: currentTrump,
        botPlayerIndex: gameMode == BatakGameMode.partner ? currentTurnIndex : null,
        playedCardsByPlayer: gameMode == BatakGameMode.partner ? playedCardsByPlayer : null,
        leadPlayerIndex: gameMode == BatakGameMode.partner ? leadIdx : null,
        memory: botMemory,
        difficulty: aiDifficulty,
      );

      // STEP 6: Revalidate card before playing
      if (!currentBot.hand.contains(cardToPlay)) return;

      await _playCardInternal(currentBot, cardToPlay, generation);
    } finally {
      _isBotActionRunning = false;
    }
  }

  // --- TUR & PUAN HESAPLAMA METOTLARI ---

  Future<void> _finishRound(int generation) async {
    if (_isAdvancingRound) return;
    _isAdvancingRound = true;
    try {
      // Mükerrer puanlama koruması (LIKYA-V2-003)
      if (_roundScored) return;
      _roundScored = true;

      currentPhase = GamePhase.roundFinished;

      // ScoringEngine ile saf puan hesaplama (LIKYA-V2-003 & LIKYA-V2-005)
      RoundResult result;
      if (gameMode == BatakGameMode.single) {
        result = ScoringEngine.computeSingleModeRound(
          players: players,
          bidderIndex: bidderIndex,
          bid: players[bidderIndex].bid,
          trump: currentTrump,
          roundNumber: currentRound,
          prevCumulativeScores: List.of(cumulativeScores),
        );
      } else if (gameMode == BatakGameMode.partner) {
        result = ScoringEngine.computePartnerModeRound(
          players: players,
          bidderIndex: bidderIndex,
          bid: players[bidderIndex].bid,
          trump: currentTrump,
          roundNumber: currentRound,
          prevCumulativeScores: List.of(cumulativeScores),
        );
      } else if (gameMode == BatakGameMode.kozMaca) {
        result = ScoringEngine.computeKozMacaRound(
          players: players,
          roundNumber: currentRound,
          prevCumulativeScores: List.of(cumulativeScores),
        );
      } else {
        result = ScoringEngine.computeSingleModeRound(
          players: players,
          bidderIndex: bidderIndex >= 0 ? bidderIndex : 0,
          bid: bidderIndex >= 0 ? players[bidderIndex].bid : 0,
          trump: currentTrump,
          roundNumber: currentRound,
          prevCumulativeScores: List.of(cumulativeScores),
        );
      }

      // Sonuçları state'e yaz
      cumulativeScores = List.of(result.cumulativeScores);
      roundScoresHistory.add(result.scoreDeltaByPlayer);
      roundResults.add(result);

      statusMessage = "Tur $currentRound tamamlandı! Puanlar hesaplandı.";
      _safeNotifyListeners();
      unawaited(autoSaveCurrentGame());

      // Sonraki eli otomatik başlatma akışı
      if (currentRound < totalRounds) {
        // 3 saniye yazboz puanlarını göster, sonra otomatik yeni eli başlat
        for (int sec = 3; sec > 0; sec--) {
          if (_isDisposed || generation != _gameGeneration) return;
          roundCountdown = sec;
          _safeNotifyListeners();
          await Future.delayed(const Duration(seconds: 1));
        }
        if (_isDisposed || generation != _gameGeneration) return;
        currentRound++;
        _startRound();
      } else {
        // Tüm eller tamamlandı → Şampiyonluk Ekranı
        currentPhase = GamePhase.gameOver;
        statusMessage = "Tüm turlar tamamlandı! Şampiyon belli oldu.";
        _safeNotifyListeners();
        unawaited(deleteSavedGame());

        // NON-AUTHORITATIVE SIDE EFFECT: Ağ kaydı (LIKYA-V2-003 §15)
        // Bu çağrı: yerel kazananı belirleme, oyun tamamlamayı engelleme,
        // ve puan mutasyonu yapmaz. Ağ hatası offline oyunu bozmaz.
        final int winner = ScoringEngine.determineWinnerIndex(cumulativeScores);
        try {
          await ApiService.saveMatchScore(
            isMultiplayer: false,
            players: players,
            winnerIndex: winner,
          );
        } catch (_) {}
      }
    } finally {
      _isAdvancingRound = false;
    }
  }

  void startNextRoundImmediately() {
    if (currentPhase == GamePhase.roundFinished && currentRound < totalRounds) {
      _cancelTimers();
      _gameGeneration++;
      _isAdvancingRound = false;
      currentRound++;
      _startRound();
    }
  }

  // ============================================================
  // DURUM KAYIT VE DEVAM ET (SAVE & RESUME) METOTLARI (LIKYA-V2-006)
  // ============================================================

  /// Mevcut oyun durumunu SavedGameModel nesnesine dönüştürür.
  SavedGameModel toSavedGameModel() {
    return SavedGameModel(
      savedAt: DateTime.now().toIso8601String(),
      gameMode: gameMode,
      currentPhase: currentPhase,
      totalRounds: totalRounds,
      currentRound: currentRound,
      currentTurnIndex: currentTurnIndex,
      biddingTurnIndex: biddingTurnIndex,
      currentHighestBid: currentHighestBid,
      highestBidderIndex: highestBidderIndex,
      bidderIndex: bidderIndex,
      passedPlayers: List.of(passedPlayers),
      currentTrump: currentTrump,
      tricksPlayed: tricksPlayed,
      players: players.map((p) => Player(
        id: p.id,
        name: p.name,
        isAI: p.isAI,
        hand: List.of(p.hand),
        bid: p.bid,
        tricksWon: p.tricksWon,
      )).toList(),
      tableCards: List.of(tableCards),
      playedCardsByPlayer: Map.of(playedCardsByPlayer),
      playedHistory: List.unmodifiable(playedHistory),
      cumulativeScores: List.of(cumulativeScores),
      roundScoresHistory: roundScoresHistory.map((h) => List.of(h)).toList(),
      roundResults: List.of(roundResults),
      roundScored: _roundScored,
      statusMessage: statusMessage,
    );
  }

  /// Doğrulanmış SavedGameModel nesnesinden oyun durumunu geri yükler.
  void restoreFromSavedGame(SavedGameModel model) {
    _gameGeneration++;
    _cancelTimers();
    _isBotActionRunning = false;
    _isHumanActionLocked = false;
    _isResolvingTrick = false;
    _isAdvancingRound = false;

    gameMode = model.gameMode;
    currentPhase = model.currentPhase;
    totalRounds = model.totalRounds;
    currentRound = model.currentRound;
    currentTurnIndex = model.currentTurnIndex;
    biddingTurnIndex = model.biddingTurnIndex;
    currentHighestBid = model.currentHighestBid;
    highestBidderIndex = model.highestBidderIndex;
    bidderIndex = model.bidderIndex;
    passedPlayers = Set<int>.from(model.passedPlayers);
    currentTrump = model.currentTrump;
    tricksPlayed = model.tricksPlayed;
    players = model.players.map((p) => Player(
      id: p.id,
      name: p.name,
      isAI: p.isAI,
      hand: List.of(p.hand),
      bid: p.bid,
      tricksWon: p.tricksWon,
    )).toList();
    tableCards = List.of(model.tableCards);
    playedCardsByPlayer = Map.of(model.playedCardsByPlayer);
    playedHistory = List.of(model.playedHistory);
    cumulativeScores = List.of(model.cumulativeScores);
    roundScoresHistory = model.roundScoresHistory.map((h) => List.of(h)).toList();
    roundResults = List.of(model.roundResults);
    _roundScored = model.roundScored;
    statusMessage = model.statusMessage;

    final restoredBidder = model.bidderIndex >= 0 ? model.bidderIndex : null;
    final TeamId? restoredBiddingTeam = (model.gameMode == BatakGameMode.partner && restoredBidder != null)
        ? TeamEngine.teamForPlayer(restoredBidder)
        : null;

    final Map<int, int> restoredTricksWon = {};
    for (int i = 0; i < players.length; i++) {
      if (players[i].tricksWon > 0) {
        restoredTricksWon[i] = players[i].tricksWon;
      }
    }

    botMemory.reconstructFromHistory(
      playedHistory,
      trump: model.currentTrump,
      bidderIdx: restoredBidder,
      winBid: (model.gameMode != BatakGameMode.kozMaca && restoredBidder != null) ? model.currentHighestBid : null,
      bidTeam: restoredBiddingTeam,
      tricksWon: restoredTricksWon,
    );

    _safeNotifyListeners();

    // Restorasyon sonrası bot sırası ise bot eylemini yeniden planla
    if (currentPhase == GamePhase.bidding) {
      if (players.isNotEmpty && biddingTurnIndex < players.length && players[biddingTurnIndex].isAI) {
        _scheduleBotBid();
      }
    } else if (currentPhase == GamePhase.playing) {
      if (players.isNotEmpty && currentTurnIndex < players.length && players[currentTurnIndex].isAI && !_isResolvingTrick) {
        _scheduleBotTurn();
      }
    }
  }

  /// Aktif oyunu otomatik olarak diske kaydeder (asenkron, non-blocking).
  Future<void> autoSaveCurrentGame() async {
    if (_isDisposed || currentPhase == GamePhase.gameOver) {
      await GameSaveService.deleteSave();
      return;
    }
    if (gameMode == BatakGameMode.gommeli) return;
    try {
      final model = toSavedGameModel();
      await GameSaveService.saveGame(model);
    } catch (_) {}
  }

  /// Kaydedilmiş oyunu siler.
  Future<void> deleteSavedGame() async {
    await GameSaveService.deleteSave();
  }
}
