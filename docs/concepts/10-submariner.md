# Submariner

## ¿Qué es?

Un proyecto CNCF que conecta las **redes de pods y services de varios clústeres**: un pod de un clúster puede llegar a la ClusterIP de otro como si fuera local, a través de un túnel entre nodos. Además añade descubrimiento de servicios multi-clúster por DNS siguiendo la [MCS API](20-multicluster-services-api.md).

## ¿Qué problema resuelve?

Las redes de pods y services son privadas de cada clúster. Sin Submariner (ni service mesh), para llamar de `hub` a una app en `remote` tendrías que exponerla con NodePort o LoadBalancer, copiar la IP a mano, protegerla porque ahora es pública o semipública, y mantener todo sincronizado cuando cambie.

## Conceptos clave

| Componente | Dónde | Función |
|---|---|---|
| **Broker** | hub, ns `submariner-k8s-broker` | Base de datos compartida (CRDs `Cluster`, `Endpoint`, `ServiceImport`, `EndpointSlice`). **No pasa tráfico por él.** |
| **Operator** | ambos | Despliega y mantiene el resto. |
| **Gateway Engine** | nodo `submariner.io/gateway=true` | Establece el túnel (aquí [IPsec/libreswan](18-ipsec-libreswan.md)). |
| **Route Agent** | cada nodo | Rutas para llevar el tráfico remoto hasta el gateway. |
| **Lighthouse agent** | ambos | Traduce `ServiceExport` ↔ broker ↔ `ServiceImport`. |
| **Lighthouse CoreDNS** | ambos | Responde la zona `clusterset.local`. |
| **Globalnet** | opcional | NAT para CIDRs solapados (no usado). |

## Cómo se usa en este POC

Instalación y flags: [submariner/README.md](../../submariner/README.md) y [scripts/submariner.sh](../../scripts/submariner.sh).

### Plano de control: cómo viaja un export

```
 remote                           broker (en hub)                    hub
 ServiceExport demo/webapp
        │ lighthouse-agent
        ▼
 EndpointSlice  ───────────────►  ServiceImport + EndpointSlice ───► ServiceImport demo/webapp
 (ClusterIP 10.120.x.y)                                              EndpointSlice 10.120.x.y
                                                                           │            │
                                                                  Envoy Gateway   Lighthouse DNS
```

### Plano de datos: cómo viaja un paquete

1. El pod de Envoy (`10.10.0.x`) envía a `10.120.x.y:80` (ClusterIP de `remote`).
2. En el nodo, el route agent dejó una tabla de rutas propia:
   ```
   $ docker exec hub-control-plane ip route show table 150
   10.20.0.0/16  dev eth0 proto static scope link src 10.10.0.1
   10.120.0.0/16 dev eth0 proto static scope link src 10.10.0.1
   ```
3. Una política XFRM del kernel (creada por libreswan) captura ese tráfico y lo cifra en ESP hacia la IP del nodo `remote`.
4. El nodo `remote` descifra; su kube-proxy traduce la ClusterIP a un pod (`10.20.0.x`).
5. El pod ve como origen la IP real del pod de Envoy: **no hay NAT** en el camino (por eso `whoami` muestra `RemoteAddr: 10.10.0.x`).

Con varios nodos, los que no son gateway enviarían primero el tráfico al gateway por una VXLAN interna (interfaz `vx-submariner`).

### DNS multi-clúster

`subctl join` añade al CoreDNS de cada clúster:

```
clusterset.local:53 {
    forward . <ClusterIP de submariner-lighthouse-coredns>
}
```

`webapp.demo.svc.clusterset.local` → Lighthouse responde con la ClusterIP del Service en `remote`. Lighthouse además deja de anunciar clústeres cuyo túnel o endpoints no estén sanos.

Envoy **no** usa este DNS (lee los EndpointSlices); sirve para cualquier otro pod.

### Reglas que conviene recordar

- `ServiceExport` debe tener **el mismo nombre y namespace** que el Service.
- El `ServiceImport` aparece donde **exista ese namespace**.
- Para un Service `ClusterIP` se publica **la ClusterIP**; para uno *headless*, las IPs de los pods.
- Durante unos segundos tras el `join`, CoreDNS se recarga y una resolución puede fallar.
- El gateway intenta descubrir su IP pública con un servicio externo aunque `--natt=false`; la verás en el objeto `Gateway`. No la pegues en issues sin revisar.

## Comandos útiles para inspeccionar / debuggear

```bash
task submariner:status                      # = subctl show all
./scripts/run.sh subctl diagnose all --context kind-hub
khub -n submariner-operator get gateways.submariner.io -o yaml
khub get serviceimport -A ; kremote get serviceexport -A
khub -n submariner-k8s-broker get clusters.submariner.io,endpoints.submariner.io
docker exec hub-control-plane ip xfrm policy
```

## Para profundizar

- <https://submariner.io/getting-started/architecture/>
- <https://submariner.io/operations/usage/>
