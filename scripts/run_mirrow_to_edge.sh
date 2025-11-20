#!/bin/bash
set -euo pipefail

########################################
# Resolve paths relative to this script
########################################

# Absolute path to the directory where THIS script lives
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# We assume this directory is the 5g_rfsimulator folder
TARGET_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"

# upf_mirror_to_edge.sh is in the same directory as this script
LOCAL_MIRROR_SCRIPT="${SCRIPT_DIR}/upf_mirror_to_edge.sh"

# Host-side shared folder used by the UPF container
UPF_SHARE_HOST_DIR="${TARGET_DIR}/upf-shared"

# Path inside the UPF container for that shared folder
UPF_SHARE_CONTAINER_DIR="/upf-shared"

# UPF container name
UPF_CONTAINER_NAME="rfsim5g-oai-upf"

# Default IPs (can be overridden on CLI)
DEFAULT_EXT_DN_IP="192.168.72.135"
DEFAULT_EDGE_IP="192.168.72.136"

########################################
# Arguments
########################################
EXT_DN_IP="${1:-$DEFAULT_EXT_DN_IP}"
EDGE_IP="${2:-$DEFAULT_EDGE_IP}"

echo "=== UPF Mirror Experiment ==="
echo "SCRIPT_DIR:               ${SCRIPT_DIR}"
echo "TARGET_DIR:               ${TARGET_DIR}"
echo "Host share dir:           ${UPF_SHARE_HOST_DIR}"
echo "Container share dir:      ${UPF_SHARE_CONTAINER_DIR}"
echo "UPF container:            ${UPF_CONTAINER_NAME}"
echo "ext-DN IP (original dst): ${EXT_DN_IP}"
echo "Edge IP (mirror dst):     ${EDGE_IP}"
echo


########################################
# 0. Flush iptables chain
########################################
docker exec -it rfsim5g-oai-upf iptables -t mangle -F UPF_MIRROR_TO_EDGE 2>/dev/null || true

########################################
# 1. Basic checks
########################################

# Ensure mirror script exists next to this script
if [ ! -f "${LOCAL_MIRROR_SCRIPT}" ]; then
    echo "[ERROR] Local mirror script not found: ${LOCAL_MIRROR_SCRIPT}"
    exit 1
fi

# Ensure share dir exists
if [ ! -d "${UPF_SHARE_HOST_DIR}" ]; then
    echo "[INFO] Creating share directory: ${UPF_SHARE_HOST_DIR}"
    mkdir -p "${UPF_SHARE_HOST_DIR}"
fi

# Ensure UPF container is running
if ! docker ps --format '{{.Names}}' | grep -qw "${UPF_CONTAINER_NAME}"; then
    echo "[ERROR] Container ${UPF_CONTAINER_NAME} is not running."
    echo "       Start it first (e.g., docker-compose up -d oai-upf) and rerun this script."
    exit 1
fi

########################################
# 2. Copy script into the host share folder
########################################

echo "[INFO] Copying ${LOCAL_MIRROR_SCRIPT} -> ${UPF_SHARE_HOST_DIR}/"
cp "${LOCAL_MIRROR_SCRIPT}" "${UPF_SHARE_HOST_DIR}/"
chmod +x "${UPF_SHARE_HOST_DIR}/$(basename "${LOCAL_MIRROR_SCRIPT}")"

########################################
# 3. Execute script inside UPF container
########################################

REMOTE_SCRIPT_PATH="${UPF_SHARE_CONTAINER_DIR}/$(basename "${LOCAL_MIRROR_SCRIPT}")"

echo "[INFO] Executing inside container:"
echo "docker exec -it ${UPF_CONTAINER_NAME} bash -c \"chmod +x ${REMOTE_SCRIPT_PATH} && ${REMOTE_SCRIPT_PATH} ${EXT_DN_IP} ${EDGE_IP}\""
echo

docker exec -it "${UPF_CONTAINER_NAME}" \
    bash -c "chmod +x '${REMOTE_SCRIPT_PATH}' && '${REMOTE_SCRIPT_PATH}' '${EXT_DN_IP}' '${EDGE_IP}' '5000'"

########################################
# 4. Dump iptables for verification
########################################

echo
echo "[INFO] Dumping mangle table from UPF container:"
docker exec -it "${UPF_CONTAINER_NAME}" iptables -t mangle -L -v

echo
echo "[INFO] Dumping FORWARD chain from UPF container:"
docker exec -it "${UPF_CONTAINER_NAME}" iptables -L FORWARD -v

echo
echo "[INFO] Mirror experiment completed."
