# Saas_erp — 2026-10-29

## Bağlam
28 Ekim gece: kullanıcı yönerge analizi maddelerinin hepsini istedi ("önce değişiklikleri yapalım, sonra bu maddelere göre çalışalım, backlog çıkar, goal çalıştıralım") ve iş kararlarını verdi (sahip boyutu yok, HAM = varyant, sevk = tüketim, kullanılmış reçete kilitli + revizyon, lot ağacı, fason sipariş bağı, 3006 = bana gelen kumaş, H6 kontinü/gün sonu dağıtım).

## Yapılanlar

### 1. Backlog + ClickUp
- **Ne:** `docs/design/analysis/2026-10-28-yonerge-backlog.md` (kararlar tablosu + E0–E10 sırası + çalışma kuralları), commit `ee8a4953`.
- ClickUp: E1–E10 `to do` görevleri (z8v9xnjpea … z8v9xnjpek, tag yonerge); E0 = z8v9xnjmxx.
- Goal metni: scratchpad `goal-yonerge-backlog.txt` (kullanıcı /goal ile çalıştıracak).

### 2. E0 Tahsis Fişi tamamlandı
- **Ön yüz:** ajanın yarım bıraktığı iş tamamdı; tek eksik menü düzeni (`menu-layout.commercial.tsx` Stok > Hareketler'e `/inventory/allocation-documents`).
- **H10:** `AllocationConsumption.ConsumeAsync` aynı (tahsis, ref) için satırı birleştirir; `UX_StockAllocationConsumption_AllocationRef` unique index. TDD: önce kırmızı test.
- **Rebase:** wtcrm origin/dev'in 13 commit gerisindeydi (araya SerialCard migration'ları girmiş). Migration klasörü sıfırlandı, WIP commit → `git rebase origin/dev` (ReceiptLotSync using ve changelog çakışması çözüldü), migration `dotnet ef migrations add` ile yeni zaman damgasıyla (20261028205741) üretildi ve elle yazılmış backfill/RAISE SQL'i eski dosyadan aktarıldı; has-pending-model-changes: No changes.
- **DEV salt-okuma kontrol:** 93 tahsis, deposuz aktif 0, uyumsuz 0.
- **Doğrulama:** verify all: backend 6592 unit geçti; frontend ilk turda api-errors fixture bayattı → `node scripts/extract-api-errors.mjs --write` → rc=0.
- **Commit:** `921ae375` — feat(inventory,production): Tahsis Fişi …
- **Deploy:** DEV 1.0.2.1100 (wtdeploy pinli, deploy-dev2.sh). API 200; DEV'de migration uygulandı: 70 fiş, 18 açık.

## Açık kalanlar
- E0 UX post-check DEV'de (çalışıyor).
- E1–E10 goal ile.
- GitHub Billing hâlâ DEV Deploy'u engelliyor (elle deploy).
