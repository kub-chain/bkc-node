#!/usr/bin/env bash
set -euo pipefail

# Verify BitkubChain Fullnode #3 sync status via JSON-RPC

RPC_URL="${BKC_RPC:-http://127.0.0.1:8545}"
REFERENCE_RPC="https://rpc.bitkubchain.io"

rpc_call() {
    local method="$1"
    local params="${2:-[]}"
    curl -sf -X POST "${RPC_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}"
}

hex_to_dec() {
    printf "%d" "$1" 2>/dev/null || echo "n/a"
}

echo "=== BitkubChain Fullnode #3 — Sync Status ==="
echo "RPC: ${RPC_URL}"
echo ""

# 1. Check node is up
if ! rpc_call "net_version" > /dev/null 2>&1; then
    echo "ERROR: Node is not responding at ${RPC_URL}"
    echo "Check: sudo systemctl status bkc-fullnode3"
    exit 1
fi

CHAIN_ID=$(rpc_call "eth_chainId" | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))")
echo "Chain ID: ${CHAIN_ID}"
[[ "${CHAIN_ID}" == "96" ]] || echo "WARNING: Unexpected chain ID (expected 96 for BKC Mainnet)"

# 2. Peer count
PEER_HEX=$(rpc_call "net_peerCount" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])")
PEER_COUNT=$(hex_to_dec "${PEER_HEX}")
echo "Connected peers: ${PEER_COUNT}"
[[ "${PEER_COUNT}" -ge 1 ]] || echo "WARNING: No peers connected — check firewall (port 30303)"

# 3. Sync progress
SYNC_STATUS=$(rpc_call "eth_syncing")
IS_SYNCING=$(echo "${SYNC_STATUS}" | python3 -c "import sys,json; d=json.load(sys.stdin)['result']; print(d is not False)")

if [[ "${IS_SYNCING}" == "False" ]]; then
    LOCAL_BLOCK_HEX=$(rpc_call "eth_blockNumber" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])")
    LOCAL_BLOCK=$(hex_to_dec "${LOCAL_BLOCK_HEX}")

    # Fetch reference block from public RPC (best-effort)
    REF_BLOCK_HEX=$(curl -sf -X POST "${REFERENCE_RPC}" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")
    REF_BLOCK=$(hex_to_dec "${REF_BLOCK_HEX}")

    echo "Sync status: SYNCED"
    echo "Local block:     ${LOCAL_BLOCK}"
    [[ "${REF_BLOCK}" -gt 0 ]] && echo "Network tip:     ${REF_BLOCK}" && \
        echo "Behind by:       $((REF_BLOCK - LOCAL_BLOCK)) blocks"
else
    CURRENT=$(echo "${SYNC_STATUS}" | python3 -c "import sys,json; d=json.load(sys.stdin)['result']; print(int(d['currentBlock'],16))")
    HIGHEST=$(echo "${SYNC_STATUS}" | python3 -c "import sys,json; d=json.load(sys.stdin)['result']; print(int(d['highestBlock'],16))")
    REMAINING=$((HIGHEST - CURRENT))
    PCT=$(python3 -c "print(f'{${CURRENT}/${HIGHEST}*100:.2f}')" 2>/dev/null || echo "n/a")

    echo "Sync status: SYNCING"
    echo "Current block:   ${CURRENT}"
    echo "Highest known:   ${HIGHEST}"
    echo "Remaining:       ${REMAINING} blocks"
    echo "Progress:        ${PCT}%"
fi

echo ""
echo "Service status:"
systemctl is-active bkc-fullnode3 2>/dev/null || echo "(systemctl not available)"
