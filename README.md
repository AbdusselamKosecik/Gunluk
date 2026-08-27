# Günlük

Yapılan işlerin **yeniden üretilebilir** kaydı. Amaç bir "yaptım listesi" değil:
disk uçtuğunda / makine değiştiğinde bu dosyaları okuyup işi baştan yapabilmek.

## Dosya düzeni

```
Yil/Ay/Gun/Proje.md      →  2026/08/27/pbxtr.md
```

- `Yil` 4 hane, `Ay` ve `Gun` 2 hane.
- `Proje` = proje klasörünün adı.
- Aynı gün aynı projede tekrar çalışılırsa **aynı dosyaya eklenir**, yeni dosya açılmaz.

## Şablon

```markdown
# <Proje> — YYYY-AA-GG

## Bağlam
Güne hangi durumda başlandı, hedef neydi.

## Yapılanlar

### 1. <Kısa başlık>
- **Neden:** ...
- **Ne yapıldı:** ...
- **Dokunulan dosyalar:** `src/...`
- **Komutlar:** (kod bloğu)
- **Sonuç / doğrulama:** ...
- **Commit:** `<sha>` — <mesaj>

## Kararlar
- ...

## Açık kalanlar / sonraki adım
- ...
```

## Kural

Bir iş biriminin sonunda önce **çalışılan proje** push edilir, sonra bu repoya günlük yazılır
ve o da push edilir. Push edilmemiş iş bitmiş sayılmaz.
