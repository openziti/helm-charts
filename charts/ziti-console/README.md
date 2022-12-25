# Helm Chart ziti-console

## Why?

You may use this chart to deploy Ziti console within kubernetes.

## Installation

This chart deploys a pod running `ziti-console`, [the OpenZiti console](https://github.com/openziti/ziti-console/).

After adding the charts repo to Helm then you may install the chart. You must supply some useful defaults, i.e. the name the console listens on. For a sample you might have a look into the [Quickstart Scenario](../../README.md#quickstart-scenario)

This is this sample from the quickstart:

```bash
helm install quickstart-console ziti-console \
     --set "ingress.enabled=true" \
     --set "ingress.hosts[0].host=quickstart-console.<example.org>" \
     --set "settings.edgeControllers[0].name=quickstart" \
     --set "settings.edgeControllers[0].url=https://quickstart-controller-mgmt:1281" \
     --set "settings.edgeControllers[0].default=true" \
     --set "ingress.annotations.traefik\.ingress\.kubernetes\.io/router\.entrypoints=websecure" \
     --set "ingress.labels.ingressMethod=traefik"

```

## Namespaces

The `helm install` command accepts param `--namespace` and so you may install this chart separately for each namespace for purposes such as achieving network isolation of your Ziti-hosted cluster services.


## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ingress.enabled | bool | `false` | Install the ingress route |
| ingress.ingressClassName | string | `""` | Ingress class name |
| ingress.annotations | object | `{}` | additional annotations for the ingress route |
| ingress.labels | object | `{}` | additional labels for the ingress route |
| ingress.hosts | object | `{}` | custom host definitions for the ingress route |
| ingress.hosts[0].host | string | `""` | The host for the ingress route. **Required when ingress.enabled = true** |
| ingress.tls | list | `[]` | TLS configuration for the ingress object |
| settings.edgeControllers | list | `[]` | Default's for the settings.json file. Have a look on the provided sample |
| image.pullPolicy | string | `"Always"` |  |
| image.pullSecrets | list | `[]` |  |
| image.repository | string | `"openziti/zac"` |  |
| image.tag | string | `"latest"` |  |
| replicas | int | `1` | Server replicas |
| affinity | object | `{}` | affinity applied to the deployments |
| podAnnotations | object | `{}` | additional annotations for the pod |
| podSecurityContext | object | `{}` | security context configuration for the pod |
| securityContext | object | `{}` | security context configuration for the statefulSet |
| tolerations | object | `{}` | toleration configuration |
| nodeSelector | object | `{}` | nodeSelector configuration |
## Sample `my-values.yaml`

This is a minimal `values.yaml` sample for an k3s-enviroment using traefik as ingress loadbalancer:

```yaml
ingress:
  enabled: true
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
  labels:
    ingressMethod: traefik
  hosts:
    - host: quickstart-console.<example.org>

settings:
  edgeControllers:
    - name: quickstart
      url: https://quickstart-controller-mgmt:1281
      default: true
```
