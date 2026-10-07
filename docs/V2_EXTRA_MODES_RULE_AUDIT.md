# Likya Batak V2 — Extra Modes Rule Audit & Decision Document

**Tarih:** 2 Ekim 2026  
**Aktif Proje:** `C:\Users\erkan\likya_batak_new`  
**Referans Proje:** `C:\Users\erkan\batak_app` (Salt Okunur)

---

## 1. Yönetici Özeti (Executive Summary)

LIKYA-V2-005 kapsamında aktif ve eski kod tabanı, commit geçmişi, test dosyaları ve kaynak dokümanları taranarak **Gömmeli Batak** ve **Koz Maça (İhalesiz Batak)** modlarının mevcut kod ve mimari durumu incelenmiştir.

---

## 2. Mod Sınıflandırması ve Bulgular

### A. Koz Maça (İhalesiz Batak)
- **Sınıflandırma:** **B) Kısmi / Kod İçi Amaçlanan Kurallar Belirli**
- **Kod İçi Kanıtlar:**
  1. `lib/models/card_model.dart:2`:  
     `spades, // Maça (İhalesiz batakta değişmez koz)`
  2. `lib/engine/game_engine.dart:7`:  
     `/// [trumpSuit]: O oyunun kozu (İhalecinin belirlediği veya standart Maça)`
- **Belirlenen Kural Seti:**
  - **Oyuncu Sayısı:** 4 oyuncu (1 İnsan + 3 Bot)
  - **Deste ve Dağıtım:** 52 kart, 4 x 13 standart dağıtım
  - **Koz:** Sabit `Suit.spades` (Maça). Değiştirilemez, ihale veya koz seçim fazı yoktur.
  - **İhale:** İhalesizdir (Açık artırma yapılmaz). Tur doğrudan `GamePhase.playing` fazı ile başlar.
  - **İlk Lider:** Dağıtıcının solundaki oyuncu (`(currentRound - 1) % 4`).
  - **Kart Oynama Kuralları:** `GameEngine.getValidMoves` ve `GameEngine.validatePlay` ile tam uyumlu (Renge uyma, koz çakma, overtrumping zorunluluğu).
  - **Puanlama:** Her oyuncunun aldığı el sayısı üzerinden hesaplanır (`tricksWon * 10` veya standart el başı puan).
  - **Durum:** **PRODUCTION-READY** olarak kural motoruna ve `GameProvider`'a entegre edilebilir.

---

### B. Gömmeli Batak (Gömülü / 3 Kişilik)
- **Sınıflandırma:** **D) Güvenilir Amaçlanan Kural Bulunamadı (GOMMELI_RULES_UNRESOLVED)**
- **Kod İçi Kanıtlar:**
  - `batak_app` (eski) ve `likya_batak_new` (aktif) kod tabanında gömü (`buriedCards`), gömüden kart alma / yere gömme (`discard`), 3 kişilik dağıtım veya gömmeli puanlama kuralına dair tek bir satır kod, yorum veya model bulunmamaktadır.
  - Bölgesel Batak varyantlarında Gömmeli Batak için çelişkili kurallar mevcuttur (ör. 3 oyuncu 16'şar kart + 4 gömü; ihaleyi alanın 4 kart alıp 4 kart gömmesi; gömülen kartların puan değeri veya ceza kuralları).
- **Kural Kararı (Master Direktif Gereği):**
  - Desteklenmeyen veya tahmin edilen kural uydurmaktan kaçınılmıştır (**DO NOT INVENT AN UNSUPPORTED REGIONAL RULESET**).
  - Durum: **GOMMELI_RULES_UNRESOLVED**
  - Ana menü ve arayüzde: **YAKINDA / DEVRE DIŞI** olarak korunacaktır.
  - İlerleyen sürümlerde ürün sahibi kural spektini netleştirdiğinde güvenle eklenecektir.

---

## 3. BatakGameMode Enum ve Mimari Yapılandırması

```dart
enum BatakGameMode {
  single,    // Tekli İhaleli Batak (4 oyuncu, açık ihale, seçilebilir koz)
  partner,   // Eşli Batak (4 oyuncu, Takım A: 0+2 vs Takım B: 1+3, min 8 ihale)
  kozMaca,   // Koz Maça / İhalesiz Batak (4 oyuncu, ihalesiz, sabit Maça kozu)
  gommeli,   // Gömmeli Batak (GOMMELI_RULES_UNRESOLVED - Menüde YAKINDA)
}
```

---

## 4. Uygulama ve Doğrulama Planı

1. `BatakGameMode.kozMaca` modunun `GameModeRules`, `GameProvider`, `ScoringEngine` ve `AIEngine` seviyesinde tam motor entegrasyonu.
2. Sabit `Suit.spades` koz garantisi ve yetkisiz koz değiştirme koruması.
3. İhale fazının atlanarak direkt oyun fazına geçişi (`GamePhase.playing`).
4. `test/koz_maca_flow_test.dart` ile 15+ test ve 100 tur deterministik simülasyon.
5. Gömmeli modunun güvenli şekilde UI'da "Yakında" olarak korunması ve testlerle doğrulanması.
