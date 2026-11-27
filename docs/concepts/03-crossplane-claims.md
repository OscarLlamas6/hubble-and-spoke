# Crossplane Claims

## ¿Qué es?

Un **Claim** es la versión *namespaced* de un recurso compuesto: lo que el consumidor de la plataforma aplica (`WebApp`). Por cada Claim, Crossplane crea un **XR** *cluster-scoped* (`XWebApp`) que es quien realmente posee y gestiona los recursos.

Es la misma idea que `PersistentVolumeClaim` → `PersistentVolume`: pides en tu namespace, otro objeto de ámbito global representa lo concedido.

> **Contexto de versiones (importante).** Los claims pertenecen al modelo v1. En Crossplane 2.x los XR modernos **no admiten claims**; siguen funcionando con un XRD `v1` (modo `LegacyCluster`), cuya API está **deprecada** (verás el aviso al aplicarlo). El detalle de qué está deprecado y la alternativa moderna, implementada en este mismo repo, está en [22 · Crossplane v2](22-crossplane-v2.md).

## ¿Qué problema resuelve?

Los XR clásicos son cluster-scoped, y en Kubernetes no puedes dar RBAC "solo mis objetos" sobre un recurso cluster-scoped. Sin Claim, permitir que un equipo cree apps implicaría darle permisos sobre **todos** los XR del clúster. El Claim permite `Role` + `RoleBinding` por namespace y deja el XR como detalle interno del equipo de plataforma.

## Conceptos clave

| Término | Definición |
|---|---|
| **Claim** (`WebApp`) | Namespaced. Lo escribe el consumidor. |
| **XR** (`XWebApp`) | Cluster-scoped. Lo administra Crossplane. |
| **`claimNames`** | Bloque del XRD que habilita el Claim. |
| **`spec.resourceRef`** (en el claim) | Apunta al XR creado. |
| **`spec.claimRef`** (en el XR) | Apunta de vuelta al claim. |
| **Labels `crossplane.io/claim-name` / `claim-namespace`** | Identidad del claim copiada al XR; la Composition las lee. |
| **`compositeDeletePolicy`** | `Background` (default) o `Foreground` al borrar. |

## Cómo se usa en este POC

[webapp-claim.yaml](../../crossplane/examples/webapp-claim.yaml) → `XWebApp`:

```yaml
# Lo que tú aplicas                    # Lo que Crossplane crea
kind: WebApp                           kind: XWebApp
metadata:                              metadata:
  name: webapp                           name: webapp-p5xst        # sufijo aleatorio
  namespace: demo                        labels:
spec:                                      crossplane.io/claim-name: webapp
  image: traefik/whoami:v1.11.0            crossplane.io/claim-namespace: demo
  hostname: webapp.local               spec:
                                         claimRef: {name: webapp, namespace: demo}
                                         resourceRefs: [ ...5 Object... ]
```

La Composition **depende** de esas labels: de ahí salen el nombre y el namespace de todo lo que crea. Están marcadas `fromFieldPath: Required`, así que un `XWebApp` creado a mano (sin claim) no genera recursos con nombres basura.

El `status` hace el viaje inverso: el paso 2 del pipeline escribe `status.hostname` en el XR y Crossplane lo copia al claim; por eso `kubectl get webapp` muestra la columna `HOSTNAME`.

### La alternativa sin claims

El lab despliega también `WebAppV2`, donde el usuario aplica el XR namespaced directamente. Comparación lado a lado: [22 · Crossplane v2](22-crossplane-v2.md).

## Comandos útiles para inspeccionar / debuggear

```bash
khub -n demo get webapp                                  # el claim
khub get xwebapp                                         # el XR
khub -n demo get webapp webapp -o jsonpath='{.spec.resourceRef.name}{"\n"}'
khub -n demo describe webapp webapp                      # eventos del claim
khub auth can-i create webapps.platform.lab.local -n demo --as=system:serviceaccount:demo:default
```

## Para profundizar

- <https://docs.crossplane.io/v1.20/concepts/claims/>
- <https://docs.crossplane.io/latest/whats-new/>
