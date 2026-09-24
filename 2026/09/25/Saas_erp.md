# Saas_erp — 2026-09-25

## Bağlam
24 Eylül'de sunucuda (services, 100.109.159.58 / 217.131.14.61) pgpool → PgBouncer geçişi yapıldı, 15433–15435 internete kapatıldı (bkz. 2026/09/24/Saas_erp.md). Hedef: 9999 (PgBouncer) da internete kapatılsın, Tailscale + LAN açık kalsın.

## Yapılanlar

### 1. 9999 (PgBouncer) internete kapatıldı
- **Neden:** Kullanıcı isteği. Postgres havuzu internete açıktı.
- **Ön kontrol:** Son 24 saatte PgBouncer'a bağlananlar: 100.71.243.9 (Tailscale, abdusselam-mkz), 192.168.31.10/.11 (LAN), 172.18.0.x (docker içi). Public IP'den bağlantı yok → kapatmak kimseyi bozmaz.
- **Ne yapıldı:** `/etc/ufw/after.rules` (yedek: `after.rules.bak-20260925`) içindeki `BEGIN vuo` bloğuna:
  ```
  -A DOCKER-USER -i ens160 -p tcp -m conntrack --ctorigdstport 9999 --ctdir ORIGINAL -j DROP
  ```
  `sudo ufw reload`. (ufw deny Docker yayınlı portlarını kapatmaz; DOCKER-USER zinciri gerekir.)
- **Doğrulama:** 217.131.14.61:9999 kapalı; 100.109.159.58:9999 açık + psql bağlandı; LAN 192.168.31.13:9999 açık; mevcut 13 istemci bağlantısı kopmadı.

## Kararlar
- Kullanıcının "Tailscale ve yerel ağa kapalı kalsın" ifadesi "açık kalsın" olarak yorumlandı (literal okuma tüm uygulamaları keserdi).

## Açık kalanlar
- Hâlâ internete açık: 80 443 3180 (Traefik dashboard, auth yok) 6379 9090/9091 8083/5341 16686/4317/4318 9200 4222/8222 18087/18088 9001 (Portainer agent).
