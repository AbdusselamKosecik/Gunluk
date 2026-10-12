# Modasima — 2026-10-12

## Bağlam
`X:\Gitlab\Modasima\new` içindeki 6 taranmış proje (scan513–518.tif, 300 dpi, 1 bit, rulo) incelendi.
Soru: fabrika ısıtması için ısı pompası + GES ne gerekir, maliyet, enerji tüketimi. Dosyalara yazılmadı (git repo değil).

## Yapılanlar
### 1. Çizimlerin okunması
- **Komut:** PIL ile genişlik 1600 px'e küçültüp 2400 px'lik parçalara bölündü (scratchpad `cizim/`), alt ajan 83 parçayı taradı.
- **Paftalar:** 513 mimari (Er&Çe), 514 sıhhi/yangın (kalorifer+doğalgaz çizimi YOK), 515 elektrik, 516 vaziyet/aplikasyon,
  517 çelik çatı, 518 betonarme.
- **Bina:** Mendoğlu Çamaşırları, Düzce Gümüşova Hacıkadirler, Ada 282 Parsel 10-11 (elektrikte "282/4, 5.180,85 m²" — tutarsız).
  23,80 × ~87 m, 4.675 m² inşaat; zemin 1.830, 1. kat dikimhane 1.573; kuzeyde idari blok 3×160 m²;
  saçak ~+10, mahya ~+12,9; çelik beşik çatı %20 (~11°), mahya ~K7°B → çatı yüzeyleri DOĞU/BATI; paratoner mahyada.
  ~318 personel (soyunma dolabı). Elektrik projesi kurulu güç 129 kW. Yalıtım/ısıtma/ısı kaybı bilgisi YOK.
### 2. Ön boyutlandırma (varsayımlarla)
- Isı kaybı: U duvar 0,6 / pencere 2,8 / çatı 0,45 / döşeme 0,5; ΔT 22 K; ~18.300 m³, 0,5 hava değişimi
  → iletim ~74 kW + havalandırma ~70 kW ≈ 145 kW; ısınma payıyla 150–200 kW ısı pompası.
- Yıllık ısı: HDD ~2.300, gece/hafta sonu düşürme, iç kazançlar (insan+makine+aydınlatma ~100 kW) → ~120–200 MWh ısı,
  SCOP ~3 → ~40–65 MWh elektrik.
- GES: çatı ~200–250 kWp (D/B yerleşim, ~1.150–1.200 kWh/kWp) → ~240–300 MWh/yıl; güney açık alan/otopark ~100 kWp ek.
- Fiyat kaynakları: Bakanlık birim fiyat Ara 2025 75 kW HP 1.538.479 TL (+58.065 montaj); GES ~500–550 $/kWp (tek kaynak).

## Açık kalanlar
- Son 12 ay elektrik/doğalgaz faturaları, sözleşme gücü/trafo kVA, çatı örtüsü ve durumu, mevcut ısıtma sistemi,
  vardiya düzeni, yaz soğutması isteniyor mu. Parsel numarası teyidi. Statik çatı yük kontrolü (GES).
