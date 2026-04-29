#!/usr/bin/env bash
# Open required ports for BitkubChain Fullnode #2 (ufw example)
# Run as root or with sudo.

set -euo pipefail

echo "==> Opening BitkubChain Fullnode #2 ports"

# P2P — must be publicly reachable for peer discovery
ufw allow 30303/tcp comment "BKC Fullnode #2 P2P TCP"
ufw allow 30303/udp comment "BKC Fullnode #2 P2P UDP"

# RPC — restrict to trusted sources in production; 0.0.0.0 is used here for
# internal/LAN access. Replace <TRUSTED_CIDR> with your actual range.
# ufw allow from <TRUSTED_CIDR> to any port 8545 proto tcp comment "BKC RPC HTTP"
# ufw allow from <TRUSTED_CIDR> to any port 8546 proto tcp comment "BKC RPC WebSocket"

# Prometheus metrics (localhost only — no public exposure needed)
# Already bound to 127.0.0.1:6060 in the systemd unit; no firewall rule required.

ufw reload
ufw status verbose
