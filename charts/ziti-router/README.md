# Helm Chart ziti-router

## Why?

You may use this chart to provision a Ziti router in Kubernetes. You can configure the router edge, forwarder, public or private.

## How?

This chart deploys a pod running `ziti-router`, [the OpenZiti router](https://docs.openziti.io/docs/reference/deployments/router/deployment). The chart uses container image `docker.io/openziti/ziti-router` and runs command `ziti router`.

## Installation

After adding the charts repo to Helm, then you may install the chart. You must supply a Ziti identity JSON file when you install the chart.

```bash
helm install ziti-router01 openziti/ziti-router --set-file zitiIdentity=/tmp/k8s-router-01.json
```

## Namespaces

The `helm install` command accepts param `--namespace` and so you may install this chart separately for each namespace for purposes such as achieving network isolation of your Ziti-hosted cluster services.

## Developing this Chart

You may install this chart from a local source directory.

```bash
helm install {release name} {source dir} --set-file zitiIdentity=/tmp/k8s-tunneler-03.json
```

If you change the chart's source files and wish to deploy with the same identity you need only bump the chart version in Chart.yaml and run:

```bash
helm upgrade {release} {source dir}
```

## Create new router

Register a new router

```
ziti edge login {controller URL}
ROUTER_NAME=test-router
ziti edge create edge-router $ROUTER_NAME --jwt-output-file $ROUTER_NAME.jwt
```

Now grab the content of `${ROUTER_NAME}.jwt` and add it as `enrollmentJwt` to `values-override.yaml`

Sample `values-override.yaml`:

```yaml
# how to find / connect the ziti controller
controller:
  endpoint: test-controller:6262

# CSR Details
# csr:
  # country: US
  # province: NC
  # locality: Charlotte
  # organization: NetFoundry
  # organizationalUnit: Ziti
  # sans:
  #   dns:
  #     - my.additional.san.example.org
  #   ip:
  #     - "192.168.1.21"

# we usually want the core router to be reachable for router2router transport
transport:
  enabled: true
  host: ziti-core-router

edge:
  enabled: true
  host: ziti-core-router.example.org
  service:
    type: LoadBalancer
    loadBalancerIP: 192.168.1.20
    externalTrafficPolicy: Local

enrollmentJwt: <${ROUTER_NAME}.jwt>
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| controller.endpoint | string | `""` | **Required**: How to reach the controller's router endpoint |
| enrollmentJwt | string | `""` | **Required**: JWT for the router enrolment |
| advertise.host | string | `""` | **conditionally required** Default advertised host name for `edge` and `transport` services for this router when enabled |
| csr.country | string | `""` | Edge CSR: country |
| csr.province | string | `""` | Edge CSR: province |
| csr.organization | string | `""` | Edge CSR: organization |
| csr.organizationalUnit | string | `""` | Edge CSR: organizational unit |
| csr.sans.dns | list | `[]` | Edge CSR: Alternative names: DNS |
| csr.sans.ip | list | `[]` | Edge CSR: Alternative names: DNS |
| edge.enabled | bool | `false` | Does this router act as edge-router? |
| edge.host | string | `"${advertise.host}"` | The host that will be advertised for edge service of this router. Required when `edge.enabled` set to true, but usually you want to set `advertise.host`|
| edge.port | int | `1290` | The port the edge service is offered |
| edge.service.annotations | object | `{}` |  |
| edge.service.enabled | bool | `true` | Create a service object to access the router's edge service |
| edge.service.labels | object | `{}` |  |
| edge.service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| edge.service.externalIPs | list | `[]` | external IP's to bind the service on |
| edge.service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| edge.service.loadBalancerIP | string | `""` | |
| edge.service.publishNotReadyAddresses | string | `""` | |
| edge.service.sessionAffinity | string | `""` | |
| edge.service.sessionAffinityConfig | object | `{}` | |
| transport.enabled | bool | `false` | Does this router expose the transport port? If it is disabled, it act's as a 'private router'. |
| transport.host | string | `"${advertise.host}"` | The host that will be advertised for transport service of this router. Required when `transport.enabled` set to true, but usually you want to set `advertise.host` |
| transport.port | int | `10080` | The port the transport service is offered |
| transport.service.annotations | object | `{}` |  |
| transport.service.enabled | bool | `true` | Create a cluster service object for the router's transport service |
| transport.service.labels | object | `{}` |  |
| transport.service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| transport.service.externalIPs | list | `[]` | external IP's to bind the service on |
| transport.service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| transport.service.loadBalancerIP | string | `""` | |
| transport.service.publishNotReadyAddresses | string | `""` | |
| transport.service.sessionAffinity | string | `""` | |
| transport.service.sessionAffinityConfig | object | `{}` | |
| tunnel.mode | string | `"disabled"` | Tunneling mode: `"disabled"`, `"tproxy"` or `"host"` |
| tunnel.resolver | string | `"udp://192.168.10.11:53"` | DNS for tproxy mode |
| tunnel.lanIf | string | `"eth0"` | interface for tproxy mode |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.pullSecrets | list | `[]` |  |
| image.repository | string | `"openziti/quickstart"` |  |
| image.tag | string | `"0.27.0"` |  |
| replicas | int | `1` | Server replicas |
| affinity | object | `{}` | affinity applied to the deployments |

## TODO's

* replicas - does it make sense? afaik every replica needs it's own identity - how does this fit in?
* lower CA / Cert livetime; refresh certificates on update
