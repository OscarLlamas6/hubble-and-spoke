// ============================================================================
// scene.js — la escena 3D: plataformas (clústeres), componentes y animaciones
// Para añadir un componente: agrégalo a NODES y usa su id en steps.js.
// ============================================================================
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { CSS2DRenderer, CSS2DObject } from "three/addons/renderers/CSS2DRenderer.js";

const HUB = 0x60a5fa, REMOTE = 0x34d399, XP = 0xc084fc, SM = 0xfbbf24, EG = 0x38bdf8, USER = 0xf472b6;

// id: [etiqueta, x, z, color, forma, descripción, doc]
export const NODES = {
  user:     ["curl / tú",            -19,  6, USER,   "sphere", "Tu máquina. Entra por localhost:8080.", "docs/architecture.md"],
  claim:    ["WebApp (claim)",       -15, -5, XP,     "doc",    "El único YAML del consumidor. Namespaced.", "docs/concepts/03-crossplane-claims.md"],
  xr:       ["XWebApp (XR)",         -11, -5, XP,     "doc",    "Recurso compuesto cluster-scoped que gestiona Crossplane.", "docs/concepts/02-crossplane-compositions.md"],
  pipeline: ["Composition pipeline",  -7, -5, XP,     "stack",  "Tres functions que calculan los recursos.", "docs/concepts/04-crossplane-pipelines-functions.md"],
  provider: ["provider-kubernetes",   -4, -2, XP,     "box",    "Crea y mantiene los Object en remote y en hub.", "docs/concepts/05-provider-kubernetes.md"],
  gwapi:    ["Gateway",              -15,  0, EG,     "doc",    "Punto de entrada declarado: listener HTTP :80.", "docs/concepts/07-gateway-api.md"],
  route:    ["HTTPRoute",             -9,  0, EG,     "doc",    "Hostname → ServiceImport. Lo crea la Composition.", "docs/concepts/07-gateway-api.md"],
  egctl:    ["Envoy Gateway",        -12,  2.5, EG,   "box",    "Control plane: traduce Gateway API a xDS.", "docs/concepts/08-envoy-gateway.md"],
  envoy:    ["Envoy proxy",          -12,  6, EG,     "hex",    "Data plane: recibe y reenvía las peticiones.", "docs/concepts/09-envoy-xds.md"],
  import:   ["ServiceImport",         -7,  3, SM,     "doc",    "El Service remoto visto desde hub.", "docs/concepts/20-multicluster-services-api.md"],
  lhHub:    ["Lighthouse",            -6,  6, SM,     "box",    "Sincroniza imports y sirve clusterset.local.", "docs/concepts/10-submariner.md"],
  broker:   ["Broker",                -3,  2, SM,     "cyl",    "CRDs compartidos en el API de hub. No pasa tráfico.", "docs/concepts/10-submariner.md"],
  smHub:    ["SM gateway",            -3,  5.5, SM,   "hex",    "Extremo del túnel IPsec en hub.", "docs/concepts/18-ipsec-libreswan.md"],
  smRemote: ["SM gateway",             4,  5.5, SM,   "hex",    "Extremo del túnel IPsec en remote.", "docs/concepts/18-ipsec-libreswan.md"],
  lhRemote: ["Lighthouse",             6,  2, SM,     "box",    "Detecta ServiceExport y lo publica al broker.", "docs/concepts/10-submariner.md"],
  export:   ["ServiceExport",          9, -1, SM,     "doc",    "«Publica este Service a todo el clusterset».", "docs/concepts/20-multicluster-services-api.md"],
  deploy:   ["Deployment",             9, -5, REMOTE, "doc",    "Creado por Crossplane; mantiene los pods.", "docs/concepts/05-provider-kubernetes.md"],
  service:  ["Service (ClusterIP)",   11,  3, REMOTE, "cyl",    "La IP a la que Envoy envía a través del túnel.", "docs/concepts/10-submariner.md"],
  pods:     ["pods whoami ×2",        15,  0, REMOTE, "pods",   "La aplicación. Solo existe en remote.", "docs/architecture.md"],
};

function shape(kind, color) {
  const material = () => new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.15, metalness: 0.2, roughness: 0.45, transparent: true });
  const mesh = (g, y = 0) => { const m = new THREE.Mesh(g, material()); m.position.y = y; return m; };
  const group = new THREE.Group();
  if (kind === "sphere") group.add(mesh(new THREE.SphereGeometry(0.8, 32, 16)));
  if (kind === "box")    group.add(mesh(new THREE.BoxGeometry(1.5, 1.1, 1.5)));
  if (kind === "doc")    group.add(mesh(new THREE.BoxGeometry(1.1, 1.4, 0.18)));
  if (kind === "cyl")    group.add(mesh(new THREE.CylinderGeometry(0.75, 0.75, 1.1, 32)));
  if (kind === "hex")    group.add(mesh(new THREE.CylinderGeometry(0.95, 0.95, 0.7, 6)));
  if (kind === "stack")  [-0.45, 0, 0.45].forEach((y) => group.add(mesh(new THREE.BoxGeometry(1.5, 0.28, 1.5), y)));
  if (kind === "pods")   [-0.65, 0.65].forEach((x) => { const m = mesh(new THREE.IcosahedronGeometry(0.55, 0)); m.position.x = x; group.add(m); });
  return group;
}

export function createScene(container, onSelect) {
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  const labels = new CSS2DRenderer();
  Object.assign(labels.domElement.style, { position: "absolute", top: "0", left: "0", pointerEvents: "none" });
  container.prepend(renderer.domElement, labels.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x070b18);
  const camera = new THREE.PerspectiveCamera(48, 1, 0.1, 300);
  camera.position.set(0, 26, 38);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.maxPolarAngle = Math.PI / 2.1;
  controls.minDistance = 8;
  controls.maxDistance = 90;

  scene.add(new THREE.AmbientLight(0xffffff, 0.75));
  const sun = new THREE.DirectionalLight(0xffffff, 1.4);
  sun.position.set(8, 20, 12);
  scene.add(sun);

  // Estrellas de fondo
  const stars = new Float32Array(1500).map(() => (Math.random() - 0.5) * 200);
  const starGeo = new THREE.BufferGeometry();
  starGeo.setAttribute("position", new THREE.BufferAttribute(stars, 3));
  scene.add(new THREE.Points(starGeo, new THREE.PointsMaterial({ color: 0x64748b, size: 0.18 })));

  function label(text, cls) {
    const el = document.createElement("div");
    el.className = `label ${cls || ""}`;
    el.textContent = text;
    return new CSS2DObject(el);
  }

  // Plataformas = clústeres
  [["clúster hub", -10, HUB, "10.10/16 · 10.110/16"], ["clúster remote", 10.5, REMOTE, "10.20/16 · 10.120/16"]]
    .forEach(([name, x, color, cidr]) => {
      const width = x < 0 ? 16 : 13, depth = 16;
      const slab = new THREE.Mesh(new THREE.BoxGeometry(width, 0.4, depth),
        new THREE.MeshStandardMaterial({ color, transparent: true, opacity: 0.09 }));
      slab.position.set(x, -1.4, 0);
      const edge = new THREE.LineSegments(new THREE.EdgesGeometry(slab.geometry), new THREE.LineBasicMaterial({ color }));
      edge.position.copy(slab.position);
      const title = label(`${name} · ${cidr}`, "cluster");
      title.element.style.color = `#${color.toString(16).padStart(6, "0")}`;
      title.position.set(x, -1, depth / 2 + 0.8);
      scene.add(slab, edge, title);
    });

  const nodes = {};
  const pickable = [];
  for (const [id, [text, x, z, color, kind, info, docPath]] of Object.entries(NODES)) {
    const group = shape(kind, color);
    group.position.set(x, 0, z);
    group.children.forEach((m) => { m.userData.id = id; pickable.push(m); });
    const tag = label(text);
    tag.position.set(0, 1.35, 0);
    tag.element.addEventListener("click", () => onSelect({ id, text, info, docPath }));
    group.add(tag);
    scene.add(group);
    nodes[id] = { group, tag, text, info, docPath };
  }

  // Túnel IPsec entre gateways: siempre visible
  const arc = (a, b, lift) => {
    const from = nodes[a].group.position.clone(), to = nodes[b].group.position.clone();
    const mid = from.clone().lerp(to, 0.5);
    mid.y += lift ?? Math.min(1 + from.distanceTo(to) * 0.18, 5);
    return new THREE.QuadraticBezierCurve3(from, mid, to);
  };
  const tunnel = new THREE.Mesh(new THREE.TubeGeometry(arc("smHub", "smRemote", 1.4), 40, 0.32, 16),
    new THREE.MeshStandardMaterial({ color: SM, transparent: true, opacity: 0.28, emissive: SM, emissiveIntensity: 0.3 }));
  const tunnelTag = label("túnel IPsec (ESP)");
  tunnelTag.position.set(0.5, 2, 5.5);
  scene.add(tunnel, tunnelTag);

  let flows = new THREE.Group();
  let packets = [];
  scene.add(flows);

  function setFlows(list) {
    flows.traverse((o) => { o.geometry?.dispose(); o.material?.dispose(); });
    scene.remove(flows);
    flows = new THREE.Group();
    packets = [];
    for (const [color, path] of list) {
      const curve = new THREE.CurvePath();
      for (let i = 0; i < path.length - 1; i++) {
        const tunnelHop = path[i].startsWith("sm") && path[i + 1].startsWith("sm");
        curve.add(arc(path[i], path[i + 1], tunnelHop ? 1.4 : undefined));
      }
      const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(curve.getSpacedPoints(160)),
        new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.55 }));
      flows.add(line);
      const speed = 5 / Math.max(curve.getLength(), 1); // velocidad constante en unidades/seg
      for (let k = 0; k < 3; k++) {
        const dot = new THREE.Mesh(new THREE.SphereGeometry(0.24, 12, 8), new THREE.MeshBasicMaterial({ color }));
        flows.add(dot);
        packets.push({ dot, curve, speed, offset: k / 3 });
      }
    }
    scene.add(flows);
  }

  const goal = { position: camera.position.clone(), target: new THREE.Vector3(), active: false };
  controls.addEventListener("start", () => { goal.active = false; }); // el usuario manda

  function show({ focus, flows: list, view }) {
    for (const [id, { group, tag }] of Object.entries(nodes)) {
      const on = focus.includes(id), dim = focus.length > 0 && !on;
      group.userData.on = on;
      group.children.forEach((m) => {
        if (!m.isMesh) return;
        m.material.opacity = dim ? 0.18 : 1;
        m.material.emissiveIntensity = on ? 0.65 : 0.15;
      });
      tag.element.classList.toggle("on", on);
      tag.element.classList.toggle("dim", dim);
    }
    setFlows(list);
    const [position, target] = view;
    goal.target.set(...target);
    // En pantallas estrechas alejamos la cámara para que todo quepa.
    const zoom = Math.max(1, 1.65 / camera.aspect);
    goal.position.set(...position).sub(goal.target).multiplyScalar(zoom).add(goal.target);
    goal.active = true;
  }

  function resize() {
    const { clientWidth: w, clientHeight: h } = container;
    renderer.setSize(w, h);
    labels.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(container);
  resize();

  const ray = new THREE.Raycaster();
  let down = null;
  renderer.domElement.addEventListener("pointerdown", (e) => { down = [e.clientX, e.clientY]; });
  renderer.domElement.addEventListener("pointerup", (e) => {
    if (!down || Math.hypot(e.clientX - down[0], e.clientY - down[1]) > 5) return;
    const box = renderer.domElement.getBoundingClientRect();
    ray.setFromCamera(new THREE.Vector2(((e.clientX - box.left) / box.width) * 2 - 1,
      -((e.clientY - box.top) / box.height) * 2 + 1), camera);
    const hit = ray.intersectObjects(pickable)[0];
    if (hit) { const id = hit.object.userData.id; onSelect({ id, ...nodes[id] }); }
  });

  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const clock = new THREE.Clock();
  renderer.setAnimationLoop(() => {
    const dt = Math.min(clock.getDelta(), 0.1), t = clock.elapsedTime;
    if (goal.active) {
      const k = still ? 1 : 1 - Math.pow(0.02, dt);
      camera.position.lerp(goal.position, k);
      controls.target.lerp(goal.target, k);
      if (camera.position.distanceTo(goal.position) < 0.05) goal.active = false;
    }
    packets.forEach((p) => p.dot.position.copy(p.curve.getPointAt((p.offset + (still ? 0 : t * p.speed)) % 1)));
    Object.values(nodes).forEach(({ group }) => { group.position.y = !still && group.userData.on ? Math.sin(t * 3) * 0.15 : 0; });
    controls.update();
    renderer.render(scene, camera);
    labels.render(scene, camera);
  });

  return { show };
}
