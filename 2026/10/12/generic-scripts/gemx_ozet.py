import sys, xml.etree.ElementTree as ET
r = ET.parse(sys.argv[1]).getroot()
print("AppVersion:", r.findtext("AppVersion/m_Str"))
ts = r.find("TechnicalSheetInfo")
print("TechnicalSheet:", {c.tag: c.findtext("m_Str") for c in ts if c.find("m_Str") is not None})
for el in r.find("PatternInformations/elements"):
    ad = el.findtext("PieceText/PieceName/m_Str")
    bed = [(g.findtext("GradingSizeName/m_Str"), g.findtext("Area/m_Str")) for g in el.find("GradingSizes/elements")]
    print(f"Parça {ad}: " + ", ".join(f"{b} ({float(a)/100:.0f} cm²)" for b, a in bed))
print("Diğer üst etiketler:", [c.tag for c in r])
