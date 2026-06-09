#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-workshop.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Run this from the directory that contains workshop.env." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"
if [[ -f workshop-outputs.env ]]; then
  # shellcheck disable=SC1091
  source workshop-outputs.env
fi

export OCI_CLI_REGION="${REGION:-}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-x402-market-deployment}"
PATH_PREFIX="${PATH_PREFIX:-/v1}"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Set $name in workshop.env or workshop-outputs.env before running this script." >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd oci
require_cmd jq
require_var API_GATEWAY_OCID
require_var FUNCTIONS_APP_OCID
require_var REGION

FUNCTION_OCID="$(oci fn function list --application-id "$FUNCTIONS_APP_OCID" --all | jq -r '.data[] | select(."display-name" == "x402-middleware") | .id' | head -n 1)"
if [[ -z "$FUNCTION_OCID" ]]; then
  echo "Could not find x402-middleware in Functions application $FUNCTIONS_APP_OCID." >&2
  exit 1
fi

EXISTING_DEPLOYMENT_OCID="$(oci api-gateway deployment list --compartment-id "$COMPARTMENT_OCID" --gateway-id "$API_GATEWAY_OCID" --all | jq -r --arg name "$DEPLOYMENT_NAME" '.data[]? | select(."display-name" == $name) | .id' | head -n 1)"

SPEC_FILE="$(mktemp)"
jq -n --arg functionId "$FUNCTION_OCID" '{
  routes: [
    "/market/signals",
    "/market/products",
    "/market/segments",
    "/market/pricing"
  ] | map({
    path: .,
    methods: ["GET"],
    backend: {
      type: "ORACLE_FUNCTIONS_BACKEND",
      functionId: $functionId
    },
    requestPolicies: {
      queryParameterValidations: {
        parameters: {}
      }
    }
  })
}' > "$SPEC_FILE"

if [[ -n "$EXISTING_DEPLOYMENT_OCID" ]]; then
  oci api-gateway deployment update \
    --deployment-id "$EXISTING_DEPLOYMENT_OCID" \
    --specification "file://$SPEC_FILE" \
    --force \
    --wait-for-state ACTIVE >/dev/null
  DEPLOYMENT_OCID="$EXISTING_DEPLOYMENT_OCID"
else
  DEPLOYMENT_OCID="$(oci api-gateway deployment create \
    --compartment-id "$COMPARTMENT_OCID" \
    --gateway-id "$API_GATEWAY_OCID" \
    --display-name "$DEPLOYMENT_NAME" \
    --path-prefix "$PATH_PREFIX" \
    --specification "file://$SPEC_FILE" \
    --wait-for-state ACTIVE \
    --query "data.id" \
    --raw-output)"
fi

DEPLOYMENT_ENDPOINT="$(oci api-gateway deployment get --deployment-id "$DEPLOYMENT_OCID" --query 'data.endpoint' --raw-output)"

cat >> workshop-outputs.env <<EOF
export API_DEPLOYMENT_OCID="$DEPLOYMENT_OCID"
export GATEWAY_URL="$DEPLOYMENT_ENDPOINT"
EOF

echo "API Gateway deployment is active."
echo "Gateway URL: $DEPLOYMENT_ENDPOINT"
echo "Test unpaid request:"
echo "curl -i \"$DEPLOYMENT_ENDPOINT/market/signals?limit=5\""
