# Crossplane

## ¿Qué es?

Crossplane convierte un clúster de Kubernetes en un **plano de control universal**. Kubernetes ya sabe hacer algo muy potente: guardar un estado deseado en su API y tener controladores que trabajan sin parar para que la realidad coincida con él. Crossplane reutiliza ese mecanismo para cosas que no son pods: bases de datos de un cloud, DNS, repositorios de GitHub o, como aquí, **objetos en otro clúster**.

Por sí solo Crossplane no sabe hablar con nada. Aporta el motor (paquetes, composición, ciclo de vida) y son los **Providers** los que añaden "idiomas": cada uno instala CRDs nuevos y el controlador que los reconcilia contra una API concreta.

## ¿Qué problema resuelve?

Sin Crossplane, crear "una aplicación expuesta desde otro clúster" exige que alguien:

1. aplique Deployment y Service con el kubeconfig de `remote`,
2. exporte el Service,
3. cambie de contexto y cree el HTTPRoute en `hub`,
4. y se acuerde de repetirlo o deshacerlo cuando algo cambie.

Eso suele acabar en un script o un pipeline que **ejecuta una vez y se olvida**. Si alguien borra el Deployment a mano, nadie lo repone. Frente a Terraform, la diferencia clave no es "qué puede crear" sino **cuándo**: Terraform converge cuando ejecutas `apply`; Crossplane reconcilia continuamente y no tiene archivo de state aparte (el estado vive en la API de Kubernetes).

Compruébalo en este lab:

```bash
source scripts/env.sh
kremote -n demo delete deploy webapp
kremote -n demo get deploy -w          # reaparece solo (suele tardar 10-40 s)
```

## Conceptos clave

| Término | Definición |
|---|---|
| **Core controller** | El pod `crossplane` en `crossplane-system`. Gestiona paquetes y ejecuta las Compositions. |
| **Provider** | Paquete OCI que instala CRDs + un controlador para una API externa. |
| **ProviderConfig** | Credenciales y destino que usa un Provider. |
| **Managed Resource (MR)** | CRD de un Provider que representa **una** cosa externa. Aquí: `Object`. |
| **Reconciliación** | Bucle *observar → comparar → actuar*, repetido indefinidamente. |
| **`SYNCED` / `READY`** | `SYNCED`: Crossplane pudo aplicar lo deseado. `READY`: el recurso está realmente operativo. Son independientes. |
| **XRD / Composition** | La capa para crear tus propias APIs → [02](02-crossplane-compositions.md). |
| **Function** | Programa que calcula qué recursos componer → [04](04-crossplane-pipelines-functions.md). |

## Cómo se usa en este POC

- **Instalación:** [scripts/crossplane.sh](../../scripts/crossplane.sh), chart Helm con versión fijada en [versions.env](../../versions.env). Solo en `hub`.
- **Provider:** [crossplane/provider-kubernetes.yaml](../../crossplane/provider-kubernetes.yaml).
- **ProviderConfigs:** [remote](../../crossplane/providerconfig-remote.yaml) (kubeconfig) y [hub](../../crossplane/providerconfig-hub.yaml) (identidad del pod).
- **API propia:** [xrd-webapp.yaml](../../crossplane/xrd-webapp.yaml) + [composition-webapp.yaml](../../crossplane/composition-webapp.yaml).
- **Prueba mínima:** [smoke-namespace.yaml](../../crossplane/smoke-namespace.yaml) crea un Namespace en `remote` antes de complicar nada.

### Qué pods verás y para qué sirve cada uno

| Pod (en `crossplane-system`) | Rol |
|---|---|
| `crossplane-…` | Reconciliador de XRDs, Compositions, XRs, Claims y paquetes. |
| `crossplane-rbac-manager-…` | Genera RBAC para los CRDs que instalan los paquetes. |
| `provider-kubernetes-…` | Reconcilia los `Object`. |
| `function-…` (3) | Servidores gRPC que el core invoca en cada reconciliación. |

### Borrado y pausa

- Borrar el claim borra en cascada XR → `Object` → objetos reales (salvo `deletionPolicy: Orphan`).
- Para depurar sin que Crossplane te "corrija", pausa un recurso con la anotación `crossplane.io/paused: "true"`.

## Comandos útiles para inspeccionar / debuggear

```bash
source scripts/env.sh
khub get providers,functions                     # INSTALLED / HEALTHY
khub get managed                                 # todos los managed resources
crossplane resource trace webapp.platform.lab.local/webapp -n demo --context kind-hub
khub describe object <nombre>                    # Events: el error real suele estar aquí
khub -n crossplane-system logs deploy/crossplane --tail=50
```

## Para profundizar

- <https://docs.crossplane.io/latest/whats-crossplane/>
- <https://docs.crossplane.io/latest/packages/providers/>
