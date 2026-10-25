# Dia_entegrasyon — 2026-10-25

## Bağlam
20.10'daki analizden devam. Kod yok, kurul henüz toplanmadı. Kullanıcı önce yapılanları sordu,
sonra DIA test kullanıcısını, ardından kapsamı netleştirdi.

## Yapılanlar

### 1. DIA test kullanıcısı arandı
- **Neden:** Demo ortamda denemek için giriş bilgisi gerekiyor.
- **Ne yapıldı:** Repo, `X:\GitHub` altı ve Gunluk tarandı; giriş bilgisi yok. Örnek JSON'lardaki
  `kullaniciadi: ws/admin` yalnızca DIA örnek verisi, şifresiz.
- **Bulgu:** DIA Web Service Tester dokümanında demo uç `https://diademo.ws.dia.com.tr/api/v3/...`
  (sunucu kodu `diademo`) var; kullanıcı/şifre/API key yazılı değil.
- **Sonuç:** Demo kullanıcısı + API key DIA'dan ya da bayiden istenecek. Gelince DPAPI ile saklanacak, repoya yazılmayacak.

### 2. Kapsam netleşti, analiz dokümanına işlendi
- **Kullanıcı cevabı:** Ürünler, birimler, renk/beden varyantları (varsa) gelecek. X, Y, Z depolarına giriş
  yapan tüm fişler gelecek. Üretim ve sarf fişlerimiz Üretim deposuna ve X, Y, Z'ye yazılacak.
- **Ne yapıldı:** `docs/dia-entegrasyon-analiz.md` içine:
  - kapsam tablosuna 8. satır (varyant) eklendi,
  - §1.1 karar tablosu yazıldı,
  - §1.2 "X/Y/Z'ye giriş" filtresi tanımlandı: transferde `_key_sis_depo_dest`, giriş türlerinde (2, 5, 6, 8, 12)
    `_key_sis_depo`; kalem bazlı filtre için `_ayrintili`; kendi `VUO` fişlerimiz atlanacak,
  - §1.3 varyantlar: `scf_stokkart_varyant_listele`, `scf_malzeme_ozellik_*`, `scf_stok_varyant_miktarlari_listele`,
    kalemde `m_varyantlar` (`_key_scf_stokkart_ozellik1..9`),
  - §6'ya 8–12 numaralı yeni açık sorular eklendi.
- **Kaynak:** <https://doc.dia.com.tr/doku.php?id=gelistirici:wsapi:stokhizmet>
- **Dokunulan dosyalar:** `docs/dia-entegrasyon-analiz.md`
- **Commit:** `2e4b219` — docs: kullanici kapsam cevabi (urun, birim, varyant, X/Y/Z depo fis filtresi, uretim/sarf depolari)

## Kararlar
- Fiş filtresi depo kodu listesi olarak ayar olacak (koda gömülmeyecek).
- İzinli dört depo dışına SaaS → DIA fiş yazılmaz, UnresolvedReceipt'e düşer.

## Açık kalanlar / sonraki adım
- Sorular: depo kodları; irsaliye/fatura dahil mi, çıkışlar hariç mi; üretim/sarf depo dağılımı;
  SaaS'ta varyant modeli var mı; başlangıç tarihi.
- DIA demo kullanıcısı + API key.
- `/kurul Dia_entegrasyon`.

## Ek: DIA demo login denemesi
- **Neden:** Kullanıcı "ws ws ile login dener misin" dedi.
- **Komut:**
  ```bash
  curl -s -X POST https://diademo.ws.dia.com.tr/api/v3/sis/json -H "Content-Type: application/json"     -d '{"login":{"username":"ws","password":"ws","disconnect_same_user":true,"lang":"tr","params":{}}}'
  ```
  Ardından `sis_kontor_sorgula`, `sis_yetkili_firma_donem_sube_depo`, `logout` çağrıldı.
- **Sonuç:**
  - Login 200 döndü, API key istemedi.
  - Kontör -50.1125 (negatif) ama ücretli çağrı yine çalıştı.
  - Firma 1 GENEL, dönem 1 (2026). Depolar AI00 (_key 2552) ve AI01 (_key 2847).
  - Yetkili firma cevabında `depokodu` da geliyor; analizdeki "sis_depo_getir gerekir" notu düzeltildi.
- **Not:** Demo ortak hesap. `disconnect_same_user` testlerde false olmalı, yazma testleri dikkatli yapılmalı.
- **Commit:** `5c189d7` — docs: DIA demo sunucu login denemesi (ws/ws), firma/donem/depo bulgulari

## Ek: Demodan stok kartı ve fiş okuma
- **Neden:** Kullanıcı "demodan stok kartlarını ve fişleri oku bakalım" dedi.
- **Ne yapıldı:** Login (`disconnect_same_user:false`), firma 1 / dönem 1 ile şu çağrılar yapıldı, sonra logout:
  - `scf_stokkart_listele` (limit 0)
  - `scf_stokkart_varyant_listele` (limit 50)
  - `scf_malzeme_ozellik_listele`
  - `scf_malzeme_fisi_listele` ve `_listele_ayrintili` (limit 0)
  - `scf_malzeme_fisi_getir` (key 33303, varyantlı transfer fişi)
- **Bulgular:**
  - Kontör eksiyken tüm çağrılar code 406 döndü ama result dolu geldi. İstemci 406'da veriyi kullanmamalı.
  - 78 kart: TCR 74, HMD 2, MML 1, KK 1. Çok birimli kart yok.
  - 11 varyantlı kart (`ozelliksayisi`). Özellikler Beden/Renk; değerler ayrı key'li, rengin hex kodu var.
  - 17 fiş, türler 1–12. Başlıkta `depokodu`/`depokodu2` kod olarak geliyor.
  - Varyant kırılımı yalnız `_getir` cevabındaki `m_varyantlar` içinde var, `_ayrintili`'de yok. Varyantlı fişler için ek getir çağrısı gerekecek.
- **Dokunulan dosyalar:** `docs/dia-entegrasyon-analiz.md` (§2.1.2), `docs/dia-demo-cevaplar/*.json` (6 ham cevap; session id içermediği kontrol edildi)
- **Commit:** `a778b4d` — docs: DIA demo stok karti, varyant ve malzeme fisi okuma sonuclari + ham cevaplar
