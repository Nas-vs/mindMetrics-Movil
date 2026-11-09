"""Compone las capas como lo hará la app y genera una hoja PNG para revisar."""
import re
import subprocess
import sys
from pathlib import Path

BASE = Path(sys.argv[1])
SALIDA = Path(sys.argv[2])

ESTADOS = [
    ("Reposo", ["sombra", "cuerpo", "mejillas", "ojos_abiertos", "boca_sonrisa"]),
    ("Parpadeo", ["sombra", "cuerpo", "mejillas", "ojos_cerrados", "boca_sonrisa"]),
    ("Alegre", ["sombra", "cuerpo", "mejillas", "ojos_felices", "boca_alegre"]),
    ("Empático", ["sombra", "cuerpo", "mejillas", "ojos_empaticos", "boca_suave"]),
    ("Pensando", ["sombra", "cuerpo", "mejillas", "ojos_pensando", "boca_pensando", "extra_pensando"]),
    ("Habla: cerrada", ["sombra", "cuerpo", "mejillas", "ojos_abiertos", "boca_cerrada"]),
    ("Habla: pequeña", ["sombra", "cuerpo", "mejillas", "ojos_abiertos", "boca_pequena"]),
    ("Habla: media", ["sombra", "cuerpo", "mejillas", "ojos_abiertos", "boca_media"]),
    ("Habla: abierta", ["sombra", "cuerpo", "mejillas", "ojos_abiertos", "boca_abierta"]),
    ("Habla: o", ["sombra", "cuerpo", "mejillas", "ojos_abiertos", "boca_o"]),
]


def interior(p: Path) -> str:
    t = p.read_text(encoding="utf-8")
    return re.sub(r"^<svg[^>]*>|</svg>\s*$", "", t.strip())


celda, cols = 200, len(ESTADOS)
partes = []
for fila, skin in enumerate(("nimbus", "plip")):
    for col, (nombre, capas) in enumerate(ESTADOS):
        x, y = col * celda, fila * (celda + 30)
        cont = "".join(interior(BASE / skin / f"{c}.svg") for c in capas)
        cont = cont.replace('id="', f'id="{skin}{col}').replace("url(#", f"url(#{skin}{col}")
        partes.append(f'<g transform="translate({x} {y + 4}) scale({celda/240})">{cont}</g>'
                      f'<text x="{x + celda/2}" y="{y + celda + 18}" text-anchor="middle" '
                      f'font-family="sans-serif" font-size="14" fill="#374151">{nombre}</text>')
w, h = cols * celda, 2 * (celda + 30)
doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
       f'<rect width="{w}" height="{h}" fill="#F0F8FF"/>{"".join(partes)}</svg>')
tmp = SALIDA.with_suffix(".svg")
tmp.write_text(doc, encoding="utf-8")
subprocess.run(["rsvg-convert", "-o", str(SALIDA), str(tmp)], check=True)
print(SALIDA)
