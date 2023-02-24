
# ziti-controller

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.27.5](https://img.shields.io/badge/AppVersion-0.27.5-informational?style=flat-square)

Host an OpenZiti controller in Kubernetes

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.jetstack.io | cert-manager | ~1.11.0 |
| https://charts.jetstack.io | trust-manager | ~0.4.0 |
| https://kubernetes.github.io/ingress-nginx/ | ingress-nginx | ~4.5.2 |

Note that ingress-nginx is not strictly required, but the chart is parameterized to allow for conveniently declaring pass-through TLS.

## Overview

This chart runs a Ziti controller in Kubernetes. It uses the custom resources provided by [cert-manager](https://cert-manager.io/docs/installation/) and [trust-manager](https://cert-manager.io/docs/projects/trust-manager/#installation), i.e., Issuer, Certificate, and Bundle. Delete the controller pod after an upgrade for the new controller configuration to take effect.

## Requirements

This chart requires Certificate, Issuer, and Bundle resources to be applied before installing the chart. Sub-charts `cert-manager`, and `trust-manager` will be installed automatically. You may disable the sub-charts if you wish to provide these resources separately, but if you do so then please use the sub-chart values at the foot of [Values.yaml](./Values.yaml) to ensure those charts are correctly configured.

### Install Required Custom Resource Definitions

This step satisfies Helm's requirement that the CRDs used in the umbrella chart
already exist in Kubernetes before installing the controller chart.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.4.0/deploy/crds/trust.cert-manager.io_bundles.yaml
```

## Minimal Installation

This first example shows a minimal installation for a Kubernetes distribution that provides TLS pass-through for Service type LoadBalancer, e.g., K3S, Minikube.

You must supply one value when you install the chart.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
|clientApi.advertisedHost|string|nil|the DNS name that edge clients and routers will resolve to reach this controller's edge client API|

```bash
helm install \
    --namespace ziti-controller ziti-controller-minimal1 \
    openziti/ziti-controller \
        --set clientApi.advertisedHost="ziti-controller-minimal.example.com" \
        --set client.ApiadvertisedPort="443"
```

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

Managed Kubernetes providers typically configure server TLS for a Service of type LoadBalancer. Ziti needs pass-through TLS because edge clients and routers authenticate with client certificates. We'll accomplish this by changing the Service type to ClusterIP and creating Ingress resources with pass-through TLS for each cluster service.

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
    --namespace ziti-controller ziti-controller-managed1 \
    openziti/ziti-controller \
    --values /tmp/controller-values.yml
```

### Expose the Router Control Plane

This is applicable if you have any routers outside the Ziti controller's cluster. You must configure pass-through TLS LoadBalancer or Ingress for the control plane service. Routers running in the same cluster as the controller can use the cluster service named `{controller release}-ctrl` (the "ctrl" endpoint). This example demonstrates a pass-through Ingress resource for `nginx-ingress`.

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
* hosting a Ziti service, or
* `kubectl port-forward`.

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

## Values Reference

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | deployment template spec affinity |
| ca.duration | string | `"87840h"` | Go time.Duration string format |
| ca.renewBefore | string | `"720h"` | Go time.Duration string format |
| cert-manager.enableCertificateOwnerRef | bool | `true` | clean up secret when certificate is deleted |
| cert-manager.enabled | bool | `true` | install the cert-manager subchart to provide CRDs Certificate, Issuer |
| cert-manager.installCRDs | bool | `false` | CRDs must be applied in advance of installing the parent chart |
| cert.duration | string | `"87840h"` | Go time.Duration string format |
| cert.renewBefore | string | `"720h"` | Go time.Duration string format |
| clientApi.advertisedHost | string | `nil` | global DNS name by which routers can resolve a reachable IP for this service |
| clientApi.advertisedPort | int | `1280` | cluster service, node port, load balancer, and ingress port |
| clientApi.containerPort | int | `1280` | cluster service target port on the container |
| clientApi.ingress.annotations | string | `nil` | ingress annotations, e.g., to configure ingress-nginx |
| clientApi.ingress.enabled | bool | `false` | create an ingress for the cluster service |
| clientApi.service.enabled | bool | `true` | create a cluster service for the deployment |
| clientApi.service.type | string | `"LoadBalancer"` | expose the service as a ClusterIP, NodePort, or LoadBalancer |
| configFile | string | `"ziti-controller.yaml"` | filename of the controller configuration file |
| configMountDir | string | `"/etc/ziti"` | read-only mountpoint where configFile and various read-only identity dirs are projected |
| ctrlPlane.advertisedHost | string | `nil` | global DNS name by which routers can resolve a reachable IP for this service: default is cluster service DNS name which assumes all routers are inside the same cluster |
| ctrlPlane.advertisedPort | int | `6262` | cluster service, node port, load balancer, and ingress port |
| ctrlPlane.alternativeIssuer | string | `nil` | kind and name of alternative issuer for the controller's identity |
| ctrlPlane.containerPort | int | `6262` | cluster service target port on the container |
| ctrlPlane.ingress.annotations | string | `nil` | ingress annotations, e.g., to configure ingress-nginx |
| ctrlPlane.ingress.enabled | bool | `false` | create an ingress for the cluster service |
| ctrlPlane.service.enabled | bool | `true` | create a cluster service for the deployment |
| ctrlPlane.service.type | string | `"ClusterIP"` | expose the service as a ClusterIP, NodePort, or LoadBalancer |
| ctrlPlaneCaDir | string | `"ctrl-plane-cas"` | read-only mountpoint for run container to read the ctrl plane trust bundle created during init |
| ctrlPlaneCasFile | string | `"ctrl-plane-cas.crt"` | filename of the ctrl plane trust bundle |
| dataMountDir | string | `"/persistent"` | writeable mountpoint where the controller will create dbFile during init |
| dbFile | string | `"ctrl.db"` | name of the BoltDB file |
| edgeSignerPki.enabled | bool | `false` | generate a separate PKI root of trust for the edge signer CA |
| execMountDir | string | `"/usr/local/bin"` | a directory included in the init and run containers' executable search path |
| highAvailability.mode | string | `"standalone"` | Ziti controller HA mode |
| highAvailability.replicas | int | `1` | Ziti controller HA swarm replicas |
| image.args | list | `["{{ .Values.configMountDir }}/{{ .Values.configFile }}","--verbose"]` | container command options and args |
| image.command | list | `["ziti","controller","run"]` | container command |
| image.pullPolicy | string | `"Always"` | deployment image pull policy |
| image.repository | string | `"docker.io/openziti/ziti-controller"` | container image tag for app deployment |
| ingress-nginx.controller.extraArgs.enable-ssl-passthrough | string | `"true"` | configure subchart ingress-nginx to enable the pass-through TLS feature |
| ingress-nginx.enabled | bool | `false` | recommended: install the ingress-nginx subchart (may be necessary for managed k8s) |
| initScriptFile | string | `"ziti-controller-init.bash"` | exec by init container |
| managementApi.advertisedPort | int | `1281` | cluster service, node port, load balancer, and ingress port |
| managementApi.containerPort | int | `1281` | cluster service target port on the container |
| managementApi.service.enabled | bool | `false` | create a cluster service for the deployment |
| managementApi.service.type | string | `"ClusterIP"` | expose the service as a ClusterIP, NodePort, or LoadBalancer |
| nodeSelector | object | `{}` | deployment template spec node selector |
| persistence.VolumeName | string | `nil` | PVC volume name |
| persistence.accessMode | string | `"ReadWriteOnce"` | PVC access mode: ReadWriteOnce (concurrent mounts not allowed), ReadWriteMany (concurrent allowed) |
| persistence.annotations | object | `{}` | annotations for the PVC |
| persistence.enabled | bool | `true` | required: place a storage claim for the BoltDB persistent volume |
| persistence.existingClaim | string | `""` | A manually managed Persistent Volume and Claim Requires persistence.enabled=true. If defined, PVC must be created manually before volume will be bound. |
| persistence.size | string | `"2Gi"` | 2GiB is enough for tens of thousands of entities, but feel free to make it larger |
| persistence.storageClass | string | `nil` | Storage class of PV to bind. By default it looks for the default storage class. If the PV uses a different storage class, specify that here. |
| podAnnotations | object | `{}` | annotations to apply to all pods deployed by this chart |
| podSecurityContext | object | `{"fsGroup":65534}` | deployment template spec security context |
| podSecurityContext.fsGroup | int | `65534` | this is the GID of "nobody" in the RedHat UBI minimal container image. This was added when troubleshooting a persistent volume permission error, and I don't know if it's necessary. |
| prometheus.advertisedPort | int | `9090` | cluster service, node port, load balancer, and ingress port |
| prometheus.containerPort | int | `9090` | cluster service target port on the container |
| prometheus.service.enabled | bool | `false` | create a cluster service for the deployment |
| prometheus.service.type | string | `"ClusterIP"` | expose the service as a ClusterIP, NodePort, or LoadBalancer |
| resources | object | `{}` | deployment container resources |
| securityContext | object | `{}` | deployment container security context |
| tolerations | list | `[]` | deployment template spec tolerations |
| trust-manager.app.trust.namespace | string | `"ziti-controller"` | trust-manager needs to be configured to trust the namespace in which the controller is deployed so that it will create the Bundle resource for the ctrl plane trust bundle |
| trust-manager.crds.enabled | bool | `false` | CRDs must be applied in advance of installing the parent chart |
| trust-manager.enabled | bool | `true` | install the trust-manager subchart to provide CRD Bundle |
| webBindingPki.enabled | bool | `false` | generate a separate PKI root of trust for web bindings, i.e., client, management, and prometheus APIs |

## TODO's

* replicas - Each controller replica needs to be it's own HA member. We have to wait until HA https://github.com/openziti/ziti/blob/release-next/doc/ha/overview.md is officially released.
* lower CA / Cert livetime; how to refresh stuff when Certs are updated?
* Deploy Prometheus scraper configuration when `prometheus.enabled = true`
* cert-manager allows issuing only one cert per key, i.e., ClientCertKeyReuseIssue prevents us from issuing a user cert and server cert backed by same private key, hence the controller config.yaml re-uses server certs in place of user certs to allow startup and testing to continue

<!-- generated with helm-docs -->
