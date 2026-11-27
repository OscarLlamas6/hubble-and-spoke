# Task (Taskfile)

## ¿Qué es?

Un ejecutor de tareas en YAML, alternativa moderna a `make`. Cada tarea tiene nombre, descripción y comandos.

## ¿Qué problema resuelve?

Sin él, "cómo levanto esto" vive en tu historial de terminal o en un README que se desactualiza. `make` sirve, pero su sintaxis (tabs, `$$`, targets basados en archivos) estorba cuando solo quieres lanzar scripts.

## Conceptos clave

| Término | Definición |
|---|---|
| **task** | Unidad ejecutable. |
| **`desc`** | Texto que muestra `task --list`. |
| **`cmds`** | Se ejecutan en orden. |
| **`deps`** | Dependencias que corren **en paralelo**. |
| **`{{.VAR}}`** | Variables; `task x VAR=valor`. |
| **`{{.CLI_ARGS}}`** | Lo que va después de `--`. |

## Cómo se usa en este POC

[Taskfile.yml](../../Taskfile.yml) es la interfaz; la lógica vive en `scripts/`. Ventajas de separarlo: puedes ejecutar y depurar cada script sin Task, y el Taskfile queda como índice legible.

`task up` encadena con `- task: …` y no con `deps:` porque el orden es estricto (no puedes instalar Submariner sin clústeres).

El [Makefile](../../Makefile) solo reenvía a `task`.

## Comandos útiles para inspeccionar / debuggear

```bash
task --list
task --summary up
task --dry up                 # qué ejecutaría
task --verbose submariner
bash -x scripts/gateway.sh    # trazar un script concreto
```

## Para profundizar

- <https://taskfile.dev/docs/guide>
