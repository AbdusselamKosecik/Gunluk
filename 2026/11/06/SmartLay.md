# SmartLay — 2026-11-06

> Çalışma klasörü: `Y:\New folder (2)` (git reposu değil, henüz kod yok). Dosya adı proje adıyla (SmartLay) verildi.

## Bağlam
Smartcoore'un "SMARTLAY KESİMHANE-SERİM UYGULAMASI.pdf" analiz dokümanı + 3 tablet mockup'ı
(Serim Ekranı, Pastal Ekranı, Ürün Giriş/Çıkış) incelendi. Hedef: web uygulaması için tüm
ekran/alt ekran listesini çıkarmak (malzeme kartı, kategori gibi tanım ekranları dahil).

## Yapılanlar

### 1. Ekran envanteri çıkarıldı
- **Neden:** Doküman sadece 9 ana ekranı tarif ediyor; çalışan bir sistem için tanım (master data),
  modal ve rapor alt ekranları da gerekiyor.
- **Ne yapıldı:** PDF (5 sayfa) + 3 görsel okundu. Ekranlar 3 kaynağa göre işaretlendi:
  📄 dokümanda var, 🖼 mockup'ta var, ➕ dokümandan türetilen/gerekli.
- **Dokunulan dosyalar:** yok (sadece analiz)
- **Sonuç:** Liste aşağıda.

#### A. Giriş
1. 📄 Login — Kullanıcı girişi (Personel ID / barkod)
2. 📄 Login — Admin girişi (mail + şifre)
3. ➕ Şifremi unuttum / sıfırlama

#### B. Serim Operatörü (tablet)
4. 📄🖼 Serim Ekranı (bekleyen / tamamlanan pastallar, Pastala Başla + barkod)
5. 📄🖼 Pastal Ekranı (kullanılacak / kullanılan toplar, kat-metraj, Top Gir / Top Bitir / Pastalı Bitir)
6. ➕ Kumaş Topu Bitir modalı (kalan metraj, fire girişi)
7. ➕ Pastalı Bitir modalı (kat + metraj kontrol/düzenle/kaydet)
8. ➕ Hatalı barkod uyarısı (pastala ilişkili olmayan top)
9. 🖼 Geçmiş
10. 🖼 Ayarlar

#### C. Depocu (tablet)
11. 📄🖼 Ürün Giriş / Çıkış
12. 📄 Barkod oluştur & topa ata (barkodsuz gelen top)
13. ➕ ERP sipariş eşleştirme (gelen topun siparişle kontrolü)
14. ➕ Etiket yazdırma
15. 🖼 Son işlemler / günlük hareketler

#### D. Admin — Operasyon
16. 📄🖼 Anasayfa / Dashboard (Masa Bilgisi canlı, tamamlanan pastallar)
17. ➕ Masa detay / canlı izleme (çoklu masa)
18. 📄 Pastal listesi
19. 📄 Pastal ekle / düzenle (barkod no, tarih, metraj, en-boy, kat)
20. 📄 Pastal — Kumaş topu ilişkilendirme
21. 📄 Pastal barkod oluştur / yazdır / kesimhaneye gönder
22. 📄 Takvim / Görevlendirme (pastal → tarih, masa, operatör)
23. 📄 Kumaş Stoğu listesi
24. ➕ Kumaş topu detay (hareket geçmişi)

#### E. Admin — Tanımlar (Master Data)
25. ➕ Malzeme (Kumaş) Kartı — kod, ad, en, gramaj, renk, birim
26. ➕ Malzeme Kategorisi / Kumaş Türü (Penye, Sweat, Gabardin, Drill…)
27. ➕ Renk / Varyant
28. ➕ Lot / Parti (boya partisi)
29. ➕ Kumaş Topu Kartı — top no, malzeme, lot, metraj, en, tedarikçi, lokasyon
30. ➕ Model / Ürün Kartı (TSH-001, SWT-020…)
31. ➕ Tedarikçi Kartı
32. ➕ Sipariş (ERP satınalma) listesi / detay
33. ➕ Serim Masası tanımı
34. ➕ Depo / Lokasyon tanımı
35. ➕ Birim tanımı (m, kg)
36. ➕ Fire nedenleri
37. ➕ Vardiya tanımı
38. ➕ Etiket / barkod şablonu

#### F. Admin — Kullanıcı & Sistem
39. 📄 Kullanıcı listesi
40. 📄 Kullanıcı ekle / düzenle (rol: Admin / Serim Operatörü / Depocu)
41. ➕ Personel ID kartı / barkod yazdır
42. ➕ Rol & yetki matrisi
43. ➕ ERP entegrasyon ayarları + senkron logu
44. ➕ Sistem parametreleri (fire toleransı, metraj sapma limiti)
45. ➕ Profil / şifre değiştir
46. ➕ İşlem (audit) logu

#### G. Raporlar
47. 📄 Pastal serim raporu (tarih / seri no filtresi)
48. 📄 Kumaş topu verim / fire raporu (top metrajı vs serilen)
49. ➕ Operatör performans raporu
50. ➕ Masa verimlilik raporu
51. ➕ Stok hareket raporu (giriş/çıkış)
52. ➕ Stok durum / yaşlandırma raporu

## Kararlar
- Tanım ekranlarının (E) hiçbiri dokümanda yok ama mockup'taki alanlar (Model, Kumaş türü, Top no,
  Metraj) bunları zorunlu kılıyor → ➕ olarak eklendi; müşteriyle teyit edilmeli.

## Açık kalanlar / sonraki adım
- Müşteriye sorulacak: ERP hangisi, master data ERP'den mi gelecek yoksa SmartLay'de mi tutulacak?
- Kat bilgisi top bazında mı pastal bazında mı tutuluyor (mockup'ta topta da "Kat" var)?
- Çoklu masa var mı (dashboard "MASA BİLGİSİ (1)")?
- Mockup'taki "Geçmiş" ve "Ayarlar" içeriği tanımsız.
