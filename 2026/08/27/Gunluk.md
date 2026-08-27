# Gunluk (günlük defteri altyapısı) — 2026-08-27

## Bağlam
HDD uçtuğu için diskte kalan iş kaybediliyordu. Projeden bağımsız, kalıcı bir kural
konması istendi: her değişiklik uzak depoya gitsin ve yapılanlar okunup yeniden
yapılabilecek biçimde günlüğe yazılsın.

## Yapılanlar

### 1. Gunluk reposu yerele klonlandı
- **Neden:** Günlüklerin yazılacağı yerel çalışma kopyası gerekiyordu.
- **Komutlar:**
  ```bash
  cd "X:/GitHub/Abdusselam" && git clone https://github.com/AbdusselamKosecik/Gunluk.git Gunluk
  ```
- **Sonuç:** `X:\GitHub\Abdusselam\Gunluk` hazır.

### 2. Global kural yazıldı
- **Neden:** Kural tek bir projeye değil, tüm projelere uygulanmalı.
- **Ne yapıldı:** `~/.claude/CLAUDE.md` (yoktu, oluşturuldu) içine iki madde yazıldı:
  (1) her iş biriminin sonunda commit + push, `git add -A` yasak, yollar açıkça sayılır;
  (2) push sonrası `Yil/Ay/Gun/Proje.md` günlüğü yazılır ve Gunluk reposu push edilir.
- **Dokunulan dosyalar:** `C:\Users\abdus\.claude\CLAUDE.md`
- **Sonuç:** Kural her oturumda otomatik yükleniyor.

### 3. Kalıcı hafızaya alındı
- **Ne yapıldı:** `her-degisiklik-push-ve-gunluk.md` hafıza dosyası + `MEMORY.md` satırı.
- **Dokunulan dosyalar:**
  `C:\Users\abdus\.claude\projects\X--GitHub-Pbxtr-pbxtr\memory\her-degisiklik-push-ve-gunluk.md`,
  aynı klasördeki `MEMORY.md`

### 4. Repo düzeni ve şablon
- **Ne yapıldı:** `README.md` dosya düzenini, şablonu ve kuralı anlatacak şekilde yazıldı;
  ilk günlük girdisi olarak bu dosya açıldı.
- **Dokunulan dosyalar:** `README.md`, `2026/08/27/Gunluk.md`

## Kararlar
- Günlük **tarif** formatındadır: ne / neden / hangi dosya / hangi komut / sonuç / commit sha.
- Aynı gün + aynı proje = aynı dosyaya ekleme.
- Proje adı dosya adıdır; gün klasörü altında birden çok proje dosyası olabilir.

## Açık kalanlar / sonraki adım
- Kural bundan sonraki her turda uygulanacak; pbxtr'da bir sonraki iş bitiminde
  `2026/08/<gun>/pbxtr.md` yazılacak.
