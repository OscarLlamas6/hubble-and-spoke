# Helm

## ¿Qué es?

El gestor de paquetes de Kubernetes: un *chart* es un conjunto de plantillas más valores por defecto; instalarlo crea una *release* versionada que se puede actualizar o revertir.

## ¿Qué problema resuelve?

Crossplane o Envoy Gateway son decenas de objetos (CRDs, RBAC, Deployments). Sin Helm aplicarías YAML enormes sin una forma limpia de parametrizar, actualizar o desinstalar.

## Conceptos clave

| Término | Definición |
|---|---|
| **Chart** | Paquete con plantillas. |
| **Release** | Instalación con nombre de un chart en un namespace. |
| **Repositorio / OCI** | Dónde se publican los charts. |
| **Values** | Parámetros. |
| **`upgrade --install`** | Instala o actualiza: hace el script idempotente. |
| **`--wait`** | No termina hasta que los recursos estén listos. |

## Cómo se usa en este POC

Solo para instalar plataforma, nunca para las apps (eso lo hace Crossplane).

| Release | Chart | Script |
|---|---|---|
| `crossplane` | `https://charts.crossplane.io/stable/crossplane-<ver>.tgz` | [scripts/crossplane.sh](../../scripts/crossplane.sh) |
| `eg` | `oci://docker.io/envoyproxy/gateway-helm` | [scripts/gateway.sh](../../scripts/gateway.sh) |

Detalle aprendido: `helm install crossplane crossplane --repo …` falla en este repo porque Helm interpreta `crossplane` como la carpeta local `./crossplane`. Por eso se usa la URL completa del chart.

## Comandos útiles para inspeccionar / debuggear

```bash
./scripts/run.sh helm --kube-context kind-hub ls -A
./scripts/run.sh helm --kube-context kind-hub -n crossplane-system get values crossplane
./scripts/run.sh helm --kube-context kind-hub -n envoy-gateway-system get manifest eg | less
./scripts/run.sh helm --kube-context kind-hub -n crossplane-system history crossplane
```

## Para profundizar

- <https://helm.sh/docs/intro/using_helm/>
