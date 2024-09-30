#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

function cleanup() {
    for EMAIL in "${EMAILS[@]}"; do
        ziti edge delete identity "${EMAIL}"
    done
    ziti edge delete auth-policy "${AUTH_POLICY_NAME}"
    ziti edge delete ext-jwt-signer "${EXT_JWT_SIGNER_NAME}"
}

: "${ZITI_BROWZER_FIELD:=email}"
: "${EXT_JWT_SIGNER_NAME:="browzer-auth0-ext-jwt-signer"}"
: "${AUTH_POLICY_NAME:="browzer-auth0-auth-policy"}"

typeset -a EMAILS=(${BROWZER_EMAILS})

issuer=$(curl -s ${ZITI_BROWZER_OIDC_URL}/.well-known/openid-configuration | jq -r .issuer)
jwks=$(curl -s ${ZITI_BROWZER_OIDC_URL}/.well-known/openid-configuration | jq -r .jwks_uri)

echo "OIDC issuer   : $issuer"
echo "OIDC jwks url : $jwks"

if  ziti edge list ext-jwt-signers "name=\"$EXT_JWT_SIGNER_NAME\"" | grep -q $EXT_JWT_SIGNER_NAME; then
    cleanup
fi
ext_jwt_signer=$(ziti edge create ext-jwt-signer "${EXT_JWT_SIGNER_NAME}" "${issuer}" --jwks-endpoint "${jwks}" --audience "${ZITI_BROWZER_CLIENT_ID}" --claims-property ${ZITI_BROWZER_FIELD})
echo "ext jwt signer id: $ext_jwt_signer"

if  ziti edge list auth-policies "name=\"$AUTH_POLICY_NAME\"" | grep -q $AUTH_POLICY_NAME; then
    auth_policy=$(ziti edge update auth-policy "${AUTH_POLICY_NAME}" --primary-ext-jwt-allowed --primary-ext-jwt-allowed-signers ${ext_jwt_signer})
else
    auth_policy=$(ziti edge create auth-policy "${AUTH_POLICY_NAME}" --primary-ext-jwt-allowed --primary-ext-jwt-allowed-signers ${ext_jwt_signer})
fi
echo "auth policy id: $auth_policy"

for EMAIL in "${EMAILS[@]}"; do
    if ziti edge list identities "name=\"${EMAIL}\"" | grep -q "${EMAIL}"; then
        ziti edge update identity "${EMAIL}" --auth-policy ${auth_policy} --external-id "${EMAIL}" -a browzer.enabled.identities
    else
        ziti edge create identity user "${EMAIL}" --auth-policy ${auth_policy} --external-id "${EMAIL}" -a browzer.enabled.identities
    fi
done
