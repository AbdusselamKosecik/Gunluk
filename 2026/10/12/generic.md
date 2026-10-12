# generic — 2026-10-12

## Bağlam
Gemini CAD (X20.1.0.4783, Apparel) ile entegrasyon: Sentez'den order + kumaş bilgisini Gemini'ye vermek.

## Yapılanlar

### 1. Araştırma
- Nest Expert sunucu modu siparişi Spread & Cut Planner / operatör / **ERP** / başka CAD'den alabiliyor; ERP ile **OTX** biçimi
  (ntcad-cam.com.vn gemini_nest_expert-en.pdf). Excel import doğrulanamadı. X20.1.0 = `*.GEMX` biçimi sürümü.

### 2. Örnek klasör incelemesi — `E:\TTTTTT\Desktop\LCW\EYSUNA` (SALT OKUNUR; orijinallere dokunulmadı)
- `EYSUNA-RPT 1  ADALET.gemx` = **ZIP**: `info_ext.xml` (AppVersion X20.1.0; TechnicalSheetInfo: ProductName,
  ClientName, SeasonName, **OrderName** — hepsi boş; 5 parça ARKA/ON/KOL/YAKA/PAT × 8 beden 1-3…3-4, alan mm²/100=cm²),
  `style_selector.xml`, `stitches.xml`, `models/rp*.rp` (ikili geometri), `thumbnail.png`.
  Kopya scratchpad'e açıldı (`unzip -x models/rp2.rp`), özet: `python -I gemx_ozet.py info_ext.xml`.
- `EYSUNA.pdf` = Gemini **Marker report**: Order info satırı
  `M1:3-6(x1);6-9(x2);9-12(x3);12-18(x3);18-24(x3);24-36(x3);3-4(x1)`, Marker width **155 cm**, length 5.35 m,
  verim %83.49, 16 ürün / 96 parça. (Kesimhane `GeminiMarker.cs` ile aynı rapor ailesi.)
- `.plt` = HPGL plot (`NE2526,1600`), `.cut` = kesim makinesi dosyası (`H1*G71*M70*...`), `-150.PLT` HPGL.
- İki `.zip` = **Gerber AccuMark V9** export (LCW'den gelen orijinal kalıplar; `*.tmp` + `version.4`).
- `Modfex-TAX ID.PDF` ilgisiz, açılmadı.

## Sonuç
- Gemini'ye giden girdi = model dosyası (.gemx) + **beden×adet oranı (M1:beden(xN);…)** + **kumaş eni**.
  Bu klasörde sipariş/nest giriş dosyası YOK (yalnız çıktılar) → giriş biçimi henüz görülmedi.

## Açık kalanlar
- Nest Expert'te kaydedilen nest/sipariş dosyası örneği (uzantısı neyse) ve lisanstaki modüller (Nest Expert Server / Cut Plan).
- OTX belgesi Gemini desteğinden.

### 3. .gemx üretme denemesi (kumaş adı, model adı, order no, kumaş eni)
- **Yapı:** `.gemx` = ZIP. Geometri ve asıl model verisi Gemini'nin ikili `unk`-etiketli biçiminde (`models/rp*.rp`,
  `phd.dat`; parça adları rp2.rp içinde UTF-16). Sıfırdan .gemx üretmek gerçekçi değil → **mevcut kalıbı şablon al, bilgi alanlarını doldur.**
- `info_ext.xml` TechnicalSheetInfo: ProductName, DesignerName, ProductTypeName, ClientName, SeasonName, **OrderName**,
  ProductDrawing, **Specifications**, AdditionalSpecifications(count), Attachements. Kumaş/en için ayrı alan YOK
  (en, nest/pastal parametresi) → şimdilik Specifications metnine.
- **Belirsizlik:** info_ext.xml büyük ihtimalle önizleme/özet önbelleği; asıl teknik föy ikili dosyada olabilir.
- **Deneme:** `gemx_bilgi_yaz.py <kaynak> <hedef> Alan=Değer ...` → `X:\Yazilim\generic\gemini-deneme\EYSUNA-DENEME-1.gemx`
  (ProductName=EYSUNA MODEL DENEME, OrderName=ORDER-DENEME-4315, ClientName=LCW, Specifications=KUMAS…155 cm).
  `unzip -t` OK. Orijinal dokunulmadı (md5 fb3c1edf…, 1612740 bayt, 23.04).
- Müşteri kalıbı içerdiği için üretilen .gemx git'e/günlüğe konmadı; betikler `generic-scripts/`.
- EYSUNA Sentez'de (Erp_Inventory / Erp_WorkOrder) bulunamadı.

## Sonraki adım
- Kullanıcı EYSUNA-DENEME-1.gemx'i Gemini'de açacak: açılıyor mu, Teknik Föy'de alanlar görünüyor mu?
- Görünmezse: Gemini'de aynı kalıba Teknik Föy'den ayırt edici değerler girip "farklı kaydet" → ikili diff ile alan yeri çözülecek.
