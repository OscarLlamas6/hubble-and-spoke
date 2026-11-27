# Crossplane CLI

## ¿Qué es?

El binario `crossplane`: herramienta de cliente para renderizar Compositions en local, trazar recursos y trabajar con paquetes. No confundir con el controlador que corre en el clúster.

## ¿Qué problema resuelve?

Depurar una Composition aplicándola y mirando eventos es lento. `render` ejecuta el pipeline en tu máquina en segundos; `trace` evita encadenar diez `kubectl get`.

## Conceptos clave

| Comando | Qué hace |
|---|---|
| `composition render` | Ejecuta el pipeline con Docker y muestra el resultado. |
| `resource trace` | Árbol Claim → XR → recursos con `SYNCED`/`READY`. |
| `--include-function-results` | Muestra los mensajes de las funciones. |
| `--observed-resources` | Simula recursos ya existentes. |
| `xpkg` | Construir y publicar paquetes. |

## Cómo se usa en este POC

- `task crossplane:render` (v1) y `task crossplane:render:v2` → [scripts/render.sh](../../scripts/render.sh).
- Se pasa `--xrd` para aplicar defaults e indicar el scope; sin él un XR v1 se renderiza como si fuera v2.
- Para pruebas automatizadas sobre `render` y `resource validate`: [xprin](23-xprin.md).
- Desde la 2.3 la CLI vive en su propio repositorio (`crossplane/cli`) y tiene versión independiente de la del controlador, por eso [versions.env](../../versions.env) las fija por separado.
- Algunos comandos están marcados como beta y pueden cambiar entre versiones.

Ejercicio: simula que el Deployment ya está listo creando un archivo de recursos observados con la anotación `crossplane.io/composition-resource-name: deployment` y una condición `Ready=True`, y pásalo con `task crossplane:render -- --observed-resources=<archivo>`.

## Comandos útiles para inspeccionar / debuggear

```bash
task crossplane:render
./scripts/run.sh crossplane resource trace webapp.platform.lab.local/webapp -n demo --context kind-hub
./scripts/run.sh crossplane version
```

## Para profundizar

- <https://docs.crossplane.io/latest/cli/>
