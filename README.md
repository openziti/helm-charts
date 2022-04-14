# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://openziti.github.io) on [Kubernetes](https://kubernetes.io/).

These files are published as [a GitHub pages site here](https://openziti-test-kitchen.github.io/helm-charts/).

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
