# sentezservis — 2026-10-06

## Bağlam
Kullanıcı bir SQL sorgusu verdi ve diğer ekranlar gibi tarih/şirket seçimli bir ekran istedi. Sorgu
`Erp_Invoice` ile `Erp_GLReceipt`'i eşliyor (`SourceModule = 11`); durumlar GL RECEIPT BULUNAMADI,
ESLESME HATASI (`|GrandTotal − Debit| > 0.1`) ve OK. Kısa tasarım onaylandı, Excel de istendi.

## Yapılanlar

### 1. Fatura muhasebe kontrolü ekranı
- **Ne yapıldı:**
  - **Core:**
    - `Fatura/MuhasebeKontrolu.cs`: `MuhasebeDurumu.Belirle` (SQL CASE ile birebir; NULL tutar → OK),
      satır ve sonuç modeli, sayaçlar.
    - `MuhasebeKontroluDeposu.cs`: ErpAcAsync ile salt okuma. Bitiş için `< bitiş + 1 gün`.
    - `MuhasebeKontrolExcel.cs`: Özet + Kontrol sayfaları, numaralar metin.
  - **Host:** `Api/MuhasebeKontroluUclari.cs`. `GET /api/muhasebe-kontrolu/` ve `/excel`, ikisi de GirisIster.
    `Program.cs`'te kayıt.
  - **Web:**
    - `api/muhasebeKontrolu.ts`, `pages/MuhasebeKontroluSayfasi.tsx` + test.
    - Şirket listesi `/api/fatura/sirketler`'den; CRS tanımsız şirket de seçilebiliyor.
    - Menü: Operasyon → Fatura muhasebe kontrolü (E-fatura mutabakatın altında).
  - **Belge:** `docs/muhasebe-kontrolu.md`.
- **Testler:**
  - .NET 671 → 682 (durum kuralı, tolerans sınırı 0,10, NULL, sayaçlar, Excel, salt okuma sınır testi).
  - Web 68 → 72.
- **Canlı doğrulama (salt okuma, yerel host üzerinden):**
  - 01 şirketi, 01–31.08.2026: 281 satır (OK 262, GL yok 6, eşleşme hatası 13). Ham SQL ile birebir aynı.
  - Süre 2,8 sn. Excel 31 KB, Özet doğru, 281 satır.
  - Hatalı tarih ve olmayan şirket 400 döndürdü.
- **Tuzak:** Scratchpad temizlenmişti; `sorgu.py`, `api.py`, `yerel_calistir.sh` yeniden yazıldı. İlk
  denemede VPN kapalıydı (192.168.1.3'e ping yok); kullanıcı bağlanınca devam edildi.
- **Commit:** `bed96a9`

### 2. Paket
- **Ön kontrol:** Commit edilmemiş kod yoktu. Kökte duran `SentezServis-2026-09-30-misirli-renk-kirilimi/`
  klasörü önceki paketin açılmış kopyası, kaynak kod değil.
- **Derleme:** Temiz worktree'den (`bed96a9`) `yayinla.ps1`, sonra `Compress-Archive`.
  - Tek komutta "derle + zip + temizle" bir güvenlik kancasına takıldı; adımlar ayrı çalıştırıldı.
- **Sonuç:** `SentezServis-2026-10-06-muhasebe-kontrolu.zip`, 73,8 MB. Arayüz 2026-10-06 03:09.
- **30.09 paketiyle karşılaştırma:**
  - Dosya listesi aynı.
  - app.js'te `muhasebe-kontrolu` 0 → 5. Diğer ekranlar (karşıt kod, planlama, Pierre, Mısırlı, kasa) aynı.
  - Örnek ayarda 6 × `<DOLDURUN>`; `appsettings.json` pakette yok.

## Açık kalanlar / sonraki adım
- Paket kurulumu sonrası `/api/surum` → arayuzTarihi 2026-10-06 03:09.
