// ============================================================================
// steps.js — EL GUION del recorrido. Edita aquí textos, orden y comandos.
//   focus : ids de componentes (scene.js) que se resaltan
//   flows : [color, [ids...]] caminos animados
//   view  : [posición de cámara, punto al que mira]
// ============================================================================
const REPO = "https://github.com/OscarLlamas6/hubble-and-spoke/blob/main/";
export const doc = (path) => REPO + path;

export const COLORS = { provision: "#c084fc", discover: "#fbbf24", xds: "#38bdf8", request: "#f472b6" };
const { provision, discover, xds, request } = COLORS;

const WIDE = [[-1, 23, 33], [-1, 0, 1]];
const HUB = [[-10, 13, 17], [-9, 1, 0]];
const REMOTE = [[10, 12, 16], [9, 1, 0]];
const MID = [[0, 12, 20], [0, 1, 0]];

export const STEPS = [
  {
    kicker: "El mapa", title: "Dos clústeres, un objetivo", view: WIDE, focus: [], flows: [],
    body: `<p><b>hub</b> es el plano de control y la entrada de tráfico. <b>remote</b> ejecuta las aplicaciones.
      Son dos clústeres <code>kind</code> (contenedores Docker) con CIDRs distintos para que cualquier IP sea inequívoca.</p>
      <p>Meta: aplicar <b>un solo YAML</b> en hub y llegar a una app que corre en remote.</p>`,
    cmd: "task up\ntask status",
    docs: [["Arquitectura", "docs/architecture.md"], ["kind", "docs/concepts/06-kind.md"]],
  },
  {
    kicker: "Base de red", title: "Submariner tiende el túnel", view: MID,
    focus: ["smHub", "smRemote", "broker"],
    flows: [[discover, ["smHub", "broker"]], [discover, ["smRemote", "broker"]]],
    body: `<p>Cada gateway publica en el <b>broker</b> quién es y qué CIDRs tiene. Con eso, ambos negocian un
      túnel <b>IPsec</b>. El broker es solo un tablón de anuncios: <b>por él no pasa tráfico</b>.</p>
      <p>El <i>route agent</i> añade rutas en cada nodo para enviar al túnel lo que va al otro clúster.</p>`,
    cmd: "task submariner:status\ndocker exec hub-control-plane ip xfrm policy",
    docs: [["Submariner", "docs/concepts/10-submariner.md"], ["IPsec", "docs/concepts/18-ipsec-libreswan.md"]],
  },
  {
    kicker: "La petición del usuario", title: "Aplicas un Claim", view: HUB,
    focus: ["user", "claim", "xr"], flows: [[provision, ["user", "claim", "xr"]]],
    body: `<p>El consumidor escribe un <code>WebApp</code> (<b>claim</b>, namespaced). Crossplane crea por detrás
      un <code>XWebApp</code> (<b>XR</b>, cluster-scoped) que gestiona el ciclo de vida.</p>
      <pre>kind: WebApp
spec:
  image: traefik/whoami:v1.11.0
  replicas: 2
  hostname: webapp.local</pre>`,
    cmd: "task example:apply\nkubectl get webapp -A\nkubectl get xwebapp",
    docs: [["Claims", "docs/concepts/03-crossplane-claims.md"], ["XRD y Compositions", "docs/concepts/02-crossplane-compositions.md"]],
  },
  {
    kicker: "La receta", title: "El pipeline calcula los recursos", view: HUB,
    focus: ["xr", "pipeline"], flows: [[provision, ["xr", "pipeline", "xr"]]],
    body: `<p>La Composition en <code>mode: Pipeline</code> encadena tres funciones sobre un <b>Desired State</b> compartido:</p>
      <ol><li><b>patch-and-transform</b>: genera 5 <code>Object</code>.</li>
      <li><b>go-templating</b>: lee lo del paso 1, calcula el hostname y completa el HTTPRoute.</li>
      <li><b>auto-ready</b>: marca Ready.</li></ol>`,
    cmd: "task crossplane:render",
    docs: [["Pipelines y Functions", "docs/concepts/04-crossplane-pipelines-functions.md"]],
  },
  {
    kicker: "Aprovisionamiento", title: "provider-kubernetes crea en remote", view: WIDE,
    focus: ["pipeline", "provider", "deploy", "service", "pods", "export"],
    flows: [[provision, ["pipeline", "provider", "deploy", "pods"]], [provision, ["provider", "service"]], [provision, ["provider", "export"]]],
    body: `<p>Con el kubeconfig de remote (<code>ProviderConfig "remote"</code>) crea Namespace, Deployment, Service y ServiceExport.</p>
      <p>Este tráfico va <b>directo al API server</b>, no por Submariner. Y se repite siempre: si borras algo a mano, vuelve.</p>`,
    cmd: "kubectl --context kind-remote -n demo get deploy,svc,serviceexport\nkubectl --context kind-remote -n demo delete deploy webapp  # reaparece",
    docs: [["provider-kubernetes", "docs/concepts/05-provider-kubernetes.md"], ["Crossplane", "docs/concepts/01-crossplane.md"]],
  },
  {
    kicker: "Aprovisionamiento", title: "…y el HTTPRoute en hub", view: HUB,
    focus: ["provider", "route"], flows: [[provision, ["provider", "route"]]],
    body: `<p>Con <code>ProviderConfig "hub"</code> crea la ruta. Su backend no es un Service, sino un <b>ServiceImport</b>:</p>
      <pre>hostnames: [webapp.local]
backendRefs:
- group: multicluster.x-k8s.io
  kind: ServiceImport
  name: webapp
  port: 80</pre>`,
    cmd: "kubectl -n demo get httproute webapp -o yaml",
    docs: [["Gateway API", "docs/concepts/07-gateway-api.md"]],
  },
  {
    kicker: "Descubrimiento", title: "Lighthouse exporta e importa", view: WIDE,
    focus: ["export", "lhRemote", "broker", "lhHub", "import"],
    flows: [[discover, ["export", "lhRemote", "broker", "lhHub", "import"]]],
    body: `<p>El <code>ServiceExport</code> viaja por el broker y aparece en hub como <b>ServiceImport + EndpointSlice</b>.</p>
      <p>Detalle clave: el endpoint es la <b>ClusterIP del Service en remote</b>, no las IPs de los pods.
      El DNS <code>webapp.demo.svc.clusterset.local</code> resuelve a esa misma IP.</p>`,
    cmd: "kubectl -n demo get serviceimport,endpointslices",
    docs: [["MCS API", "docs/concepts/20-multicluster-services-api.md"], ["CoreDNS", "docs/concepts/19-coredns.md"]],
  },
  {
    kicker: "Configuración dinámica", title: "Envoy Gateway habla xDS", view: HUB,
    focus: ["route", "import", "gwapi", "egctl", "envoy"],
    flows: [[xds, ["route", "egctl"]], [xds, ["import", "egctl"]], [xds, ["gwapi", "egctl"]], [xds, ["egctl", "envoy"]]],
    body: `<p>El control plane traduce Gateway API a la configuración de Envoy y se la envía por gRPC, sin reinicios:</p>
      <pre>Gateway listener → LDS
HTTPRoute        → RDS
backendRef       → CDS
EndpointSlice    → EDS</pre>`,
    cmd: "task xds",
    docs: [["xDS", "docs/concepts/09-envoy-xds.md"], ["Envoy Gateway", "docs/concepts/08-envoy-gateway.md"]],
  },
  {
    kicker: "La petición", title: "curl cruza los dos clústeres", view: WIDE,
    focus: ["user", "envoy", "smHub", "smRemote", "service", "pods"],
    flows: [[request, ["user", "envoy", "smHub", "smRemote", "service", "pods"]], [request, ["pods", "service", "smRemote", "smHub", "envoy", "user"]]],
    body: `<p><code>localhost:8080</code> → NodePort 30080 → Envoy (:10080) → elige ruta por <code>Host</code> →
      ClusterIP de remote → <b>cifrado en ESP</b> por el túnel → kube-proxy elige un pod.</p>
      <p>No hay NAT: el pod ve la IP real de Envoy.</p>`,
    cmd: "curl -H 'Host: webapp.local' http://localhost:8080/\ntask test",
    docs: [["Flujo de una petición", "docs/architecture.md"]],
  },
  {
    kicker: "Cuando algo falla", title: "Cada código cuenta una historia", view: MID,
    focus: ["envoy", "import", "pods"], flows: [[request, ["user", "envoy"]]],
    body: `<ul><li><b>404</b>: ninguna ruta para ese Host.</li>
      <li><b>500</b>: el backend no se resuelve (falta el export).</li>
      <li><b>503</b>: hay backend, pero no responde (sin pods).</li></ul>
      <p>Los tres se pueden provocar en el lab.</p>`,
    cmd: "./scripts/run.sh crossplane resource trace webapp.platform.lab.local/webapp -n demo --context kind-hub",
    docs: [["Troubleshooting", "docs/troubleshooting.md"]],
  },
  {
    kicker: "Tu turno", title: "Constrúyelo y rómpelo", view: WIDE, focus: [], flows: [],
    body: `<p>La guía paso a paso recorre cada fase con experimentos y ejercicios.</p>
      <p>Haz clic en cualquier componente de la escena para ver qué es.</p>`,
    cmd: "git clone https://github.com/OscarLlamas6/hubble-and-spoke.git\ncd hubble-and-spoke && task up",
    docs: [["Recorrido guiado", "docs/walkthrough.md"], ["README", "README.md"]],
  },
];
