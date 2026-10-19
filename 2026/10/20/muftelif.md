# muftelif (SentezSelvedge) — 2026-10-20

## Bağlam
Kullanıcı tepkisi: "tasarımı ve ekran düzenini X:\Gitlab\fredericTr\muftelif\Selvedge gibi yap" ve ardından
"siparişlerde indirme, ölçümler falan bir yığın şey yok, QA'larda da indirme yok". SentezSelvedge arayüzü çıplak
tablo/formdu; eski Selvedge'in PDF raporları ve sipariş satırı işlevleri taşınmamıştı.

## Yapılanlar

### 1. Arayüz eski Selvedge görünümüne çekildi
- **Neden:** Kullanıcı eski uygulamanın düzenini istiyor.
- **Ne yapıldı:** `Selvedge/src/Selvedge.Web` incelendi (MainLayout, Button/Card/Badge/Input/PageHeader/DataTable/Modal).
  `web/src/components/ui.tsx` ortak bileşenler, `Yerlesim.tsx` koyu kenar menü (slate-900, aktif indigo, MFG logosu
  invert), üst şerit kullanıcı menüsü; giriş ekranı degrade zemin; tüm liste sayfaları DataTable; form sayfaları
  PageHeader + kart; sipariş KK/model QA modal; yeni ölçüm modal. `index.css` base katmanında form odak stili ve
  tablo hücre dolgusu. Bağımlılık: `lucide-react@1.17.0`, `@radix-ui/react-dialog@1.1.15`; `public/mfg-logo.png`.
- **Doğrulama:** Sahte API (scratchpad `mock/sahte-api.mjs`, port 5401) + vite 5179 + Chrome DevTools ekran
  görüntüleri: giriş, ana sayfa, siparişler, sipariş modalı, QA raporu, ölçüm modalı, anket tasarım. Bulunan
  kusurlar düzeltildi: filtre kutularının `w-full` ile yayılması (`girdi()` yardımcı), tarih/rozet satır kırma,
  form tablolarında başlıkların yapışması, "Sil" metni → çöp kutusu ikonu, anket form etiketleri.
- **Commit:** `c6587b5` — style(sentez-selvedge/web): eski Selvedge arayuzu

### 2. PDF raporları + sipariş penceresi + QA fotoğrafları
- **Neden:** Eski uygulamada "QA raporu (MFG) indir", tekil QC PDF, sipariş anketleri/ölçümleri vardı.
- **Ne yapıldı:**
  - `Selvedge.Reports` → `api/Rapor` (OrderQaDocument, RaporVerisi, ImageDimensions, MeasureValueFormatter,
    QuestPdfBootstrap), QuestPDF 2026.5.0. Levi's/Inditex şablonları alınmadı (eskide de kullanım dışı).
  - `RaporServisi`: tek QC (`/api/kk/{id}/pdf`) ve sipariş birleşik (`/api/order-qa/order/{id}/pdf`), `?en=true`.
    Veri: KkStore detay, Measure/MeasureItem oturumları, SurveyResponse/Answer/Option, Attachment resimleri
    (`MimeType LIKE 'image/%'`), Sentez'den marka/sezon, OrderQc tedarikçi/final karar. PublicBaseUrl boş (spec §6).
  - `/api/order-qa/order/{id}/anketler`, `/api/files?entityType&entityId`, `DELETE /api/files/{id}` (soft delete).
  - Web: sipariş satırında MFG PDF + "QA raporu aç" (`/kk/yeni?siparis=`), modalda sekmeler (Sipariş KK, Model QA,
    QA raporları, Ölçümler, Anketler); QA listesinde PDF; rapor sayfasında QC PDF TR/EN + Fotoğraflar.
- **Doğrulama:** `RaporSablonTests` (QC/ORDER × TR/EN + boş rapor) gerçek PDF üretiyor; rapor SQL'leri canlıda
  salt okuma ile çalıştırıldı; testler 472/472; web build temiz.
- **Commit:** `943a603` — feat(sentez-selvedge): QA PDF raporlari, siparis penceresi, QA fotograflari

### 3. Dağıtım paketi yenilendi
- `Deploy-IIS.ps1` publish'e `-r win-x64 --self-contained false` eklendi (QuestPDF linux/osx/arm yerel
  kütüphaneleri paketi 50 MB yapıyordu → 23,6 MB). Commit `2203f19`.
- `SentezSelvedge-IIS-192.168.3.228-91.zip` yeniden üretildi (152 dosya); `IIS-KURULUM.txt`'e 2026-10-20 ekleri.

## Kararlar
- PDF'te resimler link'siz (fotoğraflar açık adreste durmaz).
- Sipariş raporunun sonucu = Sipariş KK paneli "Final KK kararı".

## Açık kalanlar / sonraki adım (eski Selvedge'de olup henüz yok)
- Dashboard (KPI/grafikler), e-posta ile rapor gönderme, listelerde Excel'e aktarma, anket cevapları sayfası +
  Excel, hata kataloğu ekranı, kullanıcı/rol yönetim ekranı, Final QC onay/sıfırlama akışı (kısmen Sipariş KK'da).
- Gerçek veriyle uçtan uca deneme sunucuda yapılmalı (bu makinede .NET → SQL bağlantısı zaman aşımı).
