#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${ADB_ORDS_HOST:-}" ]]; then
  echo "Set ADB_ORDS_HOST first, for example:" >&2
  echo 'export ADB_ORDS_HOST="https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com"' >&2
  exit 1
fi

host="${ADB_ORDS_HOST%/}"
tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT

request_status() {
  local url="$1"
  curl -sS -o "$tmp_body" -w "%{http_code}" "$url" || true
}

body_has_items() {
  if command -v jq >/dev/null 2>&1; then
    jq -e 'has("items") and (.items | type == "array")' "$tmp_body" >/dev/null 2>&1
  else
    grep -q '"items"' "$tmp_body"
  fi
}

print_sample() {
  if command -v jq >/dev/null 2>&1; then
    jq '.items[0] // .' "$tmp_body" 2>/dev/null || head -c 500 "$tmp_body"
  else
    head -c 500 "$tmp_body"
    echo
  fi
}

echo "Checking ORDS market endpoints on: $host"
echo

canonical_url="$host/ords/market/signals/?limit=1"
canonical_status="$(request_status "$canonical_url")"
echo "Canonical endpoint: $canonical_url"
echo "HTTP status: $canonical_status"

if [[ "$canonical_status" =~ ^2 ]] && body_has_items; then
  echo
  echo "Canonical market endpoint is ready."
  print_sample
  cat > ords-market.env <<EOF
export ADB_ORDS_HOST="$host"
export UPSTREAM_BASE="$host/ords/market/"
export ORDS_RECEIPTS_URL="$host/ords/x402/"
EOF
  echo
  echo "Wrote ords-market.env. Append it to workshop.env with:"
  echo "cat ords-market.env >> workshop.env"
  exit 0
fi

echo
echo "The canonical endpoint did not return the expected ORDS items array."
echo "Testing schema metadata and common fallback aliases so you can see what ORDS published."
echo

found_any=false
for schema_alias in market x402_rest sh; do
  metadata_url="$host/ords/$schema_alias/metadata-catalog/"
  metadata_status="$(request_status "$metadata_url")"
  printf '%-48s HTTP %s\n' "/ords/$schema_alias/metadata-catalog/" "$metadata_status"
  if [[ "$metadata_status" =~ ^2 ]]; then
    echo "  Schema alias responded. Metadata sample:"
    print_sample | sed 's/^/  /'
  fi

  for object_alias in signals market_signals sales; do
    url="$host/ords/$schema_alias/$object_alias/?limit=1"
    status="$(request_status "$url")"
    printf '%-48s HTTP %s\n' "/ords/$schema_alias/$object_alias/?limit=1" "$status"
    if [[ "$status" =~ ^2 ]] && body_has_items; then
      found_any=true
      echo "  Returned an ORDS items array. Sample:"
      print_sample | sed 's/^/  /'
    fi
  done
done

echo
if [[ "$found_any" == "true" ]]; then
  echo "ORDS is responding, but not at the workshop canonical path."
  echo "Re-run setup-market-autorest.sql from the latest workshop files to reset X402_REST to /ords/market/signals/."
else
  echo "No tested ORDS object endpoint returned data."
  echo "Re-download and re-run setup-market-autorest.sql as ADMIN, then run this verifier again."
fi
