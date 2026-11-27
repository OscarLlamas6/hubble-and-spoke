# CoreDNS

## ¿Qué es?

El servidor DNS del clúster. Se configura con un `Corefile` compuesto de zonas y *plugins*.

## ¿Qué problema resuelve?

Sin DNS interno los servicios se llamarían por IP. En multi-clúster, además, hace falta un nombre que signifique "este servicio, esté donde esté".

## Conceptos clave

| Término | Definición |
|---|---|
| **Corefile** | Configuración, en el ConfigMap `kube-system/coredns`. |
| **Zona** | Sufijo que un bloque atiende. |
| **Plugin `kubernetes`** | Responde `cluster.local`. |
| **Plugin `forward`** | Delega a otro servidor. |
| **`ndots:5`** | El resolver prueba sufijos de búsqueda antes del nombre completo. |
| **Plugin `reload`** | Recarga el Corefile en caliente. |

## Cómo se usa en este POC

Submariner añade una zona `clusterset.local` que reenvía al CoreDNS de Lighthouse:

```
#lighthouse-start AUTO-GENERATED SECTION. DO NOT EDIT
clusterset.local:53 {
    forward . 10.110.225.187
}
#lighthouse-end
```

| Nombre | Responde | Devuelve |
|---|---|---|
| `webapp.demo.svc.cluster.local` | CoreDNS | Service local |
| `webapp.demo.svc.clusterset.local` | Lighthouse | ClusterIP del clúster que exporta |

Tras el cambio, CoreDNS tarda en recargar (el ConfigMap se propaga con retraso): una primera resolución puede fallar. [scripts/submariner-verify.sh](../../scripts/submariner-verify.sh) exige 5 éxitos seguidos por eso.

## Comandos útiles para inspeccionar / debuggear

```bash
khub -n kube-system get cm coredns -o yaml
khub -n kube-system logs -l k8s-app=kube-dns --tail=20
khub run dns --rm -it --image=busybox:1.37 --restart=Never -- nslookup webapp.demo.svc.clusterset.local
khub -n submariner-operator logs deploy/submariner-lighthouse-coredns --tail=20
```

## Para profundizar

- <https://coredns.io/manual/toc/>
