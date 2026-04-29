#!/usr/bin/env bash
set -euo pipefail

# BitkubChain Fullnode #2 Setup Script
# Network: Mainnet (chainId: 96)
# Ports: HTTP-RPC 8545, WS 8546, P2P 30303
# Adjust NODE_DIR and port variables if running alongside another fullnode on the same host.

NODE_DIR="${NODE_DIR:-/bkc-node/fullnode-2}"
ARCH="$(uname -m)"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

case "${ARCH}" in
  x86_64) BIN_ARCH="amd64" ;;
  aarch64|arm64) BIN_ARCH="arm64" ;;
  *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

BIN_PATTERN="${OS}-${BIN_ARCH}"

echo "==> Creating node directory: ${NODE_DIR}"
mkdir -p "${NODE_DIR}/data"

# ── 1. Download geth binary ───────────────────────────────────────────────────
echo "==> Downloading BitkubChain geth (${BIN_PATTERN})"
DOWNLOAD_URL="$(curl -s https://api.github.com/repos/kub-chain/bkc/releases/latest \
  | grep browser_download_url \
  | grep "${BIN_PATTERN}" \
  | cut -d'"' -f4)"

if [[ -z "${DOWNLOAD_URL}" ]]; then
  echo "ERROR: Could not find a release asset matching '${BIN_PATTERN}'"
  exit 1
fi

ARCHIVE_NAME="geth.${BIN_PATTERN}.tar.gz"
curl -L "${DOWNLOAD_URL}" -o "${NODE_DIR}/${ARCHIVE_NAME}"
tar -xf "${NODE_DIR}/${ARCHIVE_NAME}" -C "${NODE_DIR}/"
chmod u+x "${NODE_DIR}/geth"
echo "    geth version: $("${NODE_DIR}/geth" version 2>&1 | head -1)"

# ── 2. Download mainnet genesis.json & config.toml ───────────────────────────
echo "==> Downloading mainnet config package"
MAINNET_URL="$(curl -s https://api.github.com/repos/kub-chain/bkc-node/releases/latest \
  | grep browser_download_url \
  | grep mainnet \
  | cut -d'"' -f4)"

if [[ -z "${MAINNET_URL}" ]]; then
  echo "ERROR: Could not find mainnet release asset"
  exit 1
fi

curl -L "${MAINNET_URL}" -o "${NODE_DIR}/mainnet.tar.gz"
tar -xf "${NODE_DIR}/mainnet.tar.gz" -C "${NODE_DIR}/"

GENESIS_FILE="${NODE_DIR}/mainnet/genesis.json"
CONFIG_FILE="${NODE_DIR}/mainnet/config.toml"

# ── 3. Patch DataDir in config.toml to point at this node's data directory ───
echo "==> Patching DataDir in config.toml"
sed -i "s|DataDir = .*|DataDir = \"${NODE_DIR}/data\"|" "${CONFIG_FILE}"

# ── 4. Initialise genesis block ───────────────────────────────────────────────
echo "==> Initialising genesis block"
"${NODE_DIR}/geth" --datadir "${NODE_DIR}/data" init "${GENESIS_FILE}"

echo ""
echo "Setup complete."
echo "  Node dir : ${NODE_DIR}"
echo "  Binary   : ${NODE_DIR}/geth"
echo "  Config   : ${CONFIG_FILE}"
echo "  Data     : ${NODE_DIR}/data"
echo ""
echo "Next steps:"
echo "  1. Install the systemd service:  sudo cp bkc-fullnode-2.service /etc/systemd/system/"
echo "  2. Enable & start:               sudo systemctl daemon-reload && sudo systemctl enable --now bkc-fullnode-2"
echo "  3. Check sync status:            bash check-sync.sh"
