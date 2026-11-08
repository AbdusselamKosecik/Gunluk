# claude-config — 2026-11-08

## Bağlam
`/doctor` ile Claude Code kurulum sağlık taraması. Hedef: kullanılmayan eklentileri kapatmak, yavaş hook'ları temizlemek, auto mode'u varsayılan yapmak.

## Yapılanlar

### 1. Kullanılmayan 31 eklenti kapatıldı
- **Neden:** Son 53 günde (34 oturum, 2026-09-16 → 11-08) kullanılmadılar. Skill listesi ~1% bütçesini aşmış, açıklamalar kırpılıyordu (~3.5k est. token). Ayrıca:
  - hookify her araç çağrısında Pre+Post python3 çalıştırıyordu (~350ms ×2, 42 timeout) ama hiç kural yok.
  - data-engineering (astronomer) Stop hook'u (`uv run …analyzing-data/scripts/cli.py stop`) 2580 kez hata verdi.
  - shopify-ai-toolkit her Read'de telemetri hook'u (~941ms).
- **Ne yapıldı:** `~/.claude/settings.json` → `enabledPlugins` içinde şu anahtarlar `false`:
  hookify, data-engineering, shopify-ai-toolkit, claude-security, ralph-loop, pinecone, twilio-developer-kit, cloudflare, fastly-agent-toolkit, base44, vanta, postiz, desktop-commander, microsoft-docs, context7, linear, serena, browser-use, coderabbit, code-simplifier, code-review, commit-commands, frontend-design, skill-creator, claude-md-management, claude-code-setup, mcp-tunnels, ui-theme-designer, superdesign, caveman, kotlin-lsp.
- **Açık kalanlar:** superpowers, feature-dev, chrome-devtools-mcp, unreal-engine-skills, security-guidance, remember, csharp-lsp, learning-output-style, unity.
- **Yedek:** `~/.claude/settings.json.doctor-backup-2026-11-08`
- **Geri alma:** yedeği geri kopyala ya da ilgili anahtarı `true` yap / `/plugin`.

### 2. Auto mode varsayılan yapıldı
- **Ne yapıldı:** `~/.claude/settings.json` → `"permissions": {"defaultMode": "auto"}` (tüm projeler).

## Kararlar
- csharp-lsp tutuldu (Saas_erp .NET işi), sayaç 0 olsa da LSP takibi yeni.
- İzin allow kuralı eklenmedi: reddedilen komutlar salt-okunur değildi (cd&&…, rm -rf, curl).

## Açık kalanlar / sonraki adım
- Kullanıcı elle: `/mcp disable blender`, `/mcp disable "claude.ai Figma"`, `/mcp disable "claude.ai Google Drive"`; senkron `design` eklentisi `/plugin` ile.
- pbxtr ve pbxtr-yayin `.claude/agents/backend-dev-2.md` (ve backend-dev-1) frontmatter'ına `model: sonnet` eklenmeli — kullanımın %16'sı bu alt ajanlardan (Opus'ta çalışıyor).
- `~/.claude` git deposu değil → ayar değişiklikleri uzak depoya gitmiyor; yalnızca bu günlükte kayıtlı.
- autoUpdates kapalı; sürüm 2.1.319 = güncel.
