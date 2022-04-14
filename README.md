# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://openziti.github.io) on [Kubernetes](https://kubernetes.io/).

These files are published as [a GitHub pages site here](https://openziti-test-kitchen.github.io/helm-charts/).

## Test Local Changes

Use helm to install a chart locally. Example prometheuz

zitified:
```
helm install prometheuz ./prometheus-charts/charts/prometheus \
    --set-file configmapReload.ziti.id.contents="/ziti/id/to/reload/prometheus/after/change.json" \
         --set configmapReload.ziti.targetService="my.zitified.prometheus.svc" \
         --set configmapReload.ziti.targetIdentity="hosting.ziti.identity" \
    --set-file server.ziti.id.contents="/ziti/id/to/prometheus/ziti.id.json" \
         --set server.ziti.service="my.zitified.prometheus.svc" \
         --set server.ziti.identity="hosting.ziti.identity"
```
unzitified (but... why? probably only for testing but maybe you can't zitify prometheus):
```
helm install prometheuz ./prometheus-charts/charts/prometheus \
         --set configmapReload.zitified="false" \
         --set server.ziti.enabled="false"
```


## Update this repo

### Manually

* clone this repo
* checkout the `main` branch - ensure it's up-to-date
* find/update values as needed
* update ./prometheus-charts/charts/prometheus/Chart.yaml with appVersion/version accordingly
* commit and push these changes to main, via PR or direct commit if you're spicy
* run: `helm package prometheus-charts/charts/prometheus`
* if you see an error like shown below, run `helm dependency update prometheus-charts/charts/prometheus`:

      helm package prometheus-charts/charts/prometheus
      Error: found in Chart.yaml, but missing in charts/ directory: kube-state-metrics

* run `helm package prometheus-charts/charts/prometheus`
* this produces a .tgz file at the root folder
* run `helm repo index . --debug`
* `git checkout gh-pages`
* add .tgz and yaml files to the `gh-pages` branch and commit/push

### Automatic process coming soon

Based on the process established by https://netfoundry.github.io/charts - this repo will
be updated at some point similarly

Merge changes to branch "main" to trigger the GitHub Action that runs the Helm releaser script.
This is configured in the `.github/workflows/release.yml` file. This will also merge the necessary
index to `gh-pages` branch for GitHub Pages to publish. You may verify the rebuild completed by
noting the presence of your update in https://netfoundry.github.io/charts/index.yaml. Then you may
use the update in Helm.

```bash
> helm repo update && helm search repo openziti --versions

Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "netfoundry" chart repository
Update Complete. ⎈Happy Helming!⎈
NAME                     CHART VERSION   APP VERSION     DESCRIPTION                
netfoundry/ziti-host     0.1.1           0.19.12         A Helm chart for Kubernetes
netfoundry/ziti-host     0.1.0           0.19.12         A Helm chart for Kubernetes
```
