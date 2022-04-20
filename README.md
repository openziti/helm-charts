# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://openziti.github.io) on [Kubernetes](https://kubernetes.io/).

These files are published as [a GitHub pages site here](https://openziti-test-kitchen.github.io/helm-charts/).

## Test Local Changes

Use helm to install a chart locally. Example prometheuz

zitified:
```
helm install prometheuz ./charts/prometheus \
    --set-file configmapReload.ziti.id.contents="/ziti/id/to/reload/prometheus/after/change.json" \
         --set configmapReload.ziti.targetService="my.zitified.prometheus.svc" \
         --set configmapReload.ziti.targetIdentity="hosting.ziti.identity" \
    --set-file server.ziti.id.contents="/ziti/id/to/prometheus/ziti.id.json" \
         --set server.ziti.service="my.zitified.prometheus.svc" \
         --set server.ziti.identity="hosting.ziti.identity"
```
unzitified (but... why? probably only for testing but maybe you can't zitify prometheus):
```
helm install prometheuz ./charts/prometheus \
         --set configmapReload.zitified="false" \
         --set server.ziti.enabled="false"
```


## Update this repo

### Automatic 

* clone this repo
* find/update values as needed'
* merge back to main - a github action will publish the chart

### Hisotry 

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



