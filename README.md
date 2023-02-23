# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://docs.openziti.io) on [Kubernetes](https://kubernetes.io/).

These files are published from [a GitHub repo](https://github.com/openziti/helm-charts/#readme) as [a GitHub pages site here](https://docs.openziti.io/helm-charts/).

## Add this repo to Helm

```bash
$ helm repo add openziti https://docs.openziti.io/helm-charts/
"openziti" has been added to your repositories                         
```

## Search for available charts in this repo

```bash
$ helm search repo openziti
NAME                    CHART VERSION   APP VERSION     DESCRIPTION                                       
openziti/prometheus     0.0.11          0.0.13          Prometheus is a monitoring system and time seri...
openziti/reflect        0.3.0           0.0.4           A Helm chart for Kubernetes                       
openziti/ziti-host      0.1.0           0.19.11         Host OpenZiti services with a tunneler pod                 
```

## Charts for Workloads

These charts help cluster workloads access or provide a Ziti service.

* [`ziti-host`](./charts/ziti-host/README.md): Ziti tunnel pod for hosting services (ingress only)
* `ziti-node`: [*coming soon*] Ziti tunnel daemonset for accessing services (intercept node egress)
## Charts for Self-Hosting Ziti

* [`ziti-controller`](./charts/ziti-controller/README.md)
* [`ziti-router`](./charts/ziti-router/README.md)
* [`ziti-console`](./charts/ziti-console/README.md)

## Charts that Deploy a Ziti-enabled Application

* [`httpbin`](./charts/httpbin/README.md)


### `prometheus`

The operation of this chart is described in [part 2 of the PrometheuZ tutorial](https://docs.openziti.io/blog/zitification/prometheus/part2/#deploying-prometheuz-1).

```bash
helm install prometheuz ./charts/prometheus \
     --set-file configmapReload.ziti.id.contents="/ziti/id/to/reload/prometheus/after/change.json" \
     --set configmapReload.ziti.targetService="my.zitified.prometheus.svc" \
     --set configmapReload.ziti.targetIdentity="hosting.ziti.identity" \
     --set-file server.ziti.id.contents="/ziti/id/to/prometheus/ziti.id.json" \
     --set server.ziti.service="my.zitified.prometheus.svc" \
     --set server.ziti.identity="hosting.ziti.identity"
```

### `reflect`

This chart provides a simple byte echoing server for demos and testing Ziti. You may read more about how this app can be used in [the PrometheuZ tutorial](https://docs.openziti.io/blog/zitification/prometheus/part2/#deploy-reflectz-1).

```bash
helm install reflectz openziti-test-kitchen/reflect \
     --set-file reflectIdentity="/tmp/prometheus/kubeB.reflect.id.json" \
     --set serviceName="kubeB.reflect.svc" \
     --set prometheusServiceName="kubeB.reflect.scrape.svc"
```

## Development

### Test Local Changes

Use helm to install a chart locally by targeting the local chart's directory. For example:

```bash
helm install prometheuz ./charts/prometheus \
     --set-file configmapReload.ziti.id.contents="/ziti/id/to/reload/prometheus/after/change.json" \
     --set configmapReload.ziti.targetService="my.zitified.prometheus.svc" \
     --set configmapReload.ziti.targetIdentity="hosting.ziti.identity" \
     --set-file server.ziti.id.contents="/ziti/id/to/prometheus/ziti.id.json" \
     --set server.ziti.service="my.zitified.prometheus.svc" \
     --set server.ziti.identity="hosting.ziti.identity"
```

### Update this repo

1. clone this repo
1. commit changes
1. send PR targeting main
1. merge main runs GitHub Actions to package and index the charts and triggers GitHub Pages to publish

You may verify changes are present in the Helm index: https://docs.openziti.io/helm-charts/index.yaml.
