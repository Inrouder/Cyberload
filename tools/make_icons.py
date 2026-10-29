"""Generate classic and adaptive Android PNG launcher icons from the vector art.
Reproducible, no original bitmap required. Run: python tools/make_icons.py
Requires: pip install cairosvg
"""
from pathlib import Path
import cairosvg

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ART = ASSETS / "icon.svg"

cairosvg.svg2png(url=str(ART), write_to=str(ASSETS / "icon-main-192.png"),
                 output_width=192, output_height=192)
cairosvg.svg2png(url=str(ART), write_to=str(ASSETS / "icon-foreground-432.png"),
                 output_width=432, output_height=432)
background = b'<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432"><rect width="432" height="432" fill="#050A14"/></svg>'
cairosvg.svg2png(bytestring=background,
                 write_to=str(ASSETS / "icon-background-432.png"),
                 output_width=432, output_height=432)
print("Generated classic and adaptive Android launcher icons")
