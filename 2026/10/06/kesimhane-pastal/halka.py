"""Açık halka (ayrı tonlu dikiş payı bandı) parçalarını içindeki parçayla birleştirir; parcalar.pkl'i günceller."""
import numpy as np, pickle
from scipy import ndimage as ndi
d = pickle.load(open("parcalar.pkl", "rb"))
P = d["parcalar"]
sil = set()
for i, p in enumerate(P):
    m = p["maske"]
    if m.sum() / m.size >= 0.35: continue
    y0, x0, h, w = p["y"], p["x"], *m.shape
    en_iyi, oran = None, 0
    for j, q in enumerate(P):
        if j == i: continue
        qh, qw = q["maske"].shape
        ky = max(0, min(y0 + h, q["y"] + qh) - max(y0, q["y"]))
        kx = max(0, min(x0 + w, q["x"] + qw) - max(x0, q["x"]))
        o = ky * kx / (qh * qw)
        if o > oran: en_iyi, oran = j, o
    q = P[en_iyi]
    yy0, xx0 = min(y0, q["y"]), min(x0, q["x"])
    yy1 = max(y0 + h, q["y"] + q["maske"].shape[0]); xx1 = max(x0 + w, q["x"] + q["maske"].shape[1])
    b = np.zeros((yy1 - yy0, xx1 - xx0), bool)
    b[y0 - yy0:y0 - yy0 + h, x0 - xx0:x0 - xx0 + w] |= m
    qm = q["maske"]
    b[q["y"] - yy0:q["y"] - yy0 + qm.shape[0], q["x"] - xx0:q["x"] - xx0 + qm.shape[1]] |= qm
    b = ndi.binary_fill_holes(ndi.binary_closing(np.pad(b, 3), iterations=3))[3:-3, 3:-3]
    print(f"halka {i} -> parça {en_iyi} (örtüşme {oran:.2f}), alan {qm.sum()} -> {b.sum()}")
    q.update(maske=b, x=xx0, y=yy0)
    sil.add(i)
d["parcalar"] = [p for i, p in enumerate(P) if i not in sil]
a = sum(p["maske"].sum() for p in d["parcalar"])
print(len(d["parcalar"]), "parça, alan", round(a * d["cm_px_x"] * d["cm_px_y"] / 1e4, 2), "m²")
pickle.dump(d, open("parcalar.pkl", "wb"))
