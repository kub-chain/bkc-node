#!/usr/bin/env bash
# Verify sync status for BitkubChain Fullnode #2

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"

check_rpc() {
  local method="$1" params="${2:-[]}"
  curl -sf -X POST "${RPC_URL}" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}"
}

echo "==> BitkubChain Fullnode #2 — Sync Status Check"
echo "    RPC: ${RPC_URL}"
echo ""

# eth_syncing — false when fully synced, object with progress when syncing
SYNCING=$(check_rpc "eth_syncing" | python3 -c "import sys,json; d=json.load(sys.stdin)['result']; print('false' if d is False else json.dumps(d,indent=2))" 2>/dev/null || echo "ERROR: could not reach RPC")

if [[ "${SYNCING}" == "false" ]]; then
  echo "  Sync status : SYNCED (eth_syncing returned false)"
else
  echo "  Sync status : SYNCING"
  echo "${SYNCING}"
fi

# Current block
BLOCK_HEX=$(check_rpc "eth_blockNumber" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")
BLOCK_DEC=$(printf "%d" "${BLOCK_HEX}" 2>/dev/null || echo "unknown")
echo "  Current block: ${BLOCK_DEC} (${BLOCK_HEX})"

# Peer count
PEER_HEX=$(check_rpc "net_peerCount" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "0x0")
PEER_DEC=$(printf "%d" "${PEER_HEX}" 2>/dev/null || echo "unknown")
echo "  Peer count   : ${PEER_DEC}"

# Network ID
NET_ID=$(check_rpc "net_version" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'])" 2>/dev/null || echo "unknown")
echo "  Network ID   : ${NET_ID} (expected: 96 for mainnet)"

echo ""
if [[ "${SYNCING}" == "false" && "${PEER_DEC}" -gt 0 ]]; then
  echo "  Node is healthy and fully synced."
elif [[ "${SYNCING}" == "false" && "${PEER_DEC}" -eq 0 ]]; then
  echo "  WARNING: Node is synced but has no peers. Check firewall/P2P port 30303."
else
  echo "  Node is still syncing — check back later."
fi
