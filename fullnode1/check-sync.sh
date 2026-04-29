#!/usr/bin/env bash
# Checks BitkubChain fullnode sync status via the IPC socket or HTTP RPC.
set -euo pipefail

IPC="${1:-/opt/bkc/data/geth.ipc}"
RPC="${2:-http://localhost:8545}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

rpc_call() {
    curl -fsSL -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"'"$1"'","params":[],"id":1}' \
        "${RPC}" 2>/dev/null
}

hex_to_dec() {
    python3 -c "print(int('$1', 16))" 2>/dev/null || echo "N/A"
}

main() {
    echo "Checking BitkubChain Fullnode #1 sync status..."
    echo "RPC endpoint: ${RPC}"
    echo "---"

    # Sync status
    sync_resp="$(rpc_call eth_syncing)"
    sync_result="$(echo "${sync_resp}" | python3 -c "import sys,json; d=json.load(sys.stdin)['result']; print(d)" 2>/dev/null || echo "error")"

    if [[ "${sync_result}" == "False" ]]; then
        echo -e "${GREEN}Status: SYNCED${NC} (not syncing — node is at head)"
    else
        current_hex="$(echo "${sync_resp}" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('currentBlock','0x0'))" 2>/dev/null || echo "0x0")"
        highest_hex="$(echo "${sync_resp}" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'].get('highestBlock','0x0'))" 2>/dev/null || echo "0x0")"
        current="$(hex_to_dec "${current_hex}")"
        highest="$(hex_to_dec "${highest_hex}")"
        behind=$(( highest - current ))
        echo -e "${YELLOW}Status: SYNCING${NC}"
        echo "  Current block : ${current}"
        echo "  Highest block : ${highest}"
        echo "  Blocks behind : ${behind}"
    fi

    # Latest block number
    block_hex="$(rpc_call eth_blockNumber | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")"
    echo "  Latest local block: $(hex_to_dec "${block_hex}")"

    # Peer count
    peers_hex="$(rpc_call net_peerCount | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")"
    peers="$(hex_to_dec "${peers_hex}")"
    if (( peers < 3 )); then
        echo -e "  Peers: ${RED}${peers}${NC} (low — check firewall/port 30303)"
    else
        echo -e "  Peers: ${GREEN}${peers}${NC}"
    fi

    # Chain ID
    chain_hex="$(rpc_call eth_chainId | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x60")"
    chain="$(hex_to_dec "${chain_hex}")"
    if [[ "${chain}" == "96" ]]; then
        echo -e "  Chain ID: ${GREEN}${chain}${NC} (BitkubChain mainnet)"
    else
        echo -e "  Chain ID: ${RED}${chain}${NC} (expected 96)"
    fi
}

main "$@"
