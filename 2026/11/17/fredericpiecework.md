# fredericpiecework — 2026-11-17

## Bağlam
İstek: bir seri birden fazla kez tamire gidip dönebilmeli. Ayrıca 2. kalite (2K) malların depo aktarımında yanlış depolara gittiği bildirildi.

## Yapılanlar

### 1. 2K depo eşlemesi düzeltildi (kök neden)
- **Neden:** `VariantDetail` sorguları Kalite'yi `CASE InOutType WHEN 2 THEN '2K' WHEN 3 THEN 'Numune' ELSE '3K'` ile döndürüyor. `Form1.button3_Click` (depo transfer onayı) ise sadece `"2K Giyilebilir"`/`"2K Giyilemez"` metinlerini tanıyordu → `"2K"` eşleşmiyor, varsayılan **5 (Sağlam)** deposuna gidiyordu.
- **Ne yapıldı:** `GetWarehouseIdByKalite(kalite)` eklendi: `2K`/`2K Giyilebilir`→23, `2K Giyilemez`→24, `3K`→25, `Numune`→18, diğer→5. button3 bunu kullanıyor.
- **Ek:** `SetSaglam()` artık `warehouseId=5`, `UD_BoxInType=""`, `InOutTypeStr="Saglam"` sıfırlıyor ve koliyi gizliyor (önceden sipariş değişince eski 2K/3K durumu kalıyordu).
- **Dokunulan dosyalar:** `Form1.cs`

### 2. Çoklu tamir turu
- **Neden:** `ReadedOrderNumbers.Contains(seri)` kontrolü bir seriyi bir adımda tek kez kabul ediyordu → ikinci kez Finish-Tamir çıkışı yapılamıyordu. Finish çıkışındaki "tamirden gelmemiş" kontrolü de var/yok mantığındaydı.
- **Ne yapıldı:** Tamir adımlarında (FinishTamir, YikamaTamir) sayıma dayalı kural: `bu adımda okutulma < önceki adımdan gelme`. Finish-Tamir çıkışında kaynak = Finish girişi (13/1) + Finish-Tamir girişleri (variants4). Finish çıkışı (13/2): `count(FT çıkış) > count(FT giriş)` ise engel. `variants3/4` artık FinishTamir sürecinde de yükleniyor, diğer süreçlerde sıfırlanıyor.
- **Palet kuralı:** Aynı seri aynı palete iki kez okutulamaz (`ReadedPaletNumbers` "Palet|Seri"). Sebep: `SaveAndRemoveSentez` aynı gün/kullanıcı/palet/demet/parti kaydını birleştirip `GetClearArrayString` ile seriyi tekilleştiriyor → sayım kaybolurdu. Her tamir turu için yeni palet.
- **Kaynak kayıt seçimi:** Önceki adımda birden fazla kayıt varsa seçili paletteki tercih edilir.
- **Silme:** `LiteDbProcess.DeleteAndRemoveSentez` sorgusuna `order by (Cutter=@PaletNo) önce, RecId desc` eklendi.
- **Dokunulan dosyalar:** `Form1.cs`, `LiteDbProcess.cs`
- **Komutlar:**
  ```bash
  dotnet build FredericPieceWork.sln -nologo -v q
  ```
- **Sonuç / doğrulama:** Build başarılı, 0 hata. DB'ye bağlı canlı test yapılmadı; akış kodda izlendi.
- **Commit:** `f6fb34d` — Coklu tamir turuna izin ver, 2K depo eslemesini duzelt

## Kararlar
- Sayım kuralı sadece tamir süreçlerinde; normal süreçlerde eski "tek okutma" kuralı korundu (veri hatasında çift okutmaya izin vermemek için).
- SQL'deki `InOutType=4 → '3K'` etiketi değiştirilmedi: değişirse eski aktarılmış kayıtlar (Explanation='3K') eşleşmez ve tekrar aktarılabilir. UI şu an 4 üretmiyor (KaliteSecimi: 1,2,5,3).

## Açık kalanlar / sonraki adım
- Sahada test: 2 tur tamir (FT çıkış → YT giriş → YT çıkış → FT giriş → FT çıkış #2 → ... → Finish çıkış).
- Daha önce 2K olarak 5 deposuna aktarılmış kayıtlar ERP'de elle düzeltilmeli (Explanation='2K', InWarehouseId=5 olan Erp_InventoryReceipt kayıtları).
- Geçmişte InOutType=4 kaydı var mı DB'de kontrol edilmeli.
