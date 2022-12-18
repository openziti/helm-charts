# Helm Chart ziti-router

## Why?

You may use this chart to publish a Ziti router within kubernetes. Depending on your use case the router can be deployed as edge, forwarder, public or private router.

## How?

This chart deploys a pod running `ziti-router`, [the OpenZiti router](https://openziti.github.io/operations/router/deployment/). The chart uses container image `docker.io/openziti/quickstart` and starts the `ziti-router` within it.

## Installation

After adding the charts repo to Helm then you may install the chart. You must supply a Ziti identity JSON file when you install the chart.

```bash
helm install ziti-router01 openziti/ziti-router --set-file zitiIdentity=/tmp/k8s-router-01.json
```

## Namespaces

The `helm install` command accepts param `--namespace` and so you may install this chart separately for each namespace for purposes such as achieving network isolation of your Ziti-hosted cluster services.


## Developing this Chart

If you have downloaded this source code, then you may install the chart from a local source directory.

```bash
helm install {release} {source dir} --set-file zitiIdentity=/tmp/k8s-tunneler-03.json
```

If you change the chart's source files and wish to deploy with the same identity you need only bump the chart version in Chart.yaml and run:

```bash
helm upgrade {release} {source dir}
```

## Create new router

Register a new router on controller (open a shell in the pod)

```
zitiLogin
ROUTER_NAME=test-router
ziti edge create edge-router $ROUTER_NAME --jwt-output-file $ROUTER_NAME.jwt
```

Now grab the content of `${ROUTER_NAME}.jwt` and add it as `enrolmentJwt` to `values-override.yaml`


A sample `values-override.yaml`
```
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

enrolmentJwt: <${ROUTER_NAME}.jwt>
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| controller.endpoint | string | `""` | **Required**: How to reach the controller's router endpoint |
| enrolmentJwt | string | `""` | **Required**: JWT for the router enrolment |
| csr.country | string | `""` | Edge CSR: country |
| csr.province | string | `""` | Edge CSR: province |
| csr.organization | string | `""` | Edge CSR: organization |
| csr.organizationalUnit | string | `""` | Edge CSR: organizational unit |
| csr.sans.dns | list | `[]` | Edge CSR: Alternative names: DNS |
| csr.sans.ip | list | `[]` | Edge CSR: Alternative names: DNS |
| edge.enabled | bool | `false` | Does this router act as edge-router? |
| edge.host | string | `""` | Required: The host/ip that will be advertised for this router. |
| edge.port | int | `1290` | The port the edge service is offered |
| edge.service.annotations | object | `{}` |  |
| edge.service.enabled | bool | `true` | Service that is created to access the router's edge service |
| edge.service.labels | object | `{}` |  |
| edge.service.name | string | `"edge"` |  |
| edge.service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| edge.service.externalIPs | list | `[]` | external IP's to bind the service on |
| edge.service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| edge.service.loadBalancerIP | string | `""` | |
| edge.service.publishNotReadyAddresses | string | `""` | |
| edge.service.sessionAffinity | string | `""` | |
| edge.service.sessionAffinityConfig | object | `{}` | |
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
