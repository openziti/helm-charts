# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://docs.openziti.io) on [Kubernetes](https://kubernetes.io/).

These files are published from [a GitHub repo](https://github.com/openziti/helm-charts/#readme) as [a GitHub pages site here](https://docs.openziti.io/helm-charts/).

## Use this Repo

### Subscribe

```console
$ helm repo add openziti https://docs.openziti.io/helm-charts/
"openziti" has been added to your repositories
```

## Chart Highlights

### Charts for Workloads

These charts help cluster workloads access or provide a Ziti service.

* [`ziti-host`](./charts/ziti-host/README.md): Ziti tunnel pod for hosting services (ingress only)
* [`ziti-edge-tunnel`](./charts/ziti-edge-tunnel/README.md): Ziti tunnel daemonset for accessing services (intercept node egress)

### Charts for Self-Hosting Ziti

* [`ziti-controller`](./charts/ziti-controller/README.md)
* [`ziti-router`](./charts/ziti-router/README.md)
* [`ziti-console`](./charts/ziti-console/README.md)

### Charts that Deploy a Ziti-enabled Application

* [`httpbin`](./charts/httpbin/README.md): Ziti fork of the REST testing server
* [`prometheus`](./charts/prometheus/README.md): Ziti fork of Prometheus
* [`reflect`](./charts/reflect/README.md): A Ziti original. This app echoes the bytes it receives and is useful for testing Ziti.

## Maintainers

This repo uses GitHub Actions to automate the following tasks:

1. Generate Helm docs for each chart in the repo.
1. Package and index the charts and publish the new Helm repo index and READMEs to GitHub Pages.

### Troubleshooting a Missing Chart

In case a chart release is missing from the Helm index, you can run the following commands to resolve the issue locally.

For this example, support the `httpbin` chart release version `0.1.2` exists in GitHub, but is missing from the Helm index. The solution is to run Chart Releaser locally to package and index the chart.

```console
git checkout gh-pages
cr package ./charts/httpbin
cr index --owner openziti --git-repo helm-charts --index-path .
```

## Contribute

1. Clone this repo.
1. Optionally, to customize the auto-generated `README.md` file, add a helm-docs template named `README.md.gotmpl` in the chart directory.
1. Wait for GitHub bot to generate Helm docs in your branch, or run `helm-docs --chart-search-root ./charts/my-new-chart/` locally
1. Send PR targeting main.
1. Wait for GitHub bot to bump chart versions if necessary, i.e., if anything in the chart dir changed since latest tag and the chart version is already released.
1. Merging to main runs GitHub Actions to package and index the charts and publish the new Helm repo index and READMEs to GitHub Pages.

You may verify changes are present in the Helm index: <https://docs.openziti.io/helm-charts/index.yaml>.
