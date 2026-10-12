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

### 3. Revizyon: bina DEPO olarak kullanılıyor
- **Kullanıcı:** Makine yok, sadece depo; ısıtılacak yerler yemekhane + depo içi.
- **Yeni varsayımlar:** depo 12–14 °C (tekstil için nem/yoğuşma koruması), yemekhane 20 °C; sızıntı 0,3 hava değişimi; iç kazanç ~0.
  Depo UA ~3,35 + havalandırma ~1,9 = ~5,2 kW/K × ΔT 16 K ≈ 85 kW; yemekhane ~15–20 kW → **~100 kW**.
  Yıllık: HDD(13 °C) ~1.400 → depo ~120–180 MWh ısı; yemekhane ~14 MWh; SCOP ~3,3 → **~40–60 MWh elektrik**.
  8–10 °C hedefte yaklaşık yarısı.
- **Sistem önerisi:** havadan havaya (VRF / çatı tipi paket) — su tesisatı gereksiz; yüksek tavan için destratifikasyon fanı.
  Kaba maliyet ~3–5 M TL + KDV.
- **GES:** tüketim küçük (~80–120 MWh/yıl toplam) → ~90–100 kWp yeterli (~50–65 bin $); tüm çatı (~220 kWp) fazla üretir.
  Kış üretimi düşük, mahsuplaşma kuralı kurulumcuyla netleşmeli.

### 4. Mevcut ısıtma: sıcak sulu hava apareyleri (2 fotoğraf)
- **Dosyalar:** `X:\Gitlab\Modasima\new\WhatsApp Image 2026-10-12 at 08.45.36/37.jpeg`
- **Görülen:** Duvara konsolla asılı, ayarlı panjurlu, sıcak sulu (gidiş-dönüş vanalı) hava apareyleri; galvaniz boru +
  PPR rakor geçişleri, birleşimlerde pas; panjurlar tozlu, örümcek ağı → uzun süredir kullanılmıyor olabilir.
  Sulu sistem olduğuna göre bir kazan (muhtemelen doğalgaz) var.
- **Sonuç:** Havadan suya ısı pompası mevcut boru + apareylere bağlanabilir (ayrı VRF gerekmez).
  Aparey 90/70 °C için seçilir; 50–55 °C suda kapasite ~%45–55'e düşer, ama depo hedefi 12–14 °C olduğu için
  (eski fabrika yükü ~145+ kW → depo ~85 kW) mevcut apareyler büyük ihtimalle yeter. Kazan yedek kalırsa hibrit.
- **İstenecek:** aparey sayısı + etiket (model, kW), kazan dairesi/kazan etiketi, gaz faturaları, apareylerin çalışıp çalışmadığı.
