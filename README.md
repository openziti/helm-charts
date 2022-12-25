# OpenZiti Helm Charts

This is a repository of [Helm](https://helm.sh/) charts for use with [OpenZiti](https://docs.openziti.io) on [Kubernetes](https://kubernetes.io/).

These files are published from [a GitHub repo](https://github.com/openziti/helm-charts/#readme) as [a GitHub pages site here](https://docs.openziti.io/helm-charts/).

## Add this repo to Helm

```bash
❯ helm repo add openziti https://docs.openziti.io/helm-charts/                                                                                               
"openziti" has been added to your repositories                         
```

## Search for available charts in this repo

```bash
❯ helm search repo openziti
NAME                    CHART VERSION   APP VERSION     DESCRIPTION                                       
openziti/prometheus     0.0.11          0.0.13          Prometheus is a monitoring system and time seri...
openziti/reflect        0.3.0           0.0.4           A Helm chart for Kubernetes                       
openziti/ziti-host      0.1.0           0.19.11         Host OpenZiti services with a tunneler pod                 
```

## Charts

### `ziti-controller`

This chart deploys a `ziti controller` into your cluster. It rely's on https://cert-manager.io/ for certificate deployment and requies [cert-manager already being installed on your cluster](https://cert-manager.io/docs/installation/)

### `ziti-host`

This chart deploys a pod running `ziti-edge-tunnel run-host`. This is the Linux tunneler in hosting mode. This is useful for hosting Ziti services. For example, you may install this chart once per cluster namespace and host each namespace's cluster services with the respective tunneler identity that you supplied when the chart was installed. The identity is stored as a Kubernetes Secret. For more information about the Linux tunneler please reference [the docs](https://docs.openziti.io/docs/reference/tunnelers/linux/).

```bash
helm install ziti-host openziti/ziti-host --set-file zitiIdentity=/tmp/myAcmeIdentity.json
```

### `httpbin`

This chart deploys a pod running the Ziti-embeded version of go-httpbin, a REST API server.

```bash
helm install httpbinz-release1 openziti/httpbin \
     --set zitiServiceName="my httpbin service" \
     --set-file zitiIdentity=./my-ziti-identity.json
```

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

## Quickstart Scenario

This is a little guide how to setup a quickstart scenario like described in https://openziti.github.io/docs/quickstarts/services/

### Prerequisites

We assume the helm repository already has been added and [cert-manager has been deployed](https://cert-manager.io/docs/installation/) on your cluster. Also a separate namespace for the quickstart might be a good idea:
```bash
kubectl create namespace ziti-quickstart
kubectl config set-context --current --namespace=ziti-quickstart
```

### Deployment of the ziti infrastructure

First of all we need to put the IP and name of your kubernetes cluster into the env. Please adopt and fill in how to reach the loadbalancer IP & hostname used during deployment accordingly to your environment:
```bash
export KUBE_LB_IP=192.168.x.y
export KUBE_LB_HOST=ziti-quickstart.example.org
```

#### First of all we deploy the controller:
```bash
helm install quickstart-controller openziti/ziti-controller \
     --set controller.host="${KUBE_LB_HOST}" \
     --set service.type="LoadBalancer" \
     --set service.loadBalancerIP="${KUBE_LB_IP}"

# wait for the pod to be Running state
kubectl wait --for=condition=ready --timeout=60s pod/quickstart-controller-0
kubectl get pods quickstart-controller-0
```

####  Next we deploy the router using the `ziti-router` chart. It uses the internal service-name `quickstart-controller` for internal communication to the controller
```bash
# register the quickstart-router and get the enrolment JWT
export QS_ROUTER_ENROLMENT_JWT="$(kubectl exec -it quickstart-controller-0 -- /bin/bash -i -c "zitiLogin; ziti edge create edge-router quickstart-router -a 'public'; ziti edge list edge-routers  -j | jq -M -r '.data | .[] | .enrollmentJwt'" | tee /dev/stderr | tail -1| sed  's/\r//g')"
# we install the router
helm install quickstart-router openziti/ziti-router \
     --set enrolmentJwt="${QS_ROUTER_ENROLMENT_JWT}" \
     --set controller.endpoint="quickstart-controller:6262" \
     --set transport.enabled="true" \
     --set transport.host="quickstart-router" \
     --set edge.enabled="true" \
     --set edge.host="${KUBE_LB_HOST}" \
     --set edge.service.type="LoadBalancer" \
     --set edge.service.loadBalancerIP="${KUBE_LB_IP}"
# the router should be online now
kubectl exec -it quickstart-controller-0 -- /bin/bash -i -c "zitiLogin; ziti edge list edge-routers"
```

#### Deploy the edge-router using the `ziti-host` chart.

```bash
# get a new identity for the server / edge box
SERVER_JWT="$(kubectl exec -it quickstart-controller-0 -- /bin/bash -i -c "zitiLogin; ziti edge create identity user kube.http.server -o /tmp/kube.http.server.jwt; cat /tmp/kube.http.server.jwt; rm /tmp/kube.http.server.jwt" | tee /dev/stderr | tail -1 | sed 's/\r//g')"
# we have to enroll the jwt. Piping through the `--attach` console didn't work relieable, so we start the container and exec a session into it for the deployment

kubectl run ziti-edge-tunnel-enrolment --rm --restart=Never -i --tty --image openziti/ziti-host --attach --command -- bash -c "sleep 300" &

# please wait until the pod is Running state. To check the pod state run:
kubectl wait --for=condition=ready --timeout=60s pod/ziti-edge-tunnel-enrolment
kubectl get pod ziti-edge-tunnel-enrolment

# the real enrolement
SERVER_JSON="$(kubectl exec -it ziti-edge-tunnel-enrolment -- bash -c "echo -n ${SERVER_JWT} | ziti-edge-tunnel enroll -j /dev/stdin -i /tmp/identity.json; cat /tmp/identity.json  | base64 -w0" | tee /dev/stderr | tail -1 | sed 's/\r//g')"

# save it to the json file
echo ${SERVER_JSON} | base64 -d > kube.http.server.json

# stop / remove the enrolment pod
kubectl delete pod ziti-edge-tunnel-enrolment &

# install the helm with the client acting as edge server
helm install quickstart-edge-server openziti/ziti-host \
     --set-file zitiIdentity=kube.http.server.json

# the client should be online now
kubectl exec -it quickstart-controller-0 -- /bin/bash -i -c "zitiLogin; ziti edge list identities"

```

#### We also need an Identity for our testclient

```bash
# generate the JWT for kube.quickstart.client
kubectl exec -it quickstart-controller-0 -- /bin/bash -i -c "zitiLogin; ziti edge create identity user kube.quickstart.client -a 'kube-http-clients' -o /tmp/kube.quickstart.client.jwt; cat /tmp/kube.quickstart.client.jwt; rm /tmp/kube.quickstart.client.jwt" | tee /dev/stderr | tail -1 | sed 's/\r//g' | >kube.quickstart.client.jwt
```
Now enroll `kube.quickstart.client.jwt` on your local client


#### As demo appication we deploy the simple *Hello Kubernetes* app from https://github.com/jhidalgo3/hello-kubernetes
```
helm repo add jhidalgo3-github https://jhidalgo3.github.io/helm-charts/
helm install hello-kubernetes jhidalgo3-github/hello-kubernetes-chart
```
It cerates an internal service named `hello-kubernetes-hello-kubernetes-chart` listening on port 80

#### Configure the OpenZiti policy
This is adopted from the [OpenZiti ZTHA quickstart guide](https://openziti.github.io/docs/quickstarts/services/ztha/)

```bash
# We open a shell within our controller instance
kubectl exec -it quickstart-controller-0 -- /bin/bash -i
# all following commands in this section are are executed on the controller pod

# we authenticate and open a session
zitiLogin

# Create a blanket edge router policy for #all endpoints to use #all edge routers.
ziti edge create service-edge-router-policy all-routers-all-services --edge-router-roles "#all" --service-roles "#all"

# Allow all identities to use any edge router with the "public" attribute
ziti edge create edge-router-policy all-endpoints-public-routers --edge-router-roles "#public" --identity-roles "#all"

# Create an intercept.v1 config. This config is used to instruct the client-side tunneler how to correctly intercept the targeted traffic and put it onto the overlay.
ziti edge create config kube-http.intercept.v1 intercept.v1 '{"protocols":["tcp"],"addresses":["kube-http.ziti"], "portRanges":[{"low":80, "high":80}]}'

# Create a host.v1 config. This config is used instruct the server-side tunneler how to offload the traffic from the overlay, back to the underlay.
ziti edge create config kube-http.host.v1 host.v1 '{"protocol":"tcp", "address":"hello-kubernetes-hello-kubernetes-chart", "port":80}'

# Create a service to associate the two configs created previously into a service.
ziti edge create service kube-http.svc --configs kube-http.intercept.v1,kube-http.host.v1

# Create a service-policy to authorize "HTTP Clients" to "dial" the service representing the HTTP server.
ziti edge create service-policy http.policy.dial Dial --service-roles "@kube-http.svc" --identity-roles '#kube-http-clients'

# Create a service-policy to authorize the "HTTP Server" to "bind" the service representing the HTTP server.
ziti edge create service-policy http.policy.bind Bind --service-roles '@kube-http.svc' --identity-roles "@kube.http.server"

#that's all - the quickstart setup is finished. close the connection to the pod
exit

```

#### Test the setup
```bash
# on your client machine curl is now able connect the service and prooduces some html output
curl -v http://kube-http.ziti

# you should be able to see the cuircuit when you manage to set up a longer lasting connection, i.e. with `nc`:
nc -v kube-http.ziti 80 &
kubectl exec -it quickstart-controller-0 -- /bin/bash -i -c "zitiLogin; ziti fabric list circuits"
```
#### Optional: install OpenZiti console

Install ziti-console via helm. You have to adopt to host name accordingly to your needs. My test-env is build on k3s, so i have to put proper annotations and labels for traefik - please adjust things to match your enviornment.
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

To get the admin credentials execute this command:
```bash
kubectl get secret  quickstart-controller-admin-secret -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```

Now you can open https://quickstart-console.<example.org> and authenticate using the listed credentials


#### Cleanup

To uninstall the quickstart execute follwoing commands:
```bash
# clean up helm installations
helm uninstall hello-kubernetes
helm uninstall quickstart-console
helm uninstall quickstart-edge-server
helm uninstall quickstart-router
helm uninstall quickstart-controller

# clean all secrets and certificates
kubectl delete secret/quickstart-controller-admin-secret
kubectl delete secret/quickstart-controller-edge-server-cert-secret
kubectl delete secret/quickstart-controller-edge-intermediate-ca-secret
kubectl delete secret/quickstart-controller-edge-root-ca-secret
kubectl delete secret/quickstart-controller-server-cert-secret
kubectl delete secret/quickstart-controller-intermediate-ca-secret
kubectl delete secret/quickstart-controller-root-ca-secret
kubectl delete secret/quickstart-controller-signing-root-ca-secret
kubectl delete secret/quickstart-controller-signing-intermediate-ca-secret

# delete pvc
kubectl delete pvc quickstart-controller-data-quickstart-controller-0
kubectl delete pvc quickstart-router-data-quickstart-router-0

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
