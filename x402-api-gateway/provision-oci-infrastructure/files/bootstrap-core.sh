#!/usr/bin/env bash
set -Eeuo pipefail

CURRENT_STEP="startup"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

fail_report() {
  local status="$1"
  echo >&2
  echo "Bootstrap failed during: $CURRENT_STEP" >&2
  echo "Command: $BASH_COMMAND" >&2
  echo "Exit code: $status" >&2
  echo >&2
  echo "The script is additive. Fix the reported issue, then rerun it to reuse completed resources." >&2
  exit "$status"
}

trap 'fail_report $?' ERR

ready() {
  local label="$1"
  local value="$2"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "No identifier was returned for $label." >&2
    return 1
  fi
  log "DONE: $label ready: $value"
}

ENV_FILE="${1:-workshop.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy workshop.env.example to workshop.env and edit it first." >&2
  exit 1
fi

if ! bash -n "$ENV_FILE"; then
  echo >&2
  echo "$ENV_FILE has a shell syntax error." >&2
  echo "Check for an export line with a missing closing quote, then rerun this script." >&2
  echo >&2
  nl -ba "$ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" || "${!name}" == replace-* || "${!name}" == ocid1.compartment.oc1..replace* ]]; then
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

require_cmd oci
require_cmd jq
require_var COMPARTMENT_OCID
require_var REGION
require_var REGION_KEY
require_var TENANCY_NAMESPACE
require_var ADB_ADMIN_PASSWORD

export OCI_CLI_REGION="$REGION"

expected_region_key() {
  case "$REGION" in
    us-phoenix-1) echo "phx" ;;
    us-ashburn-1) echo "iad" ;;
    eu-frankfurt-1) echo "fra" ;;
    uk-london-1) echo "lhr" ;;
    *) echo "" ;;
  esac
}

EXPECTED_REGION_KEY="$(expected_region_key)"
if [[ -n "$EXPECTED_REGION_KEY" && "${REGION_KEY,,}" != "$EXPECTED_REGION_KEY" ]]; then
  echo "REGION_KEY does not match REGION in $ENV_FILE." >&2
  echo "REGION=$REGION expects REGION_KEY=$EXPECTED_REGION_KEY, but found REGION_KEY=$REGION_KEY." >&2
  exit 1
fi

json_escape() {
  jq -Rn --arg v "$1" '$v'
}

find_by_display_name() {
  local list_command="$1"
  local display_name="$2"
  eval "$list_command" | jq -r --arg name "$display_name" '
    (
      if (.data | type) == "array" then .data
      elif (.data.items | type) == "array" then .data.items
      else []
      end
    )
    | .[]
    | select(."display-name" == $name or .displayName == $name or .name == $name)
    | .id
  ' | head -n 1
}

get_osn_service_json() {
  local service_json
  service_json="$(oci network service list --all | jq -r '.data[] | select(.name | test("All .* Services In Oracle Services Network")) | @base64' | head -n 1)"
  if [[ -z "$service_json" ]]; then
    echo "Could not find the Oracle Services Network service entry for region $REGION." >&2
    exit 1
  fi
  echo "$service_json"
}

decode_service_field() {
  local service_json="$1"
  local field="$2"
  echo "$service_json" | base64 --decode | jq -r "$field"
}

get_osn_service_id() {
  decode_service_field "$(get_osn_service_json)" '.id'
}

get_osn_service_cidr_label() {
  local service_name
  service_name="$(decode_service_field "$(get_osn_service_json)" '.name')"
  echo "$service_name" | tr '[:upper:] ' '[:lower:]-'
}

ensure_vcn() {
  local id
  id="$(find_by_display_name "oci network vcn list --compartment-id '$COMPARTMENT_OCID' --all" "$VCN_NAME")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  oci network vcn create \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "$VCN_NAME" \
    --cidr-block "10.0.0.0/16" \
    --dns-label "${WORKSHOP_PREFIX}vcn" \
    --wait-for-state AVAILABLE \
    --query "data.id" \
    --raw-output
}

ensure_internet_gateway() {
  local vcn_id="$1"
  local name="${WORKSHOP_PREFIX}-internet-gateway"
  local id
  id="$(find_by_display_name "oci network internet-gateway list --compartment-id '$COMPARTMENT_OCID' --vcn-id '$vcn_id' --all" "$name")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  oci network internet-gateway create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$vcn_id" \
    --is-enabled true \
    --display-name "$name" \
    --wait-for-state AVAILABLE \
    --query "data.id" \
    --raw-output
}

ensure_nat_gateway() {
  local vcn_id="$1"
  local name="${WORKSHOP_PREFIX}-nat-gateway"
  local id
  id="$(find_by_display_name "oci network nat-gateway list --compartment-id '$COMPARTMENT_OCID' --vcn-id '$vcn_id' --all" "$name")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  oci network nat-gateway create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$vcn_id" \
    --display-name "$name" \
    --wait-for-state AVAILABLE \
    --query "data.id" \
    --raw-output
}

ensure_service_gateway() {
  local vcn_id="$1"
  local name="${WORKSHOP_PREFIX}-service-gateway"
  local id service_id services_json
  id="$(find_by_display_name "oci network service-gateway list --compartment-id '$COMPARTMENT_OCID' --vcn-id '$vcn_id' --all" "$name")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  service_id="$(get_osn_service_id)"
  services_json="$(jq -cn --arg serviceId "$service_id" '[{serviceId: $serviceId}]')"
  oci network service-gateway create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$vcn_id" \
    --display-name "$name" \
    --services "$services_json" \
    --wait-for-state AVAILABLE \
    --query "data.id" \
    --raw-output
}

ensure_route_table() {
  local vcn_id="$1"
  local name="$2"
  local rules_json="$3"
  local id
  id="$(find_by_display_name "oci network route-table list --compartment-id '$COMPARTMENT_OCID' --vcn-id '$vcn_id' --all" "$name")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  oci network route-table create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$vcn_id" \
    --display-name "$name" \
    --route-rules "$rules_json" \
    --query "data.id" \
    --raw-output
}

ensure_subnet() {
  local vcn_id="$1"
  local name="$2"
  local cidr="$3"
  local dns_label="$4"
  local route_table_id="$5"
  local prohibit_public_ip="$6"
  local id
  id="$(find_by_display_name "oci network subnet list --compartment-id '$COMPARTMENT_OCID' --vcn-id '$vcn_id' --all" "$name")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  oci network subnet create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$vcn_id" \
    --display-name "$name" \
    --cidr-block "$cidr" \
    --dns-label "$dns_label" \
    --route-table-id "$route_table_id" \
    --prohibit-public-ip-on-vnic "$prohibit_public_ip" \
    --wait-for-state AVAILABLE \
    --query "data.id" \
    --raw-output
}

ensure_autonomous_database() {
  local id
  local create_output
  if [[ -n "${ADB_OCID:-}" ]]; then
    if ! oci db autonomous-database get --autonomous-database-id "$ADB_OCID" >/dev/null; then
      echo "ADB_OCID is set, but the Autonomous Database could not be read: $ADB_OCID" >&2
      exit 1
    fi
    echo "$ADB_OCID"
    return
  fi

  id="$(find_by_display_name "oci db autonomous-database list --compartment-id '$COMPARTMENT_OCID' --all" "$ADB_DISPLAY_NAME")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi

  if ! create_output="$(oci db autonomous-database create \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "$ADB_DISPLAY_NAME" \
    --db-name "$ADB_DB_NAME" \
    --admin-password "$ADB_ADMIN_PASSWORD" \
    --db-workload OLTP \
    --is-free-tier true \
    --license-model LICENSE_INCLUDED \
    --wait-for-state AVAILABLE \
    --query "data.id" \
    --raw-output 2>&1)"; then
    echo "$create_output" >&2
    if grep -q "adb-free-count" <<<"$create_output"; then
      echo >&2
      echo "The tenancy has already used its Always Free Autonomous Database quota." >&2
      echo "Reuse an existing Autonomous Database by setting ADB_OCID in $ENV_FILE, or remove an unused Free Tier ADB and rerun." >&2
      echo >&2
      echo "Existing Autonomous Databases in COMPARTMENT_OCID:" >&2
      oci db autonomous-database list \
        --compartment-id "$COMPARTMENT_OCID" \
        --all \
        --query 'data[].{"display-name":"display-name",id:id,"lifecycle-state":"lifecycle-state"}' \
        --output table >&2 || true

      if [[ "${ADB_ALLOW_PAID_FALLBACK,,}" == "true" ]]; then
        echo >&2
        echo "ADB_ALLOW_PAID_FALLBACK=true. Creating a billable Autonomous Database instead." >&2
        if ! create_output="$(oci db autonomous-database create \
          --compartment-id "$COMPARTMENT_OCID" \
          --display-name "$ADB_DISPLAY_NAME" \
          --db-name "$ADB_DB_NAME" \
          --admin-password "$ADB_ADMIN_PASSWORD" \
          --db-workload OLTP \
          --compute-model ECPU \
          --compute-count "${ADB_PAID_COMPUTE_COUNT:-4}" \
          --data-storage-size-in-gbs "${ADB_PAID_STORAGE_GBS:-20}" \
          --db-version "${ADB_DB_VERSION:-19c}" \
          --is-free-tier false \
          --license-model LICENSE_INCLUDED \
          --wait-for-state AVAILABLE \
          --query "data.id" \
          --raw-output 2>&1)"; then
          echo "$create_output" >&2
          exit 1
        fi
        echo "$create_output"
        return
      fi

      echo >&2
      echo "To create a billable fallback database automatically, set ADB_ALLOW_PAID_FALLBACK=\"true\" in $ENV_FILE and rerun." >&2
    fi
    exit 1
  fi
  echo "$create_output"
}

ensure_api_gateway() {
  local subnet_id="$1"
  local id
  id="$(find_by_display_name "oci api-gateway gateway list --compartment-id '$COMPARTMENT_OCID' --all" "$API_GATEWAY_NAME")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  oci api-gateway gateway create \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "$API_GATEWAY_NAME" \
    --endpoint-type PUBLIC \
    --subnet-id "$subnet_id" \
    --wait-for-state ACTIVE \
    --query "data.id" \
    --raw-output
}

ensure_functions_app() {
  local subnet_id="$1"
  local id subnet_json
  id="$(find_by_display_name "oci fn application list --compartment-id '$COMPARTMENT_OCID' --all" "$FUNCTIONS_APP_NAME")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return
  fi
  subnet_json="$(jq -cn --arg subnet "$subnet_id" '[$subnet]')"
  oci fn application create \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "$FUNCTIONS_APP_NAME" \
    --subnet-ids "$subnet_json" \
    --query "data.id" \
    --raw-output
}

log "Creating or finding core OCI resources..."
CURRENT_STEP="VCN $VCN_NAME"
log "START: checking VCN $VCN_NAME"
VCN_OCID="$(ensure_vcn)"
ready "VCN" "$VCN_OCID"

CURRENT_STEP="Internet Gateway ${WORKSHOP_PREFIX}-internet-gateway"
log "START: checking Internet Gateway ${WORKSHOP_PREFIX}-internet-gateway"
IGW_OCID="$(ensure_internet_gateway "$VCN_OCID")"
ready "Internet Gateway" "$IGW_OCID"

CURRENT_STEP="NAT Gateway ${WORKSHOP_PREFIX}-nat-gateway"
log "START: checking NAT Gateway ${WORKSHOP_PREFIX}-nat-gateway"
NAT_OCID="$(ensure_nat_gateway "$VCN_OCID")"
ready "NAT Gateway" "$NAT_OCID"

CURRENT_STEP="Service Gateway ${WORKSHOP_PREFIX}-service-gateway"
log "START: checking Service Gateway ${WORKSHOP_PREFIX}-service-gateway"
SGW_OCID="$(ensure_service_gateway "$VCN_OCID")"
ready "Service Gateway" "$SGW_OCID"

CURRENT_STEP="route rule JSON"
PUBLIC_RULES="$(jq -cn --arg igw "$IGW_OCID" '[{cidrBlock:"0.0.0.0/0", networkEntityId:$igw}]')"
SERVICE_CIDR_LABEL="$(get_osn_service_cidr_label)"
log "Using service CIDR label: $SERVICE_CIDR_LABEL"
PRIVATE_RULES="$(jq -cn --arg nat "$NAT_OCID" --arg sgw "$SGW_OCID" --arg service "$SERVICE_CIDR_LABEL" '[{cidrBlock:"0.0.0.0/0", networkEntityId:$nat}, {destination:$service, destinationType:"SERVICE_CIDR_BLOCK", networkEntityId:$sgw}]')"

CURRENT_STEP="public route table ${WORKSHOP_PREFIX}-public-route-table"
log "START: checking public route table ${WORKSHOP_PREFIX}-public-route-table"
PUBLIC_RT_OCID="$(ensure_route_table "$VCN_OCID" "${WORKSHOP_PREFIX}-public-route-table" "$PUBLIC_RULES")"
ready "Public route table" "$PUBLIC_RT_OCID"

CURRENT_STEP="private route table ${WORKSHOP_PREFIX}-private-route-table"
log "START: checking private route table ${WORKSHOP_PREFIX}-private-route-table"
PRIVATE_RT_OCID="$(ensure_route_table "$VCN_OCID" "${WORKSHOP_PREFIX}-private-route-table" "$PRIVATE_RULES")"
ready "Private route table" "$PRIVATE_RT_OCID"

CURRENT_STEP="public subnet $PUBLIC_SUBNET_NAME"
log "START: checking public subnet $PUBLIC_SUBNET_NAME"
PUBLIC_SUBNET_OCID="$(ensure_subnet "$VCN_OCID" "$PUBLIC_SUBNET_NAME" "10.0.1.0/24" "${WORKSHOP_PREFIX}pub" "$PUBLIC_RT_OCID" false)"
ready "Public subnet" "$PUBLIC_SUBNET_OCID"

CURRENT_STEP="private subnet $PRIVATE_SUBNET_NAME"
log "START: checking private subnet $PRIVATE_SUBNET_NAME"
PRIVATE_SUBNET_OCID="$(ensure_subnet "$VCN_OCID" "$PRIVATE_SUBNET_NAME" "10.0.2.0/24" "${WORKSHOP_PREFIX}priv" "$PRIVATE_RT_OCID" true)"
ready "Private subnet" "$PRIVATE_SUBNET_OCID"

CURRENT_STEP="Autonomous Database $ADB_DISPLAY_NAME"
log "START: checking Autonomous Database $ADB_DISPLAY_NAME"
ADB_OCID="$(ensure_autonomous_database)"
ready "Autonomous Database" "$ADB_OCID"

CURRENT_STEP="API Gateway $API_GATEWAY_NAME"
log "START: checking API Gateway $API_GATEWAY_NAME"
API_GATEWAY_OCID="$(ensure_api_gateway "$PUBLIC_SUBNET_OCID")"
ready "API Gateway" "$API_GATEWAY_OCID"

CURRENT_STEP="Functions application $FUNCTIONS_APP_NAME"
log "START: checking Functions application $FUNCTIONS_APP_NAME"
FUNCTIONS_APP_OCID="$(ensure_functions_app "$PRIVATE_SUBNET_OCID")"
ready "Functions application" "$FUNCTIONS_APP_OCID"

CURRENT_STEP="API Gateway hostname lookup"
log "START: reading API Gateway endpoint"
API_GATEWAY_ENDPOINT="$(oci api-gateway gateway get --gateway-id "$API_GATEWAY_OCID" --query 'data.hostname' --raw-output)"
if [[ -z "$API_GATEWAY_ENDPOINT" || "$API_GATEWAY_ENDPOINT" == "null" ]]; then
  echo "API Gateway did not return a hostname." >&2
  exit 1
fi
log "DONE: API Gateway endpoint ready: https://$API_GATEWAY_ENDPOINT"

CURRENT_STEP="writing workshop-outputs.env"
cat > workshop-outputs.env <<EOF
export COMPARTMENT_OCID="$COMPARTMENT_OCID"
export REGION="$REGION"
export REGION_KEY="$REGION_KEY"
export TENANCY_NAMESPACE="$TENANCY_NAMESPACE"
export VCN_OCID="$VCN_OCID"
export PUBLIC_SUBNET_OCID="$PUBLIC_SUBNET_OCID"
export PRIVATE_SUBNET_OCID="$PRIVATE_SUBNET_OCID"
export ADB_OCID="$ADB_OCID"
export API_GATEWAY_OCID="$API_GATEWAY_OCID"
export API_GATEWAY_ENDPOINT="https://$API_GATEWAY_ENDPOINT"
export FUNCTIONS_APP_OCID="$FUNCTIONS_APP_OCID"
export FUNCTIONS_APP_NAME="$FUNCTIONS_APP_NAME"
export API_GATEWAY_NAME="$API_GATEWAY_NAME"
EOF

echo
echo "Core resources are ready. Saved outputs to workshop-outputs.env."
echo "VCN: $VCN_OCID"
echo "Public subnet: $PUBLIC_SUBNET_OCID"
echo "Private subnet: $PRIVATE_SUBNET_OCID"
echo "Autonomous Database: $ADB_OCID"
echo "API Gateway: $API_GATEWAY_OCID"
echo "Functions application: $FUNCTIONS_APP_OCID"
echo "Gateway endpoint: https://$API_GATEWAY_ENDPOINT"
echo
echo "Next: source workshop-outputs.env, then continue to Lab 2."
