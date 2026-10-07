# Likya Batak V2 — AI Bidding & Trump Selection Architecture (LIKYA-V2-007C2)

**Tarih:** 2 Ekim 2026  
**Durum:** READY & VERIFIED  
**Kapsam:** Zorluk Seviyesine Duyarlı İhale Teklifi ve Koz Seçimi (Difficulty-Aware Bidding & Trump Selection)  
**Oyun Kuralları & Kart Oynama Stratejisi:** Değiştirilmedi / Tamamen Korundu (V2-007C1 Card-Play AI Green).

---

## 1. Genel Bakış ve Mimari

LIKYA-V2-007C2 ile yapay zeka botlarının **ihale teklifleri (bidding)** ve **koz seçimleri (trump selection)** bot zorluk seviyesine (`AIDifficulty.easy`, `AIDifficulty.normal`, `AIDifficulty.hard`) duyarlı hale getirilmiştir.

### Temel API'ler:
1. **`AIEngine.recommendBid`:**
   ```dart
   static int? recommendBid({
     required List<PlayingCard> hand,
     required int currentHighestBid,
     required BatakGameMode gameMode,
     AIDifficulty difficulty = AIDifficulty.normal,
     Random? random,
   })
   ```
   - Botun elini, mevcut en yüksek teklifi ve oyun modunu değerlendirerek ya yasal bir teklif döner ya da pas geçer (`null`).
   - Tüm teklifler `GameProvider` ve kural motoru tarafından doğrulanır (`> currentHighestBid`, `>= minBid`, `<= 13`).
   - Koz Maça modunda `GameModeRules.hasBidding == false` olduğundan her zaman `null` döner.

2. **`AIEngine.chooseTrump` & `AIEngine.chooseTrumpForHand`:**
   ```dart
   static Suit chooseTrump(
     Player bot, {
     AIDifficulty difficulty = AIDifficulty.normal,
     Random? random,
     int? winningBid,
   })
   ```
   - İhaleyi kazanan bot için en uygun koz rengini (`Suit`) belirler.
   - Geriye uyumluluk için `AIEngine.chooseTrump(bot)` çağrısı varsayılan olarak Normal zorlukla çalışır.

---

## 2. İhale Stratejisi Sözleşmeleri (Bidding Contracts)

### A. Kolay İhale (`AIDifficulty.easy`)
* **Mantık:** Yeni başlayan veya acemi oyuncu simülasyonu.
* **El Değerlendirmesi:** Kaba el kuvveti (As=1.0, Papaz=0.75, Kız=0.5, 5+ kartlık uzun renk=+1.0).
* **Kusurluluk / Çekingenlik:**
  - `random != null` olduğunda %25 ihtimalle el kuvvetini 1 eksik hesaplayabilir.
  - Kuvvetli ellerde bile %20 ihtimalle çekingenlik gösterip pas geçebilir.
* **Yasal Güvence:** Teklif verdiği durumlarda ASLA kural dışına çıkmaz (`> currentHighestBid`, `minBid <= bid <= 13`).

### B. Normal İhale (`AIDifficulty.normal`)
* **Mantık:** Standart, dengeli ve deterministik el değerlendirmesi.
* **Onör & Dağılım Puanlaması:**
  - As: +1.0
  - Papaz: Korumalı veya As'lı ise +0.85; tek kart ise +0.3
  - Kız: Korumalı ise +0.5
  - Uzunluk: 5. kart +0.75, 6. kart +0.75
  - Eşli modda ortalama partner katkısı: +3 el
* **Sonuç:** El gücü `minAllowedBid` değerini karşılıyorsa `minAllowedBid` teklif eder; yetersizse pas geçer.

### C. Zor İhale (`AIDifficulty.hard`)
* **Mantık:** İleri düzey yarışmacı Batak değerlendirmesi (Yalnızca kendi elini kullanarak).
* **Onör Sekansları & Kalite:**
  - A-K-Q sekansı: +3.2 el (tam seri hakimiyet)
  - A-K sekansı: +2.1 el
  - K-Q sekansı: +1.6 el
* **Uzun Renk Hakimiyeti:**
  - 5 kartlık renk: +1.0
  - 6 kartlık renk: +1.2 (dominant koz potansiyeli)
* **Yan Renk Kısalığı & Çakma (Ruff) Gücü:**
  - En az 5 kartlık potansiyel koz rengi varsa:
    - Yan renkte boşluk (void): +1.6 el (hemen çakabilir)
    - Yan renkte tek kart (singleton): +0.8 el
  - Uzun koz yokken kısalıklar ceza puanı alır (-0.5 el).
* **Düz Dağılım Cezası:** 4-3-3-3 dağılımı ruff potansiyeli taşımadığı için -0.8 el ceza alır.
* **Sonuç:** Yüksek kontratları doğru analiz eder; zayıf elleri pas geçer.

---

## 3. Koz Seçimi Sözleşmeleri (Trump Selection Contracts)

### A. Kolay Koz Seçimi (`AIDifficulty.easy`)
* Elindeki kart sayılarını sayar.
* `random != null` olduğunda, 2. en uzun renk de en az 3 karta sahipse ve 1. renge yakınsa %30 ihtimalle o rengi seçebilir.
* Daima elinde bulunan yasal bir `Suit` döner.

### B. Normal Koz Seçimi (`AIDifficulty.normal`)
* Renk uzunluğu (`uzunluk * 3`), As (+4), Papaz (+3), Kız (+2) ve toplam kart gücü konsantrasyonu formülüyle en yüksek puanlı rengi deterministik olarak seçer.

### C. Hard Koz Seçimi (`AIDifficulty.hard`)
* İleri düzey stratejik değerlendirme:
  - Uzunluk kontrolü: 5+ kartlarda eksponansiyel kontrol çarpanı (`len * 4 + (len >= 5 ? (len - 4) * 3 : 0)`).
  - Yüksek ihale kontratlarında (`winningBid >= 8`): 5+ uzunluktaki renklere ekstra +4 puan (koz hakimiyeti hayati).
  - Sekans onörleri: A-K (+5), A-K-Q (+8).
  - Yan renk kısalıkları: Aday renk koz olduğunda yan renkteki boşluk (+3) ve tek kartlar (+1.5) ile ruff potansiyeli hesaplanır.
* Deterministik olarak en yüksek stratejik puanlı rengi seçer.

---

## 4. Hile Karşıtı (Anti-Cheat) & Yalnızca Kendi Eli Garantisi

1. **İhale ve Koz Fonksiyonları:** `AIEngine.recommendBid` ve `AIEngine.chooseTrumpForHand` metodları parametre olarak **YALNIZCA** botun kendi elindeki kartları (`hand`) alır.
2. **Erişilemez Gizli Veriler:** Rakiplerin kapalı elleri, ortağın kapalı eli ve destedeki dağıtılmamış kartlar bu fonksiyonlara aktarılmaz.
3. **Anti-Cheat Değişmezlik Testleri:**
   - `test/ai_bidding_test.dart` Test 15 & 16
   - `test/ai_trump_selection_test.dart` Test 8 & 9
   Rakiplerin veya ortağın gizli elleri değiştirilse/silinse dahi botun ihale teklifi ve koz seçimi matematiksel olarak %100 aynı kalır.

---

## 5. Koz Maça Sabit Maça İstisnası
- Koz Maça modunda ihale aşaması bulunmaz (`hasBidding == false`).
- `AIEngine.recommendBid` çağrılırsa anında `null` döner.
- `GameProvider` Koz Maça modunu doğrudan `GamePhase.playing` fazı ve `currentTrump = Suit.spades` ile başlatır; kullanıcı veya bot koz seçim metodunu tetikleyemez.
