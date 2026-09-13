# sentezservis — 2026-09-14

## Bağlam
`X:\Gitlab\modfex-apparel\sentezservis` sadece "Ilk iskelet" commit'i (README + VS .gitignore) içeriyordu.
Hedef: Modasima'daki SentezServis kodunu buraya almak, sonra içinden çoğunu silmek.

## Yapılanlar

### 1. Modasima/sentezservis kodunun kopyalanması
- **Neden:** modfex-apparel için Sentez ERP entegrasyon servisi, Modasima'daki çalışan projeden türetilecek.
- **Ne yapıldı:** Kaynak çalışma ağacı (commit edilmemiş değişiklikler ve untracked dosyalar dahil — EtiketCiktisi vb.) kopyalandı.
  Hariç: `.git .vs bin obj node_modules yayin dist wwwroot Logs`, `*.zip *.rar`, `appsettings.json` (Modasima sırları), kaynak `.gitignore`/`README.md`.
  Kaynağın .gitignore'undaki projeye özel kurallar hedef .gitignore'un sonuna eklendi; `wwwroot/.gitkeep` oluşturuldu;
  `.gitattributes` ile `*.pdf *.xlsx *.fr3` binary işaretlendi (autocrlf PDF'i bozmasın diye).
- **Dokunulan dosyalar:** tüm ağaç — `src/ tests/ web/ docs/ deploy/ samples/ Tema/ yonetim/ SentezServis.slnx`, `.gitignore`, `.gitattributes`
- **Komutlar:**
  ```powershell
  robocopy "X:\Gitlab\Modasima\sentezservis" "X:\Gitlab\modfex-apparel\sentezservis" /E /XD .git .vs bin obj node_modules yayin dist wwwroot Logs /XF *.zip *.rar appsettings.json .gitignore README.md *.user *.log
  ```
- **Sonuç / doğrulama:** 542 dosya, 8.5 MB, hata yok. 544 dosya commit edildi.
- **Commit:** `b73c179` — Modasima/sentezservis kodu tasindi (temizlik oncesi tam kopya)

## Kararlar
- Modasima `appsettings.json` (sırlar) kopyalanmadı — modfex için yeniden oluşturulacak.
- Temizlik öncesi tam kopya ayrı commit olarak tutuldu; silme işlemleri ayrı commit'lerde.

## Açık kalanlar / sonraki adım
- Hangi modüllerin kalacağı belirlenip geri kalanı silinecek.
- README modfex'e göre güncellenecek; `appsettings.json` oluşturulacak.
