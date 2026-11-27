# Envoy xDS (Discovery Service API)

## ¿Qué es?

xDS es la familia de APIs (gRPC/REST) con las que Envoy **pide y recibe su configuración mientras está corriendo**. La "x" es un comodín: cada tipo de recurso tiene su "Discovery Service". Envoy se conecta a un *management server*, se suscribe y aplica cada cambio sin reiniciarse ni cortar conexiones.

## ¿Qué problema resuelve?

Con un archivo de configuración estático, cada pod nuevo, cada ruta nueva, exigiría regenerar el archivo y recargar el proceso. En Kubernetes eso ocurre constantemente. xDS convierte la configuración en un flujo de actualizaciones.

## Conceptos clave

| Servicio | Recurso | Pregunta que responde | Origen en Gateway API |
|---|---|---|---|
| **LDS** | Listener | ¿en qué puertos escucho y con qué filtros? | `Gateway.spec.listeners` |
| **RDS** | RouteConfiguration | para este Host/path, ¿a qué cluster? | `HTTPRoute` (hostnames, matches) |
| **CDS** | Cluster | ¿qué destinos lógicos existen y cómo hablarles? | `backendRefs` |
| **EDS** | ClusterLoadAssignment | ¿qué IP:puerto componen cada cluster? | EndpointSlices del backend |
| **SDS** | Secret | certificados y claves | `Gateway.listeners.tls` |
| **ADS** | — | todo lo anterior por **un solo stream** y en orden seguro | — |

Otros términos: **bootstrap** (config estática inicial), **Delta xDS** (solo se envían los cambios), **version** (identifica cada revisión de un recurso), **ACK/NACK** (Envoy confirma o rechaza).

> Ojo: un "Cluster" de Envoy no es un clúster de Kubernetes. Es un grupo de endpoints.

## Cómo se usa en este POC

### Estático vs. dinámico

**Bootstrap (estático)** contiene lo mínimo para encontrar al control plane:

| Elemento | Valor observado |
|---|---|
| `dynamic_resources.ads_config.api_type` | `DELTA_GRPC` |
| `lds_config`, `cds_config` | `ads: {}` |
| cluster estático `xds_cluster` | `envoy-gateway.envoy-gateway-system.svc.cluster.local:18000`, con TLS |
| listener estático | métricas en `:19001` |

**Todo lo demás llega por xDS.** Nadie escribió el listener de tu Gateway en un archivo.

### La traducción completa

```
Gateway hub-gateway                    LDS  "gateway-system/hub-gateway/http"  0.0.0.0:10080
  listener http :80          ──►            └─ filtro HTTP connection manager ─ rds ─┐
                                                                                     ▼
HTTPRoute demo/webapp                  RDS  "gateway-system/hub-gateway/http"
  hostnames: webapp.local    ──►            vhost dominio webapp.local
  matches: /                                  prefix "/" ──► cluster ─┐
                                                                      ▼
  backendRefs: ServiceImport ──►       CDS  "httproute/demo/webapp/rule/0"  type: EDS
                                                                      │
EndpointSlice (Lighthouse)   ──►       EDS  "httproute/demo/webapp/rule/0" → 10.120.x.y:80
                                                                      (ClusterIP en remote)
```

### Inspeccionar la config activa

Automatizado:

```bash
task xds              # resumen por tipo, con versiones
task xds -- raw       # además guarda out/config_dump.json
```

A mano:

```bash
source scripts/env.sh
POD=$(khub -n envoy-gateway-system get pod \
  -l gateway.envoyproxy.io/owning-gateway-name=hub-gateway -o name)
khub -n envoy-gateway-system port-forward "$POD" 19000:19000
```

En otra terminal:

```bash
# Todo. include_eds es imprescindible: sin él no aparecen los endpoints.
curl -s 'localhost:19000/config_dump?include_eds' > dump.json
jq -r '.configs[]."@type"' dump.json

# LDS
jq '.configs[] | select(."@type"|endswith("ListenersConfigDump")).dynamic_listeners[].name' dump.json
# RDS
jq '.configs[] | select(."@type"|endswith("RoutesConfigDump")).dynamic_route_configs[].route_config' dump.json
# CDS
jq '.configs[] | select(."@type"|endswith("ClustersConfigDump")).dynamic_active_clusters[].cluster.name' dump.json
# EDS
jq '.configs[] | select(."@type"|endswith("EndpointsConfigDump")).dynamic_endpoint_configs' dump.json

curl -s localhost:19000/clusters   | grep httproute     # estado y contadores por endpoint
curl -s localhost:19000/stats      | grep upstream_rq   # métricas
```

### Salida real de este lab

```
LDS   gateway-system/hub-gateway/http  puerto=10080
RDS   dominios=webapp.local → / ⇒ httproute/demo/webapp/rule/0
CDS   httproute/demo/webapp/rule/0  type=EDS
EDS   httproute/demo/webapp/rule/0 → 10.120.9.91:80
SDS   xds_certificate, xds_trusted_ca
```

Los dos secretos SDS son el material mTLS con el que Envoy se autentica ante su control plane; no son TLS de tus listeners (el lab sirve HTTP plano).

### Experimento: ver xDS reaccionar

```bash
task xds                                      # anota las versiones
khub -n demo patch webapp webapp --type=merge -p '{"spec":{"hostname":"nuevo.local","replicas":3}}'
curl -H 'Host: nuevo.local' http://localhost:8080/
task xds
task example:apply                            # restaurar
```

Lo que se observó:

| Recurso | ¿Cambió? | Por qué |
|---|---|---|
| LDS | no | los listeners siguen igual |
| **RDS** | **sí** (nueva versión) | cambió el dominio del virtual host |
| CDS | no | el backend es el mismo |
| EDS | no, pese a escalar de 2 a 3 | el único endpoint es la **ClusterIP** de `remote`; los pods quedan detrás de su kube-proxy |

El cambio de ruta estuvo activo en torno a un segundo después del `patch`.

**Consecuencia de diseño:** Envoy no balancea entre pods de `remote` ni conoce su salud. Balanceo por pod, *outlier detection* o *session affinity* no verían réplicas individuales. Para eso harían falta endpoints de pod (por ejemplo, un Service headless exportado y comprobando que el datapath enrute hacia IPs de pod).

## Comandos útiles para inspeccionar / debuggear

```bash
task xds
curl -s localhost:19000/config_dump?include_eds     # con port-forward activo
curl -s localhost:19000/ready
khub -n envoy-gateway-system logs deploy/envoy-gateway | grep -i xds | tail
```

## Para profundizar

- <https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol>
- <https://www.envoyproxy.io/docs/envoy/latest/operations/admin>
