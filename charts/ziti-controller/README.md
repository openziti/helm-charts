# Helm Chart ziti-controller

## Overview

With this chart you can deploy a `ziti controller` into your kubernetes cluster.
It rely's on https://cert-manager.io/ for certificate deployment and requies [cert-manager already being installed on your cluster](https://cert-manager.io/docs/installation/)

You might want to start with the [Quickstart Scenario](../../README.md#quickstart-scenario)

## Installation

This shows a minimal installation. The `controller.host` and `service.loadBalancerIP` settings must be adapted to your needs.

```bash
helm install -n ziti-namespace ziti-ctrl-release1 openziti/ziti-controller \
    --set advertisedHost="ziti-controller.example.org" \
    --set service.type="LoadBalancer" \
    --set service.loadBalancerIP="192.168.1.1"
```

During the installation a default admin user and password will be generated and saved to a secret. The credentials can be retrieved using this command:

```bash
kubectl get secret -n ziti-namespace ziti-ctrl-release1-admin-secret -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```

This Helm chart offers two operational scenarios. The default choice is to expose the controller API with combined client and management features. For additional security, you may split these two sets of features and expose them as separate API servers.

## Values

### Common configurations
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| controller.host | string | `""` | **Required**: The controller's primary / advertised name |
| ca.duration | string | `"87840h"` | CA's livetime duration. Equals 3660 days / 10 years. Go's time.duration only allows hours |
| ca.renewBefore | string | `"720h"` | The time the CA gets renewed before expiry. Equals 30 days.  |
| cert.duration | string | `"87840h"` | Server's cert livetime duration. Equals 3660 days / 10 years. |
| cert.renewBefore | string | `"720h"` | The time the Server's cert gets renewed before expiry. Equals 30 days.  |

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| service.enabled | bool | `true` | Create a common service object for the client management API and controller API |
| service.annotations | object | `{}` |  |
| service.labels | object | `{}` |  |
| service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| service.externalIPs | list | `[]` | external IP's to bind the service on |
| service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| service.loadBalancerIP | string | `""` | |
| service.publishNotReadyAddresses | string | `""` | |
| service.sessionAffinity | string | `""` | |
| service.sessionAffinityConfig | object | `{}` | |

### Individual services and API configurations

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ctrlPlane.port | int | `6262` | The ctrl plane port routers connect to |
| clientApi.port | int | `1280` | The port to expose client API on  |
| clientApi.service.enabled | bool | `false` | Create a dedicated service object for the client API |
| clientApi.service.annotations | object | `{}` |  |access the router's edge service |
| clientApi.service.labels | object | `{}` |  |
| clientApi.service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| clientApi.service.externalIPs | list | `[]` | external IP's to bind the service on |
| clientApi.service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| clientApi.service.loadBalancerIP | string | `""` | |
| clientApi.service.publishNotReadyAddresses | string | `""` | |
| clientApi.service.sessionAffinity | string | `""` | |
| clientApi.service.sessionAffinityConfig | object | `{}` | |
| managementApi.port | int | `1281` | Port to expose the management API on |
| managementApi.service.enabled | bool | `true` | Create a cluster service for the management API |
| managementApi.service.annotations | object | `{}` |  |object for the router's transport service |
| managementApi.service.labels | object | `{}` |  |
| managementApi.service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| managementApi.service.externalIPs | list | `[]` | external IPs to bind the service on |
| managementApi.service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| managementApi.service.loadBalancerIP | string | `""` | |
| managementApi.service.publishNotReadyAddresses | string | `""` | |
| managementApi.service.sessionAffinity | string | `""` | |
| managementApi.service.sessionAffinityConfig | object | `{}` | |
| prometheus.enabled | bool | `false` | Enable Prometheus metrics server|
| prometheus.port | int | `2112` | Port to expose Prometheus metrics on (hint: accessible via HTTPS) |
| prometheus.service.enabled | bool | `true` | Create a cluster service for the Prometheus API |
| prometheus.service.annotations | object | `{}` |  |object for the router's transport service |
| prometheus.service.labels | object | `{}` |  |
| prometheus.service.type | string | `"ClusterIP"` | either `ClusterIP`, `LoadBalancer` or `NodePort` |
| prometheus.service.externalIPs | list | `[]` | external IPs to bind the service on |
| prometheus.service.clusterIP | string | `""` | IP to use when `mode=ClusterIP` `LoadBalancer` or `NodePort` |
| prometheus.service.loadBalancerIP | string | `""` | |
| prometheus.service.publishNotReadyAddresses | string | `""` | |
| prometheus.service.sessionAffinity | string | `""` | |
| prometheus.service.sessionAffinityConfig | object | `{}` | |

### Other common settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.pullSecrets | list | `[]` |  |
| image.repository | string | `"openziti/quickstart"` |  |
| image.tag | string | `"0.27.0"` |  |
| replicas | int | `1` | Server replicas |
| affinity | object | `{}` | affinity applied to the deployments |
| podAnnotations | object | `{}` | additional annotations for the pod |
| podSecurityContext | object | `{}` | security context configuration for the pod |
| securityContext | object | `{}` | security context configuration for the statefulSet |
| tolerations | object | `{}` | toleration configuration |
| nodeSelector | object | `{}` | nodeSelector configuration |

## TODO's

* replicas - Each controller replica needs to be it's own HA member. We have to wait until HA https://github.com/openziti/ziti/blob/release-next/doc/ha/overview.md is officially released.
* lower CA / Cert livetime; how to refresh stuff when Certs are updated?
* Deploy Prometheus scraper configuration when `prometheus.enabled = true`
* cert-manager allows issuing only one cert per key, i.e., ClientCertKeyReuseIssue prevents us from issuing a user cert and server cert backed by same private key, hence the controller config.yaml re-uses server certs in place of user certs to allow startup and testing to continue