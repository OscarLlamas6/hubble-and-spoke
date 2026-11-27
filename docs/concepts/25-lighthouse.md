# Lighthouse

## ¿Qué es?

La parte de [Submariner](10-submariner.md) que se encarga del **descubrimiento de servicios entre clústeres**. El túnel de Submariner permite que un paquete *llegue* a otro clúster; Lighthouse permite *saber a dónde mandarlo*: qué servicios existen en otros clústeres, con qué nombre y en qué IP.

El nombre es "faro": señala dónde está cada cosa. Implementa la [Multi-Cluster Services API](20-multicluster-services-api.md).

## ¿Qué problema resuelve?

Con solo el túnel, desde `hub` podrías llamar a `10.120.201.5`, pero tendrías que averiguar esa IP a mano en `remote`, copiarla en el `HTTPRoute` y actualizarla cada vez que el Service se recreara. Tampoco sabrías si hay algo sano detrás.

## Conceptos clave

| Término | Definición |
|---|---|
| **lighthouse-agent** | Controlador. Observa `ServiceExport`, publica en el broker y crea `ServiceImport` + `EndpointSlice` en los clústeres. |
| **lighthouse-coredns** | Servidor DNS (CoreDNS con el plugin `lighthouse`) que responde la zona `clusterset.local`. |
| **ServiceExport** | Lo creas tú: "publica este Service". |
| **ServiceImport** | Lo crea Lighthouse: "este Service existe en el clusterset". |
| **EndpointSlice importado** | La IP a la que ir y si está sana (`ready`). |
| **`clusterset.local`** | Dominio DNS de los servicios multi-clúster. |
| **ServiceDiscovery** | CR del operator de Submariner que configura Lighthouse. |

## Cómo se usa en este POC

### Dónde se instala

Lo despliega `subctl` en **ambos** clústeres, en el namespace `submariner-operator`, porque [scripts/submariner.sh](../../scripts/submariner.sh) crea el broker con `--components service-discovery,connectivity`. `service-discovery` **es** Lighthouse; `connectivity` es el túnel.

| Deployment | Réplicas observadas | Rol |
|---|---|---|
| `submariner-lighthouse-agent` | 1 | sincroniza exports e imports |
| `submariner-lighthouse-coredns` | 2 | DNS |

Si los cambias a mano, el operator de Submariner los restaura.

### Qué archivos del repo tienen que ver

| Archivo | Relación |
|---|---|
| [scripts/submariner.sh](../../scripts/submariner.sh) | lo instala y espera a que esté listo |
| [composition-webapp.yaml](../../crossplane/composition-webapp.yaml) / [v2](../../crossplane/v2/composition-webappv2.yaml) | crean el `ServiceExport` en `remote` y un `HTTPRoute` cuyo backend es el `ServiceImport` |
| [submariner/connectivity-test.yaml](../../submariner/connectivity-test.yaml) | export de prueba de un `whoami` |
| [scripts/submariner-verify.sh](../../scripts/submariner-verify.sh) | prueba DNS y conectividad |

No hay ningún manifiesto de Lighthouse en el repo: se configura solo.

### El recorrido, paso a paso

1. Crossplane crea en `remote` el Service `demo/webapp` y un `ServiceExport` con el mismo nombre.
2. El agent de `remote` lo ve, lo marca `Valid` y `Ready`, y publica la información en el broker (que vive en `hub`).
3. El agent de `hub` la recibe y crea `ServiceImport demo/webapp` y un `EndpointSlice` con la **ClusterIP de `remote`**.
4. A partir de ahí hay **dos consumidores distintos**:

```
                      ┌─► Envoy Gateway lee ServiceImport + EndpointSlice ──► config xDS (EDS)
  Lighthouse agent ───┤        (así llega TU curl; no usa DNS)
                      └─► lighthouse-coredns responde *.clusterset.local
                               (así llaman otros pods, p. ej. submariner-verify)
```

Es el matiz que más confunde: **las peticiones por el Gateway no pasan por el DNS de Lighthouse**. Dependen del agent (que crea los objetos), no de su CoreDNS.

### DNS

El CoreDNS del clúster tiene una zona que reenvía a Lighthouse ([19 · CoreDNS](19-coredns.md)). El Corefile del propio Lighthouse:

```
clusterset.local:53 {
    lighthouse
    errors
    health
    ready
    prometheus :9153
    loadbalance
}
```

Resultados observados desde `hub`:

| Consulta | Respuesta |
|---|---|
| `webapp.demo.svc.clusterset.local` | ClusterIP del Service en `remote` |
| `remote.webapp.demo.svc.clusterset.local` | la misma (eligiendo clúster) |
| `hub.webapp.demo.svc.clusterset.local` | `NXDOMAIN`: `hub` no exporta ese servicio |
| SRV `_http._tcp.webapp.demo.svc.clusterset.local` | puerto 80 |
| `webapp.demo.svc.cluster.local` | `NXDOMAIN`: en `hub` no existe un Service local |

### Salud

Con el Deployment de `remote` en 0 réplicas, el `EndpointSlice` importado pasó a `ready: false` y el DNS dejó de devolver direcciones; por el Gateway se obtuvo 503. Al volver los pods, se recuperó solo.

## Comandos útiles para inspeccionar / debuggear

```bash
source scripts/env.sh
khub -n submariner-operator get deploy | grep lighthouse
kremote -n demo get serviceexport webapp -o yaml            # Valid y Ready
khub -n demo get serviceimport,endpointslices
khub -n submariner-operator logs deploy/submariner-lighthouse-agent --tail=30
khub run dns --rm -i --image=busybox:1.37 --restart=Never -- nslookup -type=a webapp.demo.svc.clusterset.local
```

## Para profundizar

- <https://submariner.io/getting-started/architecture/service-discovery/>
