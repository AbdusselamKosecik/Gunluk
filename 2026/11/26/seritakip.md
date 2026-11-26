# seritakip — 2026-11-26

## Bağlam
FredericPieceWork içine eklenen "Seri / QR Takip" ekranı (bkz. `fredericpiecework.md`) kullanıcı isteğiyle bağımsız programa çevrildi.

## Yapılanlar

### 1. Bağımsız SeriTakip programı + yeni GitLab reposu
- **Neden:** Takip ekranı üretim okutma programından bağımsız açılabilsin.
- **Ne yapıldı:**
  - `X:\Gitlab\fredericTr\seritakip` → `git init -b main`, `.gitignore` piecework'ten kopyalandı.
  - `SeriTakip/SeriTakip.csproj`: WinExe, `net6.0-windows` (fabrika PC'lerinde piecework ile aynı runtime), paketler `Dapper 2.1.35`, `System.Data.SqlClient 4.8.6`.
  - `Ayarlar.cs`: `<exe>\Frederic\parameter.json` (piecework ile aynı dosya/biçim) System.Text.Json ile okunur (case-insensitive); Server/Database boşsa veya dosya yoksa açılışta hata mesajı. Bağlantı: `Server=..;Database=..;User Id=..;Password=..;`. YikamaId/FinishTamirId tamir proses adları için.
  - `SeriTakipForm.cs`: piecework'teki form; DapperLite → Dapper (`QueryFirstOrDefault`, `Query(...).ToList()`), `BarcodeDetail` yerine yerel `Urun` sınıfı. SQL mantığı aynı (UD_Number virgüllü LIKE + InventoryVariantId EXISTS + opsiyonel WorkOrderId, palet = Cutter).
  - Form tam ekran açılır; `Program.cs` önce ayarı yükler.
  - SDK 10 `dotnet new sln` → `SeriTakip.slnx` üretti; proje `dotnet sln SeriTakip.slnx add` ile eklendi.
  - README: kurulum (publish + parameter.json kopyala), veri kaynağı, bilinen sınırlar.
- **Dokunulan dosyalar:** `SeriTakip.slnx`, `SeriTakip/SeriTakip.csproj`, `SeriTakip/Program.cs`, `SeriTakip/Ayarlar.cs`, `SeriTakip/SeriTakipForm.cs`, `SeriTakip/SeriTakipForm.Designer.cs`, `README.md`, `.gitignore`
- **Komutlar:**
  ```bash
  dotnet build SeriTakip.slnx
  git remote add origin git@gitlab.com:fredericTr/seritakip.git
  git push -u origin main   # GitLab push-to-create ile repo oluştu
  ```
- **Sonuç / doğrulama:** Derleme başarılı (sadece NETSDK1138 net6 EOL uyarısı). Gerçek veritabanında çalıştırılmadı.
- **Commit:** `4bc14d9` — SeriTakip: QR ile parcanin operasyon ve palet gecmisi (bagimsiz program)

## Kararlar
- Ayrı ayar dosyası açmak yerine piecework'ün `parameter.json`'u yeniden kullanıldı: kurulumda tek kopyalama yeter.
- Kod iki yerde durmasın diye ekran piecework'ten kaldırıldı.

## Açık kalanlar / sonraki adım
- Sahada gerçek QR ile test; 12=KESIM, 22=DIKIM eşlemesi doğrulanmalı.
- GitLab'da yeni repo görünürlüğü (private olmalı) kontrol edilmeli.
