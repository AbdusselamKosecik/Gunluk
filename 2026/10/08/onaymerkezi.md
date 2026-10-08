# onaymerkezi — 2026-10-08

## Bağlam
Kullanıcı yeni proje istedi: API + yönetim paneli; olaylar (event) ve onaylar; Telegram botu panelden yönetilecek;
hangi olay/onay kime gidecek panelden seçilecek; log: gönderildi / gördü / onayladı zamanları.

## Yapılanlar

### 1. Kararlar (kullanıcıya soruldu)
- Ad `onaymerkezi`; panel **web** (Blazor Server, API ile aynı sunucu); tablolar **SentezCore `UZM_`**.

### 2. Proje iskeleti
- **Ne yapıldı:** `X:\Gitlab\modfex-apparel\onaymerkezi`; `.gitignore/.gitattributes` kesimhane'den.
  `Program.cs`'e `GET /api/saglik` eklendi; `Home.razor` yer tutucu; `README.md`; `docs/tasarim-taslak.md`
  (taslak tablolar UZM_OlayTuru / UZM_Alici / UZM_OlayYonlendirme / UZM_Olay / UZM_OlayMesaj, açık sorular).
- **Komutlar:**
  ```bash
  dotnet new blazor -n OnayMerkezi -o OnayMerkezi --interactivity Server --empty
  dotnet new sln -n OnayMerkezi --format slnx; dotnet sln add OnayMerkezi
  dotnet build -c Debug     # 0 hata
  git init -b main; git remote add origin git@gitlab.com:modfex-apparel/onaymerkezi.git; git push -u origin main
  ```
- **Commit:** `32d7bee` — Ilk iskelet
- **Sonuç:** `dotnet run` → `/api/saglik` {"durum":"ok"}, `/` "Onay Merkezi" başlığı döndü.

## Kararlar
- Telegram Bot API okundu bilgisi vermez → "gördü" zamanı "Gördüm" butonu veya Mini App/link açılışıyla ölçülecek (kullanıcıya soruldu).

## Açık kalanlar / sonraki adım
- Onay zinciri (tek/sıralı/çoklu), bot–Sentez kullanıcı eşleştirmesi, API kimlik doğrulama, ilk olay türleri.
- Tasarım netleşince spec + plan, sonra tablolar ve ekranlar.
