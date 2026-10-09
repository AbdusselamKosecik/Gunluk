# generic — 2026-10-09

## Bağlam
Kod yazılmadı; yerel yapay zeka seçenekleri üzerine danışma. Hedef: dikiş makinesi başında
operatör süresi + iş (parça) sayımı. Cumartesi (2026-10-10) birlikte prototipe başlanacak.

## Donanım (ölçüldü)
- RTX 4080 Laptop 12 GB VRAM, 64 GB RAM, Windows 11. Ollama kurulu değil.

## Kararlar / öneriler
### 1. Excel/PDF analizi için yerel LLM
- **Neden:** Veriyi dışarı göndermeden analiz.
- **Ne:** Ollama + Qwen3 14B (genel/Türkçe), Qwen3-Coder 30B-A3B (pandas kodu yazdırma),
  Qwen2.5-VL 7B / Gemma 3 12B (taranmış PDF). Excel'i LLM'e okutma → LLM pandas kodu yazar,
  hesabı pandas yapar. PDF → docling/pymupdf ile Markdown'a çevir.
- **Komutlar:**
  ```powershell
  winget install Ollama.Ollama
  ollama pull qwen3:14b
  ollama pull qwen2.5vl:7b
  pip install pandas openpyxl docling
  ```

### 2. Kamera + yüz tanıma + alarm
- YOLO yüz tanımaz, sadece nesne/insan tespiti. Zincir: RTSP → YOLO11 → SCRFD (yüz bul) →
  InsightFace/ArcFace (tanı) → kural → alarm (Telegram/MQTT).
- Hazır: Frigate NVR (Docker, YOLO + yüz/plaka, MQTT). Alternatif: CompreFace, Viseron.
- KVKK: yüz verisi özel nitelikli → açık rıza + aydınlatma metni.

### 3. Dikiş makinesi: süre + iş sayımı (asıl hedef)
- **Süre:** YOLO11 + ByteTrack + makine önü poligon bölge → giriş/çıkış süresi.
- **İş sayısı:** kameradan değil makineden: iplik kesici tetiği (kesim sayısı / parça),
  motor kablosuna CT akım sensörü + ESP32 (dikiş/boşta süresi), servo kutusu IoT sayacı,
  demet (bundle) barkodu. Sensör yoksa: üstten kamera "işlenecek / bitti" yığın bölgeleri + özel YOLO.
- **Değerli metrik:** operatör oturuyor ama motor durmuş = hazırlık/kayıp süre.
- **Kimlik:** fabrikada yüz tanıma zayıf → RFID/kart veya anonim istasyon bazlı.
- **Pilot planı:** 1 makine + 1 ESP32 akım sensörü + 1 kamera → yerel sunucu (Python, SQLite, web panel).

## Açık kalanlar / sonraki adım (Cumartesi)
- Makine marka/model, servo motorlu mu? (Juki/Brother/Jack)
- Demet barkod sistemi var mı?
- Kamera açısı ekran görüntüsü, makine/kamera sayısı.
- Önce sensör mü kamera prototipi mi — karar verilecek.
