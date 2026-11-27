# kind (Kubernetes IN Docker)

## ¿Qué es?

kind levanta clústeres de Kubernetes donde **cada nodo es un contenedor Docker**. Dentro corre systemd, containerd, kubelet y, en el control plane, los componentes habituales instalados con kubeadm. Es Kubernetes de verdad, no una simulación de la API.

## ¿Qué problema resuelve?

Practicar multi-clúster requiere al menos dos clústeres con red entre ellos. En la nube cuesta dinero y tiempo; con máquinas virtuales, recursos y paciencia. Con kind, dos clústeres nacen en un par de minutos y se destruyen sin dejar rastro.

## Conceptos clave

| Término | Definición |
|---|---|
| **Node image** | Imagen con una versión concreta de Kubernetes (`kindest/node`), fijada por digest. |
| **Red Docker `kind`** | Bridge compartido por todos los clústeres kind: los nodos se ven entre sí. |
| **`podSubnet` / `serviceSubnet`** | CIDRs del clúster. |
| **`extraPortMappings`** | Publica un puerto del contenedor-nodo en tu host. |
| **kindnet** | CNI por defecto. |
| **Kubeconfig interno** | Usa el nombre del contenedor en vez de `127.0.0.1`. |

## Cómo se usa en este POC

[clusters/kind-hub.yaml](../../clusters/kind-hub.yaml), [clusters/kind-remote.yaml](../../clusters/kind-remote.yaml), [scripts/clusters.sh](../../scripts/clusters.sh).

| | hub | remote |
|---|---|---|
| Pod CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| Service CIDR | `10.110.0.0/16` | `10.120.0.0/16` |
| Nodos | 1 | 1 |
| Port mapping | `127.0.0.1:8080 → 30080` | — |

### Por qué los CIDRs no pueden solaparse

Submariner instala rutas del tipo "para llegar a `10.20.0.0/16`, entra al túnel". Si `hub` también usara `10.20.0.0/16`, un paquete hacia `10.20.0.7` sería ambiguo y la ruta local ganaría: nunca saldría del clúster. El default de kind es **el mismo** en todos los clústeres (`10.244.0.0/16`), por eso hay que fijarlos. Cuando no puedes cambiarlos (clústeres ya existentes), Submariner ofrece **Globalnet**, que añade NAT con un rango virtual.

### Por qué un nodo por clúster

Cada nodo consume instancias de `inotify`. Con el default de muchas distribuciones (`fs.inotify.max_user_instances=128`), un segundo nodo puede hacer que el kubelet no arranque. Un nodo por clúster funciona sin tocar el host y no cambia nada conceptual. Con el límite subido puedes añadir workers.

### Limitaciones frente a clústeres reales

| Aspecto | kind | Real |
|---|---|---|
| `Service type: LoadBalancer` | se queda `<pending>` | balanceador del cloud |
| Red entre clústeres | mismo bridge, sin NAT ni firewall | VPN, NAT, rutas, firewalls |
| Fallos de nodo / zona | no representativos | reales |
| Almacenamiento | local-path | CSI de red |
| IPs de nodo | pueden cambiar al reiniciar Docker | estables |

## Comandos útiles para inspeccionar / debuggear

```bash
kind get clusters
docker ps --filter label=io.x-k8s.kind.cluster
docker exec -it hub-control-plane bash          # "SSH" al nodo
docker network inspect kind
kind export logs ./out/logs --name remote       # volcado completo para depurar
```

## Para profundizar

- <https://kind.sigs.k8s.io/docs/user/configuration/>
- <https://kind.sigs.k8s.io/docs/user/known-issues/>
