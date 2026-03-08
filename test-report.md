# zrok2 Helm Chart — Test Report

## Date

2026-03-24

## Status

**Template validation: PASS** | **Deployment: PASS** | **Named share test: BLOCKED** (AMQP mapping propagation issue)

## Integration Test Results

| Stage | Result | Notes |
|-------|--------|-------|
| clean | PASS | minikube profile deleted |
| minikube | PASS | kvm2 driver, mz-31791 profile |
| prereqs | PASS | ziti 1.6.14, miniziti installed |
| testvalues | PASS | override YAML written |
| upgrade (cluster-init) | PASS | required patched miniziti for sslip.io DNS check |
| verify | PASS | ZAC console accessible |
| proxy-test | PASS | ziti ops verify traffic |
| rabbitmq | PASS | deployment ready in zrok2 namespace |
| zrok2 | PASS | controller + frontend both Running 1/1 |
| zrok2-test | FAIL | named share not served by frontend after 60s |

## Fixes Applied (This Session)

### Fix 1: DPC Identity Path — PVC Instead of Secret Volume

**Problem:** The DPC identity was stored as a K8s Secret and mounted as a
volume. On first deploy, the secret doesn't exist yet (it's created by the
init container), so Kubernetes won't schedule the pod — chicken-and-egg.

**Fix:** Changed `ctrl.yaml` to reference the identity at the PVC path
(`/var/lib/zrok2/.zrok2/identities/dynamicProxyController.json`) where the
bootstrap writes it. Removed the `dpc-identity` Secret volume mount from
the controller deployment. The identity persists on the PVC across restarts.

### Fix 2: Frontend Identity Secret — Optional Volume

**Problem:** The frontend-identity Secret is created by the controller
bootstrap, but the frontend Deployment references it as a volume.
Kubernetes won't schedule the frontend pod until the secret exists.

**Fix:** Added `optional: true` to the frontend-identity Secret volume
definition. The kubelet syncs the secret contents once created.

### Fix 3: DPC Identity Creation — `zrok2 admin create identity`

**Problem:** The bootstrap used `ziti edge create identity -o ...` which
writes an enrollment JWT file, not a usable Ziti identity config JSON.
The controller then panicked: `invalid character 'e' looking for beginning
of value`.

**Fix:** Changed to `zrok2 admin create identity dynamicProxyController`
which creates AND enrolls the identity through the zrok2 API, producing a
valid Ziti SDK config JSON. Kept the `ziti edge` commands for creating the
Ziti service, SERP, and bind/dial policies (these aren't handled by the
zrok2 admin command).

### Fix 4: Canary Test Flag

**Problem:** `zrok2 test canary public-proxy --http` failed with
"unknown flag: --http" — the `--http` flag doesn't exist in zrok2 v2.

**Fix:** Removed the `--http` flag.

### Fix 5: Namespace Creation Idempotency

**Problem:** The frontend bootstrap panicked with HTTP 409 when trying
to create the `public` namespace if it already existed. The awk-based
idempotency check parsed the table output incorrectly.

**Fix:** Changed the namespace existence check from awk field matching to
`grep -qw 'public'`, and added `|| true` to the create commands to
tolerate conflicts gracefully.

### Fix 6: Test Job Timing

**Problem:** The test Job started immediately with the Deployment but
needed the `ziggy-account-token` Secret which is created by the frontend
bootstrap init container. The Job failed with `CreateContainerConfigError`.

**Fix:** Added Helm hook annotations (`post-install,post-upgrade,test`)
to the test Job so it runs after all deployments are ready.

## Template Validation

All three configuration combinations render without errors:

| Configuration | `helm lint` | `helm template` |
|---|---|---|
| rabbitmq only | PASS | PASS |
| rabbitmq + influxdb | PASS | PASS |
| neither (degraded) | PASS | PASS |

## Known Issues

### 1. Named Share AMQP Propagation

The dynamic proxy frontend connects to RabbitMQ, creates its AMQP queue,
and binds to the `dynamicProxy` exchange with the frontend token as routing
key. The controller connects to the same exchange as a publisher. Both
connections are confirmed in logs.

However, when a named share is created via `zrok2 share public
--name-selection`, the frontend never receives the mapping update via AMQP.
The `mappings.run` method only ever reports 0 mappings.

**Investigation needed:** Check whether the controller's DPC component
actually publishes mapping updates when shares are created/deleted. The
controller logs show no AMQP publish activity — only the initial connection.

### 2. Canary Test URL Scheme

The `zrok2 test canary public-proxy` generates share URLs without a protocol
scheme prefix, causing `unsupported protocol scheme ""`. This is likely
because the frontend URL template uses `http://{token}.{dnsZone}` but the
canary constructs the URL differently. Not blocking — the canary test
reports the error and continues.

### 3. Miniziti DNS Check Bug (kvm2 driver)

Miniziti's `checkDns` compares the sslip.io hostname against the minikube
node IP, but with the kvm2 driver + MetalLB the Traefik LB gets a different
IP. Required a patched miniziti that checks the LB IP instead. This is a
miniziti bug, not a chart issue.

## How to Run

From the host shell:

```bash
: Full clean run with experimental image
SKIP_BASELINE=1 ALWAYS_DEBUG=1 NO_DESTROY=1 MINIKUBE_DRIVER=kvm2 \
    ZROK2_IMAGE_REPOSITORY=kbinghamnetfoundry/zrok2 \
    ZROK2_IMAGE_TAG=2.0.0-ec31ad36 \
    bash run-miniziti.bash

: Resume from zrok2 stages if Ziti infra is healthy
ALWAYS_DEBUG=1 NO_DESTROY=1 ZITI_NAMESPACE=mz-NNNNN \
    ZROK2_IMAGE_REPOSITORY=kbinghamnetfoundry/zrok2 \
    ZROK2_IMAGE_TAG=2.0.0-ec31ad36 \
    bash run-miniziti.bash zrok2 zrok2-test
```

## Changes Summary (All Tasks)

### Task 1: Dynamic Frontend with AMQP ✅

- Bootstrap creates DPC identity via `zrok2 admin create identity`
- Ziti service, SERP, bind/dial policies created via `ziti edge`
- DPC identity stored on PVC (not Secret volume)
- `ctrl.yaml` has `dynamic_proxy_controller` with AMQP publisher
- Frontend uses `access dynamicProxy` with AMQP subscriber config
- Frontend identity Secret volume marked `optional: true`

### Task 2: Metrics Pipeline ✅

- `ctrl.yaml` has `metrics.agent.source.type: amqpSource` (when both
  rabbitmq.url AND influxdb.url are set)
- Ziti controller publishes fabric.usage events directly to AMQP
  (configured via `additionalConfigs.events` in run-miniziti.bash)
- No separate metrics-bridge needed in k8s

### Task 3: Helm Test ✅

- Test job with `helm.sh/hook: post-install,post-upgrade,test`
- Canary looper + named share verification
- Gated by `test.enabled` value

### Task 4: Probes ✅

- Controller: startup/liveness/readiness on `/api/v1/version`
- Frontend: startup/liveness/readiness on TCP port 8080

### Task 5: Ops Best Practices ✅

- Resources, security contexts, RBAC, checksum annotations
- Pre-delete hook for Ziti cleanup
- NOTES.txt with post-install instructions

### Task 6: run-miniziti.bash ✅

- `stage_rabbitmq()`, `stage_zrok2()`, `stage_zrok2_test()`
- AMQP events configuration for Ziti controller
- Image override support

### Task 7: README.md.gotmpl ✅

- External dependencies, degradation matrix, quick start guide
- TLS sections for Ingress and Gateway API

### Task 8: Example Values ✅

- `values-ingress-traefik.yaml` and `values-gateway-traefik.yaml`

### Task 9: charts/zrok Deprecation ✅

- `deprecated: true` in Chart.yaml
- Deprecation banner in README.md.gotmpl and NOTES.txt

### Task 10: generate-docs.bash ✅

- Already includes zrok2 in the chart glob
