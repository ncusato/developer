#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-workshop.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
if [[ -f workshop-outputs.env ]]; then
  # shellcheck disable=SC1091
  source workshop-outputs.env
fi

FILES_BASE="${WORKSHOP_FILES_BASE:-https://raw.githubusercontent.com/oracle-livelabs/developer/main/x402-api-gateway}"
CLIENT_DIR="${CLIENT_DIR:-x402-client}"

if [[ -z "${GATEWAY_URL:-}" ]]; then
  echo "Set GATEWAY_URL or run Lab 4 first." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing required command: curl" >&2
  exit 1
fi

mkdir -p "$CLIENT_DIR"
curl -fsSL "$FILES_BASE/test-agent-client/files/client.js" -o "$CLIENT_DIR/client.js"
curl -fsSL "$FILES_BASE/test-agent-client/files/package.json" -o "$CLIENT_DIR/package.json"

cd "$CLIENT_DIR"
npm install

cat > run-client.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
export GATEWAY_URL="${GATEWAY_URL}"
export PRIVATE_KEY="\${PRIVATE_KEY:?Set PRIVATE_KEY to your Base Sepolia test wallet private key}"
node client.js
EOF
chmod +x run-client.sh

echo "Client project is ready in $CLIENT_DIR."
echo "Run it with:"
echo "cd $CLIENT_DIR"
echo "PRIVATE_KEY=0xYOUR_TESTNET_PRIVATE_KEY ./run-client.sh"
