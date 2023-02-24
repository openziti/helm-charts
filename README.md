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
NAME                            CHART VERSION   APP VERSION     DESCRIPTION                                       
openziti/ziti-controller        0.1.2           0.27.5          Host an OpenZiti controller in Kubernetes         
openziti/ziti-router            0.1.3           0.27.5          Host an OpenZiti router in Kubernetes             
openziti/ziti-console           0.1.1           latest          Deploy OpenZiti console as kubernetes service     
openziti/ziti-host              0.3.5           0.20.20         Host OpenZiti services with a tunneler pod        
openziti/hello-toy              1.3.1           latest          Run the lightweight toy web server, optionally ...
openziti/httpbin                0.1.2           latest          Run the Ziti fork of go-httpbin                   
openziti/reflect                0.3.3           0.0.4           Deploy a pod running the Ziti-embeded version o...
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
1. Optionally, to customize the auto-generated README.md file, add a helm-docs template named README.md.gotmpl in the chart directory.
1. Send PR targeting main.
1. Wait for GitHub bot to generate Helm docs in your PR branch, or run `helm-docs --chart-search-root ./charts/my-new-chart/` locally
1. Wait for GitHub bot to bump chart versions if necessary, i.e., if anything in the chart dir changed and the chart version is already released.
1. Merging to main runs GitHub Actions to package and index the charts and publish the new Helm repo index and READMEs to GitHub Pages.

You may verify changes are present in the Helm index: https://docs.openziti.io/helm-charts/index.yaml.
