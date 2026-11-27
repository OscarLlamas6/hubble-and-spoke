# Submariner en este laboratorio

> Concepto a fondo (arquitectura, datapath, DNS): [docs/concepts/10-submariner.md](../docs/concepts/10-submariner.md) y [25-lighthouse.md](../docs/concepts/25-lighthouse.md).
> Aquí: **qué comandos se ejecutan, con qué flags y por qué**.
> Automatizado en [scripts/submariner.sh](../scripts/submariner.sh) (`task submariner`).

## Los cinco conceptos en una tabla

| Concepto | Qué es | Dónde vive |
|---|---|---|
| **Broker** | Un namespace + CRDs en un API server que sirve de "tablón de anuncios". No transporta tráfico. | `hub`, ns `submariner-k8s-broker` |
| **Gateway Engine** | Pod en el nodo etiquetado `submariner.io/gateway=true`; termina el túnel entre clústeres. | ambos |
| **Route Agent** | DaemonSet que programa rutas en cada nodo para mandar el tráfico remoto hacia el gateway. | ambos |
| **Lighthouse** | `lighthouse-agent` (sincroniza exports) + `lighthouse-coredns` (responde `*.svc.clusterset.local`). | ambos |
| **ServiceExport / ServiceImport** | API estándar MCS: tú creas el *Export*; Submariner crea el *Import* en los demás clústeres. | `remote` / `hub` |

## Comandos, paso a paso

### 1. Desplegar el broker

```bash
subctl deploy-broker --context kind-hub \
  --broker-url https://<IP-nodo-hub>:6443 \
  --components service-discovery,connectivity \
  --version 0.24.3
```

| Flag | Por qué |
|---|---|
| `--broker-url` | El kubeconfig de tu host usa `https://127.0.0.1:<puerto>`. Esa URL queda grabada en `broker-info.subm` y la usan **pods** de `remote`, donde `127.0.0.1` es el propio pod. Hay que anunciar la IP del nodo en la red Docker `kind`. |
| `--components` | `connectivity` = túneles; `service-discovery` = Lighthouse (DNS). |
| `--version` | Fija las imágenes; sin esto la versión depende del binario. |

Genera `out/broker-info.subm`: URL del broker, token y **PSK de IPsec**. Es un secreto (está en `.gitignore`).

### 2. Elegir el gateway node

```bash
kubectl --context kind-hub    label node hub-control-plane    submariner.io/gateway=true
kubectl --context kind-remote label node remote-control-plane submariner.io/gateway=true
```

### 3. Join de cada clúster

```bash
subctl join out/broker-info.subm --context kind-remote \
  --clusterid remote --natt=false --cable-driver libreswan \
  --clustercidr 10.20.0.0/16 --servicecidr 10.120.0.0/16
```

| Flag | Por qué |
|---|---|
| `--clusterid` | Identidad única; aparece en DNS (`<cluster>.<svc>.<ns>.svc.clusterset.local` para headless). |
| `--natt=false` | Los nodos kind se ven directamente en el bridge Docker: no hay NAT que atravesar. |
| `--cable-driver libreswan` | Túnel IPsec cifrado (default). Alternativas: `wireguard`, `vxlan` (sin cifrado, útil para depurar). |
| `--clustercidr` / `--servicecidr` | Lo que este clúster anuncia a los demás. Deben coincidir con `clusters/kind-*.yaml`. |

Sin `--globalnet`: nuestros CIDRs no se solapan, así que las IPs se usan tal cual.

### 4. Verificar

```bash
task submariner:status          # subctl show all
task submariner:verify          # whoami en remote, curl desde hub
KEEP=1 task submariner:verify   # igual, pero deja los recursos para explorarlos
```

La prueba usa [connectivity-test.yaml](connectivity-test.yaml).

## Qué mirar después de un export

```bash
source scripts/env.sh
KEEP=1 task submariner:verify
khub -n sm-test get serviceimport whoami -o yaml
khub -n sm-test get endpointslices -l multicluster.kubernetes.io/service-name=whoami -o yaml
kremote -n sm-test get serviceexport whoami -o yaml   # conditions: Valid, Ready
khub -n kube-system get configmap coredns -o yaml      # bloque lighthouse añadido
```

Dos detalles que sorprenden y que son clave para entender el resto del lab:

1. El `EndpointSlice` importado en `hub` **no** contiene IPs de pods: contiene la **ClusterIP del Service en `remote`**. El balanceo entre pods lo hace el kube-proxy de `remote`.
2. El `ServiceImport` aparece en el namespace del mismo nombre en `hub`. Por eso la Composition crea el namespace en **ambos** clústeres.

## Limitaciones de esta configuración

Un solo gateway node por clúster (sin HA), PSK compartida generada por `subctl`, y la IP del broker es la del contenedor: si Docker reasigna IPs tras reiniciar, lo más simple es `task down && task up`.
