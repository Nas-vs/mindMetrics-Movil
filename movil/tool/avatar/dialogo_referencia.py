"""Implementación de REFERENCIA (Python) del motor de diálogo del avatar
(lib/features/avatar/domain/dialogo/).

Sirve para validar los casos de prueba compartidos (casos_extractor.json,
casos_sesion.json) antes de portarlos a Dart. El código de la app es el Dart;
este archivo replica el mismo algoritmo, paso por paso.
"""
from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any, Optional

# ───────────────────────────── texto ─────────────────────────────

def normalizar(t: str) -> str:
    t = unicodedata.normalize("NFD", t.lower())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    t = re.sub(r"(\d),(\d)", r"\1.\2", t)
    t = re.sub(r"[^a-z0-9.\s]", " ", t)
    t = re.sub(r"(?<!\d)\.|\.(?!\d)", " ", t)
    return re.sub(r"\s+", " ", t).strip()


UNIDADES = {"cero": 0, "un": 1, "uno": 1, "una": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5,
            "seis": 6, "siete": 7, "ocho": 8, "nueve": 9}
ESPECIALES = {"diez": 10, "once": 11, "doce": 12, "trece": 13, "catorce": 14, "quince": 15,
              "dieciseis": 16, "diecisiete": 17, "dieciocho": 18, "diecinueve": 19, "veinte": 20,
              "veintiun": 21, "veintiuno": 21, "veintiuna": 21, "veintidos": 22, "veintitres": 23,
              "veinticuatro": 24, "veinticinco": 25, "veintiseis": 26, "veintisiete": 27,
              "veintiocho": 28, "veintinueve": 29}
DECENAS = {"treinta": 30, "cuarenta": 40, "cincuenta": 50, "sesenta": 60, "setenta": 70,
           "ochenta": 80, "noventa": 90}


@dataclass
class Numero:
    valor: float
    inicio: int   # índice de palabra
    fin: int      # índice de palabra (exclusivo)
    de_palabras: bool


def _numero_en(p: list[str], i: int) -> Optional[tuple[float, int, bool]]:
    """Lee un número que empieza en la palabra i. Devuelve (valor, siguiente, de_palabras)."""
    w = p[i]
    if re.fullmatch(r"\d+(\.\d+)?", w):
        return float(w), i + 1, False
    base = None
    j = i
    if w in ("cien", "ciento"):
        base, j = 100.0, i + 1
        if w == "ciento" and j < len(p):
            resto = _numero_en(p, j)
            if resto and resto[0] < 100:
                return 100 + resto[0], resto[1], True
        return base, j, True
    if w in DECENAS:
        base, j = float(DECENAS[w]), i + 1
        if j + 1 < len(p) and p[j] == "y" and p[j + 1] in UNIDADES and p[j + 1] != "cero":
            return base + UNIDADES[p[j + 1]], j + 2, True
        return base, j, True
    if w in ESPECIALES:
        return float(ESPECIALES[w]), i + 1, True
    if w in UNIDADES:
        # "un ocho", "una seis": el artículo no es un número
        if w in ("un", "una") and i + 1 < len(p) and _es_numero(p[i + 1]):
            return None
        return float(UNIDADES[w]), i + 1, True
    return None


def _es_numero(w: str) -> bool:
    return (re.fullmatch(r"\d+(\.\d+)?", w) is not None or w in UNIDADES or w in ESPECIALES
            or w in DECENAS or w in ("cien", "ciento"))


def numeros(texto: str) -> list[Numero]:
    p = texto.split()
    out: list[Numero] = []
    i = 0
    while i < len(p):
        # "media hora" sola
        if p[i] == "media" and i + 1 < len(p) and p[i + 1].startswith("hora") and not (i > 0 and p[i - 1] == "y"):
            out.append(Numero(0.5, i, i + 2, True)); i += 2; continue
        # "hora y media" sin número delante
        if p[i] == "hora" and i + 2 < len(p) and p[i + 1] == "y" and p[i + 2] == "media" and not out_cubre(out, i - 1):
            out.append(Numero(1.5, i, i + 3, True)); i += 3; continue
        r = _numero_en(p, i)
        if r is None:
            i += 1; continue
        valor, j, palabras = r
        # "y media" / "y cuarto" (con o sin "hora(s)" en medio)
        k = j + 1 if j < len(p) and p[j].startswith("hora") else j
        if k + 1 < len(p) and p[k] == "y" and p[k + 1] in ("media", "medio"):
            valor += 0.5; j = k + 2
        elif k + 1 < len(p) and p[k] == "y" and p[k + 1] == "cuarto":
            valor += 0.25; j = k + 2
        out.append(Numero(valor, i, j, palabras))
        i = j
    return out


def out_cubre(out: list[Numero], i: int) -> bool:
    return any(n.inicio <= i < n.fin for n in out)


def contiene(texto: str, frase: str) -> bool:
    return re.search(rf"(?<![a-z0-9]){re.escape(frase)}(?![a-z0-9])", texto) is not None


def posiciones(texto: str, frase: str) -> list[int]:
    return [m.start() for m in re.finditer(rf"(?<![a-z0-9]){re.escape(frase)}(?![a-z0-9])", texto)]


# ───────────────────────────── extractor ─────────────────────────────

@dataclass
class Extraccion:
    valor: Any = None
    confianza: float = 0.0
    motivo: str = "sin_valor"          # ok | sin_valor | ambiguo | fuera_de_rango
    candidatos: list = field(default_factory=list)


SI = ["si", "claro", "obvio", "afirmativo", "correcto", "exacto", "asi es", "efectivamente",
      "he tenido", "tengo", "tuve", "sip", "aja", "por supuesto", "de acuerdo", "eso es", "a veces"]
NO = ["no", "nunca", "jamas", "ninguno", "ninguna", "para nada", "nop", "negativo", "tampoco"]
DUDA = ["no se", "no estoy seguro", "no estoy segura", "no recuerdo", "no me acuerdo"]

CUALITATIVOS = [("muchisimo", 10), ("demasiado", 10), ("extremo", 10), ("bastante", 7), ("mucho", 8),
                ("muy poco", 2), ("poquito", 2), ("poco", 3), ("nada", 1), ("regular", 5),
                ("mas o menos", 5), ("normal", 5), ("medio", 5)]
DIARIO = ["al dia", "diario", "diarias", "diarios", "por dia", "cada dia", "diariamente"]
SEMANAL = ["a la semana", "semanal", "semanales", "por semana", "cada semana", "semanalmente"]
CERO = ["nada", "ninguna", "ninguno", "no hago", "no tengo", "cero"]


def extraer_si_no(t: str) -> Extraccion:
    if any(contiene(t, d) for d in DUDA):
        return Extraccion(motivo="sin_valor")
    pos_si = min([p for s in SI for p in posiciones(t, s)], default=None)
    pos_no = min([p for s in NO for p in posiciones(t, s)], default=None)
    if pos_si is None and pos_no is None:
        return Extraccion()
    if pos_no is None:
        return Extraccion(True, 0.95, "ok")
    if pos_si is None:
        return Extraccion(False, 0.95, "ok")
    return Extraccion(pos_si < pos_no, 0.6, "ok")


def _negado(t: str, pos: int, sinonimo: str) -> bool:
    if sinonimo.startswith("no "):
        return False
    antes = t[:pos].split()[-2:]
    return "no" in antes or "ni" in antes


def extraer_opcion(t: str, pregunta: dict) -> Extraccion:
    # Tramos (inicio, fin) de cada opción que aparece sin negación
    tramos: dict[str, list[tuple[int, int]]] = {}
    for op in pregunta["opciones"]:
        for s in op["sinonimos_n"]:
            for pos in posiciones(t, s):
                if not _negado(t, pos, s):
                    tramos.setdefault(op["valor"], []).append((pos, pos + len(s)))
    # Una opción cuyos tramos caen todos dentro del tramo de OTRA opción no
    # cuenta ("no binario" contiene "binario"; "no me cuesta" contiene "no").
    def contenido(v):
        return all(any(o != v and a2 <= a1 and b1 <= b2 and (a2, b2) != (a1, b1)
                       for o, ts in tramos.items() for a2, b2 in ts)
                   for a1, b1 in tramos[v])
    validos = [v for v in tramos if not contenido(v)]
    if not validos:
        return Extraccion()
    if len(validos) == 1:
        return Extraccion(validos[0], 0.9, "ok")
    return Extraccion(None, 0.0, "ambiguo", validos)


def _valor_numerico(t: str) -> tuple[Optional[float], float]:
    ns = numeros(t)
    if not ns:
        if any(contiene(t, c) for c in CERO):
            return 0.0, 0.7
        return None, 0.0
    if len(ns) >= 2:
        a, b = ns[0], ns[1]
        entre = " ".join(t.split()[a.fin:b.inicio])
        if entre in ("y", "o", "a", "u", "o sea") or t.split()[max(a.inicio - 1, 0)] == "entre":
            return (a.valor + b.valor) / 2, 0.6
        return None, 0.0   # dos números sin relación: ambiguo
    n = ns[0]
    return n.valor, (0.9 if n.de_palabras else 0.95)


def extraer_numero(t: str, pregunta: dict) -> Extraccion:
    valor, conf = _valor_numerico(t)
    if valor is None:
        return Extraccion(motivo="ambiguo" if len(numeros(t)) >= 2 else "sin_valor")
    if pregunta.get("periodo") == "semana" and any(contiene(t, d) for d in DIARIO):
        valor = valor * pregunta.get("dias_por_semana", 7)
        conf = min(conf, 0.6)
    elif pregunta.get("periodo") == "dia" and any(contiene(t, s) for s in SEMANAL):
        valor = valor / 7
        conf = min(conf, 0.6)
    valor = round(valor, 1)
    if not (pregunta["min"] <= valor <= pregunta["max"]):
        return Extraccion(valor, conf, "fuera_de_rango")
    return Extraccion(valor, conf, "ok")


def extraer_escala(t: str, pregunta: dict) -> Extraccion:
    ns = numeros(t)
    if len(ns) == 1 or (len(ns) >= 2 and _valor_numerico(t)[0] is not None):
        valor, conf = _valor_numerico(t)
        if valor is None:
            return Extraccion(motivo="ambiguo")
        valor_int = int(valor + 0.5)  # 6.5 → 7 (redondeo hacia arriba en la mitad)
        if valor != valor_int:
            conf = min(conf, 0.6)
        if not (pregunta["min"] <= valor_int <= pregunta["max"]):
            return Extraccion(valor_int, conf, "fuera_de_rango")
        return Extraccion(valor_int, conf, "ok")
    if len(ns) >= 2:
        return Extraccion(motivo="ambiguo")
    for palabra, v in CUALITATIVOS:
        if contiene(t, palabra):
            return Extraccion(v, 0.6, "ok")
    return Extraccion()


def extraer(texto: str, pregunta: dict) -> Extraccion:
    t = normalizar(texto)
    tipo = pregunta["tipo"]
    if tipo == "si_no":
        return extraer_si_no(t)
    if tipo == "opcion":
        return extraer_opcion(t, pregunta)
    if tipo == "numero":
        return extraer_numero(t, pregunta)
    if tipo == "escala":
        return extraer_escala(t, pregunta)
    raise ValueError(tipo)


# ───────────────────────────── guion ─────────────────────────────

def cargar_guion(ruta: str) -> dict:
    g = json.load(open(ruta, encoding="utf-8"))
    for p in g["preguntas"]:
        for op in p.get("opciones", []):
            op["sinonimos_n"] = [normalizar(s) for s in op["sinonimos"]]
    g["crisis"]["frases_n"] = [normalizar(f) for f in g["crisis"]["frases"]]
    g["crisis"]["continuar_n"] = [normalizar(f) for f in g["crisis"]["continuar"]]
    g["comandos_n"] = {k: [normalizar(x) for x in v] for k, v in g["comandos"].items()}
    return g


def hay_crisis(texto: str, guion: dict) -> bool:
    t = normalizar(texto)
    return any(contiene(t, f) for f in guion["crisis"]["frases_n"])


def es_comando(t: str, frases: list[str]) -> bool:
    n = len(t.split())
    return any(contiene(t, f) and n <= len(f.split()) + 2 for f in frases)


# ───────────────────────────── sesión ─────────────────────────────

@dataclass
class Turno:
    tipo: str            # pregunta | confirmacion | aclaracion | crisis | fin | formulario
    texto: str
    emocion: str
    campo: Optional[str] = None
    opciones: list = field(default_factory=list)
    progreso: float = 0.0


def formatear(valor: Any, p: dict) -> str:
    if p["tipo"] == "numero":
        s = f"{valor:g}".replace(".", ",")
        return f"{s} {p['unidad']}"
    if p["tipo"] == "escala":
        return f"{valor} de 10"
    if p["tipo"] == "si_no":
        return "que sí" if valor else "que no"
    return "«" + next(o["etiqueta"] for o in p["opciones"] if o["valor"] == valor) + "»"


def personalizar(texto: str, mascota: str, apodo: Optional[str] = None) -> str:
    """Igual que `personalizar` en sesion_dialogo.dart."""
    t = texto.replace("{mascota}", mascota)
    a = (apodo or "").strip()
    if a:
        return t.replace("{apodo}", a)
    t = re.sub(r",\s*\{apodo\}", "", t)
    return re.sub(r"\{apodo\},?\s*", "", t)


class Sesion:
    def __init__(self, guion: dict, mascota: str = "Nimbus", apodo: Optional[str] = None):
        self.g = guion
        self.mascota = mascota
        self.apodo = apodo
        self.preguntas = [p for p in guion["preguntas"] if p["tipo"] != "mensaje"]
        self.i = 0                 # índice en guion["preguntas"]
        self.estado = "inicio"
        self.intentos = 0
        self.pendiente: Any = None
        self.respuestas: dict[str, Any] = {}
        self.hubo_crisis = False

    # -- auxiliares
    def _actual(self) -> dict:
        return self.g["preguntas"][self.i]

    def _progreso(self) -> float:
        return len(self.respuestas) / len(self.preguntas)

    def _opciones(self, p) -> list:
        if p["tipo"] == "opcion":
            return [(o["valor"], o["etiqueta"]) for o in p["opciones"]]
        if p["tipo"] == "si_no":
            return [(True, "Sí"), (False, "No")]
        if p["tipo"] == "escala":
            return [(n, str(n)) for n in range(p["min"], p["max"] + 1)]
        return []

    def _preguntar(self, prefijo: str = "", con_opciones=False) -> Turno:
        textos = [prefijo] if prefijo else []
        while self._actual()["tipo"] == "mensaje":
            textos.append(self._actual()["texto"]); self.i += 1
        p = self._actual()
        textos.append(p["texto"])
        self.estado = "respuesta"
        return Turno("pregunta", " ".join(textos), p["emocion"], p["campo"],
                     self._opciones(p) if con_opciones else [], self._progreso())

    def _msg(self, clave: str, **kw) -> str:
        return self.g["mensajes"][clave].format(**kw)

    def _guardar_y_seguir(self, valor, prefijo="") -> Turno:
        self.respuestas[self._actual()["campo"]] = valor
        self.i += 1
        self.intentos = 0
        self.pendiente = None
        if self.i >= len(self.g["preguntas"]):
            self.estado = "fin"
            d = self.g["despedida"]
            texto = " ".join(x for x in [prefijo, personalizar(d["texto"], self.mascota, self.apodo)] if x)
            return Turno("fin", texto, d["emocion"], progreso=1.0)
        return self._preguntar(prefijo)

    # -- API
    def iniciar(self) -> Turno:
        b = self.g["bienvenida"]
        t = self._preguntar(personalizar(b["texto"], self.mascota, self.apodo))
        t.emocion = b["emocion"]
        return t

    def responder(self, texto: str) -> Turno:
        if self.estado in ("fin", "formulario"):
            raise RuntimeError("sesion_cerrada")
        t = normalizar(texto)
        if hay_crisis(texto, self.g):
            self.hubo_crisis = True
            self.estado_previo = self.estado if self.estado != "crisis" else self.estado_previo
            self.estado = "crisis"
            c = self.g["crisis"]
            return Turno("crisis", c["texto"], c["emocion"], progreso=self._progreso())
        if self.estado == "crisis":
            if es_comando(t, self.g["crisis"]["continuar_n"]):
                self.pendiente = None
                p = self._actual()
                self.estado = "respuesta"
                return Turno("pregunta", self._msg("continuar_tras_crisis", pregunta=p["texto"]),
                             "empatico", p["campo"], [], self._progreso())
            c = self.g["crisis"]
            return Turno("crisis", c["texto"], c["emocion"], progreso=self._progreso())
        if es_comando(t, self.g["comandos_n"]["formulario"]):
            self.estado = "formulario"
            return Turno("formulario", self._msg("formulario"), "neutral", progreso=self._progreso())
        if es_comando(t, self.g["comandos_n"]["repetir"]):
            p = self._actual()
            if self.estado == "confirmacion":
                return self._turno_confirmar()
            return Turno("pregunta", p["texto"], p["emocion"], p["campo"], [], self._progreso())

        p = self._actual()
        if self.estado == "confirmacion":
            sn = extraer_si_no(t)
            nuevo = extraer(texto, p)
            if sn.motivo == "ok" and sn.valor is True and not (nuevo.motivo == "ok" and nuevo.valor != self.pendiente
                                                              and p["tipo"] != "si_no"):
                return self._guardar_y_seguir(self.pendiente, self._msg("confirmado"))
            if sn.motivo == "ok" and sn.valor is False:
                # "no, siete": trae un valor nuevo distinto → se toma sin volver a preguntar
                if p["tipo"] != "si_no" and nuevo.motivo == "ok" and nuevo.valor != self.pendiente:
                    return self._guardar_y_seguir(nuevo.valor, self._msg("confirmado"))
                self.pendiente = None
                self.estado = "respuesta"
                return Turno("aclaracion", f"{self._msg('corregir')} {p['texto']}", p["emocion"], p["campo"],
                             [], self._progreso())
            if nuevo.motivo == "ok" and p["tipo"] != "si_no":
                return self._evaluar(nuevo, p)
            return self._turno_confirmar()

        ex = extraer(texto, p)
        return self._evaluar(ex, p)

    def elegir(self, valor) -> Turno:
        if self.estado not in ("respuesta", "confirmacion"):
            raise RuntimeError("no_hay_pregunta")
        return self._guardar_y_seguir(valor)

    def _evaluar(self, ex: Extraccion, p: dict) -> Turno:
        if ex.motivo == "ok":
            if ex.confianza >= self.g["umbral_confirmacion"]:
                return self._guardar_y_seguir(ex.valor)
            self.pendiente = ex.valor
            self.estado = "confirmacion"
            return self._turno_confirmar()
        self.intentos += 1
        if self.intentos >= self.g["intentos_antes_de_opciones"] and self._opciones(p):
            return Turno("aclaracion", self._msg("usar_opciones", pregunta=p["texto"]), p["emocion"], p["campo"],
                         self._opciones(p), self._progreso())
        if ex.motivo == "fuera_de_rango":
            texto = self._msg("fuera_de_rango", min=p["min"], max=p["max"], pregunta=p["texto"])
        else:
            texto = self._msg("no_entendi", pregunta=p["texto"])
        return Turno("aclaracion", texto, p["emocion"], p["campo"], [], self._progreso())

    def _turno_confirmar(self) -> Turno:
        p = self._actual()
        return Turno("confirmacion", self._msg("confirmar", respuesta=formatear(self.pendiente, p)),
                     p["emocion"], p["campo"], [(True, "Sí"), (False, "No")], self._progreso())

    def fila_supabase(self) -> dict:
        if self.estado != "fin":
            raise RuntimeError("sesion_incompleta")
        return {"canal": "voz", **self.respuestas}
