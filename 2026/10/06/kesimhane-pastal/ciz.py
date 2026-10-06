"""Orijinal ve yeni pastalı aynı ölçekte alt alta çizer."""
import numpy as np, pickle
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

d = pickle.load(open("parcalar.pkl", "rb"))
n = pickle.load(open("nest_pay1.pkl", "rb"))
H, W, cx, cy = d["H"], d["W"], d["cm_px_x"], d["cm_px_y"]
P = d["parcalar"]
ALAN_M2 = 7.65  # Gemini raporundaki kullanılan alan

# Yeni yerleşim: orijinal maskeleri (pay olmadan) pay kadar kaydırarak boya; çakışma kontrolü.
uc = n["uc"]
yeni = np.full((H, uc, 3), 255, np.uint8)
dolu = np.zeros((H, uc), np.int16)
for k, x, y, rot in n["yer"]:
    m = np.rot90(np.pad(P[k]["maske"], n["pay"]), rot)
    h, w = m.shape
    dolu[y:y + h, x:x + w] += m
    bolge = yeni[y:y + h, x:x + w]
    bolge[m] = P[k]["renk"]
    kenar = m & ~ndi.binary_erosion(m)
    bolge[kenar] = (40, 40, 40)
print("çakışan piksel:", int((dolu > 1).sum()))

orj = np.asarray(Image.open("sayfa2_16.jpeg").convert("RGB"))

OL = 0.6  # ekran ölçeği
def olcekle(a): return Image.fromarray(a).resize((int(a.shape[1] * OL), int(a.shape[0] * OL)), Image.LANCZOS)
o, y_ = olcekle(orj), olcekle(yeni)

try:
    f = ImageFont.truetype("arialbd.ttf", 30); fk = ImageFont.truetype("arial.ttf", 22)
except OSError:
    f = fk = ImageFont.load_default()

bas, ara = 60, 110
genislik = o.width + 40
tuval = Image.new("RGB", (genislik, bas + o.height + ara + y_.height + 90), "white")
c = ImageDraw.Draw(tuval)
boy_yeni = uc * cx / 100
verim_yeni = ALAN_M2 / (1.72 * boy_yeni)
c.text((20, 12), "ORİJİNAL — 6328-4731001-EKRU-D-40KAT   boy 7.40 m   verim %60.05", fill=(170, 30, 30), font=f)
tuval.paste(o, (20, bas))
c.rectangle([20, bas, 20 + o.width, bas + o.height], outline=(170, 30, 30), width=3)
y2 = bas + o.height + ara
c.text((20, y2 - 48), f"YENİ (yaklaşık) — boy {boy_yeni:.2f} m   verim ~%{verim_yeni*100:.1f}   "
       f"kazanç {7.40 - boy_yeni:.2f} m/kat  ({(7.40 - boy_yeni)*40:.0f} m / 40 kat)", fill=(20, 120, 40), font=f)
tuval.paste(y_, (20, y2))
c.rectangle([20, y2, 20 + y_.width, y2 + y_.height], outline=(20, 120, 40), width=3)
# 7.40 m hizası
x740 = 20 + o.width
c.line([x740, y2 - 10, x740, y2 + y_.height + 10], fill=(170, 30, 30), width=2)
c.text((20, y2 + y_.height + 18),
       "En 172 cm, 0°/180° dönüş, 308 parça (rapordaki sayı). Pastal resminden (≈2.9 mm/px) çıkarılmış yaklaşık yerleşim —\n"
       "kesimden önce Gemini Nest'te aynı ayarlarla yeniden pastal çıkarılmalı.", fill=(80, 80, 80), font=fk)
tuval.save("pastal_karsilastirma.png")
Image.fromarray(yeni).save("pastal_yeni.png")
print(f"yeni boy {boy_yeni:.2f} m, verim {verim_yeni:.2%}")
