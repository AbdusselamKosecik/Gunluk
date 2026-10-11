# onaymerkezi — 2026-10-11

## Bağlam
Görev tanımı: `X:\Yazilim\generic\pdks-rapor\ONAYMERKEZI_PROMPT.md` (generic oturumunda hazırlandı). Kullanıcı: "ia apisini locale çek".
Hedef: Telegram botuna yerel Gemma ile `/ai`, BioTime'dan `/pdks` `/gelmeyenler` `/gec`; onay YZ değerlendirmesini Claude'dan
yerel modele almak. Tek long-polling istemcisi kuralı (409) nedeniyle ayrı bot yazılmadı, mevcut BotServisi'ne eklendi.
(İş 2026-10-10 gecesi başladı, 11'inde paketlendi.)

## Yapılanlar

### 1. Yerel LLM istemcisi ve yerel YZ onaycısı
- **Neden:** veri dışarı çıkmasın; MODFEXSRV'de llama-server (gemma-4-26b, 192.168.0.2:8180, -np 2).
- **Ne yapıldı:** `Yz/YerelLlm.cs`: `IYerelLlm`/`YerelLlm` (OpenAI uyumlu `/v1/chat/completions`, `chat_template_kwargs.enable_thinking`,
  düşünmede max_tokens ≥ 8192, görsel data-URL, SemaphoreSlim(2) + `Mesgul`), `YerelYzDegerlendirici`, `SecmeliYzDegerlendirici`
  (`UZM_OnayAyar.YzSaglayici`: "claude" → Claude, aksi → yerel; varsayılan yerel). HttpClient "llm" zaman aşımı 5 dk (Program.cs).
- **Karar:** json_schema (`response_format`) canlıda Gemma'da `gerekce` boş döndü → şema kaldırıldı; istemin sonuna JSON isteği eklenir,
  yanıttan ilk `{` … son `}` ayıklanır (`JsonAyikla`), `YzIstemMetni.Coz` ile çözülür. **Bu sürüm canlı doğrulanmadı** (laptop ağ dışındaydı).
- **Canlı test:** `MODFEX_LLM_TEST=1 dotnet test --filter YerelLlmCanliTesti` (serbest soru geçti; karar testi eski şemalı sürümde "Gerekçe boş").

### 2. Bot komutları
- `Komut/KomutMetni.cs` (ayrıştırıcı `/ad[@bot] arg`, `YanitBicimi.Bol` 3500 karakter, basit markdown→HTML), `Komut/KomutServisi.cs`.
- BotServisi: `GelenMesaj` → önce `OlayServisi.MesajAsync` (kayıt, /kayit, ret nedeni), sonra `KomutServisi.IsleAsync`.
- `/ai` `/ai+`: "⏳ düşünüyorum…" (dolu ise "sırada") → arka planda yanıt → `editMessageText`, kalan parçalar yeni mesaj.
- Yetki: görev kodu (UZM_OnayGorev.Kod) — varsayılan `YZ` ve `PDKS`, panelden değişir. Yetkisize kısa ret.
- KVKK varsayılanı: grupta yalnız özet sayılar; isimli Excel/listeler yalnız özel mesaj (`PdksGruptaIsim=1` ile gruplara da).

### 3. PDKS
- `Pdks/PdksRaporu.cs` (durum kuralları prototipten: dakika bazında geç/erken, Gelmedi/Giriş yok/Çıkış yok), `PdksMetni`, `PdksExcel.cs`
  (ClosedXML 0.105.0; "Günlük" + "Özet"), `SqlPdksKaynagi.cs` (Dapper, SQL prototiple aynı; bağlantı `UZM_OnayAyar.PdksBaglanti`).
- **Doğrulama:** SQL, WinRM ile sunucuda çalıştırıldı (2026-10-07): aktif 359, geldi 329, gelmedi 30, geç 19, eksik 16 — referansla birebir.
- `db/0002_pdks_okuyucu.sql`: `pdks_okuyucu` login, yalnız 3 tabloda SELECT. **Çalıştırılmadı** — kullanıcı şifreyi doldurup çalıştıracak.

### 4. Panel
- `/yz-pdks` (YzPdksAyar.razor): sağlayıcı, LLM adres/model/düşünme, görev kodları, PDKS bağlantısı (gizli, boş = koru), eşikler, KVKK kutusu.
  Menüye "Yapay zeka & PDKS". Saat SS:dd ve http(s) adres doğrulaması.

### 5. Paket
- **Komutlar:**
  ```bash
  dotnet test OnayMerkezi.Tests            # 162 geçti, 7 atlandı (canlı)
  powershell -File dagitim/yayinla.ps1     # 0002 betiği de pakete kopyalanır
  Compress-Archive yayin\* onaymerkezi-2026-10-11.zip
  ```
- Paket derlemesi `1.0.0+3bd44ac`, ~59 MB.
- **Commit:** `13dd072` — Yerel YZ ve PDKS…; `3bd44ac` — KURULUM NUL karakter düzeltmesi (python'da `\0002` NUL'a dönmüştü).

## Kararlar
- Ayrı bot süreci yok (409 Conflict). Ayarlar UZM_OnayAyar anahtar-değer (şema değişikliği yok).
- PDKS metinleri Türkçe; bot durum metinleri tr/en/ar.

## Açık kalanlar / sonraki adım
- Sunucuda paketi kur (servisi durdur, kopyala, başlat); `/api/surum` → 3bd44ac.
- Görevler: `YZ` ve `PDKS` kodlu görevleri aç, kişi ata (şu an kayıtlı kişi yalnız Abdusselam).
- `0002_pdks_okuyucu.sql` çalıştır + bağlantı metnini panele gir.
- Ağa dönünce `YerelLlmCanliTesti` ile şemasız karar sürümünü doğrula.
- Kullanıcıya sorulacaklar: mesai saatleri (cumartesi), 8–9 Ekim boşluğu, KVKK tercihi, /ai hangi gruplarda.
- Sentezservis: v2 takip tablosu betiği hâlâ bekliyor (ayrı günlük).
