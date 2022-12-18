# Helm Chart ziti-host

## Why?

With this chart you can deploy a `ziti controller` into your kubernetes cluster.

## How?

tbd

## Installation


```bash
helm install -n ziti-test test-controller openziti/ziti-controller --set-file zitiIdentity=/tmp/k8s-tunneler-03.json
```

during the installation a default admin user an password will be generated and saved to a secret. The credentials can be retrieved using this command:

```
kubectl get secret -n ziti-text test-controller-admin-secret -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```

