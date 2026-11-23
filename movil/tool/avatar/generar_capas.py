"""Genera las capas SVG de los avatares de mindMetrics-Movil.

Todas las capas comparten viewBox 0 0 240 240, así que se apilan sin
cálculos de posición. Solo usa elementos que flutter_svg dibuja bien:
path, ellipse, circle, linearGradient y opacity (sin filtros, máscaras,
<style> ni texto).

Uso:  python3 generar_capas.py <carpeta_salida>
Crea <salida>/nimbus/*.svg y <salida>/plip/*.svg
"""
import sys
from pathlib import Path

from shapely.geometry import Point, box
from shapely.ops import unary_union

LADO = 240
OSCURO = "#2F3E4E"       # ojos y boca
LENGUA = "#F27C8F"
MEJILLA = "#F59AAE"


def svg(cuerpo: str, defs: str = "") -> str:
    d = f"<defs>{defs}</defs>" if defs else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{LADO}" height="{LADO}" '
            f'viewBox="0 0 {LADO} {LADO}">{d}{cuerpo}</svg>\n')


def f(n: float) -> str:
    return f"{n:.1f}".rstrip("0").rstrip(".")


def trazo(d: str, ancho: float = 4, color: str = OSCURO) -> str:
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{f(ancho)}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


# ---------------------------------------------------------------- cara común
def ojos_abiertos(cx, cy, sep, dx=0.0, dy=0.0, rx=8.5, ry=11.0):
    out = []
    for x in (cx - sep + dx, cx + sep + dx):
        y = cy + dy
        out += [f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx)}" ry="{f(ry)}" fill="{OSCURO}"/>',
                f'<circle cx="{f(x - 2.8)}" cy="{f(y - 4)}" r="3.2" fill="#FFFFFF"/>',
                f'<circle cx="{f(x + 2.6)}" cy="{f(y + 3.6)}" r="1.5" fill="#FFFFFF" opacity="0.9"/>']
    return "".join(out)


def ojos_cerrados(cx, cy, sep):
    return "".join(trazo(f"M{f(x-8)} {f(cy)} Q{f(x)} {f(cy+6)} {f(x+8)} {f(cy)}")
                   for x in (cx - sep, cx + sep))


def ojos_felices(cx, cy, sep):
    return "".join(trazo(f"M{f(x-8)} {f(cy+3)} Q{f(x)} {f(cy-9)} {f(x+8)} {f(cy+3)}")
                   for x in (cx - sep, cx + sep))


def ojos_empaticos(cx, cy, sep):
    l, r = cx - sep, cx + sep
    cejas = (trazo(f"M{f(l-9)} {f(cy-15)} Q{f(l-1)} {f(cy-17)} {f(l+7)} {f(cy-22)}", 3.5)
             + trazo(f"M{f(r+9)} {f(cy-15)} Q{f(r+1)} {f(cy-17)} {f(r-7)} {f(cy-22)}", 3.5))
    return ojos_abiertos(cx, cy + 1, sep, rx=8, ry=10) + cejas


def boca_elipse(cx, my, rx, ry, lengua=True):
    s = f'<ellipse cx="{f(cx)}" cy="{f(my)}" rx="{f(rx)}" ry="{f(ry)}" fill="{OSCURO}"/>'
    if lengua:
        s += (f'<ellipse cx="{f(cx)}" cy="{f(my + ry*0.45)}" rx="{f(rx*0.6)}" '
              f'ry="{f(ry*0.45)}" fill="{LENGUA}"/>')
    return s


def bocas(cx, my):
    return {
        # Expresiones en silencio
        "boca_sonrisa": trazo(f"M{f(cx-11)} {f(my-2)} Q{f(cx)} {f(my+8)} {f(cx+11)} {f(my-2)}"),
        "boca_alegre": (f'<path d="M{f(cx-14)} {f(my-4)} Q{f(cx)} {f(my+18)} {f(cx+14)} {f(my-4)} Z" '
                        f'fill="{OSCURO}" stroke="{OSCURO}" stroke-width="2" stroke-linejoin="round"/>'
                        f'<path d="M{f(cx-6)} {f(my+4)} Q{f(cx)} {f(my+1)} {f(cx+6)} {f(my+4)} '
                        f'Q{f(cx)} {f(my+8)} {f(cx-6)} {f(my+4)} Z" fill="{LENGUA}"/>'),
        "boca_suave": trazo(f"M{f(cx-7)} {f(my-1)} Q{f(cx)} {f(my+4)} {f(cx+7)} {f(my-1)}", 3.5),
        "boca_pensando": trazo(f"M{f(cx-5)} {f(my+1)} Q{f(cx)} {f(my-2)} {f(cx+4)} {f(my+1)} "
                               f"T{f(cx+12)} {f(my)}", 3.5),
        # Visemas para hablar (de menor a mayor apertura + la "o")
        "boca_cerrada": trazo(f"M{f(cx-8)} {f(my+1)} Q{f(cx)} {f(my+3)} {f(cx+8)} {f(my+1)}"),
        "boca_pequena": boca_elipse(cx, my + 1, 8, 4.5, lengua=False),
        "boca_media": boca_elipse(cx, my + 2, 10, 7.5),
        "boca_abierta": boca_elipse(cx, my + 3, 12, 11.5),
        "boca_o": boca_elipse(cx, my + 2, 7, 9, lengua=False),
    }


def capas_cara(cx, cy, sep, sep_mejillas, mejilla=MEJILLA, opacidad=0.55):
    my = cy + 20
    capas = {
        "ojos_abiertos": ojos_abiertos(cx, cy, sep),
        "ojos_cerrados": ojos_cerrados(cx, cy, sep),
        "ojos_felices": ojos_felices(cx, cy, sep),
        "ojos_empaticos": ojos_empaticos(cx, cy, sep),
        "ojos_pensando": ojos_abiertos(cx, cy, sep, dx=3.5, dy=-3.5),
        "mejillas": "".join(f'<ellipse cx="{f(x)}" cy="{f(cy+12)}" rx="9" ry="5.5" fill="{mejilla}" opacity="{opacidad}"/>'
                            for x in (cx - sep_mejillas, cx + sep_mejillas)),
    }
    capas.update(bocas(cx, my))
    return {k: svg(v) for k, v in capas.items()}


def sombra():
    return svg('<ellipse cx="120" cy="224" rx="58" ry="8" fill="#0A5483" opacity="0.16"/>')


def burbujas_pensando(color_borde):
    b = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" stroke="{color_borde}" stroke-width="2.5"/>'
                for x, y, r in ((190, 58, 5), (204, 40, 7.5), (221, 18, 10)))
    return svg(b)


# ---------------------------------------------------------------- nube
def contorno_nimbus() -> str:
    circulos = [(78, 128, 40), (122, 98, 50), (168, 120, 42), (54, 160, 30), (190, 158, 30)]
    forma = unary_union([Point(x, y).buffer(r, quad_segs=24) for x, y, r in circulos]
                        + [box(54, 150, 190, 190), Point(54, 160).buffer(30, quad_segs=24)])
    # Base redondeada: recorta lo que baja de y=190 y suaviza con un buffer.
    forma = forma.intersection(box(0, 0, LADO, 190)).buffer(-6, quad_segs=12).buffer(6, quad_segs=12)
    pts = list(forma.exterior.coords)
    return "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts) + " Z"


def capas_nimbus():
    d = contorno_nimbus()
    grad = ('<linearGradient id="nubeRelleno" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.55" stop-color="#F4FAFE"/>'
            '<stop offset="1" stop-color="#D3E8F6"/></linearGradient>')
    brillos = ('<ellipse cx="104" cy="70" rx="17" ry="9" fill="#FFFFFF" opacity="0.95" transform="rotate(-22 104 70)"/>'
               '<ellipse cx="62" cy="108" rx="9" ry="5" fill="#FFFFFF" opacity="0.9" transform="rotate(-35 62 108)"/>'
               '<ellipse cx="164" cy="92" rx="8" ry="4.5" fill="#FFFFFF" opacity="0.85" transform="rotate(-10 164 92)"/>')
    cuerpo = (f'<path d="{d}" fill="url(#nubeRelleno)" stroke="#8DBBD6" stroke-width="3.5" '
              f'stroke-linejoin="round"/>' + brillos)
    capas = {"cuerpo": svg(cuerpo, grad), "sombra": sombra(),
             "extra_pensando": burbujas_pensando("#8DBBD6")}
    capas.update(capas_cara(cx=121, cy=136, sep=28, sep_mejillas=46))
    return capas


# ---------------------------------------------------------------- gota
def capas_plip():
    grad = ('<linearGradient id="gotaRelleno" x1="0.2" y1="0" x2="0.8" y2="1">'
            '<stop offset="0" stop-color="#A6EEF0"/><stop offset="0.5" stop-color="#5CC6CF"/>'
            '<stop offset="1" stop-color="#1C9AA5"/></linearGradient>')
    d = "M120 26 C132 60 190 96 190 142 A70 70 0 0 1 50 142 C50 96 108 60 120 26 Z"
    brillos = ('<ellipse cx="84" cy="112" rx="10" ry="22" fill="#FFFFFF" opacity="0.55" transform="rotate(28 84 112)"/>'
               '<circle cx="96" cy="80" r="5" fill="#FFFFFF" opacity="0.7"/>'
               '<path d="M150 196 Q172 184 180 160" fill="none" stroke="#0E7C86" stroke-width="4" '
               'stroke-linecap="round" opacity="0.35"/>')
    cuerpo = (f'<path d="{d}" fill="url(#gotaRelleno)" stroke="#0E6F78" stroke-width="3.5" '
              f'stroke-linejoin="round"/>' + brillos)
    capas = {"cuerpo": svg(cuerpo, grad), "sombra": sombra(),
             "extra_pensando": burbujas_pensando("#5CC6CF")}
    capas.update(capas_cara(cx=120, cy=146, sep=26, sep_mejillas=42, mejilla="#FFB0C0", opacidad=0.8))
    return capas


def main():
    salida = Path(sys.argv[1] if len(sys.argv) > 1 else "avatar")
    for nombre, capas in (("nimbus", capas_nimbus()), ("plip", capas_plip())):
        carpeta = salida / nombre
        carpeta.mkdir(parents=True, exist_ok=True)
        for k, v in capas.items():
            (carpeta / f"{k}.svg").write_text(v, encoding="utf-8")
        print(nombre, len(capas), "capas")


if __name__ == "__main__":
    main()
