# Likya Batak V2 — AI Difficulty Architecture & Guarantees (LIKYA-V2-007C1)

**Tarih:** 2 Ekim 2026  
**Durum:** READY & VERIFIED  
**Kapsam:** Yalnızca Kart Oynama Stratejisi (Card-Play Strategy Only)  
**İhale / Koz Seçimi Stratejisi:** Mevcut temel sezgisel yapı korunmuştur (Değiştirilmedi).

---

## 1. Genel Bakış ve Mimari

LIKYA-V2-007C1 ile botların kart oynama kararları, oyuncu tercihine göre 3 seviyeli bir zorluk mekanizmasıyla güçlendirilmiştir:
- `AIDifficulty.easy` (Kolay)
- `AIDifficulty.normal` (Normal - Varsayılan)
- `AIDifficulty.hard` (Zor)

Bu seviyeler `lib/models/ai_difficulty.dart` içinde tip güvenli bir `enum` olarak tanımlanmış, `AIEngine.chooseCard` API'sine parametre olarak eklenmiş ve `GameProvider` içinde `likya_batak_ai_difficulty` anahtarıyla `SharedPreferences` üzerinde kalıcı hale getirilmiştir.

Tüm zorluk seviyeleri **mutlak surette** `GameEngine.getValidMoves(...)` tarafından sağlanan yasal kart havuzundan seçim yapar. Hiçbir zorluk seviyesinde kural dışı kart oynanamaz.

---

## 2. Zorluk Seviyesi Sözleşmeleri (Contracts)

### A. Kolay Seviye (`AIDifficulty.easy`)
* **Amaç:** Yeni başlayan veya rahat bir oyun deneyimi arayan oyuncular için daha az rekabetçi, tahmin edilebilir hamleler sunmak.
* **Davranış Modeli:**
  1. Yasal kartlar arasından küçük değerli kartları atmaya eğilimlidir.
  2. Masada kazanan bir kart varken %30 ihtimalle elindeki en yüksek kazanan yerine elinde varsa daha zayıf veya el almayan bir yasal kart atarak kasıtlı suboptimal (kusurlu) hamle yapar.
  3. Deterministik testler için opsiyonel `Random(seed)` parametresi kabul eder.
  4. `BotMemory` kamu hafızasına ihtiyaç duymaz.

### B. Normal Seviye (`AIDifficulty.normal`)
* **Amaç:** Dengeli, adil ve standart klasik Batak tecrübesi.
* **Davranış Modeli:**
  1. Temel kural sezgisellerini uygular.
  2. Masayı kazanabilecek yasal kartlar arasından **en küçük kazananı** atar (elindeki daha büyük kağıtları israf etmez).
  3. Masayı kazanamıyorsa elindeki **en küçük kartı** elden çıkarır.
  4. Eşli oyunda ortağın eli kazandığını biliyorsa ortağın elini ezmez ve gereksiz yere koz atmaz.

### C. Zor Seviye (`AIDifficulty.hard`)
* **Amaç:** Kamuya açık tüm masayı, oynanan elleri ve rakip zaaflarını analiz eden üst düzey rekabetçi zeka.
* **Davranış Modeli:**
  1. **Master Kart Tespiti (`isMasterCard`):** Elindeki kartın o renkte masadaki en büyük kart olup olmadığını (örneğin As'ı veya As'ı daha önce oynanmış Papaz'ı) kamuya açık `BotMemory.hasCardBeenPlayed` verisiyle anlık tespit eder.
  2. **Boşluk / Çakma Farkındalığı (`voidSuitsForPlayer`):** Rakiplerin hangi renklerde boş olduğunu hafızadan bilir. Yerdeki rakiplerin boş olduğu bir renge girip master kartını çaktırmaktan kaçınır.
  3. **Koz Bitirme / Eritme Stratejisi (`remainingTrumpCount`):** Dışarıdaki koz sayısı sıfırlanmışsa tüm yan renk master'larını güvenle tahsil eder. Kendisi ihale sahibi ve kozları güçlüyse, yan renkleri sağlama almak için rakiplerin kozunu eritir.
  4. **Stratejik Iskarta / Kaçış (`_chooseHardDiscard`):** Masayı kazanamadığı veya ortağa el bıraktığı durumlarda, gelecekte el alma potansiyeli olan master kartları veya tek kalan korumalı kartları saklar; işe yaramayan boş kağıtları veya dışarıdaki tehlikesiz renkleri elden çıkarır.
  5. **Minimum Yeterli Koz ile Çakma:** Çakması gerektiğinde, masadaki kozu yenebilecek en küçük kozu seçerek yüksek kozlarını sonraki turlar için muhafaza eder.
  6. **İhale & Kontrat Koruması:** Kendisi veya ortağı ihale sahibiyse kontrat hedefine ulaşmak için garantili ellere oynar; rakip ihaleciyse rakibin el almasını engellemek üzere erken baskı kurar.

---

## 3. Anti-Cheat & Kamusal Bilgi İzolasyon Garantisi

Likya Batak bot motoru, zorluk seviyesi ne olursa olsun **KESİNLİKLE HİLE YAPMAZ**.

1. **İzole Girdi Parametreleri:** `AIEngine.chooseCard` fonksiyonu parametre olarak yalnızca:
   - Botun kendi eli (`bot.hand`)
   - Masadaki açık kartlar (`tableCards`)
   - Koz rengi (`trumpSuit`)
   - Kamuya açık hafıza (`BotMemory`)
   - İlgili botun masa indeksi (`botPlayerIndex`)
   - Eşli oyun bayrakları (`partnerIsWinning`)
   alır.
2. **Erişilemez Gizli Veriler:** Rakiplerin kapalı elleri, ortağın kapalı eli ve destede henüz dağıtılmamış kartlar motor seviyesinde **FONKSİYONA ASLA AKTARILMAZ**.
3. **Bütünlük Testi:** `test/advanced_ai_strategy_test.dart` içindeki anti-cheat testi, rakiplerin veya ortağın gizli elleri değiştirilse dahi botun kararının %100 aynı kaldığını matematiksel olarak doğrular.

---

## 4. Kamu Durumu Duyarlılığı (Public-State Sensitivity)

Hard AI, rakiplerin ellerini görmez; ancak masada **herkesin gözü önünde gerçekleşen** kamu olaylarına doğrudan duyarlıdır:
- Bir oyuncu belirli bir renge uymayıp başka bir renk attığında veya koz çaktığında, bu durum `BotMemory.recordPlay` ile kaydedilir.
- Hard AI bu bilgiyi okuyarak o oyuncunun o renkte tükendiğini anlar (`voidSuitsForPlayer`).
- `test/advanced_ai_strategy_test.dart` testleri, kamu hafızasındaki bu değişikliklerin Hard AI'ın hamle seçimini doğrudan ve ölçülebilir şekilde değiştirdiğini kanıtlar.

---

## 5. Kalıcılık ve Varsayılan Değerler

- Zorluk tercihi `SharedPreferences` üzerinde `likya_batak_ai_difficulty` anahtarında saklanır.
- Kayıtlı değer bulunamadığında veya bozuk olduğunda sistem güvenli şekilde `AIDifficulty.normal` değerine geri döner (`fallback`).
- Kayıt/devam (Save/Resume) süreçlerinde oyun durumu etkilenmez.
