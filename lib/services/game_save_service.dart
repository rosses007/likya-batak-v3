import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_game_model.dart';
import '../providers/game_provider.dart';
import '../engine/game_mode_rules.dart';

/// Yetkili kayıt ve devam servisi (LIKYA-V2-006).
///
/// SharedPreferences üzerinden 'likya_batak_active_game_v1' anahtarı ile
/// aktif yarım kalmış çevrimdışı maçları yönetir.
/// Tüm diske yazma ve okuma işlemleri sıralı bir kuyruk üzerinden asenkron yarışları
/// (race condition) engelleyecek şekilde yürütülür.
class GameSaveService {
  static const String saveKey = 'likya_batak_active_game_v1';

  /// Yarım kalmış aktif oyunu SharedPreferences'a kaydeder.
  /// Hata durumunda oyunu kitlemez, false döner.
  static Future<bool> saveGame(SavedGameModel model) async {
    if (model.currentPhase == GamePhase.gameOver) {
      await deleteSave();
      return false;
    }
    // Desteklenmeyen modları (Gömmeli / Online) kaydetme
    if (model.gameMode == BatakGameMode.gommeli) {
      return false;
    }

    try {
      final validationErrors = model.validateIntegrity();
      if (validationErrors.isNotEmpty) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = model.toJsonString();
      return await prefs.setString(saveKey, jsonStr);
    } catch (_) {
      return false;
    }
  }

  /// Kayıtlı oyunu yükler ve bütünlüğünü doğrular.
  /// Bozuk veya geçersiz kayıt varsa otomatik siler ve null döner.
  static Future<SavedGameModel?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(saveKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return null;
      }

      final model = SavedGameModel.fromJsonString(jsonStr);
      if (model == null) {
        await prefs.remove(saveKey);
        return null;
      }

      // Desteklenmeyen mod kontrolü
      if (model.gameMode == BatakGameMode.gommeli ||
          model.currentPhase == GamePhase.gameOver) {
        await prefs.remove(saveKey);
        return null;
      }

      final errors = model.validateIntegrity();
      if (errors.isNotEmpty) {
        await prefs.remove(saveKey);
        return null;
      }

      return model;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(saveKey);
      } catch (_) {}
      return null;
    }
  }

  /// Aktif geçerli bir kayıt var mı kontrol eder.
  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(saveKey) &&
          (prefs.getString(saveKey)?.isNotEmpty ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Kayıtlı oyunu güvenli şekilde siler.
  static Future<bool> deleteSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(saveKey);
    } catch (_) {
      return false;
    }
  }
}
