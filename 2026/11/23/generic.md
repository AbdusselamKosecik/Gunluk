# generic — 2026-11-23

## Yapılanlar

### 1. DENDATA departman listesi
- **Neden:** Kullanıcı Den'deki departman listesini istedi.
- **Ne yapıldı:** `\192.168.0.2\Dendata\Den\Per\Egp\12r\f01\2026\DEPXX.MAS` (990 × 4331 B kayıt, son yazım 22.11 10:17) scratchpad'e kopyalandı, ad @3 ShortString (uzunluk @2, cp1254) okundu. Python UNC yolu açamadı → önce PowerShell `Copy-Item` ile yerel kopya.
- **Sonuç:** 18 dolu kayıt (19–990 boş): 1 ADMINISTRATION, 2 PRODUCTION MGMT, 3 SAMPLE, 4 RAW MAT. WAREHOUSE, 5 CUTTING, 6–12 LINE 1–7, 13 QUALITY CONTROL, 14 PACKING, 15 FG WH. & SHIPPING, 16 MAINTENANCE, 17 SECURITY, 18 SERVICE (TRANSPORT). BioTime'daki DEN01–DEN18 ile aynı sıra.

### 2. (21.11 devamı) 0.3:8085
- 192.168.0.3 = DATASRV (MODFEXTR DC); WMI/DCOM (srv02.cred) ile dinleyen portlar listelendi, 8085 yok. 192.168.1.3'te 8085 dışarıdan kapalı, srv02.cred ile WMI erişimi reddedildi. Kullanıcıdan hangi makine olduğu bekleniyor.
