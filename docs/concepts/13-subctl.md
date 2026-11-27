# subctl

## ¿Qué es?

La CLI oficial de Submariner: despliega el broker, une clústeres, exporta servicios y diagnostica.

## ¿Qué problema resuelve?

Instalar Submariner a mano implica CRDs, el operator, credenciales para el broker, la PSK de IPsec, el objeto `Submariner` y retocar CoreDNS. `subctl` hace todo eso de forma coherente.

## Conceptos clave

| Subcomando | Qué hace |
|---|---|
| `deploy-broker` | Prepara el broker y escribe `broker-info.subm`. |
| `join` | Une un clúster usando ese archivo. |
| `export service` | Atajo para crear un `ServiceExport`. |
| `show` | Estado: gateways, conexiones, versiones. |
| `diagnose` | Comprobaciones de salud y compatibilidad. |
| `verify` | Suite E2E entre dos clústeres. |
| `gather` | Recoge logs y recursos para depurar. |
| `uninstall` | Desinstala. |

## Cómo se usa en este POC

Versión fijada en [versions.env](../../versions.env), instalada en `.bin/` por [scripts/tools.sh](../../scripts/tools.sh), usada en [scripts/submariner.sh](../../scripts/submariner.sh).

`broker-info.subm` (en `out/`, ignorado por git) contiene la URL del broker, un token y la PSK: **trátalo como un secreto**.

En el lab los exports los crea Crossplane aplicando el `ServiceExport` directamente: es la API estándar y `subctl export` solo es un atajo.

## Comandos útiles para inspeccionar / debuggear

```bash
source scripts/env.sh
subctl show all --context kind-hub
subctl diagnose all --context kind-hub
subctl gather --context kind-hub --dir out/gather
subctl verify --context kind-hub --tocontext kind-remote --only connectivity,service-discovery
```

`subctl verify` crea y borra recursos de prueba y tarda varios minutos; para el día a día basta `task submariner:verify`.

## Para profundizar

- <https://submariner.io/operations/deployment/subctl/>
