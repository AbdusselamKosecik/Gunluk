"""Gemini pastal resminden parçaları ayıklar (dolgu rengi bölgeleri, kontur çizgileriyle ayrılır)."""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import pickle, sys

RESIM = "sayfa2_16.jpeg"
BOY_CM, EN_CM = 740.0, 172.0

im = np.asarray(Image.open(RESIM).convert("RGB")).astype(np.int16)
H, W, _ = im.shape
cm_px_x, cm_px_y = BOY_CM / W, EN_CM / H
print(f"resim {W}x{H}, 1 px = {cm_px_x*10:.2f} x {cm_px_y*10:.2f} mm")

mx, mn = im.max(2), im.min(2)
beyaz = mn > 225
koyu = mx < 120                      # kontur ve yazı
dolgu = ~beyaz & ~koyu

# Kenar çerçevesi ve sağdaki dikey bilgi şeridi dışarıda.
dolgu[:, W - 12:] = False
dolgu[:3, :] = False; dolgu[-3:, :] = False; dolgu[:, :3] = False

etiket, n = ndi.label(dolgu, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]])
alan = ndi.sum(np.ones_like(etiket), etiket, index=np.arange(1, n + 1))
print("ham bileşen", n)

# Yazı etiketiyle ikiye bölünmüş parçaları birleştir: 3 px yakın ve aynı renk -> aynı parça.
renkler = np.array([im[etiket == i + 1].mean(0) if alan[i] >= 30 else (0, 0, 0) for i in range(n)])
ana = list(range(n + 1))
def kok(a):
    while ana[a] != a:
        ana[a] = ana[ana[a]]; a = ana[a]
    return a
for i, sl in enumerate(ndi.find_objects(etiket)):
    # Yalnız kırıntılar (250-900 px) birleşir; gürültü (<250) köprü olamaz, büyük parçalar birbirine eklenmez.
    if not (250 <= alan[i] < 900): continue
    y0, y1 = max(sl[0].start - 3, 0), min(sl[0].stop + 3, H)
    x0, x1 = max(sl[1].start - 3, 0), min(sl[1].stop + 3, W)
    yerel = etiket[y0:y1, x0:x1]
    genis = ndi.binary_dilation(yerel == i + 1, iterations=3)
    adaylar, temas = np.unique(yerel[genis], return_counts=True)
    en_iyi = None
    for j, c in zip(adaylar, temas):
        if j == 0 or j == i + 1 or alan[j - 1] < 900: continue
        if np.abs(renkler[i] - renkler[j - 1]).max() < 28 and (en_iyi is None or c > en_iyi[1]):
            en_iyi = (j, c)
    if en_iyi:
        ana[i + 1] = en_iyi[0]
birlesik = np.vectorize(lambda v: kok(v) if v else 0)(np.arange(n + 1))[etiket]
etiket = birlesik
idler = [v for v in np.unique(etiket) if v]
alan_d = dict(zip(idler, ndi.sum(np.ones_like(etiket), etiket, index=idler)))
print("birleştirme sonrası bileşen", len(idler))

parcalar = []
for v, sl in zip(idler, ndi.find_objects(etiket)[0:0] or [ndi.find_objects((etiket == v).astype(int))[0] for v in idler]):
    if alan_d[v] < 250:
        continue
    i = v - 1
    m = etiket[sl] == v
    m = ndi.binary_fill_holes(m)
    m = np.pad(m, 2)
    m = ndi.binary_dilation(m, iterations=1)   # konturu geri ekle
    m = ndi.binary_fill_holes(m)
    # Koyu dolgulu parçalarda yalnız açık kenar halkası yakalanır: kapatıp içini doldur.
    for it in range(2, 12, 2):
        if m.sum() / m.size >= 0.35: break
        m = ndi.binary_fill_holes(ndi.binary_closing(np.pad(m, it), iterations=it))[it:-it, it:-it]
    ys, xs = np.nonzero(m)
    m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    y0, x0 = sl[0].start - 2 + ys.min(), sl[1].start - 2 + xs.min()
    renk = im[sl][etiket[sl] == v].mean(0).astype(int)
    parcalar.append(dict(maske=m, x=x0, y=y0, renk=tuple(renk)))

alanlar = np.array([p["maske"].sum() for p in parcalar])
print("parça", len(parcalar), "alan px min/medyan/max", alanlar.min(), int(np.median(alanlar)), alanlar.max())
toplam_cm2 = alanlar.sum() * cm_px_x * cm_px_y
print(f"toplam parça alanı {toplam_cm2/1e4:.2f} m²  (rapor: 7.65 m²)  -> verim {toplam_cm2/(BOY_CM*EN_CM):.2%} (rapor 60.05%)")

# Çok büyük olanlar birleşik olabilir.
med = np.median(alanlar)
print("medyanın 1.8 katından büyük:", [(i, int(a)) for i, a in enumerate(alanlar) if a > 1.8 * med])
print("medyanın 0.35 katından küçük:", [(i, int(a)) for i, a in enumerate(alanlar) if a < 0.35 * med])

pickle.dump(dict(parcalar=parcalar, W=W, H=H, cm_px_x=cm_px_x, cm_px_y=cm_px_y), open("parcalar.pkl", "wb"))

# Kontrol resmi: her parçayı rastgele renkle boya.
rng = np.random.default_rng(1)
cikti = np.full((H, W, 3), 255, np.uint8)
for p in parcalar:
    h, w = p["maske"].shape
    bolge = cikti[p["y"]:p["y"] + h, p["x"]:p["x"] + w]
    bolge[p["maske"]] = rng.integers(40, 230, 3)
Image.fromarray(cikti).save("ayiklanan.png")
