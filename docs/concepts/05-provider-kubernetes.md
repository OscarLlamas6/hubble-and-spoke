# provider-kubernetes

## ¿Qué es?

El Provider que permite a Crossplane gestionar **cualquier objeto de Kubernetes**, en el clúster local o en otro. Su recurso principal, `Object`, es un sobre: dentro va un manifiesto normal (`spec.forProvider.manifest`) y fuera, las instrucciones (a qué clúster, cuándo considerarlo listo, qué hacer al borrar).

## ¿Qué problema resuelve?

Una Composition legacy (`LegacyCluster`) crea recursos desde el clúster donde corre Crossplane. Nada en Kubernetes permite que un objeto de `hub` produzca otro en `remote`: hace falta un controlador que tenga credenciales de `remote` y mantenga el objeto allí. Sin él acabarías con `kubectl --context remote apply` en un script, sin reconciliación ni borrado en cascada.

## Conceptos clave

| Término | Definición |
|---|---|
| **`Object`** | Managed Resource que envuelve un manifiesto. |
| **`ProviderConfig`** | Destino y credenciales. Cada `Object` elige uno en `providerConfigRef`. |
| **`source: Secret`** | Credenciales = kubeconfig guardado en un Secret. |
| **`source: InjectedIdentity`** | Usa el ServiceAccount del pod del provider. |
| **`status.atProvider.manifest`** | Copia del objeto real tal como está en el destino. |
| **`readiness.policy`** | `SuccessfulCreate`, `DeriveFromObject`, `AllTrue`, `DeriveFromCelQuery`. |
| **`deletionPolicy`** | `Delete` u `Orphan`. |
| **Poll interval** | Cada cuánto vuelve a observar el objeto real. |

## Cómo se usa en este POC

```
            hub                                             remote
 Object ─► pod provider-kubernetes ──── ProviderConfig "remote" ───► API server :6443
                    │                      (Secret kubeconfig)        Namespace, Deployment,
                    │                                                 Service, ServiceExport
                    └─── ProviderConfig "hub" (InjectedIdentity) ───► HTTPRoute (en hub)
```

### El kubeconfig remoto, paso a paso

```bash
kind get kubeconfig --name remote --internal |
  kubectl --context kind-hub -n crossplane-system create secret generic remote-kubeconfig \
    --from-file=kubeconfig=/dev/stdin
```

`--internal` es la clave: el kubeconfig normal apunta a `127.0.0.1:<puerto>`, válido solo en tu host. El interno usa `https://remote-control-plane:6443`, resoluble desde los pods porque ambos clústeres comparten la red Docker `kind`.

Ten presente que **este tráfico de API no pasa por Submariner**: va directo por la red Docker. Submariner solo transporta tráfico entre pods y services.

### Configuración no obvia en [provider-kubernetes.yaml](../../crossplane/provider-kubernetes.yaml)

| Qué | Por qué |
|---|---|
| ServiceAccount con nombre fijo | El default lleva un hash; no se le podría atar RBAC de forma estable. |
| `--poll=20s` | El default es 10 minutos: el drift y el `Ready` parecerían congelados. |
| `ClusterRole` solo de `httproutes` | Es lo único que se crea en `hub`. |

### Seguridad (laboratorio vs. real)

El kubeconfig es `cluster-admin` de `remote` y no rota. En producción: ServiceAccount con RBAC mínimo, tokens de corta duración o identidad federada, y el Secret gestionado por un gestor de secretos.

## Comandos útiles para inspeccionar / debuggear

```bash
khub get object                                   # KIND, PROVIDERCONFIG, SYNCED, READY
khub get object <n> -o jsonpath='{.status.atProvider.manifest}' | jq .
khub describe object <n>                          # "cannot get object", RBAC, etc.
khub -n crossplane-system logs -l pkg.crossplane.io/provider=provider-kubernetes --tail=50
khub get providerconfigusage                      # quién usa cada ProviderConfig
```

El provider instala dos variantes y el lab usa **ambas**:

| | API v1 (claims) | API v2 |
|---|---|---|
| `Object` | `kubernetes.crossplane.io` (cluster) | `kubernetes.m.crossplane.io` (namespaced) |
| Configuración | `ProviderConfig` | `ClusterProviderConfig` |
| `providerConfigRef` | `{name}` | `{kind, name}` |

Con las dos instaladas, `kubectl get object` muestra solo las cluster-scoped; para las modernas usa `objects.kubernetes.m.crossplane.io`. Ver [22](22-crossplane-v2.md).

## Para profundizar

- <https://github.com/crossplane-contrib/provider-kubernetes>
