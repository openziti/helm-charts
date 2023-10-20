# traefik

![Version: 0.0.4](https://img.shields.io/badge/Version-0.0.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.2.0](https://img.shields.io/badge/AppVersion-1.2.0-informational?style=flat-square)

A Traefik based Kubernetes ingress controller

**Homepage:** <https://traefik.io/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| emilevauge | <emile@vauge.com> |  |
| dtomcej | <daniel.tomcej@gmail.com> |  |
| ldez | <ldez@traefik.io> |  |

## Source Code

* <https://github.com/traefik/traefik>
* <https://github.com/traefik/traefik-helm-chart>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| additionalArguments | list | `[]` |  |
| additionalVolumeMounts | list | `[]` |  |
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| deployment.additionalContainers | list | `[]` |  |
| deployment.additionalVolumes | list | `[]` |  |
| deployment.annotations | object | `{}` |  |
| deployment.enabled | bool | `true` |  |
| deployment.imagePullSecrets | list | `[]` |  |
| deployment.initContainers | list | `[]` |  |
| deployment.kind | string | `"Deployment"` |  |
| deployment.labels | object | `{}` |  |
| deployment.podAnnotations | object | `{}` |  |
| deployment.podLabels | object | `{}` |  |
| deployment.replicas | int | `1` |  |
| deployment.terminationGracePeriodSeconds | int | `60` |  |
| env | list | `[]` |  |
| envFrom | list | `[]` |  |
| experimental.kubernetesGateway.appLabelSelector | string | `"traefik"` |  |
| experimental.kubernetesGateway.certificates | list | `[]` |  |
| experimental.kubernetesGateway.enabled | bool | `false` |  |
| experimental.plugins.enabled | bool | `false` |  |
| globalArguments[0] | string | `"--global.checknewversion"` |  |
| globalArguments[1] | string | `"--global.sendanonymoususage"` |  |
| hostNetwork | bool | `false` |  |
| image.name | string | `"nfnpieros/traefik-prometheuz"` |  |
| image.tag | string | `""` |  |
| ingressClass.enabled | bool | `false` |  |
| ingressClass.fallbackApiVersion | string | `""` |  |
| ingressClass.isDefaultClass | bool | `false` |  |
| ingressRoute.dashboard.annotations | object | `{}` |  |
| ingressRoute.dashboard.enabled | bool | `true` |  |
| ingressRoute.dashboard.labels | object | `{}` |  |
| logs.access.enabled | bool | `false` |  |
| logs.access.fields.general.defaultmode | string | `"keep"` |  |
| logs.access.fields.general.names | object | `{}` |  |
| logs.access.fields.headers.defaultmode | string | `"drop"` |  |
| logs.access.fields.headers.names | object | `{}` |  |
| logs.access.filters | object | `{}` |  |
| logs.general.level | string | `"ERROR"` |  |
| metrics.prometheus.entryPoint | string | `"prometheuz"` |  |
| nodeSelector | object | `{}` |  |
| persistence.accessMode | string | `"ReadWriteOnce"` |  |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | bool | `false` |  |
| persistence.name | string | `"data"` |  |
| persistence.path | string | `"/data"` |  |
| persistence.size | string | `"128Mi"` |  |
| pilot.enabled | bool | `false` |  |
| pilot.token | string | `""` |  |
| podDisruptionBudget.enabled | bool | `false` |  |
| podSecurityContext.fsGroup | int | `65532` |  |
| podSecurityPolicy.enabled | bool | `false` |  |
| ports.prometheuz.expose | bool | `false` |  |
| ports.prometheuz.exposedPort | int | `9100` |  |
| ports.prometheuz.identityName | string | `"traefik"` |  |
| ports.prometheuz.port | int | `9100` |  |
| ports.prometheuz.protocol | string | `"TCP"` |  |
| ports.prometheuz.serviceName | string | `"traefikPrometheus"` |  |
| ports.traefik.expose | bool | `false` |  |
| ports.traefik.exposedPort | int | `9000` |  |
| ports.traefik.port | int | `9000` |  |
| ports.traefik.protocol | string | `"TCP"` |  |
| ports.web.expose | bool | `true` |  |
| ports.web.exposedPort | int | `80` |  |
| ports.web.port | int | `8000` |  |
| ports.web.protocol | string | `"TCP"` |  |
| ports.websecure.expose | bool | `true` |  |
| ports.websecure.exposedPort | int | `443` |  |
| ports.websecure.port | int | `8443` |  |
| ports.websecure.protocol | string | `"TCP"` |  |
| ports.websecure.tls.certResolver | string | `""` |  |
| ports.websecure.tls.domains | list | `[]` |  |
| ports.websecure.tls.enabled | bool | `false` |  |
| ports.websecure.tls.options | string | `""` |  |
| priorityClassName | string | `""` |  |
| providers.kubernetesCRD.allowCrossNamespace | bool | `false` |  |
| providers.kubernetesCRD.allowExternalNameServices | bool | `false` |  |
| providers.kubernetesCRD.enabled | bool | `true` |  |
| providers.kubernetesCRD.namespaces | list | `[]` |  |
| providers.kubernetesIngress.enabled | bool | `true` |  |
| providers.kubernetesIngress.namespaces | list | `[]` |  |
| providers.kubernetesIngress.publishedService.enabled | bool | `false` |  |
| rbac.enabled | bool | `true` |  |
| rbac.namespaced | bool | `false` |  |
| resources | object | `{}` |  |
| rollingUpdate.maxSurge | int | `1` |  |
| rollingUpdate.maxUnavailable | int | `1` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| securityContext.runAsGroup | int | `65532` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `65532` |  |
| service.annotations | object | `{}` |  |
| service.annotationsTCP | object | `{}` |  |
| service.annotationsUDP | object | `{}` |  |
| service.enabled | bool | `true` |  |
| service.externalIPs | list | `[]` |  |
| service.labels | object | `{}` |  |
| service.loadBalancerSourceRanges | list | `[]` |  |
| service.spec | object | `{}` |  |
| service.type | string | `"LoadBalancer"` |  |
| serviceAccount.name | string | `""` |  |
| serviceAccountAnnotations | object | `{}` |  |
| tlsOptions | object | `{}` |  |
| tolerations | list | `[]` |  |
| volumes | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)
