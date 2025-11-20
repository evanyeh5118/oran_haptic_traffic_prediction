#!/bin/bash
set -euo pipefail

DN_IFACE="eth1"
EXT_DN_IP="${1:-192.168.72.135}"
EDGE_IP="${2:-192.168.72.136}"
UDP_PORT="${3:-5000}"           # <--- NEW: UDP port to mirror
MIRROR_CHAIN="UPF_MIRROR_TO_EDGE"

echo "[INFO] Using DN_IFACE=${DN_IFACE}, EXT_DN_IP=${EXT_DN_IP}, EDGE_IP=${EDGE_IP}, UDP_PORT=${UDP_PORT}"

if command -v modprobe >/dev/null 2>&1; then
    modprobe xt_TEE 2>/dev/null || true
fi

# Create / flush chain
if iptables -t mangle -L "${MIRROR_CHAIN}" -n >/dev/null 2>&1; then
    iptables -t mangle -F "${MIRROR_CHAIN}"
else
    iptables -t mangle -N "${MIRROR_CHAIN}"
fi

# Remove old jumps
while iptables -t mangle -C POSTROUTING -o "${DN_IFACE}" -d "${EXT_DN_IP}" -p udp --dport "${UDP_PORT}" -j "${MIRROR_CHAIN}" 2>/dev/null; do
    iptables -t mangle -D POSTROUTING -o "${DN_IFACE}" -d "${EXT_DN_IP}" -p udp --dport "${UDP_PORT}" -j "${MIRROR_CHAIN}"
done

# New jump: ONLY UDP to EXT_DN_IP:UDP_PORT
iptables -t mangle -A POSTROUTING -o "${DN_IFACE}" -d "${EXT_DN_IP}" -p udp --dport "${UDP_PORT}" -j "${MIRROR_CHAIN}"

# In mirror chain: TEE
iptables -t mangle -A "${MIRROR_CHAIN}" -j TEE --gateway "${EDGE_IP}"

# Allow forwarding to EDGE_IP
iptables -C FORWARD -o "${DN_IFACE}" -d "${EDGE_IP}" -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -o "${DN_IFACE}" -d "${EDGE_IP}" -j ACCEPT

echo "[INFO] Mirror rule installed for UDP dst=${EXT_DN_IP}:${UDP_PORT} -> copy to ${EDGE_IP}"
