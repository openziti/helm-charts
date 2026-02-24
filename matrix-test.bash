#!/usr/bin/env bash
# matrix-test.bash — triangulate JWKS stale-cache failure across K8s × ziti versions
#
# Context: see ci-failure-analysis-server-cert-subjects.md
#
# After a ziti-controller pod restart the controller generates a new ephemeral
# OIDC JWT signing key.  The ziti-router caches the JWKS at startup and does
# NOT re-fetch it on reconnect, so JWT validation fails with:
#   "JWT validation failed: public key not found"
#
# Dimensions:
#   K8s minor        : top 3 stable minors (mirrors .github/workflows/miniziti.yml)
#   ziti version     : VERSIONS array
#   restart combo    : A=none  B=ctrl-only  D=ctrl+wait  C=ctrl+router
#
# K8s minor iterations run in parallel; each gets a distinct minikube profile
# (and ZITI_NAMESPACE) of the form "miniziti-1-<minor>" so that minikube
# profiles and k8s contexts never collide.  run-miniziti.bash passes
# --kube-context "${ZITI_NAMESPACE}" to every helm call, so parallel runs are
# fully isolated.
#
# Usage:
#   bash matrix-test.bash
#   VERSIONS="1.6.12 1.7.2" bash matrix-test.bash
#   K8S_MINORS="1.32" VERSIONS="1.7.2" bash matrix-test.bash   # single cell
#   MATRIX_PARALLELISM=1 bash matrix-test.bash                  # serial
#
# Environment variables:
#   VERSIONS              space-separated ziti image versions  (default: 1.6.12 1.7.2 1.8.0-pre5)
#   K8S_MINORS            space-separated K8s minor versions   (default: top 3 stable)
#   MATRIX_PARALLELISM    K8s-minor workers to run at once     (default: 1)
#   WORKER_START_DELAY_SECS seconds to sleep between launching workers (default: 0)
#   MINIZITI_TIMEOUT_SECS forwarded to run-miniziti.bash       (default: 600)
#   UPGRADE_SETTLE_SECS   settle wait after upgrade before combo A (default: 30)
#   JWKS_WAIT_SECS        timed wait after ctrl restart for combo D (default: 300)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/run-miniziti.bash"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RESULTS_FILE="${SCRIPT_DIR}/matrix-results-${TIMESTAMP}.md"
RESULT_DIR="$(mktemp -d -t matrix-results-XXXXXX)"
trap 'rm -rf "${RESULT_DIR}"' EXIT

# ── config ────────────────────────────────────────────────────────────────────
read -ra VERSIONS <<< "${VERSIONS:-1.6.12 1.7.2 1.8.0-pre5}"
MATRIX_PARALLELISM="${MATRIX_PARALLELISM:-1}"
WORKER_START_DELAY_SECS="${WORKER_START_DELAY_SECS:-0}"
UPGRADE_SETTLE_SECS="${UPGRADE_SETTLE_SECS:-30}"
JWKS_WAIT_SECS="${JWKS_WAIT_SECS:-300}"

# Default timeout is higher than run-miniziti.bash's default to account for
# parallel resource contention across multiple clusters
export MINIZITI_TIMEOUT_SECS="${MINIZITI_TIMEOUT_SECS:-600}"

LOCAL_BIN="${HOME}/.local/bin"
export PATH="${LOCAL_BIN}:${PATH}"

# ── logging ───────────────────────────────────────────────────────────────────
ts()  { date -u '+%H:%M:%S'; }
log() { printf '\n[matrix %s] %s\n' "$(ts)" "$*"; }
log_sep() { printf '\n[matrix %s] %s\n' "$(ts)" "═══════════════════════════════════════════════"; }

# ── K8s minor resolution ──────────────────────────────────────────────────────
compute_k8s_minors() {
    local stable major rest minor
    stable="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    stable="${stable#v}"
    major="${stable%%.*}"
    rest="${stable#*.}"
    minor="${rest%%.*}"
    echo "${major}.$((minor)) ${major}.$((minor - 1)) ${major}.$((minor - 2))"
}

resolve_k8s_patch() {
    curl -fsSL "https://dl.k8s.io/release/stable-${1}.txt"
}

# ── K8s namespace/profile name from minor ─────────────────────────────────────
# "1.35" → "miniziti-1-35"   (dots replaced with hyphens)
k8s_ns() { printf 'miniziti-%s' "${1//./-}"; }

# ── helpers ───────────────────────────────────────────────────────────────────
# Run stages that MUST succeed; relies on caller having exported ZITI_NAMESPACE
must_run() { bash "${RUNNER}" "$@"; }

# Run a single stage and write "PASS" or "FAIL" to result_file
probe_and_record() {
    local stage="$1" result_file="$2"
    local exit_code=0
    bash "${RUNNER}" "${stage}" || exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        echo "PASS" > "${result_file}"
    else
        printf '[%s] stage "%s" exited %d → FAIL\n' "${ZITI_NAMESPACE}" "${stage}" "${exit_code}" >&2
        echo "FAIL" > "${result_file}"
    fi
}

# ── per-K8s-minor worker (runs in a background subshell) ──────────────────────
run_k8s_worker() {
    # Clear the parent's EXIT trap so this background subshell does not delete
    # RESULT_DIR when it exits (only the parent should do that cleanup).
    trap - EXIT

    local k8s_minor="$1"
    local k8s_patch="$2"
    local ns
    ns="$(k8s_ns "${k8s_minor}")"

    # Each worker exports its own ZITI_NAMESPACE, KUBERNETES_VERSION, and
    # TESTVALUES_DIR so that all child bash "${RUNNER}" processes are isolated.
    export ZITI_NAMESPACE="${ns}"
    export KUBERNETES_VERSION="${k8s_patch}"
    export TESTVALUES_DIR="${SCRIPT_DIR}/testvalues/${ns}"

    local pfx="[${ns}]"
    printf '%s K8s %s (%s) — starting\n' "${pfx}" "${k8s_minor}" "${k8s_patch}"

    for ver in "${VERSIONS[@]}"; do
        local key="${k8s_minor}__${ver}"
        local iter_start=${SECONDS}
        export MINIZITI_VERSION="${ver}"
        printf '%s ziti %s — deploying fresh cluster [+%ds]\n' "${pfx}" "${ver}" "$((SECONDS - iter_start))"

        must_run clean minikube testvalues baseline zrok upgrade

        # ── settle wait: give router edge-channel time to establish after upgrade
        printf '%s ziti %s — settle wait %ds after upgrade [+%ds]\n' \
            "${pfx}" "${ver}" "${UPGRADE_SETTLE_SECS}" "$((SECONDS - iter_start))"
        sleep "${UPGRADE_SETTLE_SECS}"

        # ── A: no restart ────────────────────────────────────────────────────
        # Expected: PASS (baseline sanity check)
        printf '%s ziti %s — combo A (no restart) [+%ds]\n' "${pfx}" "${ver}" "$((SECONDS - iter_start))"
        probe_and_record proxy-test "${RESULT_DIR}/${key}__no_restart"

        # ── B: ctrl restart only ─────────────────────────────────────────────
        # Expected: FAIL (stale JWKS — router hasn't refreshed its key cache)
        printf '%s ziti %s — combo B (restart-ctrl, no wait) [+%ds]\n' "${pfx}" "${ver}" "$((SECONDS - iter_start))"
        must_run restart-ctrl
        probe_and_record proxy-test "${RESULT_DIR}/${key}__ctrl_only"

        # ── D: ctrl restart + timed wait ─────────────────────────────────────
        # Fresh restart so the wait clock starts from zero; tests whether JWKS
        # cache has a TTL / auto-refresh within JWKS_WAIT_SECS seconds.
        # Expected: FAIL (confirms no self-healing; router restart is required)
        printf '%s ziti %s — combo D (restart-ctrl + %ds wait) [+%ds]\n' \
            "${pfx}" "${ver}" "${JWKS_WAIT_SECS}" "$((SECONDS - iter_start))"
        must_run restart-ctrl
        sleep "${JWKS_WAIT_SECS}"
        probe_and_record proxy-test "${RESULT_DIR}/${key}__ctrl_wait"

        # ── C: ctrl + router restart ─────────────────────────────────────────
        # Expected: PASS (router re-fetches JWKS on startup → fix confirmed)
        printf '%s ziti %s — combo C (restart-router) [+%ds]\n' "${pfx}" "${ver}" "$((SECONDS - iter_start))"
        must_run restart-router
        probe_and_record proxy-test "${RESULT_DIR}/${key}__ctrl_router"

        printf '%s ziti %s — done [+%ds]\n' "${pfx}" "${ver}" "$((SECONDS - iter_start))"
    done

    printf '%s K8s %s — all ziti versions complete\n' "${pfx}" "${k8s_minor}"
}

# ── resolve K8s minors ────────────────────────────────────────────────────────
declare -a K8S_MINORS_ARR
if [[ -n "${K8S_MINORS:-}" ]]; then
    read -ra K8S_MINORS_ARR <<< "${K8S_MINORS}"
else
    log "Computing top 3 stable Kubernetes minors..."
    read -ra K8S_MINORS_ARR <<< "$(compute_k8s_minors)"
fi

log "K8s minors  : ${K8S_MINORS_ARR[*]}"
log "Ziti versions: ${VERSIONS[*]}"
log "Parallelism : ${MATRIX_PARALLELISM} (stagger: ${WORKER_START_DELAY_SECS}s)"

declare -A K8S_PATCH_MAP
for m in "${K8S_MINORS_ARR[@]}"; do
    patch="$(resolve_k8s_patch "${m}")"
    K8S_PATCH_MAP[${m}]="${patch}"
    log "  ${m} → ${patch}"
done

# ── install tooling once (serial, shared across workers) ─────────────────────
log "Installing prerequisites (once)..."
# prereqs uses ZITI_NAMESPACE only for PATH export; any value is fine here
ZITI_NAMESPACE=miniziti bash "${RUNNER}" prereqs

# ── launch parallel K8s workers with concurrency cap ─────────────────────────
declare -a worker_pids=()
declare -a worker_minors=()
active=0

for k8s_minor in "${K8S_MINORS_ARR[@]}"; do
    # Honour concurrency cap: wait for one slot to free up
    while [[ ${active} -ge ${MATRIX_PARALLELISM} ]]; do
        wait "${worker_pids[0]}" || true   # wait for oldest; swallow exit (we record per-probe)
        worker_pids=("${worker_pids[@]:1}")
        worker_minors=("${worker_minors[@]:1}")
        (( active-- )) || true
    done

    if [[ ${#worker_pids[@]} -gt 0 && ${WORKER_START_DELAY_SECS} -gt 0 ]]; then
        log "Delaying ${WORKER_START_DELAY_SECS}s before launching K8s ${k8s_minor} worker..."
        sleep "${WORKER_START_DELAY_SECS}"
    fi
    log "Launching worker for K8s ${k8s_minor} (${K8S_PATCH_MAP[${k8s_minor}]})"
    run_k8s_worker "${k8s_minor}" "${K8S_PATCH_MAP[${k8s_minor}]}" &
    worker_pids+=($!)
    worker_minors+=("${k8s_minor}")
    (( active++ )) || true
done

# Wait for all remaining workers
for pid in "${worker_pids[@]}"; do
    wait "${pid}" || true
done

log_sep
log "All workers finished — aggregating results"
log_sep

# ── terminal summary ──────────────────────────────────────────────────────────
local_wait_label="CTRL+${JWKS_WAIT_SECS}s WAIT"
printf '\n  %-8s  %-14s  %-12s  %-20s  %-24s  %-22s\n' \
    "K8S" "ZITI" "NO-RESTART" "CTRL-ONLY" "${local_wait_label}" "CTRL+ROUTER"
printf '  %-8s  %-14s  %-12s  %-20s  %-24s  %-22s\n' \
    "---" "----" "----------" "---------" "-------------------" "-----------"

read_result() {
    local f="$1"
    if [[ -f "${f}" ]]; then cat "${f}"; else echo "N/A"; fi
}

for k8s_minor in "${K8S_MINORS_ARR[@]}"; do
    for ver in "${VERSIONS[@]}"; do
        key="${k8s_minor}__${ver}"
        printf '  %-8s  %-14s  %-12s  %-20s  %-24s  %-22s\n' \
            "${k8s_minor}" "${ver}" \
            "$(read_result "${RESULT_DIR}/${key}__no_restart")" \
            "$(read_result "${RESULT_DIR}/${key}__ctrl_only")" \
            "$(read_result "${RESULT_DIR}/${key}__ctrl_wait")" \
            "$(read_result "${RESULT_DIR}/${key}__ctrl_router")"
    done
done

# ── write markdown report ─────────────────────────────────────────────────────
log "Writing results to ${RESULTS_FILE}..."
{
cat <<HEADER
# Matrix Test Results: JWKS Stale-Cache Triangulation

**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Branch:** $(git -C "${SCRIPT_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
**Commit:** $(git -C "${SCRIPT_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)
**K8s minors tested:** ${K8S_MINORS_ARR[*]}
**Ziti versions tested:** ${VERSIONS[*]}
**Parallelism:** ${MATRIX_PARALLELISM}

## Background

After a \`ziti-controller\` pod restart the controller generates a new ephemeral
OIDC JWT signing key (not persisted to any Kubernetes Secret). The
\`ziti-router\` caches the controller's JWKS at startup and does **not** re-fetch
it on reconnect to a restarted controller. Any identity that authenticates
against the restarted controller receives a JWT signed with the new key, which
the router rejects with:

> \`JWT validation failed: public key not found\`

See \`ci-failure-analysis-server-cert-subjects.md\` for full analysis.

## Isolation

Each K8s minor version runs in a **separate minikube profile** (and k8s context)
named \`miniziti-1-<minor>\`. All \`helm\` calls pass \`--kube-context\` explicitly,
so parallel workers never touch each other's clusters.

## K8s Patch Versions Resolved

HEADER

for m in "${K8S_MINORS_ARR[@]}"; do
    printf -- '- %s → %s\n' "${m}" "${K8S_PATCH_MAP[${m}]}"
done

printf '\n## Test Procedure\n\n'
printf 'For each (K8s minor, ziti version) pair:\n'
printf '1. Fresh minikube cluster at that K8s patch + baseline + zrok + upgrade to branch charts\n'
printf '2. Settle wait (%ds) after upgrade to allow router edge-channel to establish\n' "${JWKS_WAIT_SECS}"
printf '3. **Combo A** — `proxy-test` with no restarts (should always PASS)\n'
printf '4. **Combo B** — `restart-ctrl` then `proxy-test` (FAIL expected if stale-JWKS bug present)\n'
printf '5. **Combo D** — fresh `restart-ctrl` then wait %ds then `proxy-test`\n' "${JWKS_WAIT_SECS}"
printf '   (tests whether JWKS cache has a TTL / auto-refresh; FAIL → no self-healing)\n'
printf '6. **Combo C** — `restart-router` then `proxy-test` (PASS expected if router restart is the fix)\n\n'
printf 'Sequence per version: A → restart-ctrl → B → restart-ctrl → sleep(%ds) → D → restart-router → C\n\n' "${JWKS_WAIT_SECS}"
printf '`proxy-test` runs `ziti ops verify traffic` inside the controller container\n'
printf 'via `kubectl exec`, exercising end-to-end traffic through the ziti-router.\n'

printf '\n## Results\n\n'
printf '| K8s | Ziti | No Restart | Ctrl Only | Ctrl+%ds Wait | Ctrl+Router |\n' "${JWKS_WAIT_SECS}"
printf '|-----|------|:----------:|:---------:|:--------------:|:-----------:|\n'

for k8s_minor in "${K8S_MINORS_ARR[@]}"; do
    for ver in "${VERSIONS[@]}"; do
        key="${k8s_minor}__${ver}"
        printf '| %-5s | %-14s | %-10s | %-9s | %-14s | %-11s |\n' \
            "${k8s_minor}" "${ver}" \
            "$(read_result "${RESULT_DIR}/${key}__no_restart")" \
            "$(read_result "${RESULT_DIR}/${key}__ctrl_only")" \
            "$(read_result "${RESULT_DIR}/${key}__ctrl_wait")" \
            "$(read_result "${RESULT_DIR}/${key}__ctrl_router")"
    done
done

cat <<FOOTER

## Legend

- **PASS**: \`ziti ops verify traffic\` succeeded (JWT validated, traffic routed)
- **FAIL**: \`ziti ops verify traffic\` failed (\`public key not found\` — stale JWKS)
- **N/A**: stage not reached (earlier stage failed)

## Expected Pattern (stale-JWKS bug present, no self-healing)

| K8s | Ziti | No Restart | Ctrl Only | Ctrl+${JWKS_WAIT_SECS}s Wait | Ctrl+Router |
|-----|------|:----------:|:---------:|:-------------:|:-----------:|
| any | any  | PASS       | **FAIL**  | **FAIL**      | PASS        |

If Ctrl+${JWKS_WAIT_SECS}s Wait shows PASS for any version, the JWKS cache has a TTL < ${JWKS_WAIT_SECS}s for that version.
FOOTER
} > "${RESULTS_FILE}"

log "Full results written to: ${RESULTS_FILE}"
