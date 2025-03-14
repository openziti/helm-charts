#!/usr/bin/env bash
#
# set owner labels and annotations for existing cert-manager and trust-manager CRDs and resources to allow a future
# cert-manager and trust-manager Helm releases to import them
#

set -o errexit
set -o pipefail
set -o nounset

: "${CM_NAMESPACE:=cert-manager}"
: "${CM_RELEASE_NAME:=cert-manager}"
: "${TM_NAMESPACE:=cert-manager}"
: "${TM_RELEASE_NAME:=trust-manager}"
: "${ZITI_NAMESPACE:=ziti}"

# cert-manager CRDs, not trust-manager CRD
while read
do
        kubectl annotate crds "$REPLY" --overwrite \
                meta.helm.sh/release-name="${CM_RELEASE_NAME}" \
                meta.helm.sh/release-namespace="${CM_NAMESPACE}"
        kubectl label crds "$REPLY" \
                app.kubernetes.io/managed-by=Helm
done< <(kubectl get crds | grep -v 'bundles\.trust\.cert-manager\.io' | grep -w 'cert-manager\.io' | cut -f 1 -d ' ')

# trust-manager CRD
kubectl annotate crds bundles.trust.cert-manager.io --overwrite \
        meta.helm.sh/release-name="${TM_RELEASE_NAME}" \
        meta.helm.sh/release-namespace="${CM_NAMESPACE}"
kubectl label crds bundles.trust.cert-manager.io \
        app.kubernetes.io/managed-by=Helm

# cluster-wide core resources to be imported by trust-manager
for R in ClusterRole{,Binding} ValidatingWebhookConfiguration
do
        kubectl annotate "$R" "${TM_RELEASE_NAME}" --overwrite \
                meta.helm.sh/release-name="${TM_RELEASE_NAME}" \
                meta.helm.sh/release-namespace="${CM_NAMESPACE}"
        kubectl label "$R" "${TM_RELEASE_NAME}" \
                app.kubernetes.io/managed-by=Helm
done

# namespaced core resources to be imported by trust-manager
for R in Role{,Binding}
do
        kubectl annotate -n "${ZITI_NAMESPACE}" "$R" "${TM_RELEASE_NAME}" --overwrite \
                meta.helm.sh/release-name="${TM_RELEASE_NAME}" \
                meta.helm.sh/release-namespace="${CM_NAMESPACE}"
        kubectl label -n "${ZITI_NAMESPACE}" "$R" "${TM_RELEASE_NAME}" \
                app.kubernetes.io/managed-by=Helm
done
