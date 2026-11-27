# Crossplane Claims

## ¿Qué es?

Un **Claim** es la versión *namespaced* de un recurso compuesto: lo que el consumidor de la plataforma aplica (`WebApp`). Por cada Claim, Crossplane crea un **XR** *cluster-scoped* (`XWebApp`) que es quien realmente posee y gestiona los recursos.

Es la misma idea que `PersistentVolumeClaim` → `PersistentVolume`: pides en tu namespace, otro objeto de ámbito global representa lo concedido.

> **Contexto de versiones (importante).** Los Claims son el modelo de Crossplane v1. En Crossplane 2.x los XR nuevos (XRD `apiextensions.crossplane.io/v2`) pueden ser namespaced y **no admiten claims**. Los claims siguen funcionando usando un XRD `v1`, cuyos XR quedan en modo `LegacyCluster`. Este lab usa Crossplane 2.4 con XRD v1 a propósito, para estudiar claims; al aplicarlo verás un aviso de deprecación.

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

### Cómo sería en el modelo v2 (sin claims)

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
spec:
  scope: Namespaced          # el XR mismo vive en el namespace
  names: { kind: WebApp, plural: webapps }   # sin claimNames
```

El usuario aplica `WebApp` y ese objeto **es** el XR. La Composition leería `metadata.name` / `metadata.namespace` en lugar de las labels del claim y usaría los managed resources namespaced (`kubernetes.m.crossplane.io`). Es un buen ejercicio de repaso: migra este XRD.

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
