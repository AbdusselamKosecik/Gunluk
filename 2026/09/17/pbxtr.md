# pbxtr — 2026-09-17

## Bağlam

Dokuzuncu turun devamı: `/goal Kalan tum maddeleri bitir` altında backlog'dan kalan
kartlar sırayla kapatılıyor. Canlı sunucuya erişim bu oturumda **salt-okunur**;
gün 09-17'ye `BR-FE-84` ile giriliyor.

## Yapılanlar

### 1. `BR-FE-84` — kural reddi artık **gerekçesini söylüyor**

- **Neden:** `#47`/`#48` kullanıcı ekranlarında sunucunun `meta.rule` ile gönderdiği
  bazı redler ekrana **genel "İşlem tamamlanamadı"** olarak düşüyordu. Kullanıcı neden
  reddedildiğini göremediği için **aynı formu tekrar gönderiyordu.**
- **Ölçüm (kartın öncülü doğrulandı ve genişledi):** `userErrorRule`
  (`usersApi.ts:541-544`) `meta.rule`'u **kod anahtarından ÖNCE** okuyor. Dolayısıyla
  `RULE_KEY` içindeki `PERMISSION_ESCALATION` / `TENANT_SCOPE_DENIED` **kod**
  anahtarlarına, kural taşıyan bir redde **hiç ulaşılmıyor.** Sunucu tarafı
  (`src/Pbxtr.Api/Modules/Access/UserAdminEndpoints.cs:2005-2019`, `RuleOf`) **11
  adlandırılmış kural** + `denied` üretiyor; istemcide **üçü eksikti**:
  `permission_escalation`, `scope_denied`, `role_not_delegated`.
- **Ne yapıldı:**
  - `RULE_KEY`'e üç satır eklendi. İlk ikisi **mevcut metinleri paylaşır** — biri HTTP
    kodu, öteki kural adıdır; aynı redde iki farklı cümle yazmak yanlış olurdu.
    Üçüncüsü için yeni `usrE.roleNotDelegated` metni **9 dile** eklendi.
  - **`denied` bilerek eşlenmedi.** O sunucunun `_ =>` dalıdır, yani *adlandırılmamış
    red*; ona özel bir cümle yazmak **ölçülmemiş bir gerekçeyi ölçülmüş gibi**
    gösterirdi. Metin genel yetki cümlesine düşer ve bu bir **kontrol grubu testiyle**
    kilitlendi.
  - Yeni **parite bekçisi** `src/app/screens/users/userRuleParity.test.ts`: sunucunun
    `RuleOf` gövdesini **C# kaynağından** okur (emsal: `auditActionParity.test.ts`) ve
    her adlandırılmış kuralın istemcide bir metni olduğunu ölçer. Ters yön bilerek
    **gevşektir** ("ad sunucu dosyasında hiç geçmiyor"), çünkü kural adları tek yerden
    gelmiyor: doğrulama kuralları (`invalid_login`, `extension_taken` …) aynı dosyada
    ama `RuleOf` dışında, `Meta("…")` ile üretiliyor — ilk sıkı sürüm bu yüzden
    **dokuz yanlış bulgu** verdi.
  - `vitest.config.ts` → `server.fs.allow` yalnızca `../Pbxtr.Api/Modules/Access` ile
    genişletildi (`..` yazılmadı; geliştirme sunucusu C# ağacını servis edemesin).
- **Dokunulan dosyalar:** `src/Pbxtr.Web/src/app/screens/users/usersApi.ts`,
  `…/usersApi.test.ts`, `…/userRuleParity.test.ts` (yeni),
  `src/Pbxtr.Web/vitest.config.ts`, `src/app/i18n/messages/*.json` (9 dil),
  `yonetim/backlog.md`
- **Komutlar:**
  ```bash
  npx vitest run src/app/screens/users/usersApi.test.ts src/app/screens/users/userRuleParity.test.ts
  npm run typecheck && npx vitest run
  ```
- **Sonuç / doğrulama:** **Mutasyon 3/3 kırmızı** — üç eşlemenin her biri tek tek
  silindiğinde **ikişer** test kırmızı (tam metin eşitliği **ve** parite bekçisi),
  geri alınınca kontrol yeşil. Tam takım **214 dosya / 1934 test yeşil**, `tsc -b` temiz.
- **Commit:** `38ec93b9` — BR-FE-84 bitti: kural reddi ARTIK gerekcesini soyluyor

## Kararlar

- **Aynı reddi iki kez adlandırma.** Kod anahtarı ile kural adı aynı şeyi söylüyorsa
  **aynı metni** paylaşırlar; ayrı cümle yazmak kullanıcıya iki farklı gerekçe gösterirdi.
- **Adlandırılmamış red için cümle yazılmaz.** `denied` eşlenseydi, sunucunun "bilmiyorum"
  dediği yerde ekran **kesin bir sebep** göstermiş olurdu.
- **Parite bekçisinin yönü tutucudur.** Kaçan ölü satır riski alınır, yanlış alarm
  alınmaz — çünkü yanlış alarm veren bir kapı kaçınılmaz olarak silinir.

## Açık kalanlar / sonraki adım

- Backlog'da kalan kartlara devam (`yonetim/backlog.md`); büyük kısmı canlı PBX/sunucu
  işi (bu oturumda erişim salt-okunur) veya kurul kararı bekliyor.
