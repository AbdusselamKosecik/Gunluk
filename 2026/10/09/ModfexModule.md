# ModfexModule — 2026-10-09

## Bağlam
ModaSimaModule (Sentez/LIVE eklenti modülü) temel alınarak yeni müşteri için ModfexModule oluşturulacak.

## Yapılanlar

### 1. ModaSimaModule → ModfexModule kopyası
- **Neden:** Modfex için aynı altyapıyla (e-Fatura/e-Arşiv controller'ları, Web API, BO extension'ları) ayrı modül.
- **Ne yapıldı:** ModaSimaModule'ün çalışma ağacı (commitlenmemiş değişiklikler dahil; .git/.vs/bin/obj hariç) `X:\GitHub\Sentez-Core\ModfexModule` altına kopyalandı. Dosya adları ve tüm metinlerde `ModaSima→Modfex`, `modasima→modfex` değiştirildi (namespace, sınıf, servis kaydı `ModfexIncomingEInvoiceGetControlService`, menü kaynağı `ModfexModuleMenu`, log dosyası `modfex_*.log`). .sln'de yeni proje GUID'i (`D5DE8B99-A8D1-42E2-A6A3-9A25EA3237BE`). Web API portu ModaSima ile çakışmasın diye 3132 → **3133**.
- **Dokunulan dosyalar:** `ModfexModule/` (tamamı yeni)
- **Komutlar:**
  ```bash
  cd /x/GitHub/Sentez-Core && mkdir ModfexModule
  (cd ModaSimaModule && tar --exclude=./.git --exclude=./.vs --exclude=./bin --exclude=./obj -cf - .) | (cd ModfexModule && tar -xf -)
  # dosya adlarında ve içerikte ModaSima->Modfex, modasima->modfex (sed)
  # ModfexModule.cs: WebApiPort = 3133 ; .sln: yeni GUID
  dotnet build ModfexModule.csproj
  git init -b main && git add <yollar> && git commit
  ```
- **Sonuç / doğrulama:** `dotnet build` → 0 hata, 44 uyarı (kaynaktan gelen mevcut uyarılar). Çıktı `..\output` altına `ModfexModule.dll`.
- **Commit:** `90fa592` — ModfexModule: ModaSimaModule'den kopyalandi

## Kararlar
- Web API portu 3133 (ModaSima 3132'de; iki modül aynı LIVE'da yüklenirse çakışmasın).
- ModaSima'nın commitlenmemiş halleri de kopyaya dahil edildi (çalışma ağacı esas alındı).

## Açık kalanlar / sonraki adım
- ~~Remote~~ → `gh repo create Sentez-Core/ModfexModule --private --source=. --remote=origin --push` ile oluşturuldu ve push edildi: https://github.com/Sentez-Core/ModfexModule
- Kod içindeki müşteriye özel mantık (ModaSima'ya özgü kurallar) Modfex için gözden geçirilmeli.
