"""Valida los casos compartidos con la referencia en Python (sin Flutter).

Uso, desde movil/:   python3 tool/avatar/validar_casos.py
Los mismos casos los ejecuta `flutter test test/features/avatar/dialogo`.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from dialogo_referencia import Sesion, cargar_guion, extraer  # noqa: E402

GUION = "assets/guiones/encuesta_inicial_v1.json"
CASOS = Path("test/features/avatar/dialogo")

g = cargar_guion(GUION)
P = {p["campo"]: p for p in g["preguntas"]}
fallas = 0

for c in json.load(open(CASOS / "casos_extractor.json", encoding="utf-8"))["casos"]:
    ex = extraer(c["texto"], P[c["campo"]])
    ok = ex.motivo == c["motivo"]
    if ok and c["motivo"] == "ok":
        ok = (ex.valor == c["valor"] and isinstance(ex.valor, bool) == isinstance(c["valor"], bool)
              and (ex.confianza < g["umbral_confirmacion"]) == c["confirma"])
    if not ok:
        fallas += 1
        print(f"FALLA extractor {c['campo']}: {c['texto']!r} → {ex}")

datos = json.load(open(CASOS / "casos_sesion.json", encoding="utf-8"))
previas = datos["respuestas_previas"]
for e in datos["escenarios"]:
    s = Sesion(g)
    t = s.iniciar()
    if "hasta" in e:
        while t.campo != e["hasta"]:
            t = s.responder(previas[t.campo])
    for i, paso in enumerate(e["pasos"]):
        t = s.elegir(paso["elige"]) if "elige" in paso else s.responder(paso["dice"])
        if t.tipo != paso["tipo"] or ("campo" in paso and t.campo != paso["campo"]):
            fallas += 1
            print(f"FALLA [{e['nombre']}] paso {i}: {t.tipo}/{t.campo} ≠ {paso['tipo']}/{paso.get('campo')}")
    for k, v in e.get("respuestas", {}).items():
        if s.respuestas.get(k) != v:
            fallas += 1
            print(f"FALLA [{e['nombre']}] {k}: {s.respuestas.get(k)!r} ≠ {v!r}")

print("Todos los casos pasan." if not fallas else f"{fallas} fallas.")
sys.exit(1 if fallas else 0)
