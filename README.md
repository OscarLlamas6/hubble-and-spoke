# hubble-and-spoke 🛰️

## ¿Qué hace este proyecto? (en palabras simples)

Tienes **dos clústeres de Kubernetes** en tu máquina:

- **`hub`**: la "central". Desde aquí pides las cosas y por aquí entran las visitas.
- **`remote`**: donde realmente corren las aplicaciones.

Escribes **un archivo de unas pocas líneas** en `hub` que dice *"quiero una app web con esta imagen, 2 copias y este nombre"*. Con eso, automáticamente:

1. **Se crea la app en el otro clúster** (`remote`). De eso se encarga *Crossplane*.
2. **Los dos clústeres quedan comunicados** por un túnel cifrado, y `hub` se entera de que la app existe. De eso se encarga *Submariner*.
3. **Se publica la app en una puerta de entrada** en `hub`. De eso se encargan *Gateway API* y *Envoy Gateway*.

Resultado: abres una petición contra `hub` y **te responde una app que está corriendo en `remote`**.

```bash
curl -H "Host: webapp.local" http://localhost:8080/   # entra por hub, responde remote
```

Y si alguien borra o cambia algo a mano, la plataforma lo vuelve a dejar como pediste.

Una analogía: `hub` es la **recepción** de una empresa y `remote` la **oficina** donde se trabaja. Tú entregas una solicitud en recepción; alguien monta el puesto en la oficina, tiende la línea entre ambos edificios y apunta en el directorio a dónde pasar las llamadas.

📖 ¿Un término no te suena? Está en el **[glosario](docs/glossary.md)**.

## Ficha técnica

**Un solo YAML en un clúster → una aplicación corriendo en otro, publicada por un Gateway.**

Laboratorio local para aprender a fondo **Crossplane**, **Compositions**, **Gateway API**, **Envoy Gateway / xDS** y **Submariner**, con dos clústeres `kind`. Es material de aprendizaje, **no** una referencia de producción.

🎬 **[Recorrido 3D interactivo](https://oscarllamas6.github.io/hubble-and-spoke/)** · en local: `task tour`

## Qué construyes

```mermaid
flowchart LR
  you([curl]) -->|"localhost:8080<br/>Host: webapp.local"| envoy

  subgraph hub["🔵 hub — control y entrada"]
    claim["📄 WebApp (claim)"] --> xp["Crossplane<br/>XRD + Composition"]
    xp -->|HTTPRoute| envoy["Envoy Gateway"]
    si["ServiceImport"] -.-> envoy
  end

  subgraph remote["🟢 remote — aplicaciones"]
    app["Deployment + Service<br/>+ ServiceExport"]
  end

  xp -->|"① provisiona<br/>provider-kubernetes"| app
  app -.->|"② descubre<br/>Lighthouse"| si
  envoy ==>|"③ tráfico<br/>túnel IPsec Submariner"| app
```

El consumidor escribe esto ([webapp-claim.yaml](crossplane/examples/webapp-claim.yaml)):

```yaml
apiVersion: platform.lab.local/v1alpha1
kind: WebApp
metadata: { name: webapp, namespace: demo }
spec:
  image: traefik/whoami:v1.11.0
  replicas: 2
  hostname: webapp.local
```

Y la plataforma crea:

| Recurso | Dónde |
|---|---|
| Namespace, Deployment, Service | `remote` |
| ServiceExport | `remote` |
| HTTPRoute → ServiceImport | `hub` |

## Dos formas de pedir lo mismo

| | `WebApp` — claims (v1) | `WebAppV2` — XR namespaced (v2) |
|---|---|---|
| Estado | XRD v1 **deprecado** | modelo actual |
| Objetos | claim + XR | solo el XR |
| HTTPRoute | envuelto en `Object` | recurso directo |
| Prueba | `curl -H "Host: webapp.local" localhost:8080` | `curl -H "Host: webapp-v2.local" localhost:8080` |

`task up` despliega las dos. Comparación completa: [docs/concepts/22-crossplane-v2.md](docs/concepts/22-crossplane-v2.md).

## ¿Y xDS?

Es la API con la que Envoy recibe su configuración **en caliente**. Aquí no se escribe a mano: Envoy Gateway traduce `Gateway`/`HTTPRoute` a Listeners, Routes, Clusters y Endpoints. Míralo en vivo con `task xds` y léelo en [docs/concepts/09-envoy-xds.md](docs/concepts/09-envoy-xds.md).

## Quickstart

Necesitas Linux, Docker, [Task](https://taskfile.dev/installation/) y `jq` ([detalle](docs/prerequisites.md)).

```bash
git clone https://github.com/OscarLlamas6/hubble-and-spoke.git
cd hubble-and-spoke
task up        # ~4-5 minutos
task test      # prueba de punta a punta (v1 y v2)
task test:unit # tests de las Compositions, sin clúster
task down      # destruye todo
```

```bash
curl -H "Host: webapp.local" http://localhost:8080/
# Hostname: webapp-5f4cbd5db8-r8vtw   ← un pod que solo existe en remote
```

> Las CLIs se instalan en `./.bin` y el lab usa su propio kubeconfig (`./.kube/config`). No toca tu `~/.kube/config`. Para usar `kubectl` a mano: `source scripts/env.sh`.

## Por dónde empezar a aprender

| Si quieres… | Ve a |
|---|---|
| Verlo en imágenes | [Recorrido 3D](https://oscarllamas6.github.io/hubble-and-spoke/) |
| Construirlo paso a paso, rompiendo cosas | [docs/walkthrough.md](docs/walkthrough.md) |
| Entender cómo encaja todo | [docs/architecture.md](docs/architecture.md) |
| Buscar qué significa un término | [docs/glossary.md](docs/glossary.md) |
| Saber por qué se hizo así | [docs/decisions.md](docs/decisions.md) |
| Algo no funciona | [docs/troubleshooting.md](docs/troubleshooting.md) |

## Índice de conceptos

Todos con la misma plantilla: qué es, qué problema resuelve, conceptos clave, uso en este repo, comandos y enlaces.

| Crossplane | Red y tráfico | Herramientas |
|---|---|---|
| [01 · Crossplane](docs/concepts/01-crossplane.md) | [07 · Gateway API](docs/concepts/07-gateway-api.md) | [06 · kind](docs/concepts/06-kind.md) |
| [02 · XRD y Compositions](docs/concepts/02-crossplane-compositions.md) | [08 · Envoy y Envoy Gateway](docs/concepts/08-envoy-gateway.md) | [11 · Helm](docs/concepts/11-helm.md) |
| [03 · Claims](docs/concepts/03-crossplane-claims.md) | [09 · xDS](docs/concepts/09-envoy-xds.md) | [12 · Taskfile](docs/concepts/12-taskfile.md) |
| [04 · Pipelines y Functions](docs/concepts/04-crossplane-pipelines-functions.md) | [10 · Submariner](docs/concepts/10-submariner.md) | [13 · subctl](docs/concepts/13-subctl.md) |
| [05 · provider-kubernetes](docs/concepts/05-provider-kubernetes.md) | [18 · IPsec / libreswan](docs/concepts/18-ipsec-libreswan.md) | [14 · Crossplane CLI](docs/concepts/14-crossplane-cli.md) |
| [15 · patch-and-transform](docs/concepts/15-function-patch-and-transform.md) | [19 · CoreDNS](docs/concepts/19-coredns.md) | [21 · Three.js y Pages](docs/concepts/21-threejs-github-pages.md) |
| [16 · go-templating](docs/concepts/16-function-go-templating.md) | [20 · Multi-Cluster Services API](docs/concepts/20-multicluster-services-api.md) | |
| [17 · auto-ready](docs/concepts/17-function-auto-ready.md) | | [23 · xprin](docs/concepts/23-xprin.md) |
| [22 · Crossplane v2](docs/concepts/22-crossplane-v2.md) | [25 · Lighthouse](docs/concepts/25-lighthouse.md) | [24 · yq](docs/concepts/24-yq.md) |

## Comandos

| Comando | Qué hace |
|---|---|
| `task up` / `task down` | ciclo de vida completo |
| `task test` | smoke test de punta a punta (`test:v1`, `test:v2`) |
| `task test:unit` | tests con xprin, sin clúster |
| `task status` | foto de todo el flujo |
| `task xds` | config efectiva de Envoy |
| `task crossplane:render` / `crossplane:render:v2` | pipeline en local, sin clúster |
| `task submariner:status` / `submariner:verify` | túnel y prueba cross-cluster |
| `task example:apply` / `example:delete` | gestionar claims (`FILE=…`); sufijo `:v2` para el XR v2 |
| `task tour` | recorrido 3D en local |

Fases sueltas: `tools`, `check-deps`, `clusters`, `submariner`, `crossplane`, `api`, `gateway`. También funciona `make up`, `make test`, `make down`.

## Estructura

```
.
├── Taskfile.yml · Makefile · versions.env
├── clusters/        configuración de kind (CIDRs, puertos)
├── submariner/      comandos, flags y prueba de conectividad
├── crossplane/      provider, functions, XRD, Composition, ejemplos (v2/ = modelo actual)
├── tests/           suites de xprin
├── gateway/         EnvoyProxy, GatewayClass, Gateway
├── scripts/         lo que ejecuta cada task, comentado
├── docs/            arquitectura, walkthrough, troubleshooting, concepts/
└── tour/            recorrido 3D (GitHub Pages)
```

## Problemas comunes

| Síntoma | Primera acción |
|---|---|
| El kubelet no arranca / `too many open files` | límites de [inotify](docs/troubleshooting.md#problemas-de-instalación) |
| Túnel no conecta o CIDRs solapados | `task submariner:status` |
| `clusterset.local` no resuelve | espera ~1 min; revisa el `ServiceExport` |
| Claim en `READY=False` | `crossplane resource trace` ([método](docs/troubleshooting.md#método-sigue-la-cadena)) |
| 404 / 500 / 503 | [significado de cada uno](docs/troubleshooting.md#gateway--envoy) |

## Alcance

Fuera a propósito: clouds reales, TLS/cert-manager, observabilidad, CI/CD del lab, HA. Ver [qué haría distinto en producción](docs/architecture.md#qué-haría-distinto-en-producción).
