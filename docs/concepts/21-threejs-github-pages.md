# Three.js y GitHub Pages (recorrido 3D)

## ¿Qué es?

**Three.js** es una librería de JavaScript para dibujar 3D en el navegador con WebGL. **GitHub Pages** publica archivos estáticos de un repositorio como sitio web.

## ¿Qué problema resuelve?

Un diagrama plano cuesta de leer cuando hay dos clústeres, un plano de control y un plano de datos a la vez. El recorrido anima el orden de los eventos. Pages evita tener un servidor.

## Conceptos clave

| Término | Definición |
|---|---|
| **Scene / Camera / Renderer** | Los tres objetos básicos de Three.js. |
| **Mesh** | Geometría + material. |
| **OrbitControls** | Rotar y hacer zoom. |
| **CSS2DRenderer** | Etiquetas HTML posicionadas en el espacio 3D. |
| **Import map** | Permite `import 'three'` desde un CDN sin bundler. |
| **Workflow de Pages** | GitHub Actions que sube una carpeta como sitio. |

## Cómo se usa en este POC

- Código en [tour/](../../tour/): `index.html`, `style.css`, `scene.js` (objetos 3D) y `steps.js` (el guion; **edita aquí** para cambiar textos).
- Sin paso de build. Three.js se carga desde jsDelivr con versión fija.
- Publicación: [.github/workflows/pages.yml](../../.github/workflows/pages.yml) sube **solo** `tour/`. Requiere activar una vez *Settings → Pages → Source: GitHub Actions*.

El workflow es solo publicación del sitio; el lab no tiene CI/CD (fuera de alcance).

## Comandos útiles para inspeccionar / debuggear

```bash
task tour                          # servidor local en http://localhost:8000
gh workflow view pages.yml
gh run list --workflow=pages.yml
```

Abre el sitio con un servidor: con `file://` los módulos ES no cargan.

## Para profundizar

- <https://threejs.org/docs/>
- <https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages>
