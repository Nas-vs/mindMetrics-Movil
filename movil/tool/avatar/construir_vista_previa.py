"""Construye la vista previa interactiva (HTML autocontenido) con las capas reales."""
import json
import sys
from pathlib import Path

capas_dir = Path(sys.argv[1])
salida = Path(sys.argv[2])

ORDEN = ["sombra", "cuerpo", "mejillas",
         "ojos_abiertos", "ojos_cerrados", "ojos_felices", "ojos_empaticos", "ojos_pensando",
         "boca_sonrisa", "boca_alegre", "boca_suave", "boca_pensando",
         "boca_cerrada", "boca_pequena", "boca_media", "boca_abierta", "boca_o",
         "extra_pensando"]
capas = {p: {c: (capas_dir / p / f"{c}.svg").read_text(encoding="utf-8").strip() for c in ORDEN}
         for p in ("nimbus", "plip")}

html = r"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Avatares MindMetrics · Nimbus y Plip</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800&display=swap" rel="stylesheet">
<style>
  :root{--fondo:#F0F8FF;--primario:#15919B;--texto:#374151;--atenuado:#6B7280;--borde:#E5E7EB;--tarjeta:#FFFFFF;--suave:#EFF6FB}
  *{box-sizing:border-box}
  body{margin:0;font-family:Nunito,system-ui,sans-serif;background:var(--fondo);color:var(--texto)}
  main{max-width:1040px;margin:0 auto;padding:28px 20px 60px}
  h1{font-size:26px;font-weight:800;margin:0 0 4px}
  h2{font-size:18px;font-weight:800;margin:40px 0 12px}
  p.sub{margin:0 0 20px;color:var(--atenuado)}
  .escenario{display:grid;grid-template-columns:1fr 1fr;gap:16px}
  .tarjeta{background:var(--tarjeta);border:1px solid var(--borde);border-radius:16px;padding:18px}
  .personaje{display:flex;flex-direction:column;align-items:center}
  .personaje h3{margin:6px 0 0;font-size:16px}
  .personaje small{color:var(--atenuado)}
  .avatar{position:relative;width:240px;height:240px}
  .avatar img,.avatar .capa{position:absolute;inset:0;width:100%;height:100%}
  .cuerpo{position:absolute;inset:0;will-change:transform}
  .anillo{position:absolute;left:50%;top:50%;border-radius:50%;transform:translate(-50%,-50%);pointer-events:none}
  .controles{display:grid;gap:14px;margin-top:16px}
  .fila{display:flex;flex-wrap:wrap;align-items:center;gap:8px}
  .fila > span{min-width:84px;font-weight:700;font-size:14px}
  button{font:inherit;font-weight:700;font-size:14px;border:1px solid var(--borde);background:var(--suave);color:var(--texto);
    border-radius:999px;padding:8px 14px;cursor:pointer}
  button[aria-pressed="true"]{background:var(--primario);border-color:var(--primario);color:#fff}
  button.principal{background:var(--primario);color:#fff;border-color:var(--primario);border-radius:10px;padding:10px 18px}
  button:disabled{opacity:.6;cursor:default}
  label.check{display:flex;align-items:center;gap:8px;font-size:14px}
  .estado{font-size:13px;color:var(--atenuado);min-height:18px}
  .hoja{display:grid;grid-template-columns:repeat(auto-fill,minmax(112px,1fr));gap:10px}
  .hoja figure{margin:0;background:var(--tarjeta);border:1px solid var(--borde);border-radius:12px;padding:8px;text-align:center}
  .hoja .mini{position:relative;width:96px;height:96px;margin:0 auto;background:
     repeating-conic-gradient(#F3F4F6 0 25%,#fff 0 50%) 0 0/12px 12px;border-radius:8px}
  .hoja .mini img{position:absolute;inset:0;width:100%;height:100%}
  .hoja figcaption{font-size:11px;font-family:ui-monospace,monospace;margin-top:6px;word-break:break-all}
  table{width:100%;border-collapse:collapse;font-size:14px;background:var(--tarjeta);border-radius:12px;overflow:hidden}
  th,td{text-align:left;padding:9px 12px;border-bottom:1px solid var(--borde);vertical-align:top}
  th{background:var(--suave);font-weight:800}
  code{font-family:ui-monospace,monospace;font-size:12.5px;background:var(--suave);padding:1px 5px;border-radius:5px}
  .tabs{display:flex;gap:8px;margin-bottom:12px}
  @media (max-width:640px){.escenario{grid-template-columns:1fr}}
</style>
</head>
<body>
<main>
  <h1>Avatares de MindMetrics</h1>
  <p class="sub">Nimbus y Plip armadas con las mismas capas SVG que usa la app. La animación replica la lógica de <code>AvatarMascota</code> en Flutter.</p>

  <section class="tarjeta">
    <div class="escenario">
      <div class="personaje"><div class="avatar" id="av-nimbus"></div><h3>Nimbus</h3><small>Nube de lluvia · flota y se balancea</small></div>
      <div class="personaje"><div class="avatar" id="av-plip"></div><h3>Plip</h3><small>Gota de agua · se estira y se aplasta</small></div>
    </div>
    <div class="controles">
      <div class="fila" id="f-actividad"><span>Actividad</span></div>
      <div class="fila" id="f-emocion"><span>Emoción</span></div>
      <div class="fila"><span>Voz</span>
        <label class="check"><input type="checkbox" id="manual"> Nivel manual</label>
        <input type="range" id="nivel" min="0" max="1" step="0.01" value="0.5" disabled aria-label="Nivel de voz">
        <span class="estado" id="lectura"></span>
      </div>
      <div class="fila"><span>Opciones</span>
        <label class="check"><input type="checkbox" id="reducir"> Reducir movimiento</label>
        <button class="principal" id="simular">Simular un turno</button>
      </div>
      <div class="estado" id="estado"></div>
    </div>
  </section>

  <h2>Cómo se elige cada capa</h2>
  <table>
    <tr><th>Estado</th><th>Ojos</th><th>Boca</th><th>Extra</th></tr>
    <tr><td>Reposo · neutral</td><td><code>ojos_abiertos</code></td><td><code>boca_sonrisa</code></td><td>Parpadeo cada 2,5–5,5 s</td></tr>
    <tr><td>Emoción alegre</td><td><code>ojos_felices</code></td><td><code>boca_alegre</code></td><td>Mejillas al 100 %</td></tr>
    <tr><td>Emoción empática</td><td><code>ojos_empaticos</code></td><td><code>boca_suave</code></td><td>Para preguntas sensibles</td></tr>
    <tr><td>Escuchando</td><td>según emoción</td><td>según emoción</td><td>Anillo pulsante + inclinación</td></tr>
    <tr><td>Pensando</td><td><code>ojos_pensando</code></td><td><code>boca_pensando</code></td><td><code>extra_pensando</code></td></tr>
    <tr><td>Hablando</td><td>según emoción</td><td>Visema por nivel de voz: &lt;0,08 <code>cerrada</code> · &lt;0,35 <code>pequena</code> · &lt;0,65 <code>media</code>/<code>o</code> · resto <code>abierta</code></td><td>Ritmo simulado si el TTS no da amplitud</td></tr>
  </table>

  <h2>Hoja de capas</h2>
  <div class="tabs" id="tabs"></div>
  <div class="hoja" id="hoja"></div>
</main>

<script>
const CAPAS = __CAPAS__;
const ORDEN = __ORDEN__;
const OJOS = ['abiertos','cerrados','felices','empaticos','pensando'];
const BOCAS = ['sonrisa','alegre','suave','pensando','cerrada','pequena','media','abierta','o'];
const PERSONAJES = {
  nimbus: {movimiento:'flotar', acento:'141,187,214'},
  plip: {movimiento:'rebotar', acento:'21,145,155'},
};
const uri = s => 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s);

// ---------- estado compartido (equivale a AvatarControlador)
const estado = {actividad:'inactivo', emocion:'neutral', nivelExterno:null};

// ---------- reglas (equivalen a CapasAvatar)
function ojosPara(e, parpadeando){
  let base = e.actividad==='pensando' ? 'pensando'
           : e.emocion==='alegre' ? 'felices'
           : e.emocion==='empatico' ? 'empaticos' : 'abiertos';
  if (parpadeando && base!=='felices') return 'cerrados';
  return base;
}
function bocaPara(e, nivel, redonda){
  if (e.actividad==='hablando'){
    if (nivel<0.08) return 'cerrada';
    if (nivel<0.35) return 'pequena';
    if (nivel<0.65) return redonda ? 'o' : 'media';
    return 'abierta';
  }
  if (e.actividad==='pensando') return 'pensando';
  return {alegre:'alegre', empatico:'suave', neutral:'sonrisa'}[e.emocion];
}

// ---------- generador de sílabas (equivale a GeneradorSilabas)
class Silabas {
  constructor(){ this.reiniciar(); }
  reiniciar(){ this.d=0; this.t=0; this.pausa=true; this.pico=0; this.redonda=false; this.nivel=0; }
  sig(){
    this.pausa = !this.pausa && Math.random()<0.14;
    if (this.pausa) this.d = 70 + Math.random()*110;
    else { this.d = 110 + Math.random()*110; this.pico = 0.35+Math.random()*0.65; this.redonda = Math.random()<0.22; }
  }
  avanzar(dt){
    this.t += dt;
    while (this.t >= this.d){ this.t -= this.d; this.sig(); }
    this.nivel = this.pausa ? 0 : this.pico*Math.sin(Math.PI*Math.pow(this.t/this.d,0.7));
    return this.nivel;
  }
}

// ---------- avatar (equivale a AvatarMascota)
class Avatar {
  constructor(el, id){
    this.id=id; this.cfg=PERSONAJES[id]; this.silabas=new Silabas();
    this.proximo=1800; this.finParpadeo=0; this.img={};
    const sombra = this.capa('sombra'); this.sombra=sombra;
    this.anillo = document.createElement('div'); this.anillo.className='anillo';
    this.cuerpo = document.createElement('div'); this.cuerpo.className='cuerpo';
    el.append(sombra, this.anillo, this.cuerpo);
    for (const c of ORDEN.filter(c=>c!=='sombra')) this.cuerpo.append(this.capa(c));
    el.setAttribute('role','img');
  }
  capa(nombre){
    const i=document.createElement('img'); i.src=uri(CAPAS[this.id][nombre]); i.alt=''; i.draggable=false;
    this.img[nombre]=i; return i;
  }
  frame(ms, dt, reducir){
    const e=estado, t=ms/1000, amp=reducir?0:1, hablando=e.actividad==='hablando';
    if (hablando){ if (e.nivelExterno===null) this.silabas.avanzar(dt); }
    else if (this.silabas.nivel!==0) this.silabas.reiniciar();
    if (ms>=this.proximo){ this.finParpadeo=ms+140; this.proximo = ms + (Math.random()<1/6 ? 300 : 2500+Math.random()*3000); }

    const nivel = hablando ? (e.nivelExterno ?? this.silabas.nivel) : 0;
    const ojos = ojosPara(e, !reducir && ms<this.finParpadeo);
    const boca = bocaPara(e, nivel, e.nivelExterno===null && this.silabas.redonda);
    for (const o of OJOS) this.img['ojos_'+o].style.opacity = o===ojos ? 1 : 0;
    for (const b of BOCAS) this.img['boca_'+b].style.opacity = b===boca ? 1 : 0;
    this.img.mejillas.style.opacity = e.emocion==='alegre' ? 1 : .75;
    this.img.extra_pensando.style.opacity = e.actividad==='pensando' ? .6+.4*(Math.sin(2*Math.PI*t/1.2)+1)/2 : 0;

    const onda=Math.sin(2*Math.PI*t/3.2), bal=Math.sin(2*Math.PI*t/5.3);
    let dy=0, rot=(e.actividad==='escuchando'?0.06:0)*amp, sx=1, sy=1, sombraX=1, origen='50% 50%';
    if (this.cfg.movimiento==='flotar'){
      dy=(-6*onda-3*nivel)*amp; rot+=0.025*bal*amp; sx=sy=1+0.015*nivel*amp; sombraX=1-0.1*(onda+1)/2*amp;
    } else {
      origen='50% 87.5%'; sy=1+(0.025*onda+0.04*nivel)*amp; sx=1-(0.025*onda+0.02*nivel)*amp; sombraX=1+0.04*onda*amp;
    }
    this.cuerpo.style.transformOrigin=origen;
    this.cuerpo.style.transform=`translateY(${dy}px) rotate(${rot}rad) scale(${sx},${sy})`;
    this.sombra.style.transformOrigin='50% 93.5%';
    this.sombra.style.transform=`scaleX(${sombraX})`;

    if (e.actividad==='escuchando'){
      const p = reducir ? .5 : (t%1.4)/1.4, lado=240*(.7+.3*p);
      Object.assign(this.anillo.style,{display:'block',width:lado+'px',height:lado+'px',
        border:`3px solid rgba(${this.cfg.acento},${.55*(1-p)})`});
    } else this.anillo.style.display='none';
    return nivel;
  }
}

const avatares=[new Avatar(document.getElementById('av-nimbus'),'nimbus'), new Avatar(document.getElementById('av-plip'),'plip')];
const reducir=document.getElementById('reducir');
try { reducir.checked = matchMedia('(prefers-reduced-motion: reduce)').matches; } catch(_){}

// ---------- controles
const ACTIVIDADES=[['inactivo','Reposo'],['escuchando','Escuchar'],['pensando','Pensar'],['hablando','Hablar']];
const EMOCIONES=[['neutral','Neutral'],['alegre','Alegre'],['empatico','Empático']];
function grupo(id, items, clave){
  const f=document.getElementById(id);
  for (const [v,txt] of items){
    const b=document.createElement('button'); b.textContent=txt; b.dataset.v=v;
    b.onclick=()=>{ cambiar({[clave]:v}); }; f.append(b);
  }
}
grupo('f-actividad', ACTIVIDADES, 'actividad'); grupo('f-emocion', EMOCIONES, 'emocion');
const manual=document.getElementById('manual'), nivel=document.getElementById('nivel');
function cambiar(c){
  Object.assign(estado,c);
  if (estado.actividad!=='hablando') estado.nivelExterno=null;
  else if (manual.checked) estado.nivelExterno=+nivel.value;
  pintar();
}
function pintar(){
  for (const b of document.querySelectorAll('#f-actividad button')) b.setAttribute('aria-pressed', b.dataset.v===estado.actividad);
  for (const b of document.querySelectorAll('#f-emocion button')) b.setAttribute('aria-pressed', b.dataset.v===estado.emocion);
  for (const a of avatares) a.cuerpo.parentElement.setAttribute('aria-label', `${a.id==='nimbus'?'Nimbus':'Plip'}, ${estado.actividad}`);
}
manual.onchange=()=>{ nivel.disabled=!manual.checked; estado.nivelExterno = manual.checked && estado.actividad==='hablando' ? +nivel.value : null; };
nivel.oninput=()=>{ if (estado.actividad==='hablando') estado.nivelExterno=+nivel.value; };

const sim=document.getElementById('simular'), txt=document.getElementById('estado');
sim.onclick=async()=>{
  sim.disabled=true;
  const pasos=[
    [{actividad:'hablando',emocion:'alegre'},2200,'Saluda (alegre)'],
    [{actividad:'hablando',emocion:'empatico'},2600,'Hace una pregunta sensible (empático)'],
    [{actividad:'escuchando'},3000,'Escucha la respuesta (micrófono abierto)'],
    [{actividad:'pensando'},1800,'Envía la respuesta al motor'],
    [{actividad:'hablando',emocion:'neutral'},2400,'Responde'],
    [{actividad:'inactivo'},0,''],
  ];
  for (const [c,ms,d] of pasos){ cambiar(c); txt.textContent=d; await new Promise(r=>setTimeout(r,ms)); }
  sim.disabled=false;
};

let previo=null;
function bucle(ms){
  const dt = previo===null ? 16 : Math.min(ms-previo, 100); previo=ms;
  let n=0; for (const a of avatares) n=a.frame(ms, dt, reducir.checked);
  document.getElementById('lectura').textContent = estado.actividad==='hablando' ? `nivel ${n.toFixed(2)}` : '';
  requestAnimationFrame(bucle);
}
pintar(); requestAnimationFrame(bucle);

// ---------- hoja de capas
const tabs=document.getElementById('tabs'), hoja=document.getElementById('hoja');
function mostrarHoja(id){
  for (const b of tabs.children) b.setAttribute('aria-pressed', b.dataset.v===id);
  hoja.innerHTML='';
  for (const c of ORDEN){
    const fig=document.createElement('figure');
    const mini=document.createElement('div'); mini.className='mini';
    const im=document.createElement('img'); im.src=uri(CAPAS[id][c]); im.alt=c;
    mini.append(im); fig.append(mini);
    const cap=document.createElement('figcaption'); cap.textContent=c+'.svg'; fig.append(cap);
    hoja.append(fig);
  }
}
for (const [v,t] of [['nimbus','Nimbus'],['plip','Plip']]){
  const b=document.createElement('button'); b.textContent=t; b.dataset.v=v; b.onclick=()=>mostrarHoja(v); tabs.append(b);
}
mostrarHoja('nimbus');
</script>
</body>
</html>
"""
html = html.replace("__CAPAS__", json.dumps(capas, ensure_ascii=False)).replace("__ORDEN__", json.dumps(ORDEN))
salida.write_text(html, encoding="utf-8")
print(salida, len(html))
