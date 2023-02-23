# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://docs.openziti.io) on [Kubernetes](https://kubernetes.io/).

These files are published from [a GitHub repo](https://github.com/openziti/helm-charts/#readme) as [a GitHub pages site here](https://docs.openziti.io/helm-charts/).

## Use this Repo

### Subscribe

```bash
$ helm repo add openziti https://docs.openziti.io/helm-charts/
"openziti" has been added to your repositories                         
```

### Search for available charts in this repo

```bash
$ helm search repo openziti
NAME                    CHART VERSION   APP VERSION     DESCRIPTION                                       
openziti/prometheus     0.0.11          0.0.13          Prometheus is a monitoring system and time seri...
openziti/reflect        0.3.0           0.0.4           A Helm chart for Kubernetes                       
openziti/ziti-host      0.1.0           0.19.11         Host OpenZiti services with a tunneler pod                 
```

## Chart Highlights

### Charts for Workloads

These charts help cluster workloads access or provide a Ziti service.

* [`ziti-host`](./charts/ziti-host/README.md): Ziti tunnel pod for hosting services (ingress only)
* (*planned*) [`ziti-node`](./charts/ziti-node/README.md): Ziti tunnel daemonset for accessing services (intercept node egress)

### Charts for Self-Hosting Ziti

* [`ziti-controller`](./charts/ziti-controller/README.md)
* [`ziti-router`](./charts/ziti-router/README.md)
* [`ziti-console`](./charts/ziti-console/README.md)

### Charts that Deploy a Ziti-enabled Application

* [`httpbin`](./charts/httpbin/README.md): Ziti fork of the REST testing server
* [`prometheus`](./charts/prometheus/README.md): Ziti fork of Prometheus
* [`reflect`](./charts/reflect/README.md): A Ziti original. This app echoes the bytes it receives and is useful for testing Ziti.

## Contribute

1. Clone this repo.
1. Optionally, to customize the generated README.md file, add a helm-docs template named README.md.gotmpl.
1. Send PR targeting main.
1. Merging to main runs GitHub Actions to package and index the charts, generate REAME.md, and publish to GitHub Pages.

You may verify changes are present in the Helm index: https://docs.openziti.io/helm-charts/index.yaml.
