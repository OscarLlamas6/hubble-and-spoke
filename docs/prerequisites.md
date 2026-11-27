# Prerrequisitos y versiones

## Qué debes tener instalado

| Requisito | Notas |
|---|---|
| Linux (x86_64 o arm64) | probado en x86_64, kernel 6.8; macOS/WSL no están probados |
| Docker | probado con 29.x; tu usuario en el grupo `docker` |
| `task` ≥ 3 | <https://taskfile.dev/installation/> |
| `bash`, `curl`, `tar`, `xz`, `sha256sum`, `jq` | `jq` lo usan `example.sh` y `xds.sh` |
| RAM | ≥ 8 GB libres recomendados |
| Internet | imágenes, charts y CLIs |
| Puerto 8080 libre | entrada del Gateway |

El resto (`kind`, `kubectl`, `helm`, `subctl`, `crossplane`, `xprin`, `yq`) se descarga en `./.bin` con `task tools`, sin `sudo` y sin tocar lo que tengas instalado.

## Aislamiento de tu entorno

Los scripts usan `KUBECONFIG=<repo>/.kube/config`. **Tu `~/.kube/config` no se lee ni se modifica**, así que ningún comando del lab puede tocar otros clústeres. Para usar `kubectl` a mano: `source scripts/env.sh`.

## Versiones usadas

Definidas en [versions.env](../versions.env) y en los manifiestos de paquetes.

| Componente | Versión | Dónde se fija |
|---|---|---|
| kind | v0.33.0 | versions.env |
| Kubernetes (nodos) | v1.35.8 (por digest) | versions.env |
| kubectl | v1.35.8 | versions.env |
| Helm | v3.22.1 | versions.env |
| Submariner / subctl | 0.24.3 | versions.env |
| Crossplane | 2.4.4 | versions.env |
| Crossplane CLI | v2.4.1 | versions.env |
| Envoy Gateway | v1.9.4 (Envoy 1.39) | versions.env |
| xprin / xprin-helpers | v0.7.0 | versions.env |
| yq | v4.54.3 | versions.env |
| CRDs de Gateway API (tests) | v1.6.1 | versions.env |
| provider-kubernetes | v1.4.1 | crossplane/provider-kubernetes.yaml |
| function-patch-and-transform | v0.11.2 | crossplane/functions.yaml |
| function-go-templating | v0.13.2 | crossplane/functions.yaml |
| function-auto-ready | v0.7.3 | crossplane/functions.yaml |
| whoami | v1.11.0 | ejemplos |

Compatibilidad que condiciona la elección: Envoy Gateway 1.9 está probado con Kubernetes 1.33–1.36 ([matriz](https://gateway.envoyproxy.io/news/releases/matrix/)).

Para actualizar: cambia la versión, `task down && task up && task test`.
