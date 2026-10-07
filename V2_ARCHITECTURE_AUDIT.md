# Likya Batak V2 — Architecture Inventory & Baseline Audit

**Tarih:** 2 Ekim 2026  
**Aktif Proje:** `C:\Users\erkan\likya_batak_new`  
**Referans (Eski) Proje:** `C:\Users\erkan\batak_app` (Salt Okunur)  
**Paket Adı:** `com.likyastudios.likyabatak`  
**Sürüm:** `1.0.0+1`  
**İmzalama:** `C:\Users\erkan\.likya_batak_keys\likya-batak-upload.jks` (`likya_batak_upload`)

---

## 1. Mevcut Oyun Modları (Existing Game Modes)

| Mod | Kod Durumu | UI Durumu | Açıklama |
|---|---|---|---|
| **Tekli İhaleli Batak** (`BatakGameMode.single`) | Aktif & Çalışır | Ana Menüde Seçilebilir | 4 tekil oyuncu, ihale 5-13 arası, batma/alma puanlaması |
| **Eşli Batak (Ortaklı)** (`BatakGameMode.partner`) | Aktif & Çalışır | Ana Menüde Seçilebilir | Oyuncu & Bot 2 vs Bot 1 & Bot 3, ortak puanlama |
| **Gömmeli Batak** | **Eksik** (Kodda enum yok) | Menüde Yok | Mağaza metinlerinde vaat edilmiş ancak motor seviyesinde yok |
| **Koz Maça** | **Eksik** (Kodda enum yok) | Menüde Yok | İhalesiz sabit koz Maça modu henüz kodlanmamış |

---

## 2. Çalışan Ekranlar (Working Screens)

1. **`SplashScreen` (`lib/screens/splash_screen.dart`):**  
   Likya logosu animasyonu, AdMob ön başlatma, ana menüye geçiş.
2. **`MainMenuScreen` (`lib/screens/main_menu_screen.dart`):**  
   Mod seçimi (Tekli, Eşli, Online-kilitli), tur sayısı seçimi (1..7), ayarlar/profil, liderlik tablosu, nasıl oynanır diyaloğu.
3. **`GameScreen` (`lib/screens/game_screen.dart`):**  
   4 kişilik masa çuhası, oyuncu koltukları, gerçekçi kart render'ları (yelpaze veya çift sıra), ihale paneli, koz seçim paneli, el tamamlama animasyonları, yazboz diyaloğu (`ScoreboardDialog`), maç sonu özeti.
4. **`MatchmakingScreen` & `MultiplayerGameScreen`:**  
   Çevrimiçi altyapı ekranları; "YAKINDA" diyaloğu ile kilitli ve erişilemez durumda.

---

## 3. Mükerrer ve Eski Kodlar (Duplicate / Legacy Code)

| Dosya | Durum | Teşhis |
|---|---|---|
| `lib/state/game_state.dart` | **Ölü Kod (Dead Code)** | `GameProvider` öncesi yazılmış eski 99 satırlık alternatif state sınıfı. Hiçbir yerde import edilmiyor. |
| `lib/controllers/store_provider.dart` | **Gereksiz Wrapper** | Yalnızca `export '../providers/store_provider.dart';` içeren 2 satırlık dosya. Hiçbir yerde kullanılmıyor. |
| `assets/store/kart_ornekleri_duzeltilmis.png` | **Geçici Asset** | Mağaza hazırlığı sırasında referans amaçlı üretilmiş görsel. Kod tarafından okunmuyor. |

---

## 4. GameProvider Sorumlulukları (God Object Analizi)

`lib/providers/game_provider.dart` (426 satır) şu an bir "God Object" olarak çalışmaktadır:
- Deste ve kart dağıtımı (`Deck`)
- Faz yönetimi (`GamePhase`: bidding, trumpSelection, playing, trickFinished, roundFinished, gameOver)
- İhale döngüsü ve teklif artırma kuralları
- Koz seçimi ve aktarımı
- Kart oynama ve el toplama akışı
- Ses efektleri tetikleme (`SoundService`)
- Skor hesaplama ve tur yazboz geçmişi (`roundScoresHistory`, `cumulativeScores`)
- Bot oynatma döngüsü (`_checkBotTurn` ve `Future.delayed` akışları)
- Masa rengi ve kart yerleşim modu tercihleri
- Skorun sunucuya iletilmesi (`ApiService.submitScore`)

**Ayrıştırma İhtiyacı:** Kural motoru, bot zamanlayıcısı ve UI state yönetimi birbirinden net çizgilerle ayrılmalıdır.

---

## 5. Kurallar Motoru Durumu (RulesEngine Status)

`lib/engine/game_engine.dart` (203 satır):
- `getValidMoves`: Saf (Pure) kural API'si; renge uyma, koz çakma, koz büyütme (overtrumping) ve çöp atma kurallarını eksiksiz hesaplar.
- `isValidPlay`: Herhangi bir kartın mevcut masa durumunda yasal olup olmadığını doğrular.
- `validatePlay`: Faz, sıra, kart sahipliği, masa çakışması ve kuralları kapsayan yapısal `ValidationResult` guard sistemi.
- `determineWinnerIndex`: Yerdeki 4 karttan eli kazananı belirleme.
- `calculateScore`: Tekli ve eşli batak için ceza ve kazanç puanlaması.

✅ **LIKYA-V2-001 İLE ÇÖZÜLDÜ (RESOLVED):**  
`GameProvider.playCard()`, `userPlaceBid()`, `userPassBid()` ve `userSelectTrump()` metotları motor seviyesinde otoriter hale getirildi. UI bağımsız olarak yetkisiz ve kural dışı hiçbir hamle state mutasyonuna yol açamaz.

---

## 6. Yapay Zeka Durumu (AI Status)

`lib/engine/ai_engine.dart` & `lib/models/ai_difficulty.dart`:
- **Kart Seçimi (`chooseCard`):** `GameEngine.getValidMoves` ile geçerli kartları filtreler. `AIDifficulty` seviyesine göre ayrışır:
  - **Easy:** Düşük kart tercihi, %30 oranında yasal suboptimal hamle, deterministik `Random(seed)` desteği, hafızaya ihtiyaç duymaz.
  - **Normal:** Temel sezgiseller (en küçük yenen kart, en düşük ıskarta, partner eline saygı).
  - **Hard:** Tam kamusal hafıza analizi (`BotMemory`): Master kart tespiti (`isMasterCard`), rakip boşluk/çakma farkındalığı (`voidSuitsForPlayer`), kalan koz tükenme takibi (`remainingTrumpCount`), stratejik ıskarta (`_chooseHardDiscard`), partner koruma ve en küçük yeterli kozla çakma.
- **İhale Tahmini (`recommendBid`):** `AIDifficulty` seviyesine göre ayrışır:
  - **Easy:** Kaba el kuvveti hesabı, tohumlu rastgelelik, çekingenlik/kusurlu pas eğilimi.
  - **Normal:** Standart onör-el tablosu ve dağılım hesabı ile dengeli yasal teklif.
  - **Hard:** Onör sekansları (A-K-Q, A-K), uzun renk hakimiyeti, yan renk kısalıkları (void/singleton) ve ruff potansiyeli hesabı.
- **Koz Seçimi (`chooseTrump`):** `AIDifficulty` seviyesine göre ayrışır:
  - **Easy:** Basit kart sayısı sayımı, tohumlu yakın renk seçimi.
  - **Normal:** Renk uzunluğu, As/Papaz/Kız varlığı ve kart gücü konsantrasyonu.
  - **Hard:** Stratejik uzunluk kontrolü, A-K onör sekansı, yan renk kısalıkları (çakma gücü) ve ihale büyüklüğü katsayısı.
- **Anti-Cheat Güvencesi:** Kapalı eller, partner eli ve deste fonksiyon parametrelerine ASLA aktarılmaz; yalnızca botun kendi eli ve kamuya açık veriler kullanılır.

---

## 7. Asenkron & Zamanlayıcı Riskleri (Async / Timer Risks)

✅ **LIKYA-V2-002 İLE ÇÖZÜLDÜ (RESOLVED):**
- **Oturum ve Nesil Sayacı (`_gameGeneration`):** Her `startNewGame`, `_startRound`, `leaveMatch` ve `dispose` çağrısında generation artırılır. Havada kalan veya gecikmiş bot aksiyonları nesil uyuşmazlığında anında iptal edilir.
- **İptal Edilebilir Zamanlayıcılar (`Timer`):** Başıboş `Future.delayed` çağrıları yerine `_botTurnTimer`, `_biddingTimer` ve `_trickResolutionTimer` nesneleri kullanıldı. Reset, ayrılma ve dispose anında tüm zamanlayıcılar derhal sonlandırılır.
- **Re-entrancy Kilitleri:**
  - `_isBotActionRunning`: Eşzamanlı mükerrer bot tetiklemelerini önler.
  - `_isHumanActionLocked`: Seri/çift kart dokunmalarında ikinci kartın masaya düşmesini engeller.
  - `_isResolvingTrick`: El toplama sırasında yeni kart atılmasını kilitler.
  - `_isAdvancingRound`: Tur bittiğinde mükerrer sayfa/tur atlama akışlarını engeller.
- **Güvenli Dinleyici (`_safeNotifyListeners`):** Provider dispose edildikten sonra `notifyListeners()` çağrılmasını önler.

---

## 8. Kalıcılık Durumu (Persistence Status)

- `SharedPreferences`:
  - Oyuncu takma adı (nickname: `player_name`)
  - Toplam maç, kazanılan maç, ELO puanı
  - VIP üyelik durumu (`isVip`)
  - **Aktif Oyun Kaydı (`likya_batak_active_game_v1`):**

✅ **LIKYA-V2-006 İLE ÇÖZÜLDÜ (RESOLVED):**
- **Yetkili Model (`SavedGameModel` - Şema v1):**
  - Mantıksal durum serileştirmesi: `gameMode`, `currentPhase`, `currentRound`, `totalRounds`, `currentTurnIndex`, `biddingTurnIndex`, `currentHighestBid`, `highestBidderIndex`, `bidderIndex`, `passedPlayers`, `currentTrump`, `tricksPlayed`, `players` (eller, teklifler, kazanılan eller), `tableCards`, `playedCardsByPlayer`, `cumulativeScores`, `roundScoresHistory`, `roundResults`, `roundScored`, `statusMessage`.
  - Zamanlayıcılar, kilitler, BuildContext veya ağ nesneleri ASLA diske yazılmaz.
- **Kart ve Durum Bütünlüğü Doğrulaması (`validateIntegrity`):**
  - Mükerrer kart koruması (duplicate card detection).
  - El boyutu (maks 13 kart) ve masa boyutu (maks 4 kart) denetimleri.
  - Toplam aktif kart sayısı korunum kuralları.
- **Bozuk Kayıt Karantinası (Corrupt Save Quarantine):**
  - Bozuk veya ayrıştırılamayan JSON / şema uyuşmazlığı tespit edildiğinde kayıt sessizce diskten silinir ve ana menü çökmeden açılır.
- **Otomatik Kayıt (Autosave):**
  - Her ihale teklifi/pas, koz seçimi, kart oynama, el toplama ve tur tamamlama anında arka planda `unawaited(autoSaveCurrentGame())` ile tetiklenir.
  - `GameScreen` lifecycle dinleyicisi ile uygulama arka plana atıldığında (`inactive`, `paused`, `detached`) anında diske kaydedilir.
- **Kayıt Silme (Save Deletion):**
  - Yalnızca maç bittiğinde (`GamePhase.gameOver`), masadan ayrılınca (`leaveMatch`) veya kullanıcı onaylı yeni oyuna başladığında silinir.
- **UI Entegrasyonu:**
  - `MainMenuScreen` üzerinde aktif kayıt varsa "DEVAM ET" butonu ve detay kartı (Mod, Tur, Durum) gösterilir.
  - Aktif kayıt varken yeni oyuna basılırsa onay diyaloğu açılır.

---

## 9. Reklam & Satın Alma Durumu (Ads & IAP)

- **Google Mobile Ads (`AdService`):**  
  Varsayılan olarak Google resmi test ID'leri tanımlıdır (`ca-app-pub-3940256099942544...`). `--dart-define` ile canlı ID'leri alabilir.
- **Google Play Billing (`StoreProvider`):**  
  Yeni ürün kimliği `likya_batak_vip_monthly` olarak tanımlanmıştır. VIP durumu yerel bellekte saklanmaktadır.

---

## 10. Çevrimiçi Çok Oyunculu Durumu (Online Multiplayer)

- Backend kodları `backend/` klasöründe mevcuttur (FastAPI + WebSockets).
- Flutter istemci kodları (`multiplayer_game_provider.dart`, `websocket_service.dart`, `matchmaking_screen.dart`, `multiplayer_game_screen.dart`) mevcuttur.
- **Güvenlik Koruması:** `main_menu_screen.dart` içinde "YAKINDA" diyaloğu arkasında kilitlenmiştir. V2 kuralları gereği kapalı kalmaya devam edecektir.

---

## 11. Test Durumu (Tests)

- Toplam **271 birim ve entegrasyon testi** tamamı PASS durumdadır:
  1. `test/game_engine_test.dart` (20 test): Pure rules, renge uyma, koz çakma, overtrumping, çöp atma, el kazananı, skorlama, validatePlay.
  2. `test/game_provider_validation_test.dart` (5 test): Faz kısıtlamaları, ihale sınırları, koz seçimi, playCard yetki ve sahiplik koruması.
  3. `test/game_provider_async_test.dart` (11 test + 50 döngülü stres testi): Zamanlayıcı iptali, dispose koruması, re-entrancy kilitleri, seri kart basma koruması, nesil güvenliği.
  4. `test/scoring_engine_test.dart` (21 test): Tekli/Eşli batak puan kuralları, RoundResult yapısı, deste doğrulama, el toplamı doğrulama, kazanan belirleme.
  5. `test/ihaleli_batak_flow_test.dart` (32 test + 100 tur simülasyonu): Deste, ihale, koz seçimi, 13 el akışı, el kazanan indeksi, round state machine, game over, ağ yan etki koruması.
  6. `test/esli_batak_flow_test.dart` (47 test + 100 tur eşli simülasyonu): Takım kimliği (0+2 / 1+3), eşli ihale kuralları (min 8), koz seçimi, eşli el toplama, eşli puanlama, RoundResult gameMode, 100 tur deterministik eşli simülasyon.
  7. `test/esli_ai_test.dart` (9 test): Partner farkındalığı, ortağın kazandığı eli ezmeme, gereksiz koz atmama, rakibi geçme, kural uyumluluğu, gizli kartlara erişim engeli, tüm oturum pozisyonları.
  8. `test/koz_maca_flow_test.dart` (12 test + 100 tur simülasyonu): Koz Maça 4 oyuncu deste doğrulama, sabit Maça ♠ kozu, ihale fazını atlayıp direkt playing'e geçiş, yetkisiz ihale/koz seçimi reddi, scoring, 100 tur deterministik simülasyon.
  9. `test/game_save_service_test.dart` (15 test): PlayingCard/Player/RoundResult/SavedGameModel serileştirme, SharedPreferences IO, bozuk JSON karantinası, mükerrer kart engelleme, şema versiyon doğrulama, Gömmeli modu koruması.
  10. `test/game_resume_test.dart` (13 test + 100 döngülü persistence stres testi + JSON boyut analizi): İhaleli/Eşli/Koz Maça restorasyonu, mükerrer puanlama koruması, nesil güvenliği, terk etme ve sıfırlama kayıt temizliği.
  11. `test/bot_memory_test.dart` (17 test): Kamu bilgisi oynanan kart kaydı, mükerrer hamle koruması, renk sayacı, koz sayımı, kalan koz, boşluk (void) çıkarsaması, löve kazananı, tur sıfırlaması, gizli el izolasyonu.
  12. `test/played_history_test.dart` (10 test): Yetkili oynama kaydı, geçersiz hamle izolasyonu, el numarası, kayıt/devam geçmiş serileştirmesi, eski şema uyumluluğu, geçmişten hafıza yeniden inşası.
  13. `test/ai_public_information_test.dart` (4 test): AI kararının yalnızca kamuya açık verilerle çalışması, gizli ellerin mutlak izolasyonu, anti-cheat garantisi.
  14. `test/ai_difficulty_test.dart` (20 test): Easy/Normal/Hard yasal hamle koruması, deterministik tohumlama, en küçük kazanan, kamu hafızası kullanımı, master kart tespiti, koz takibi, kontrat hedefleri, partner koruma, varsayılan ve kalıcılık testleri.
  15. `test/advanced_ai_strategy_test.dart` (4 test): Hile karşıtı değişmezlik (kapalı ellerin AI kararına etki etmemesi), kamu durumu duyarlılığı (hafızadaki void bilgisinin kararı değiştirmesi), zorluk seviyeleri ayrışma testi, rakip boşluğuna göre el başlatma testi.
  16. `test/ai_bidding_test.dart` (16 test): Easy/Normal/Hard yasal ihale teklifi, 13 tavanı, Tekli (min 5) ve Eşli (min 8) kuralları, en yüksek teklif artırma, zayıf el pas, kuvvetli el teklif, pas geçenin tekrar girememesi, tohumlu determinizm, zorluk ayrışması, kapalı el hile karşıtı değişmezliği.
  17. `test/ai_trump_selection_test.dart` (12 test): Yasal koz rengi garantisi, tohumlu Easy seçimi, Normal kuvvetli renk seçimi, Hard stratejik uzunluk ve ruff potansiyeli seçimi, A-K onör sekansı etkisi, yalnızca kendi elini kullanma, kapalı ellerin etkisizliği, Koz Maça ihalesiz sabit maça garantisi.
  18. `test/ai_simulation_test.dart` (1 test): 600 turluk çoklu mod deterministik simülasyon testi (İhaleli, Eşli, Koz Maça x Easy, Normal, Hard; 0 kural ihlali, 0 çökme, 0 kilitlenme, p95 < 10ms).
  19. `test/widget_test.dart` (1 test): Temel widget smoke testi.

---

## 12. Öncelikli Problemler ve Yol Haritası (Priority Problems)

### Tamamlananlar (LIKYA-V2-000 → V2-007D)

1. [x] **Öncelik 1 (Kural Güvenliği):** LIKYA-V2-001 ile tamamlandı.
2. [x] **Öncelik 2 (Test Altyapısı):** 271 teste çıkarıldı.
3. [x] **Öncelik 3 (Asenkron Güvenlik):** LIKYA-V2-002 ile `_gameGeneration` ve re-entrancy kilitleri eklenerek çözüldü.
4. [x] **Öncelik 4 (İhaleli Tam Oyun Akışı):** LIKYA-V2-003 ile tamamlandı.
5. [x] **Öncelik 5 (Ölü Kod Temizliği):** `lib/state/game_state.dart` ve `lib/controllers/store_provider.dart` dosyaları projeden tamamen kaldırıldı.
6. [x] **Öncelik 6 (Eşli Batak Tam Akış & Takım Sistemi):** LIKYA-V2-004 ile tamamlandı.
7. [x] **Öncelik 7 (Ek Modlar — Koz Maça & Gömmeli Kural Araştırması):** LIKYA-V2-005 ile tamamlandı.
8. [x] **Öncelik 8 (Save & Resume / Durum Kalıcılığı):** LIKYA-V2-006 ile:
   - `SavedGameModel` (Şema v1) ve `GameSaveService` oluşturuldu.
   - İhaleli, Eşli ve Koz Maça için eksiksiz durum kaydı ve devam etme sağlandı.
   - Bozuk veri karantina mekanizması ve kart bütünlüğü kuralları uygulandı.
   - 100 döngülü kesintisiz persistence stres testi 0 hata ile doğrulandı.
9. [x] **Öncelik 9 (AI Kamuya Açık Hafıza Temeli — LIKYA-V2-007B):**
   - **AI Memory Foundation:** READY
   - **Hidden Hand Access:** NONE (Gizli eller ve deste kesinlikle belleğe alınamaz)
   - `PlayedCardRecord`, `BotMemory`, kamuya açık oynanan kart geçmişi, boşluk (void) çıkarsaması, koz sayımı ve kayıt/devam yeniden inşası eksiksiz kuruldu.
10. [x] **Öncelik 10 (Gelişmiş AI Stratejisi & Doğrulama — LIKYA-V2-007C1..D):**
   - **AI Memory Foundation:** READY
   - **Easy Card AI:** READY
   - **Normal Card AI:** READY
   - **Hard Card AI:** READY
   - **Difficulty Bidding AI:** READY
   - **Difficulty Trump AI:** READY
   - **Anti-Cheat:** VERIFIED (Gizli eller kararı etkilemez)
   - **Public-State Sensitivity:** VERIFIED (Kamu hafızası kararı yönlendirir)
   - **600-Round Simulation:** PASS (0 kural ihlali, 0 çökme, 0 kart kaybı)
   - **AI Performance:** PASS (Ortalama 0.4 - 3.4 µs, p95 2 µs)
   - **Save/Resume with AI:** PASS

### Kalan Riskler / Sonraki Adımlar

11. [ ] **Öncelik 11 (Final Sürüm & Release Hazırlığı):** `1.1.0+2` sürüm güncellemesi ve yayınlama kontrolleri.

---

## 13. Batak Modları Kural Özeti

| Kural | Tekli İhaleli Batak | Eşli Batak | Koz Maça (İhalesiz) | Gömmeli Batak |
|---|---|---|---|---|
| **Durum** | **PRODUCTION-READY** | **PRODUCTION-READY** | **PRODUCTION-READY** | **GOMMELI_RULES_UNRESOLVED (Yakında)** |
| **Kayıt/Devam (Save & Resume)** | **DESTEKLENİYOR** | **DESTEKLENİYOR** | **DESTEKLENİYOR** | **KAYDEDİLMEZ (Kilitli)** |
| **Takım Yapısı** | Bireysel (Herkes tek) | Takım A (0+2) vs Takım B (1+3) | Bireysel (Herkes tek) | 3 Kişilik Bireysel (Planlanan) |
| **Oyuncu Sayısı** | 4 | 4 | 4 | 3 (Planlanan) |
| **İhale** | Açık İhale (Min 5) | Açık İhale (Min 8) | **İhalesiz** | Kapalı/Açık İhale (Belirsiz) |
| **Koz** | İhalecinin Seçimi | İhalecinin Seçimi | **Sabit Maça ♠** | İhalecinin Seçimi |
| **Başlangıç Lideri** | İhale kazananı | İhale kazananı | Dağıtıcının solu | İhale kazananı |
| **Puanlama** | Başarı: bid*10+fazlalık, Batar: -bid*10 | Başarı: bid*10+fazlalık, Batar: -bid*10, Rakip: el*10 | **Her El: +10 Puan** | Belirsiz |

