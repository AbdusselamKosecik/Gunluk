"""Kaynak .gemx'i değiştirmeden kopyalar; yalnız info_ext.xml TechnicalSheetInfo alanlarını doldurur."""
import sys, zipfile, re
from xml.sax.saxutils import escape
kaynak, hedef = sys.argv[1], sys.argv[2]
alanlar = dict(a.split("=", 1) for a in sys.argv[3:])
with zipfile.ZipFile(kaynak) as zi, zipfile.ZipFile(hedef, "w") as zo:
    for info in zi.infolist():
        veri = zi.read(info.filename)
        if info.filename == "info_ext.xml":
            metin = veri.decode("utf-8")
            for alan, deger in alanlar.items():
                metin, n = re.subn(rf"(<{alan}>\s*<m_Str>)(</m_Str>|)(\s*)", lambda m: m.group(1) + escape(deger) + "</m_Str>" + m.group(3), metin, count=1)
                metin = re.sub(rf"(<{alan}>\s*)<m_Str\s*/>", lambda m: m.group(1) + f"<m_Str>{escape(deger)}</m_Str>", metin, count=1) if n == 0 else metin
            veri = metin.encode("utf-8")
        zo.writestr(info, veri, compress_type=info.compress_type)
print("yazıldı:", hedef)
