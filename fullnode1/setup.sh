#!/usr/bin/env bash
set -euo pipefail

# BitkubChain Fullnode #1 — installation and initialization script
# Installs the bkc geth binary, initializes genesis, and prepares the data directory.
# Tested on Ubuntu 22.04 LTS (amd64/arm64).

INSTALL_DIR="/opt/bkc"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="${INSTALL_DIR}/config"
BIN_DIR="${INSTALL_DIR}/bin"
LOG_DIR="/var/log/bkc"
SERVICE_USER="bkc"
ARCH="$(uname -m)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
}

detect_arch() {
    case "${ARCH}" in
        x86_64)  echo "linux-amd64" ;;
        aarch64) echo "linux-arm64" ;;
        *) die "Unsupported architecture: ${ARCH}" ;;
    esac
}

download_geth() {
    local arch_tag
    arch_tag="$(detect_arch)"
    log "Downloading latest bkc geth binary (${arch_tag})..."

    local download_url
    download_url="$(curl -fsSL https://api.github.com/repos/kub-chain/bkc/releases/latest \
        | grep browser_download_url \
        | grep "${arch_tag}" \
        | cut -d'"' -f4)"

    [[ -n "${download_url}" ]] || die "Could not find download URL for ${arch_tag}"

    local tarball="/tmp/geth.${arch_tag}.tar.gz"
    curl -fsSL -o "${tarball}" "${download_url}"
    tar -xf "${tarball}" -C "${BIN_DIR}"
    chmod u+x "${BIN_DIR}/geth"
    rm -f "${tarball}"
    log "geth installed: $(${BIN_DIR}/geth version 2>&1 | head -1)"
}

download_config() {
    log "Downloading mainnet config and genesis..."

    local config_url
    config_url="$(curl -fsSL https://api.github.com/repos/kub-chain/bkc-node/releases/latest \
        | grep browser_download_url \
        | grep mainnet \
        | cut -d'"' -f4)"

    [[ -n "${config_url}" ]] || die "Could not find mainnet config release URL"

    local tarball="/tmp/mainnet.tar.gz"
    curl -fsSL -o "${tarball}" "${config_url}"
    tar -xf "${tarball}" -C "${CONFIG_DIR}" --strip-components=1
    rm -f "${tarball}"
    log "config.toml and genesis.json installed to ${CONFIG_DIR}"
}

create_directories() {
    log "Creating directory structure..."
    mkdir -p "${BIN_DIR}" "${DATA_DIR}" "${CONFIG_DIR}" "${LOG_DIR}"
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_DIR}" "${LOG_DIR}"
}

create_service_user() {
    if id "${SERVICE_USER}" &>/dev/null; then
        warn "User '${SERVICE_USER}' already exists, skipping."
    else
        log "Creating system user '${SERVICE_USER}'..."
        useradd --system --no-create-home --shell /bin/false "${SERVICE_USER}"
    fi
}

init_genesis() {
    log "Initializing genesis block..."
    if [[ -d "${DATA_DIR}/geth/chaindata" ]]; then
        warn "Chaindata already exists — skipping genesis init. Delete ${DATA_DIR} to re-initialize."
        return
    fi
    sudo -u "${SERVICE_USER}" "${BIN_DIR}/geth" \
        --datadir "${DATA_DIR}" \
        init "${CONFIG_DIR}/genesis.json"
    log "Genesis initialized successfully."
}

install_service() {
    log "Installing systemd service..."
    cp "$(dirname "$0")/bkc-fullnode.service" /etc/systemd/system/bkc-fullnode.service
    systemctl daemon-reload
    systemctl enable bkc-fullnode.service
    log "Systemd service installed and enabled."
}

print_summary() {
    cat <<EOF

${GREEN}===== BitkubChain Fullnode #1 Setup Complete =====${NC}

  Binary       : ${BIN_DIR}/geth
  Data dir     : ${DATA_DIR}
  Config dir   : ${CONFIG_DIR}
  Log dir      : ${LOG_DIR}
  Service user : ${SERVICE_USER}

  Ports:
    RPC  (HTTP)      : 8545
    RPC  (WebSocket) : 8546
    P2P              : 30303/tcp+udp

  Start node   : sudo systemctl start bkc-fullnode
  Check status : sudo systemctl status bkc-fullnode
  View logs    : sudo journalctl -u bkc-fullnode -f
  Check sync   : sudo -u bkc ${INSTALL_DIR}/bin/geth attach ${DATA_DIR}/geth.ipc --exec eth.syncing

EOF
}

main() {
    require_root
    create_service_user
    create_directories
    download_geth
    download_config
    init_genesis
    install_service
    print_summary
}

main "$@"
