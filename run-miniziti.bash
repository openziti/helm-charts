#!/usr/bin/env bash
# run-miniziti.bash — mirrors .github/workflows/miniziti.yml
#
# Called by the workflow for all application-level stages (after the
# Actions-specific setup: checkout, minikube, ziti CLI, miniziti install).
# Also runnable standalone for local reproduction.
#
# Workflow usage:
#   bash run-miniziti.bash testvalues baseline proxy-test zrok upgrade verify proxy-test zrok-test
#   bash run-miniziti.bash testvalues upgrade verify proxy-test zrok-test  # SKIP_BASELINE path
#   bash run-miniziti.bash debug                                           # always / on failure
#
# Local usage:
#   MINIZITI_REF=codify-jwks-orchestration ALWAYS_DEBUG=1 bash -x ./run-miniziti.bash
#   SKIP_BASELINE=1 ./run-miniziti.bash          # upgrade-only (skips baseline + zrok stages)
#   ./run-miniziti.bash clean minikube prereqs testvalues upgrade debug
#
# Stages:
#   clean        (local) delete the minikube profile and miniziti state dir
#   minikube     (local) start a fresh minikube cluster with ZITI_NAMESPACE profile
#   prereqs      (local) install ziti CLI and miniziti to ~/.local/bin
#   testvalues   write helm override YAML files to ./testvalues/
#   baseline     miniziti start with latest stable release charts
#   proxy-test   exec ziti ops verify traffic inside the controller container
#   zrok         install zrok from latest release (test.enabled=false)
#   upgrade        miniziti start --charts ./charts --check-cert-subject
#   verify         curl-check the ZAC console is accessible
#   restart-ctrl   rollout restart ziti-controller + wait for ready
#   restart-router rollout restart ziti-router + wait for ready
#   zrok-test      upgrade zrok (test.enabled=true) and wait for the test job
#   debug          dump pod/log/service/network state (best-effort)
#
# Environment variables:
#   ZITI_NAMESPACE          minikube profile / k8s namespace  (default: miniziti)
#   MINIZITI_TIMEOUT_SECS   timeout passed to miniziti start   (default: 300)
#   MINIZITI_REF            git ref for local miniziti install  (default: codify-jwks-orchestration)
#   MINIZITI_VERSION        if set, pins image.tag in testvalues (controller + router)
#   KUBERNETES_VERSION      if set, passed as --kubernetes-version to minikube start
#   SKIP_BASELINE           set 1 to run the upgrade-only pipeline locally
#   ALWAYS_DEBUG            set 1 to run the debug stage even on success

set -euo pipefail

# ── config ────────────────────────────────────────────────────────────────────
ZITI_NAMESPACE="${ZITI_NAMESPACE:-miniziti}"
MINIZITI_TIMEOUT_SECS="${MINIZITI_TIMEOUT_SECS:-300}"
MINIZITI_REF="${MINIZITI_REF:-codify-jwks-orchestration}"
SKIP_BASELINE="${SKIP_BASELINE:-0}"
ALWAYS_DEBUG="${ALWAYS_DEBUG:-0}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# TESTVALUES_DIR can be overridden via environment for parallel/isolated runs
TESTVALUES_DIR="${TESTVALUES_DIR:-${REPO_ROOT}/testvalues}"
LOCAL_BIN="${HOME}/.local/bin"

# ── logging ───────────────────────────────────────────────────────────────────
log_stage() { echo; printf '══════════════════════════════════════════════\n  STAGE: %s\n══════════════════════════════════════════════\n' "$*"; }
log_info()  { printf '  ▶ %s\n' "$*"; }
log_ok()    { printf '  ✓ %s\n' "$*"; }

# ── miniziti wrapper ──────────────────────────────────────────────────────────
# Always forward --profile so that parallel workers with different ZITI_NAMESPACE
# values each target their own minikube profile.  miniziti's internal
# MINIKUBE_PROFILE is not inherited from the environment — it must be passed
# explicitly via the --profile flag.  With the default ZITI_NAMESPACE=miniziti
# this is equivalent to the previous behaviour.
miniziti() { command miniziti --profile "${ZITI_NAMESPACE}" "$@"; }

# ── cluster helpers ───────────────────────────────────────────────────────────
get_ingress_zone() {
    miniziti kubectl get configmap miniziti-config \
        -n "${ZITI_NAMESPACE}" -o jsonpath='{.data.ingress-zone}'
}
get_ziti_pwd() {
    miniziti kubectl get secrets "ziti-controller-admin-secret" \
        -n "${ZITI_NAMESPACE}" \
        --output go-template='{{index .data "admin-password" | base64decode }}'
}

# ── stage: clean ──────────────────────────────────────────────────────────────
stage_clean() {
    log_stage clean

    # always attempt delete; minikube exits 0 if profile does not exist
    log_info "deleting minikube profile: ${ZITI_NAMESPACE}"
    minikube delete --profile "${ZITI_NAMESPACE}" || true

    local state_dir="${HOME}/.local/state/miniziti/profiles/${ZITI_NAMESPACE}"
    if [[ -d "${state_dir}" ]]; then
        log_info "removing miniziti state: ${state_dir}"
        rm -rf "${state_dir}"
    fi

    log_ok "clean done"
}

# ── stage: minikube ───────────────────────────────────────────────────────────
stage_minikube() {
    log_stage minikube
    local -a k8s_args=()
    [[ -n "${KUBERNETES_VERSION}" ]] && k8s_args=(--kubernetes-version="${KUBERNETES_VERSION}")
    minikube start --profile "${ZITI_NAMESPACE}" "${k8s_args[@]}"
    log_ok "minikube running"
}

# ── stage: prereqs ────────────────────────────────────────────────────────────
# Installs ziti CLI and miniziti to ~/.local/bin (no sudo required).
# In CI the workflow installs these via supplypike/setup-bin; this stage is
# only needed for standalone local runs.
stage_prereqs() {
    log_stage prereqs
    mkdir -p "${LOCAL_BIN}"

    local ziti_tag ziti_ver arch tmp
    ziti_tag="$(curl -sSf https://api.github.com/repos/openziti/ziti/releases/latest \
        | jq -r '.tag_name')"
    ziti_ver="${ziti_tag#v}"
    arch="$(uname -m)"; [[ "${arch}" == "x86_64" ]] && arch=amd64 || arch=arm64

    # skip ziti download if already at the target version
    if command -v ziti &>/dev/null && ziti version 2>/dev/null | grep -qF "v${ziti_ver}"; then
        log_ok "ziti ${ziti_ver} already installed at $(command -v ziti)"
    else
        log_info "installing ziti ${ziti_ver} (linux/${arch}) to ${LOCAL_BIN}"
        tmp="$(mktemp -d)"
        curl -fsSL \
            "https://github.com/openziti/ziti/releases/download/${ziti_tag}/ziti-linux-${arch}-${ziti_ver}.tar.gz" \
            | tar -xz -C "${tmp}"
        # archive extracts a single 'ziti' binary at the root of the tar
        install -m 0755 "${tmp}/ziti" "${LOCAL_BIN}/ziti"
        rm -rf "${tmp}"
        log_ok "installed ziti ${ziti_ver}"
    fi

    # always (re-)fetch miniziti for the configured ref so the version is authoritative
    log_info "installing miniziti from ref ${MINIZITI_REF} to ${LOCAL_BIN}"
    curl -fsSL \
        "https://raw.githubusercontent.com/openziti/ziti/${MINIZITI_REF}/quickstart/kubernetes/miniziti.bash" \
        -o "${LOCAL_BIN}/miniziti"
    chmod +x "${LOCAL_BIN}/miniziti"
    log_ok "installed miniziti (${MINIZITI_REF})"

    # ensure LOCAL_BIN is on PATH for the remainder of this process
    export PATH="${LOCAL_BIN}:${PATH}"
    log_info "PATH prefix: ${LOCAL_BIN}"
}

# ── stage: testvalues ─────────────────────────────────────────────────────────
stage_testvalues() {
    log_stage testvalues
    mkdir -p "${TESTVALUES_DIR}"

    cat > "${TESTVALUES_DIR}/ziti-controller.yaml" <<'EOF'
image:
  additionalArgs:
    - --verbose
EOF
    cat > "${TESTVALUES_DIR}/ziti-router.yaml" <<'EOF'
image:
  additionalArgs:
    - --verbose
EOF
    cat > "${TESTVALUES_DIR}/httpbin.yaml" <<'EOF'
debug: true
EOF

    if [[ -n "${MINIZITI_VERSION:-}" ]]; then
        log_info "pinning image.tag=${MINIZITI_VERSION}"
        printf '  tag: "%s"\n' "${MINIZITI_VERSION}" >> "${TESTVALUES_DIR}/ziti-controller.yaml"
        printf '  tag: "%s"\n' "${MINIZITI_VERSION}" >> "${TESTVALUES_DIR}/ziti-router.yaml"
    fi

    log_ok "testvalues written"
    ls -1 "${TESTVALUES_DIR}"
}

# ── stage: baseline ───────────────────────────────────────────────────────────
stage_baseline() {
    log_stage "baseline (latest release charts)"
    MINIZITI_TIMEOUT_SECS="${MINIZITI_TIMEOUT_SECS}" \
        miniziti start --no-hosts --verbose --values-dir "${TESTVALUES_DIR}"
    log_ok "baseline install complete"
}

# ── stage: proxy-test ─────────────────────────────────────────────────────────
# Runs "ziti ops verify traffic" inside the controller container so we use the
# exact ziti binary shipped with the deployed image, with no local CLI required.
# $ZITI_ADMIN_PASSWORD and $ZITI_CTRL_PLANE_CA are already set in the container
# by the Helm chart (sourced from the admin-secret and the ctrl-plane-cas mount).
stage_proxy_test() {
    log_stage "proxy-test (ziti ops verify traffic inside controller container)"

    # zitiLogin is a chart-installed script (configmap.yaml) that runs
    # "ziti edge login $ZITI_MGMT_API --ca $ZITI_CTRL_PLANE_CA/ctrl-plane-cas.crt".
    # Calling it first ensures ziti-cli.json exists even after a controller-pod
    # restart (which wipes the container's ephemeral filesystem).
    #
    # --ca must point to a FILE; $ZITI_CTRL_PLANE_CA is a directory.
    # The chart template renders ctrlPlaneCasFile as "ctrl-plane-cas.crt"
    # (_helpers.tpl), so the full path is $ZITI_CTRL_PLANE_CA/ctrl-plane-cas.crt.
    #
    # ${ZITI_NAMESPACE} is expanded by the host shell; $ZITI_ADMIN_PASSWORD and
    # $ZITI_CTRL_PLANE_CA are expanded by the container shell.
    local max_attempts=10 delay=3 attempt
    for (( attempt = 1; attempt <= max_attempts; attempt++ )); do
        if miniziti kubectl exec \
            -n "${ZITI_NAMESPACE}" \
            deployments/ziti-controller \
            -c ziti-controller \
            -- \
            sh -c 'zitiLogin > /dev/null 2>&1 && ziti ops verify traffic \
                --timeout 60 \
                --prefix '"${ZITI_NAMESPACE}"' \
                --password "$ZITI_ADMIN_PASSWORD" \
                --ca "$ZITI_CTRL_PLANE_CA/ctrl-plane-cas.crt" \
                --cleanup' 2>/dev/null; then
            log_ok "traffic verified"
            return 0
        fi
        if (( attempt < max_attempts )); then
            echo "  retry ${attempt}/${max_attempts} — waiting ${delay}s …" >&2
            sleep "${delay}"
        fi
    done
    echo "ERROR: ziti ops verify traffic failed after ${max_attempts} attempts" >&2
    return 1
}

# ── stage: zrok ───────────────────────────────────────────────────────────────
stage_zrok() {
    log_stage "zrok (latest release, test.enabled=false)"
    local ingress_zone ziti_pwd
    ingress_zone="$(get_ingress_zone)"
    ziti_pwd="$(get_ziti_pwd)"

    helm upgrade --install \
        --kube-context "${ZITI_NAMESPACE}" \
        --namespace zrok --create-namespace \
        --values "${REPO_ROOT}/charts/zrok/values-ingress-traefik.yaml" \
        --set "ziti.advertisedHost=${ZITI_NAMESPACE}-controller.${ingress_zone}" \
        --set "ziti.password=${ziti_pwd}" \
        --set "dnsZone=${ingress_zone}" \
        --set "controller.ingress.hosts[0]=zrok.${ingress_zone}" \
        --set "test.enabled=false" \
        zrok openziti/zrok

    log_ok "zrok installed (test.enabled=false)"
}

# ── stage: upgrade ────────────────────────────────────────────────────────────
stage_upgrade() {
    log_stage "upgrade (branch charts + --check-cert-subject)"
    MINIZITI_TIMEOUT_SECS="${MINIZITI_TIMEOUT_SECS}" \
        miniziti start \
            --no-hosts \
            --verbose \
            --charts "${REPO_ROOT}/charts" \
            --values-dir "${TESTVALUES_DIR}" \
            --check-cert-subject
    log_ok "upgrade complete"
}

# ── stage: restart-ctrl ───────────────────────────────────────────────────────
# Simulate the CI condition: force a new ephemeral OIDC signing key by restarting
# the controller pod, then wait for rollout to complete.  The router is NOT
# restarted, so its JWKS cache still holds the old key — the subsequent
# proxy-test stage should expose the JWT validation failure.
stage_restart_ctrl() {
    log_stage "restart-ctrl (rollout restart ziti-controller)"
    miniziti kubectl rollout restart deployment/ziti-controller \
        -n "${ZITI_NAMESPACE}"
    miniziti kubectl rollout status deployment/ziti-controller \
        -n "${ZITI_NAMESPACE}" --timeout "${MINIZITI_TIMEOUT_SECS}s"
    log_ok "controller restarted and ready"
}

# ── stage: restart-router ──────────────────────────────────────────────────────
# Force the router to reconnect and re-fetch the controller's JWKS endpoint,
# picking up any new OIDC signing key generated after a controller restart.
stage_restart_router() {
    log_stage "restart-router (rollout restart ziti-router)"
    miniziti kubectl rollout restart deployment/ziti-router \
        -n "${ZITI_NAMESPACE}"
    miniziti kubectl rollout status deployment/ziti-router \
        -n "${ZITI_NAMESPACE}" --timeout "${MINIZITI_TIMEOUT_SECS}s"
    log_ok "router restarted and ready"
}

# ── stage: verify ─────────────────────────────────────────────────────────────
stage_verify() {
    log_stage "verify (ZAC console reachable)"
    local ingress_zone status
    ingress_zone="$(get_ingress_zone)"
    status="$(curl -skSfw '%{http_code}' -o/dev/null \
        "https://${ZITI_NAMESPACE}-controller.${ingress_zone}/zac/")"
    log_info "HTTP ${status} — https://${ZITI_NAMESPACE}-controller.${ingress_zone}/zac/"
    [[ "${status}" == "200" ]] \
        || { printf 'ERROR: ZAC console returned HTTP %s\n' "${status}" >&2; exit 1; }
    log_ok "ZAC console accessible"
}

# ── stage: zrok-test ──────────────────────────────────────────────────────────
stage_zrok_test() {
    log_stage "zrok-test (branch chart, test.enabled=true)"
    local ingress_zone ziti_pwd
    ingress_zone="$(get_ingress_zone)"
    ziti_pwd="$(get_ziti_pwd)"

    helm upgrade --install \
        --kube-context "${ZITI_NAMESPACE}" \
        --namespace zrok --create-namespace \
        --values "${REPO_ROOT}/charts/zrok/values-ingress-traefik.yaml" \
        --set "ziti.advertisedHost=${ZITI_NAMESPACE}-controller.${ingress_zone}" \
        --set "ziti.password=${ziti_pwd}" \
        --set "dnsZone=${ingress_zone}" \
        --set "controller.ingress.hosts[0]=zrok.${ingress_zone}" \
        --set "test.enabled=true" \
        zrok "${REPO_ROOT}/charts/zrok"

    log_info "waiting for zrok-test-job (240s)..."
    miniziti kubectl -n zrok wait \
        --for=condition=complete \
        --timeout=240s \
        job/zrok-test-job
    log_ok "zrok-test-job passed"
}

# ── stage: debug ──────────────────────────────────────────────────────────────
stage_debug() {
    log_stage debug
    set +e  # best-effort: collect everything even if individual commands fail

    echo "--- pods (all namespaces) ---"
    miniziti kubectl get pods -A

    echo "--- services (all namespaces) ---"
    miniziti kubectl get services -A

    echo "--- ingresses (all namespaces) ---"
    miniziti kubectl get ingresses -A

    echo "--- secrets (${ZITI_NAMESPACE}) ---"
    miniziti kubectl get secrets -n "${ZITI_NAMESPACE}" \
        -o custom-columns='NAME:.metadata.name,CREATED:.metadata.creationTimestamp'

    echo "--- ziti-controller logs (last 100) ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/component=ziti-controller \
        -n "${ZITI_NAMESPACE}" --tail=100

    echo "--- ziti-router logs (last 100) ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/component=ziti-router \
        -n "${ZITI_NAMESPACE}" --tail=100

    echo "--- zrok controller bootstrap logs ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/name=zrok-controller \
        -n zrok -c zrok-bootstrap --tail=-1 || true

    echo "--- zrok controller logs ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/name=zrok-controller \
        -n zrok -c zrok --tail=-1 || true

    echo "--- zrok frontend bootstrap logs ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/name=zrok-frontend \
        -n zrok -c zrok-bootstrap-frontend --tail=-1 || true

    echo "--- zrok frontend logs ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/name=zrok-frontend \
        -n zrok -c zrok-frontend --tail=-1 || true

    echo "--- zrok-test-job logs ---"
    miniziti kubectl -n zrok logs job/zrok-test-job || true

    echo "--- httpbin logs (full) ---"
    miniziti kubectl logs \
        --selector app.kubernetes.io/name=httpbin \
        -n "${ZITI_NAMESPACE}" --tail=-1 || true

    echo "--- ziti network state ---"
    miniziti login || true
    ziti edge policy-advisor services --quiet httpbin-service || true
    ziti edge list terminators || true
    ziti edge list identities || true
    ziti edge list services || true
    ziti edge list service-policies || true

    set -e
    log_ok "debug dump complete"
}

# ── dispatch ──────────────────────────────────────────────────────────────────
run_stage() {
    case "$1" in
        clean)       stage_clean ;;
        minikube)    stage_minikube ;;
        prereqs)     stage_prereqs ;;
        testvalues)  stage_testvalues ;;
        baseline)    stage_baseline ;;
        proxy-test)  stage_proxy_test ;;
        zrok)        stage_zrok ;;
        upgrade)     stage_upgrade ;;
        verify)         stage_verify ;;
        restart-ctrl)   stage_restart_ctrl ;;
        restart-router) stage_restart_router ;;
        zrok-test)      stage_zrok_test ;;
        debug)          stage_debug ;;
        *) printf 'ERROR: unknown stage "%s"\n' "$1" >&2; exit 1 ;;
    esac
}

main() {
    local -a stages=("$@")

    if [[ ${#stages[@]} -eq 0 ]]; then
        if [[ "${SKIP_BASELINE}" == "1" ]]; then
            stages=(clean minikube prereqs testvalues upgrade verify proxy-test zrok-test)
        else
            stages=(clean minikube prereqs testvalues baseline proxy-test zrok upgrade verify proxy-test zrok-test)
        fi
    fi

    for s in "${stages[@]}"; do
        run_stage "${s}"
    done

    [[ "${ALWAYS_DEBUG}" == "1" ]] && stage_debug

    echo
    log_ok "all requested stages completed"
}

main "$@"
