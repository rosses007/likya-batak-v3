# Likya Batak V2 — AI 600-Round Simulation & Performance Report (LIKYA-V2-007D)

**Tarih:** 2 Ekim 2026  
**Toplam Simüle Edilen Tur:** 600 / 600  
**Genel Bütünlük Durumu:** PASSED (%100 HATASIZ)  
**Toplam Süre:** 273 ms  

---

## 1. Simülasyon Metodolojisi ve Tohumlama Stratejisi

Simülasyon motoru kural ihlallerini, kilitlenmeleri (deadlock) ve performans darboğazlarını tespit etmek için deterministik tohumlama (`seededDeal`) stratejisi kullanmıştır:
- **İhaleli Batak (300 Tur):**
  - Easy: Seed 1000..1099 (100 Tur)
  - Normal: Seed 2000..2099 (100 Tur)
  - Hard: Seed 3000..3099 (100 Tur)
- **Eşli Batak (150 Tur):**
  - Easy: Seed 4000..4049 (50 Tur)
  - Normal: Seed 5000..5049 (50 Tur)
  - Hard: Seed 6000..6049 (50 Tur)
- **Koz Maça (150 Tur):**
  - Easy: Seed 7000..7049 (50 Tur)
  - Normal: Seed 8000..8049 (50 Tur)
  - Hard: Seed 9000..9049 (50 Tur)

---

## 2. Mod ve Zorluk Seviyesi Bütünlük Matrisi

| Mod | Zorluk | İstenen | Tamamlanan | Kural İhlali | Mükerrer Kart | Kilitlenme | Çökme | Skor Hatası | Löve Hatası |
|---|---|---|---|---|---|---|---|---|---|
| single | easy | 100 | 100 | 0 | 0 | 0 | 0 | 0 | 0 |
| single | normal | 100 | 100 | 0 | 0 | 0 | 0 | 0 | 0 |
| single | hard | 100 | 100 | 0 | 0 | 0 | 0 | 0 | 0 |
| partner | easy | 50 | 50 | 0 | 0 | 0 | 0 | 0 | 0 |
| partner | normal | 50 | 50 | 0 | 0 | 0 | 0 | 0 | 0 |
| partner | hard | 50 | 50 | 0 | 0 | 0 | 0 | 0 | 0 |
| kozMaca | easy | 50 | 50 | 0 | 0 | 0 | 0 | 0 | 0 |
| kozMaca | normal | 50 | 50 | 0 | 0 | 0 | 0 | 0 | 0 |
| kozMaca | hard | 50 | 50 | 0 | 0 | 0 | 0 | 0 | 0 |

---

## 3. Yapay Zeka Karar Performansı (Stopwatch Ölçümleri)

| Zorluk | Karar Tipi | Örnek Sayısı | Ortalama (µs) | Medyan (µs) | p95 (µs) | En Kötü (µs) |
|---|---|---|---|---|---|---|
| easy | Kart Oynama | 10400 | 2.2 | 1 | 5 | 2873 |
| easy | İhale Teklifi | 468 | 9.5 | 4 | 14 | 1715 |
| easy | Koz Seçimi | 150 | 18.5 | 6 | 24 | 1457 |
| normal | Kart Oynama | 10400 | 0.6 | 0 | 1 | 464 |
| normal | İhale Teklifi | 471 | 7.0 | 4 | 9 | 1150 |
| normal | Koz Seçimi | 150 | 7.2 | 4 | 7 | 445 |
| hard | Kart Oynama | 10400 | 1.4 | 0 | 2 | 1493 |
| hard | İhale Teklifi | 553 | 7.8 | 5 | 10 | 1095 |
| hard | Koz Seçimi | 150 | 14.3 | 7 | 13 | 496 |

---

## 4. Stratejik Karar ve Hafıza Metrikleri

### EASY Seviyesi Stratejik Özeti:
- Toplam Kart Kararı: 10400
- El Alma Fırsatları: 6816
- En Küçük Yeterli Kazanan Kullanımı: 4832
- Gereksiz Yüksek Kart Oynama: 1083
- Toplam Koz Oynama: 2600
- Partner Kazanırken Gereksiz Koz: 113
- Partner Elini Ezme (Overtake): 157
- Partner Elini Koruma (Preserve): 337

### NORMAL Seviyesi Stratejik Özeti:
- Toplam Kart Kararı: 10400
- El Alma Fırsatları: 5623
- En Küçük Yeterli Kazanan Kullanımı: 3940
- Gereksiz Yüksek Kart Oynama: 1598
- Toplam Koz Oynama: 2600
- Partner Kazanırken Gereksiz Koz: 146
- Partner Elini Ezme (Overtake): 136
- Partner Elini Koruma (Preserve): 402

### HARD Seviyesi Stratejik Özeti:
- Toplam Kart Kararı: 10400
- El Alma Fırsatları: 5966
- En Küçük Yeterli Kazanan Kullanımı: 4512
- Gereksiz Yüksek Kart Oynama: 1344
- Toplam Koz Oynama: 2600
- Partner Kazanırken Gereksiz Koz: 159
- Partner Elini Ezme (Overtake): 112
- Partner Elini Koruma (Preserve): 381
- Master Kart Tanıma Fırsatları: 7796
- Master Kart Tahsilatı: 2573
- Kalan Koz Tükenme Takibi (`remainingTrumpCount == 0`): 307 karar
- Rakip Boşluk (Void-suit) Farkındalığı: 7063 karar

---

## 5. Doğrulama ve Sonuç
- **600 Turun Tamamı:** 0 kural dışı hamle, 0 çökme, 0 kilitlenme ve 0 kart kaybı ile tamamlandı.
- **Kart Korunumu (Card Conservation):** 52 kartın tamamı her löve ve tur geçişinde eksiksiz doğrulandı.
- **Performans:** Hard AI ortalama karar süresi 10-50 mikrosaniye aralığında olup hedef sınırı olan 5000 mikrosaniyenin (5 milisaniye) 100 kat altındadır.

**DURUM: LIKYA-V2-007D AI SYSTEM VERIFIED READY**
