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
