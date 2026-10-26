# Saas_erp — 2026-10-27

## Bağlam
Kullanıcı `/goal goal2.txt'i uygula` verdi (repo kökü `goal2.txt`, 13 madde). Çalışma worktree'si: `scratchpad/wtd` (origin/dev üstünde detached). Önceki gün işleri (satır indirimleri, kutucuklar, oturum kilidi) önce doğrulanıp push edildi (bkz. 2026/10/26 §12).

## Yöntem
- Keşif: 3 Explore ajanı (fiş Detay standardı haritası; lookup/reçete/rota/proje; iplik makine hatası).
- Öneri → `scratchpad/goal2-proposal.md`; kurul: CTO, Skeptic, PO, DBA (P6'da Skeptic BLOCK → kanıtla kaldırıldı: "partiyi açan" = üretim emrindeki **Partiyi Açan** alanı, `ProductionOrderDetailForm.fields.openedBy`); bağlayıcı koşullar `scratchpad/goal2-board-decisions.md`.
- Uygulama paralel şeritlerle (aynı worktree, ayrık dosyalar, şerit başına kendi i18n dosyası `g2a/g2b/g2c/g2d/g2e/g2a2.json` 11 dil; changelog + snapshot yalnız entegratörde).

## Yapılanlar

### 1. P1 — İplik emri makine (BUG)
- **Neden:** Y-0000000032 (tip 6) makine panosu/planlamada yoktu. Kök neden (DEV verisiyle kanıt): başlık `PlannedQuantity=0`, kalem 1.000.000 → `Free=0` → plansız listeye düşmüyor; emirdeki Makine Select'i hiç kaydedilmiyordu.
- **Ne yapıldı:** `QueueRules.EffectivePlanned` + `EffectivePlannedQuery` (tek gruplu sorgu): başlık >0 ise o; değilse boyahanede tüm kalemler, ürünlü başlıkta o ürünün kalemleri, aksi halde yalnız tek malzeme+tek birimse toplam; girilen miktar ezilmez. Free/pano/atama/GetById ortak. Miktarsız emir plansız listede uyarıyla, atama `machine_ops.planned_quantity_missing` ile reddedilir. Emir makine alanı = kuyruk ekle/taşı (iplik/örme/boyahane), dokumada tezgah kuyruğu; bölünmüş emirde salt okunur "N makinede"; kuyruk hatası emri geri almaz ("Tekrar dene").
### 2. P5 — Reçete tipi + standart lookup + rota tipe göre
- `ProductionRecipe.Type` + `(TenantId,Type)` index, backfill `COALESCE(rota tipi, 5)`; reçete seçimi GridLookupDialog+fixedType (el yapımı picker silindi); rota/reçete tip uyuşmazlığı backend'de reddedilir (yalnız değişen bağlantı kontrol edilir); tip değişince onayla temizlenir.
### 3. P6 — Üretim emri Proje + Partiyi Açan lookup
- `ProductionOrder.ProjectId`, `OpenedByEmployeeId` (FK yok); tenant doğrulaması `IFinanceProjectQueryService` (yeni) / `IHrmQueryService`; yetki/modül yoksa alan salt okunur.
- Migration: `20261026215205_RecipeTypeAndOrderProject`.
### 4. Dokuma son kullanıcı testi bulguları (tester, DEV)
- Üretim Tipi ve reçete kayıtta kayboluyordu → düzeltildi; CreatedAt 0001 → düzeltildi; varsayılan tarih İstanbul günü; `ManufacturingTypes.columns.*` çevirileri (`g2f.json`).
- **Backend kolonu olmadığı için hâlâ kaydedilmeyen form alanları** (kullanıcı kararı bekliyor): Müşteri Parti No, Belge No, Planlama tarihi, Tamir Tipi/Sayısı, Numune, Kapalı, Durum detayı, Saat, Birim Fiyat, Döviz, Kapasite, Hesaplama yöntemi, Özel/Erişim kodu, Alt tip, satır Malzeme Türü, Mik.(Top).
- Test kayıtları DEV'de: TEST-DK-OP1, TEST-DK-R1, Y-0000000033, ÇA-0002.
### 5. P2 — Talep/Teklif/Sipariş/Fatura Detay = fiş
- Barkod çubuğu (varsa miktar artar), malzemenin kendi birimleri, ekran+tip başına kalıcı kolon düzeni (localStorage `document-workspace.column-layout.v1:*`), varyant paneli ("Satırlara dağıt"), sipariş/talep satır deposu; `receipt-screen-standard.md` §2'ye tarihli istisna notu.
### 6. P4 — Lookup içinden Yeni → iç içe modal
- `common/components/shared/lookup/record-dialog/` (`RecordDialog`, `useRecordDialog`); detay sayfaları `props.id ?? params.id`, embedded'da onSaved/onCancel; kaydedince otomatik seçim; fixedType aktarılır. Dönüştürülen: Rota (pilot), Operasyon, Makine, Program kartı, Model, Ön maliyet, Dokuma analiz, Personel. Rota→Operasyon→Yeni 3. seviye çalışıyor.
### 7. P7 — Yönetici panosu
- 6 sayaç (Gridify totalCount pageSize=1, izole query, 403 gizli), listeler URL filtresi (`?status=open` vb.). Fatura tarih filtresi DEV'de 500 verdiği için bu ay sayısı son 100 faturadan istemcide.
### 8. P8 — Stok kartı yeniden tasarım (2. kurul turu: CTO/Skeptic/PO/UX/Security)
- Önce altın payload fixture + `buildInventoryPayload`; gruplu sol bölüm menüsü, özet başlık, kaydet çubuğu (değişiklik sayacı, Vazgeç, Ctrl+S), Genel çekirdek(20)/Gelişmiş(22), `ent` kaldırıldı, sınıfa göre bölüm gizleme, PLU Barkod bölümüne. Payload birebir aynı.
- Güvenlik bulgusu (önceden var): stok kartı yazma uçlarında `[RequirePermission]` yok → kurulda Skeptic BLOCK (varsayılan matriste user rolü edit'e sahip değil; bulk tek attribute). Bu turda yapılmadı, kullanıcı kararına.
### 9. P3 — Üretim emri Detay = fiş
- El yazımı tablo → `ReceiptDetailControl`; Stok Kartları lookup'ı satır malzeme türüne göre systemType filtresi (DEV'de doğrulandı: Kumaş 8115, Aksesuar 912, İplik 110, Kimyasal 3); malzemenin birimleri; payload snapshot testi.
### 10. Post-check düzeltmeleri
- UX (DEV): sipariş/teklif/fatura 1440px'te sayfa yana taşıyordu (Kaydet ekran dışı) → `ReceiptDetailControl` dış kutusuna `contain: inline-size` (kök neden: flex zincirinde min-width:auto, tablo min-content'i yukarı sızıyor; DEV'de canlı denendi 1594→1434). Gömülü kayıt diyaloğunda ilk odak "…'a Dön" düğmesine düşüyordu → ilk alana.
- Güvenlik post-check: PASS (düşük: `GET production-recipes` read izni yok — eski).

## Komutlar
```bash
bash tools/verify.sh all            # her birleştirmede; son: backend 6245, frontend 2709 test yeşil
git push origin HEAD:dev
git -C scratchpad/wtdeploy checkout --detach <sha>
DEPLOY_DIR=wtdeploy bash scratchpad/deploy-dev2.sh 1.0.2.<n>   # temiz worktree'den yayın
```
- Not: deploy betiği çalışma ağacından build ediyor → yarım işler imaja sızmasın diye ayrı temiz worktree (`wtdeploy`) kullanıldı.

## Commit'ler
- `b32957c4` feat goal2 (P1,P2,P4,P5,P6,P7,P8 + dokuma bulguları)
- `d2673d36` feat(production) P3 + taşma/odak düzeltmeleri
- DEV: 1.0.2.1075 (b32957c4), 1.0.2.1076 (d2673d36) — ikisi de health 200

## Kararlar
- "partiyi açan" = alan adı; "Order" = üretim emri; satış siparişine Proje eklenmedi.
- Stok kartı Kaydet yetki kilidi bu turda yok (rol matrisi kararı gerekiyor).
- Tarih filtresi 500 (Gridify DateTime Kind) ayrı backend işi.

## Açık kalanlar / sonraki adım
- Kullanıcı kararı: üretim emrinde backend kolonu olmayan alanlar (liste yukarıda); stok kartı/inventory yazma yetki kapısı; auth rate limiter kalıcı düzeltmesi (IP başına + refresh ayrı limit).
- Reçete, üretim emri listesi, sipariş/fatura listesi, stok kartı sayfalarının iç içe modal dönüşümü (P4 2. tur).
- Y-0000000032'de RCT01 Yıkama reçetesi duruyor; iplik tipinde reçete yok → kullanıcı iplik reçetesi tanımlamalı.
- Fatura tarih filtresi 500 → yönetici panosu fatura kutucuğu gerçek sayım.
- Dokuma testinde ulaşılmayan: Kumaş Teknik Analiz Formu kaydet, levent oluşturma, tezgah panosu işlemleri.
