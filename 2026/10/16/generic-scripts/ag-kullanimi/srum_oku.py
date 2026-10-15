"""SRUM kopyasından uygulama × ağ × gün bazında indirme/yükleme çıkarır, pano.html üretir.

Kullanım: .venv\\Scripts\\python srum_oku.py   (önce yönetici olarak srum_kopyala.ps1)
"""
import datetime as dt
import json
import re
import struct
import sys
import winreg
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

from dissect.esedb import EseDB

KOK = Path(__file__).parent
AG_TABLOSU = "{973F5D5C-1D90-4944-BE8E-24B94231A174}"
IF_WIFI = 71
TOPLAM_SATIRI = 1


def ole_tarih(ham: int) -> dt.date:
    """SRUM TimeStamp: OLE otomasyon tarihi (1899-12-30'dan beri gün, double) — int bit deseni olarak gelir."""
    gun = struct.unpack("<d", struct.pack("<q", ham))[0]
    return (dt.datetime(1899, 12, 30) + dt.timedelta(days=gun)).date()


def uygulama_adi(tip: int, blob: bytes | None) -> tuple[str, str]:
    if not blob:
        return "Bilinmeyen", ""
    s = blob.decode("utf-16-le", "replace").rstrip("\x00")
    if tip == 1:                                  # Windows hizmeti (DoSvc, BITS…)
        return f"{s} (hizmet)", s
    if s.startswith("!!"):                       # !!conhost.exe!1994/05/20...!
        return s.split("!")[2], s
    yol = s.replace("/", "\\")
    ad = yol.rsplit("\\", 1)[-1]
    if "_" in ad and "\\" not in s:              # UWP paket adı: Microsoft.WindowsStore_8wekyb3d8bbwe
        ad = ad.split("_")[0]
    return ad or s, s


def wifi_adlari() -> dict[int, str]:
    """WlanSvc ProfileIndex (= SRUM L2ProfileId) -> SSID / profil adı."""
    adlar = {}
    xmler = {p.stem.upper(): p for p in Path(r"C:\ProgramData\Microsoft\Wlansvc\Profiles\Interfaces").glob("*/*.xml")}
    with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\WlanSvc\Interfaces") as ifs:
        for i in range(winreg.QueryInfoKey(ifs)[0]):
            ifad = winreg.EnumKey(ifs, i)
            try:
                prof = winreg.OpenKey(ifs, ifad + r"\Profiles")
            except OSError:
                continue
            for j in range(winreg.QueryInfoKey(prof)[0]):
                g = winreg.EnumKey(prof, j)
                with winreg.OpenKey(prof, g) as k:
                    try:
                        idx = winreg.QueryValueEx(k, "ProfileIndex")[0]
                    except OSError:
                        continue
                ad = g
                if (x := xmler.get(g.upper())) is not None:
                    kok = ET.parse(x).getroot()
                    ns = re.match(r"\{.*\}", kok.tag)
                    ad = kok.findtext(f"{ns.group(0) if ns else ''}name") or g
                adlar[idx] = ad
    return adlar


def arayuz_adlari() -> dict[int, str]:
    a = json.loads((KOK / "veri" / "arayuzler.json").read_text(encoding="utf-8-sig"))
    return {int(x["Luid"]): x["Name"] for x in a}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    wifi, arayuz = wifi_adlari(), arayuz_adlari()

    with open(KOK / "veri" / "SRUDB.dat", "rb") as f:
        db = EseDB(f)
        # Tip 0 uygulama, 1 hizmet, 2 mağaza paketi, 3 kullanıcı SID'i (atlanır).
        idmap = {r.get("IdIndex"): (r.get("IdType"), r.get("IdBlob"))
                 for r in db.table("SruDbIdMapTable").records() if r.get("IdType") != 3}

        def ag_adi(luid: int, l2: int | None) -> tuple[str, str]:
            tur = luid >> 48
            if tur == IF_WIFI:
                if not l2:
                    return "Wi-Fi (profilsiz)", "Wi-Fi"
                return wifi.get(l2, f"Silinmiş Wi-Fi profili #{l2 & 0xFFFF}"), "Wi-Fi"
            if not luid:
                return "Bilinmeyen arayüz", "Diğer"
            ad = arayuz.get(luid, f"Kaldırılmış arayüz ({tur})")
            return ad, "VPN" if tur == 53 else ("Ethernet" if tur == 6 else "Diğer")

        uyg = defaultdict(lambda: {"ag": defaultdict(lambda: [0, 0]), "gun": defaultdict(lambda: [0, 0])})
        aglar, gunler = {}, set()
        for r in db.table(AG_TABLOSU).records():
            ind, yuk = r.get("BytesRecvd") or 0, r.get("BytesSent") or 0
            # AppId 1 (adsız) uygulama değil, arayüz başına tüm uygulamaların toplamı; çift sayılmasın.
            if (ind == 0 and yuk == 0) or r.get("AppId") == TOPLAM_SATIRI:
                continue
            gun = ole_tarih(r.get("TimeStamp")).isoformat()
            ag, tur = ag_adi(r.get("InterfaceLuid"), r.get("L2ProfileId"))
            aglar[ag] = tur
            gunler.add(gun)
            u = uyg[r.get("AppId")]
            u["ag"][ag][0] += ind; u["ag"][ag][1] += yuk
            u["gun"][gun][0] += ind; u["gun"][gun][1] += yuk

    # Aynı ada sahip kimlikler (farklı sürüm/yol: chrome.exe, WhatsApp 2.2632/2.2635…) tek satırda birleşir.
    birlesik = {}
    for app_id, u in uyg.items():
        ad, yol = uygulama_adi(*idmap.get(app_id, (0, None)))
        b = birlesik.setdefault(ad.lower(), {"id": app_id, "ad": ad, "yollar": defaultdict(int),
                                             "ag": defaultdict(lambda: [0, 0]), "gun": defaultdict(lambda: [0, 0])})
        for kaynak, hedef in ((u["ag"], b["ag"]), (u["gun"], b["gun"])):
            for k, v in kaynak.items():
                hedef[k][0] += v[0]; hedef[k][1] += v[1]
        b["yollar"][yol] += sum(v[0] + v[1] for v in u["ag"].values())

    liste = []
    for b in birlesik.values():
        ind = sum(v[0] for v in b["ag"].values()); yuk = sum(v[1] for v in b["ag"].values())
        liste.append({"id": b["id"], "ad": b["ad"], "yol": max(b["yollar"], key=b["yollar"].get), "ind": ind, "yuk": yuk,
                      "ag": {k: v for k, v in sorted(b["ag"].items(), key=lambda kv: -sum(kv[1]))},
                      "gun": dict(sorted(b["gun"].items()))})
    liste.sort(key=lambda x: -(x["ind"] + x["yuk"]))

    veri = {"uretim": dt.datetime.now().isoformat(timespec="minutes"),
            "bas": min(gunler), "bit": max(gunler), "aglar": aglar, "uygulamalar": liste}
    sablon = (KOK / "pano_sablon.html").read_text(encoding="utf-8")
    (KOK / "pano.html").write_text(sablon.replace("/*VERI*/null", json.dumps(veri, ensure_ascii=False)), encoding="utf-8")
    print(f"{len(liste)} uygulama, {len(aglar)} ağ, {veri['bas']} – {veri['bit']} → pano.html")
    for x in liste[:5]:
        print(f"  {x['ad']:<30} ↓{x['ind']/1e9:7.2f} GB ↑{x['yuk']/1e9:6.2f} GB")


if __name__ == "__main__":
    main()
