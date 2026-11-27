// ============================================================================
// app.js — panel de texto y navegación. La escena 3D se carga de forma
// diferida para que el recorrido siga siendo legible si WebGL/CDN fallan.
// ============================================================================
import { STEPS, doc } from "./steps.js";

const $ = (id) => document.getElementById(id);
let current = 0, scene = null, timer = null;

const links = (docs) => docs.map(([name, path]) => `<a href="${doc(path)}" target="_blank" rel="noopener">${name}</a>`).join(" · ");
const escape = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

function go(index) {
  current = Math.max(0, Math.min(STEPS.length - 1, index));
  const step = STEPS[current];
  $("card").innerHTML = `
    <p class="kicker">${current + 1}/${STEPS.length} · ${step.kicker}</p>
    <h2>${step.title}</h2>
    ${step.body}
    <h3>Pruébalo <small>(tras <code>source scripts/env.sh</code>)</small></h3><pre>${escape(step.cmd)}</pre>
    <h3>Profundiza</h3><p>${links(step.docs)}</p>`;
  $("card").scrollTop = 0;
  [...$("dots").children].forEach((b, i) => {
    if (i === current) b.setAttribute("aria-current", "step");
    else b.removeAttribute("aria-current");
  });
  $("prev").disabled = current === 0;
  $("next").disabled = current === STEPS.length - 1;
  history.replaceState(null, "", `#${current + 1}`);
  scene?.show(step);
}

function select({ text, info, docPath }) {
  stop();
  $("card").innerHTML = `
    <p class="kicker">Componente</p><h2>${text}</h2><p>${info}</p>
    <p>${links([["Leer la documentación", docPath]])}</p>
    <p><button type="button" id="back">Volver al paso ${current + 1}</button></p>`;
  $("back").onclick = () => go(current);
}

function stop() {
  clearInterval(timer);
  timer = null;
  $("play").textContent = "▶ Auto";
  $("play").setAttribute("aria-pressed", "false");
}

STEPS.forEach((step, i) => {
  const b = document.createElement("button");
  b.type = "button";
  b.textContent = i + 1;
  b.title = step.title;
  b.onclick = () => { stop(); go(i); };
  $("dots").append(b);
});
$("prev").onclick = () => { stop(); go(current - 1); };
$("next").onclick = () => { stop(); go(current + 1); };
$("play").onclick = () => {
  if (timer) return stop();
  $("play").textContent = "❚❚ Pausa";
  $("play").setAttribute("aria-pressed", "true");
  timer = setInterval(() => go((current + 1) % STEPS.length), 9000);
};
addEventListener("keydown", (e) => {
  if (e.key === "ArrowRight") { stop(); go(current + 1); }
  if (e.key === "ArrowLeft") { stop(); go(current - 1); }
});

go((parseInt(location.hash.slice(1), 10) || 1) - 1);

import("./scene.js")
  .then(({ createScene }) => { scene = createScene($("stage"), select); scene.show(STEPS[current]); })
  .catch((error) => { console.error(error); $("nowebgl").hidden = false; });
