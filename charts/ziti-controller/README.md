# Helm Chart ziti-controller

## Overview

This chart runs a Ziti controller in Kubernetes. It uses the custom resources provided by [cert-manager](https://cert-manager.io/docs/installation/) and [trust-manager](https://cert-manager.io/docs/projects/trust-manager/#installation), i.e., Issuer, Certificate, and Bundle. Delete the controller pod after an upgrade for the new controller configuration to take effect.

## Minimal Installation

This first example shows a minimal installation for a Kubernetes distribution that provides TLS pass-through for Service type LoadBalancer, e.g., K3S, Minikube.

```bash
helm install \
    --create-namespace --namespace ziti-controller ziti-controller-minimal1 \
    openziti/ziti-controller \
        --set clientApi.advertisedHost="ziti-controller-minimal.example.com"
```

The advertised DNS name must resolve to a reachable IP for all Ziti edge clients and routers.

A default admin user and password will be generated and saved to a secret during installation. The credentials can be retrieved using this command:

```bash
kubectl get secret \
    -n ziti-controller ziti-controller-minimal1-admin-secret \
    -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```

You may log in the `ziti` CLI with one command or omit the `-p` part to prompt:

```bash
ziti edge login ziti-controller-minimal.example.com:1280 \
    --yes \
    -u admin \
    -p $(kubectl -n ziti-controller \
            get secrets ziti-controller-minimal1-admin-secret \
            -o go-template='{{index .data "admin-password" | base64decode }}'
        )
```

## Managed Kubernetes Installation

Managed Kubernetes providers typically configure server TLS for a Service of type LoadBalancer. Ziti needs pass-through TLS because it uses the client certificates of edge clients and routers. We'll accomplish this by changing the Service type to ClusterIP and creating Ingress resources with pass-through TLS for each cluster service.

This example demonstrates creating TLS pass-through Ingress resources for use with [ingress-nginx](https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-helm/). 

Ensure you have the `ingress-nginx` chart installed with `controller.extraArgs.enable-ssl-passthrough=true`. You can verify this feature is enabled by running `kubectl describe pods {ingress-nginx-controller pod}` and checking the args for `--enable-ssl-passthrough=true`.

Create a Helm chart values file like this.

```yaml
# /tmp/controller-values.yml
clientApi:
    advertisedHost: ziti-controller-managed.example.com
    advertisedPort: 443
    service:
        type: ClusterIP
    ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
            kubernetes.io/ingress.allow-http: "false"
            nginx.ingress.kubernetes.io/ssl-passthrough: "true"
            nginx.ingress.kubernetes.io/secure-backends: "true"
```

Now install or upgrade this controller chart with your values file.

```bash
helm install \
    --create-namespace --namespace ziti-controller \
    ziti-controller-managed1 openziti/ziti-controller \
    --values /tmp/controller-values.yml
```

### Expose the Router Control Plane

This is applicable if you have any routers outside the Ziti controller's cluster. You must configure pass-through TLS LoadBalancer or Ingress for the control plane service, i.e., "ctrl." Routers running in the same cluster as the controller can use the cluster service named `{controller release}-ctrl` (the ctrl endpoint). This example demonstrates a pass-through Ingress resource for `nginx-ingress`.

Merge this with your Helm chart values file before installing or upgrading.

```yaml
ctrlPlane:
    advertisedHost: ziti-controller-managed-ctrl.example.com
    advertisedPort: 443
    service:
        enabled: true
    ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
            kubernetes.io/ingress.allow-http: "false"
            nginx.ingress.kubernetes.io/ssl-passthrough: "true"
            nginx.ingress.kubernetes.io/secure-backends: "true"
```

## Extra Security for the Management API

You can split the client and management APIs into separate cluster services by setting `managementApi.service.enabled=true`. With this configuration, you'll have an additional cluster service named `{controller release}-mgmt` that is the management API, and the client API will not have management features.

This Helm chart's values allow for both operational scenarios: combined and split. The default choice is to expose the combined client and management APIs as the cluster service named `{controller release}-client`, which is convenient because you can use the `ziti` CLI immediately. For additional security, you may shelter the management API by splitting these two sets of features, exposing them as separate API servers. After the split, you can access the management API in several ways:

* running the web console inside the cluster,
* hosting a Ziti service to make it available to your admin devices,
* `kubectl port-forward`, or
* configuring a restrictive cluster ingress to the service.

## Advanced PKI

The default configuration generates a singular PKI root of trust for all the controller's servers and the edge signer CA. Optionally, you may provide the name of a cert-manager Issuer or ClusterIssuer to become the root of trust for the Ziti controller's identity.

Merge this with your Helm chart values file before installing or upgrading.

```yaml
ctrlPlane:
  issuer:
    kind: ClusterIssuer
    name: my-alternative-cluster-issuer
```

You may also configure the Ziti controller to use separate PKI roots of trust for its three main identities: control plane, edge signer, and web bindings.

For example, to use a separate CA for the edge signer function, merge this with your Helm chart values file before installing or upgrading.

```yaml
edgeSignerPki:
  enabled: true
```

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