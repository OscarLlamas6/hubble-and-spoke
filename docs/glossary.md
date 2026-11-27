# Glosario técnico

Definiciones cortas de los términos del proyecto. Cada una enlaza al documento donde se explica a fondo.

## Los que más se confunden

| Par | Diferencia |
|---|---|
| **XRD** vs **XR** | el XRD define el tipo; el XR es una instancia |
| **Claim** vs **XR** | el claim es lo que pide el usuario (v1, con namespace); el XR es lo que gestiona Crossplane |
| **Provider** vs **ProviderConfig** | el *cómo* hablar con una API; el *dónde y con qué credenciales* |
| **Gateway** (Gateway API) vs **gateway node** (Submariner) | entrada de tráfico HTTP; extremo del túnel entre clústeres |
| **Envoy** vs **Envoy Gateway** | el proxy que mueve el tráfico; el controlador que lo configura |
| **Cluster** (Envoy) vs clúster (Kubernetes) | grupo de destinos; conjunto de nodos |
| **Submariner** vs **Lighthouse** | llegar al otro clúster; saber qué hay allí |

## A

| Término | Definición | Más |
|---|---|---|
| **ADS (Aggregated Discovery Service)** | Variante de xDS que envía todos los tipos de configuración por una sola conexión y en orden seguro. Es la que usa este lab. | [09](concepts/09-envoy-xds.md) |
| **API server** | El componente de Kubernetes que recibe y guarda todos los objetos. Todo lo demás habla con él. | [06](concepts/06-kind.md) |
| **Aserción (assertion)** | En un test, una expectativa que se comprueba: "deben salir 5 recursos". | [23](concepts/23-xprin.md) |
| **auto-ready (function)** | Función que marca el XR como `Ready` cuando lo están todos sus recursos. | [17](concepts/17-function-auto-ready.md) |

## B

| Término | Definición | Más |
|---|---|---|
| **Backend / backendRef** | El destino al que una ruta envía las peticiones. Aquí, un `ServiceImport`. | [07](concepts/07-gateway-api.md) |
| **Bootstrap (Envoy)** | Configuración estática mínima con la que Envoy arranca para encontrar a su control plane. | [09](concepts/09-envoy-xds.md) |
| **Broker** | Almacén compartido (CRDs en `hub`) donde los clústeres de Submariner publican quiénes son. No transporta tráfico. | [10](concepts/10-submariner.md) |

## C

| Término | Definición | Más |
|---|---|---|
| **Cable driver** | Tecnología con la que Submariner construye el túnel: `libreswan` (IPsec), `wireguard` o `vxlan`. | [18](concepts/18-ipsec-libreswan.md) |
| **CDS (Cluster Discovery Service)** | Parte de xDS que entrega los *clusters* de Envoy (destinos lógicos). | [09](concepts/09-envoy-xds.md) |
| **CEL** | Common Expression Language: expresiones cortas que Kubernetes y provider-kubernetes evalúan. Aquí deciden cuándo algo está listo. | [05](concepts/05-provider-kubernetes.md) |
| **Chart** | Paquete de Helm. | [11](concepts/11-helm.md) |
| **CIDR** | Rango de direcciones IP, como `10.20.0.0/16`. Los de cada clúster no deben solaparse. | [06](concepts/06-kind.md) |
| **Claim** | Objeto con namespace que el usuario aplica para pedir un recurso compuesto (modelo v1). Aquí, `WebApp`. | [03](concepts/03-crossplane-claims.md) |
| **Cluster (de Envoy)** | Grupo de destinos equivalentes dentro de Envoy. No es un clúster de Kubernetes. | [09](concepts/09-envoy-xds.md) |
| **ClusterIP** | IP virtual y estable de un Service, válida dentro del clúster. | [20](concepts/20-multicluster-services-api.md) |
| **ClusterProviderConfig** | Configuración de un provider compartida por todos los namespaces (modelo v2). | [22](concepts/22-crossplane-v2.md) |
| **ClusterSet** | Conjunto de clústeres que comparten servicios entre sí. | [20](concepts/20-multicluster-services-api.md) |
| **`clusterset.local`** | Dominio DNS de los servicios visibles en todo el clusterset. | [25](concepts/25-lighthouse.md) |
| **Composed resource** | Cada recurso que genera una Composition a partir de un XR. | [02](concepts/02-crossplane-compositions.md) |
| **Composition** | La "receta": qué recursos se crean a partir de un XR. | [02](concepts/02-crossplane-compositions.md) |
| **Composition Function** | Programa que calcula los recursos de una Composition. | [04](concepts/04-crossplane-pipelines-functions.md) |
| **CompositionRevision** | Copia inmutable de una versión de una Composition. | [02](concepts/02-crossplane-compositions.md) |
| **Control plane** | La parte que decide y configura. Ejemplo: Envoy Gateway. | [08](concepts/08-envoy-gateway.md) |
| **CoreDNS** | El servidor DNS de Kubernetes. | [19](concepts/19-coredns.md) |
| **CRD (Custom Resource Definition)** | La forma de añadir tipos de objeto nuevos a Kubernetes. | [02](concepts/02-crossplane-compositions.md) |
| **Crossplane** | Convierte Kubernetes en un plano de control capaz de crear y mantener cualquier recurso. | [01](concepts/01-crossplane.md) |

## D

| Término | Definición | Más |
|---|---|---|
| **Data plane** | La parte por la que pasa el tráfico real. Ejemplo: el proxy Envoy. | [08](concepts/08-envoy-gateway.md) |
| **Desired state / Observed state** | Lo que se quiere que exista / lo que existe ahora. | [04](concepts/04-crossplane-pipelines-functions.md) |
| **Drift** | Diferencia entre lo deseado y lo real, por ejemplo tras un cambio a mano. | [01](concepts/01-crossplane.md) |

## E

| Término | Definición | Más |
|---|---|---|
| **E2E (end to end)** | Prueba que recorre el sistema completo. | [23](concepts/23-xprin.md) |
| **EDS (Endpoint Discovery Service)** | Parte de xDS que entrega las IP y puertos de cada cluster. | [09](concepts/09-envoy-xds.md) |
| **EndpointSlice** | Objeto de Kubernetes con las IP que hay detrás de un servicio y su estado. | [20](concepts/20-multicluster-services-api.md) |
| **Envoy** | Proxy L4/L7; aquí recibe las peticiones y las reenvía. | [08](concepts/08-envoy-gateway.md) |
| **Envoy Gateway** | Control plane que implementa Gateway API usando Envoy. | [08](concepts/08-envoy-gateway.md) |
| **EnvoyProxy (CRD)** | Personaliza cómo Envoy Gateway despliega el proxy. | [08](concepts/08-envoy-gateway.md) |
| **ESP** | Protocolo de IPsec que lleva los datos cifrados. | [18](concepts/18-ipsec-libreswan.md) |

## G

| Término | Definición | Más |
|---|---|---|
| **Gateway** | Punto de entrada: qué puertos y protocolos se escuchan. | [07](concepts/07-gateway-api.md) |
| **Gateway API** | API estándar de Kubernetes para exponer y enrutar tráfico; sucesora de Ingress. | [07](concepts/07-gateway-api.md) |
| **Gateway Engine / gateway node** | El pod de Submariner, y el nodo donde corre, que termina el túnel. No confundir con el `Gateway` de Gateway API. | [10](concepts/10-submariner.md) |
| **GatewayClass** | Indica qué implementación atiende los Gateways. | [07](concepts/07-gateway-api.md) |
| **Globalnet** | Función de Submariner para conectar clústeres con CIDRs solapados. No se usa aquí. | [10](concepts/10-submariner.md) |
| **go-templating (function)** | Función que genera recursos con plantillas de Go. | [16](concepts/16-function-go-templating.md) |
| **Golden file** | Salida de referencia contra la que se compara un test. | [23](concepts/23-xprin.md) |

## H

| Término | Definición | Más |
|---|---|---|
| **Helm** | Gestor de paquetes de Kubernetes. | [11](concepts/11-helm.md) |
| **HTTPRoute** | Reglas HTTP: qué hostname y path van a qué backend. | [07](concepts/07-gateway-api.md) |
| **Hub and spoke** | Topología con un centro (`hub`) y periferias (*spokes*; aquí, `remote`). Da nombre al repo. | [06](concepts/06-kind.md) |

## I

| Término | Definición | Más |
|---|---|---|
| **Idempotente** | Que puede ejecutarse varias veces con el mismo resultado. | [12](concepts/12-taskfile.md) |
| **IPsec / libreswan** | Cifrado a nivel de red / su implementación en Linux. | [18](concepts/18-ipsec-libreswan.md) |

## K

| Término | Definición | Más |
|---|---|---|
| **kind** | Clústeres de Kubernetes cuyos nodos son contenedores Docker. | [06](concepts/06-kind.md) |
| **kubeconfig** | Archivo con la dirección y credenciales para hablar con un clúster. | [05](concepts/05-provider-kubernetes.md) |

## L

| Término | Definición | Más |
|---|---|---|
| **LDS (Listener Discovery Service)** | Parte de xDS que entrega los listeners. | [09](concepts/09-envoy-xds.md) |
| **Lighthouse** | Componente de Submariner para descubrir servicios entre clústeres. | [25](concepts/25-lighthouse.md) |
| **Listener** | Puerto en el que un Gateway o Envoy escucha. | [07](concepts/07-gateway-api.md) |

## M

| Término | Definición | Más |
|---|---|---|
| **Managed Resource (MR)** | Recurso de un provider que representa una cosa concreta. Aquí, `Object`. | [01](concepts/01-crossplane.md) |
| **managementPolicies / deletionPolicy** | Qué puede hacer Crossplane con un recurso / qué hace al borrarlo. | [22](concepts/22-crossplane-v2.md) |
| **MCS API (Multi-Cluster Services)** | Estándar de `ServiceExport` y `ServiceImport`. | [20](concepts/20-multicluster-services-api.md) |

## N

| Término | Definición | Más |
|---|---|---|
| **Namespace** | Partición lógica de un clúster. | [20](concepts/20-multicluster-services-api.md) |
| **NodePort** | Service que abre un puerto en cada nodo. Es por donde entra el tráfico al lab. | [08](concepts/08-envoy-gateway.md) |

## O

| Término | Definición | Más |
|---|---|---|
| **`Object`** | Recurso de provider-kubernetes que envuelve cualquier manifiesto. | [05](concepts/05-provider-kubernetes.md) |

## P

| Término | Definición | Más |
|---|---|---|
| **patch-and-transform (function)** | Función que genera recursos desde plantillas copiando y transformando campos. | [15](concepts/15-function-patch-and-transform.md) |
| **Pipeline** | Modo de Composition que encadena funciones. | [04](concepts/04-crossplane-pipelines-functions.md) |
| **Provider** | Paquete que enseña a Crossplane a manejar una API. | [01](concepts/01-crossplane.md) |
| **ProviderConfig** | Credenciales y destino que usa un provider. | [05](concepts/05-provider-kubernetes.md) |
| **PSK (pre-shared key)** | Clave compartida con la que se autentica el túnel. | [18](concepts/18-ipsec-libreswan.md) |

## R

| Término | Definición | Más |
|---|---|---|
| **RBAC** | Control de permisos de Kubernetes. | [22](concepts/22-crossplane-v2.md) |
| **RDS (Route Discovery Service)** | Parte de xDS que entrega las rutas. | [09](concepts/09-envoy-xds.md) |
| **Reconciliación** | Bucle continuo: observar, comparar y corregir. | [01](concepts/01-crossplane.md) |
| **render** | Ejecutar una Composition en local para ver qué produciría. | [14](concepts/14-crossplane-cli.md) |
| **Route Agent** | Componente de Submariner que pone las rutas en cada nodo. | [10](concepts/10-submariner.md) |

## S

| Término | Definición | Más |
|---|---|---|
| **SDS (Secret Discovery Service)** | Parte de xDS que entrega certificados. | [09](concepts/09-envoy-xds.md) |
| **Service** | Nombre e IP estables para un conjunto de pods. | [20](concepts/20-multicluster-services-api.md) |
| **ServiceExport** | "Publica este Service en el clusterset". Lo creas tú. | [20](concepts/20-multicluster-services-api.md) |
| **ServiceImport** | Representación de un Service de otro clúster. Lo crea Lighthouse. | [20](concepts/20-multicluster-services-api.md) |
| **Smoke test** | Prueba rápida de que lo esencial funciona. | [12](concepts/12-taskfile.md) |
| **subctl** | CLI de Submariner. | [13](concepts/13-subctl.md) |
| **Submariner** | Conecta las redes de pods y services de varios clústeres. | [10](concepts/10-submariner.md) |

## T

| Término | Definición | Más |
|---|---|---|
| **Task / Taskfile** | Ejecutor de tareas y su archivo. | [12](concepts/12-taskfile.md) |

## U

| Término | Definición | Más |
|---|---|---|
| **Upstream / Downstream** | Para un proxy: hacia el backend / desde el cliente. | [08](concepts/08-envoy-gateway.md) |

## X

| Término | Definición | Más |
|---|---|---|
| **xDS** | Familia de APIs con las que Envoy recibe su configuración en caliente. | [09](concepts/09-envoy-xds.md) |
| **XFRM** | Marco del kernel Linux que aplica IPsec. | [18](concepts/18-ipsec-libreswan.md) |
| **xprin** | Framework de tests para Compositions. | [23](concepts/23-xprin.md) |
| **XR (Composite Resource)** | El recurso compuesto: la instancia de tu API que Crossplane gestiona. Aquí, `XWebApp` (v1) o `WebAppV2` (v2). | [02](concepts/02-crossplane-compositions.md) |
| **XRD (Composite Resource Definition)** | Define tu API propia: nombre y campos. A veces se escribe mal como "XDR". | [02](concepts/02-crossplane-compositions.md) |

## Y

| Término | Definición | Más |
|---|---|---|
| **yq** | Procesador de YAML en línea de comandos. | [24](concepts/24-yq.md) |
