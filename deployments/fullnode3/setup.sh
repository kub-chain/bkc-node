#!/usr/bin/env bash
set -euo pipefail

# BitkubChain Fullnode #3 — Setup Script
# Network: Mainnet (Chain ID 96)
# Ports: HTTP 8545 | WS 8546 | P2P 30303

INSTALL_DIR="/opt/bkc-node"
DATA_DIR="${INSTALL_DIR}/mainnet/data"
CONFIG_DIR="${INSTALL_DIR}/mainnet"
SERVICE_NAME="bkc-fullnode3"
GETH_BIN="${INSTALL_DIR}/geth"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---------- 1. Detect architecture ----------
detect_arch() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    case "${arch}" in
        x86_64)  arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;;
    esac
    echo "${os}-${arch}"
}

# ---------- 2. Download geth binary ----------
install_geth() {
    log "Installing geth binary..."
    local platform
    platform="$(detect_arch)"
    local tarball="geth.${platform}.tar.gz"

    local download_url
    download_url=$(curl -s https://api.github.com/repos/kub-chain/bkc/releases/latest \
        | grep browser_download_url \
        | grep "${platform}" \
        | cut -d'"' -f4)

    if [[ -z "${download_url}" ]]; then
        log "ERROR: Could not find release URL for platform ${platform}"
        exit 1
    fi

    log "Downloading: ${download_url}"
    curl -L "${download_url}" -o "/tmp/${tarball}"
    tar -xf "/tmp/${tarball}" -C /tmp/
    install -m 0755 /tmp/geth "${GETH_BIN}"
    rm -f "/tmp/${tarball}" /tmp/geth
    log "geth installed at ${GETH_BIN}: $(${GETH_BIN} version 2>&1 | head -1)"
}

# ---------- 3. Deploy config files ----------
deploy_configs() {
    log "Deploying genesis.json and config.toml..."
    mkdir -p "${CONFIG_DIR}"
    cp "${SCRIPT_DIR}/genesis.json" "${CONFIG_DIR}/genesis.json"
    cp "${SCRIPT_DIR}/config.toml"  "${CONFIG_DIR}/config.toml"
    log "Config files written to ${CONFIG_DIR}"
}

# ---------- 4. Initialize genesis ----------
init_genesis() {
    if [[ -d "${DATA_DIR}/geth/chaindata" ]]; then
        log "Data directory already initialized — skipping genesis init."
        return
    fi
    log "Initializing genesis block..."
    mkdir -p "${DATA_DIR}"
    "${GETH_BIN}" --datadir "${DATA_DIR}" init "${CONFIG_DIR}/genesis.json"
    log "Genesis initialized."
}

# ---------- 5. Install systemd service ----------
install_service() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log "WARNING: Not running as root — skipping systemd service installation."
        log "Run with sudo to install the systemd service."
        return
    fi

    log "Installing systemd service..."
    cp "${SCRIPT_DIR}/bkc-fullnode3.service" "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    log "Service ${SERVICE_NAME} enabled. Start with: sudo systemctl start ${SERVICE_NAME}"
}

# ---------- 6. Open firewall ports (ufw) ----------
configure_firewall() {
    if ! command -v ufw &>/dev/null; then
        log "ufw not found — skipping firewall config. Ensure ports 30303/tcp, 30303/udp, 8545/tcp, 8546/tcp are open."
        return
    fi
    log "Configuring ufw firewall rules..."
    ufw allow 30303/tcp comment "BKC P2P"
    ufw allow 30303/udp comment "BKC P2P UDP"
    ufw allow 8545/tcp comment "BKC HTTP-RPC"
    ufw allow 8546/tcp comment "BKC WS-RPC"
    log "Firewall rules applied."
}

# ---------- Main ----------
main() {
    log "=== BitkubChain Fullnode #3 Setup ==="

    # Create install dir (requires root in production; adapt as needed)
    mkdir -p "${INSTALL_DIR}"

    install_geth
    deploy_configs
    init_genesis
    install_service
    configure_firewall

    log ""
    log "=== Setup complete ==="
    log "To start the node:   sudo systemctl start ${SERVICE_NAME}"
    log "To watch logs:       sudo journalctl -u ${SERVICE_NAME} -f"
    log "To verify sync:      bash ${SCRIPT_DIR}/verify-sync.sh"
}

main "$@"
