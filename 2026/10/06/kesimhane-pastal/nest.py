"""Ayıklanan parçaları 172 cm ene, 0/180° dönüşle, sol-alt doldurma (FFT çakışma haritası) ile yeniden yerleştirir."""
import numpy as np, pickle, sys, time
from scipy import ndimage as ndi
from scipy.signal import fftconvolve

d = pickle.load(open("parcalar.pkl", "rb"))
H, W, cx, cy = d["H"], d["W"], d["cm_px_x"], d["cm_px_y"]
PAY = int(sys.argv[1]) if len(sys.argv) > 1 else 1   # ek kontur payı (px): raster maske gerçek parçadan küçük

parcalar = []
for p in d["parcalar"]:
    m = np.pad(p["maske"], PAY)
    if PAY: m = ndi.binary_dilation(m, iterations=PAY)
    parcalar.append(dict(p, m=m.astype(np.float32)))
alan_px = sum(p["m"].sum() for p in parcalar)
print(f"{len(parcalar)} parça, payla alan {alan_px*cx*cy/1e4:.2f} m²")

def yerlestir(sira):
    occ = np.zeros((H, W + 400), np.float32)
    uc = 0
    yer = []
    for k in sira:
        p = parcalar[k]
        en_iyi = None
        for rot in (0, 2):
            m = np.rot90(p["m"], rot)
            h, w = m.shape
            pencere = occ[:, :min(uc + w + 1, occ.shape[1])]
            if pencere.shape[1] < w: pencere = occ[:, :w]
            c = fftconvolve(pencere, m[::-1, ::-1], mode="valid")
            ys, xs = np.nonzero(c < 0.5)
            if len(xs) == 0: continue
            # önce en soldaki x, sonra en alttaki (en küçük y)
            sec = np.lexsort((ys, xs))[0]
            aday = (xs[sec], ys[sec], rot, m)
            if en_iyi is None or aday[0] < en_iyi[0] or (aday[0] == en_iyi[0] and aday[1] < en_iyi[1]):
                en_iyi = aday
        x, y, rot, m = en_iyi
        h, w = m.shape
        occ[y:y + h, x:x + w] += m
        uc = max(uc, x + w)
        yer.append((k, x, y, rot))
    return uc, yer

sonuclar = []
alanlar = np.array([p["m"].sum() for p in parcalar])
genis = np.array([p["m"].shape[1] for p in parcalar])
yuks = np.array([p["m"].shape[0] for p in parcalar])
siralar = {
    "alan": np.argsort(-alanlar),
    "en": np.argsort(-genis),
    "boy": np.argsort(-yuks),
}
rng = np.random.default_rng(7)
for i in range(int(sys.argv[2]) if len(sys.argv) > 2 else 3):
    gurultu = alanlar * rng.uniform(0.85, 1.15, len(alanlar))
    siralar[f"rastgele{i}"] = np.argsort(-gurultu)

for ad, sira in siralar.items():
    t = time.time()
    uc, yer = yerlestir(sira)
    print(f"{ad:10s} boy {uc*cx/100:.2f} m  ({time.time()-t:.0f} sn)", flush=True)
    sonuclar.append((uc, ad, yer))

uc, ad, yer = min(sonuclar, key=lambda s: s[0])
print(f"EN İYİ: {ad} -> {uc*cx/100:.2f} m (orijinal 7.40 m)")
pickle.dump(dict(uc=uc, ad=ad, yer=yer, pay=PAY), open(f"nest_pay{PAY}.pkl", "wb"))
