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

FILES_BASE="${WORKSHOP_FILES_BASE:-https://raw.githubusercontent.com/oracle-livelabs/developer/main/x402-api-gateway}"
PROJECT_DIR="${PROJECT_DIR:-x402-middleware}"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" || "${!name}" == replace-* || "${!name}" == 0xYour* ]]; then
    echo "Set $name in $ENV_FILE before running this script." >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd fn
require_var PAY_TO_ADDRESS
require_var REGION
require_var REGION_KEY
require_var TENANCY_NAMESPACE
require_var COMPARTMENT_OCID

mkdir -p "$PROJECT_DIR"
curl -fsSL "$FILES_BASE/deploy-x402-middleware/files/func.js" -o "$PROJECT_DIR/func.js"
curl -fsSL "$FILES_BASE/deploy-x402-middleware/files/package.json" -o "$PROJECT_DIR/package.json"
curl -fsSL "$FILES_BASE/deploy-x402-middleware/files/func.yaml" -o "$PROJECT_DIR/func.yaml"

fn use context default
fn update context oracle.compartment-id "$COMPARTMENT_OCID"
fn update context api-url "https://functions.$REGION.oci.oraclecloud.com"
fn update context registry "$REGION_KEY.ocir.io/$TENANCY_NAMESPACE/x402"

cd "$PROJECT_DIR"
npm install
fn -v deploy --app "${FUNCTIONS_APP_NAME:-x402-functions}"

set_config() {
  fn config function "${FUNCTIONS_APP_NAME:-x402-functions}" x402-middleware "$1" "$2"
}

set_config PAY_TO_ADDRESS "$PAY_TO_ADDRESS"
set_config FACILITATOR_URL "${FACILITATOR_URL:-https://x402.org/facilitator}"
set_config NETWORK "${NETWORK:-eip155:84532}"
set_config ASSET_ADDRESS "${ASSET_ADDRESS:-0x036CbD53842c5426634e7929541eC2318f3dCF7e}"
set_config USDC_EIP712_NAME "${USDC_EIP712_NAME:-USDC}"
set_config USDC_EIP712_VERSION "${USDC_EIP712_VERSION:-2}"

[[ -n "${UPSTREAM_BASE:-}" ]] && set_config UPSTREAM_BASE "$UPSTREAM_BASE"
[[ -n "${ORDS_RECEIPTS_URL:-}" ]] && set_config ORDS_RECEIPTS_URL "$ORDS_RECEIPTS_URL"
[[ -n "${ORDS_CLIENT_ID:-}" ]] && set_config ORDS_CLIENT_ID "$ORDS_CLIENT_ID"
[[ -n "${ORDS_CLIENT_SECRET:-}" ]] && set_config ORDS_CLIENT_SECRET "$ORDS_CLIENT_SECRET"

echo "Middleware project is ready in $PROJECT_DIR and deployed to ${FUNCTIONS_APP_NAME:-x402-functions}."
echo "If UPSTREAM_BASE or ORDS receipt variables were missing, add them to workshop.env and rerun this script."
