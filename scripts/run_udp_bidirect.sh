#!/bin/bash

# Script to run UDP bidirectional communication test
# Sends packets from UE to ext-dn and receives echo responses

#--------------------------------------------------------
# UE: udp_sender_bidirect.py
# ext-dn: udp_receiver_bidirect.py
# No program running on the edge, so once the mirroring to edge is established, 
# edge will echo back the packets to the UE automatically, and UE shows a unknown packets.
#--------------------------------------------------------

DOCKER_COMPOSE_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"
SRC_PY_DIR="src/udp/"
UE_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ue-shared"
EXT_DN_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ext-dn-shared"
UE_CONTAINER="rfsim5g-oai-nr-ue"
EXT_DN_CONTAINER="rfsim5g-oai-ext-dn"
SENDER_INTERVAL=1
CONDA_ENV="torch222"  # Conda environment to activate (change as needed)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function to kill background processes
cleanup() {
    echo -e "\n${BLUE}[INFO] Shutting down...${NC}"
    if [ ! -z "$RECEIVER_PID" ]; then
        kill $RECEIVER_PID 2>/dev/null
        wait $RECEIVER_PID 2>/dev/null
        sleep 1
    fi
    
    # Kill any leftover receiver processes in the container
    echo -e "${BLUE}[INFO] Cleaning up leftover processes in ext-dn container...${NC}"
    docker exec ${EXT_DN_CONTAINER} pkill -f "udp_receiver_bidirect" 2>/dev/null || true
    docker exec ${EXT_DN_CONTAINER} pkill -f "haptic_receiver" 2>/dev/null || true
    
    echo -e "${BLUE}[INFO] All processes stopped${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ===== SETUP RECEIVER (ext-dn) =====
echo -e "${BLUE}[INFO] Copying UDP receiver script to ext-dn shared volume...${NC}"
cp ${SRC_PY_DIR}/udp_receiver_bidirect.py "${EXT_DN_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Receiver script copied to ${EXT_DN_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy receiver script${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO] Starting UDP receiver in ext-dn container: ${EXT_DN_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Listening on 192.168.72.135:5000, echoing to UE (12.1.1.2:5001)${NC}"

docker exec ${EXT_DN_CONTAINER} bash -lc \
  "source /opt/conda/etc/profile.d/conda.sh && conda activate ${CONDA_ENV} && python3 -u /ext-dn-shared/udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0" &

RECEIVER_PID=$!
sleep 2  # Give receiver time to start

# ===== SETUP SENDER (UE) =====
echo -e "${BLUE}[INFO] Copying UDP sender script to UE shared volume...${NC}"
cp ${SRC_PY_DIR}/udp_sender_bidirect.py "${UE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Sender script copied to ${UE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy sender script${NC}"
    kill $RECEIVER_PID 2>/dev/null
    exit 1
fi

echo -e "${BLUE}[INFO] Executing UDP sender in UE container: ${UE_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Sending to ext-dn (192.168.72.135:5000) from UE (12.1.1.2)${NC}"

docker exec -it ${UE_CONTAINER} bash -c "python3 /ue-shared/udp_sender_bidirect.py \
  --ip 192.168.72.135 \
  --port 5000 \
  --listen-port 5001 \
  --src-ip 12.1.1.2 \
  --interval ${SENDER_INTERVAL} \
  --iface oaitun_ue1"

echo -e "${BLUE}[INFO] UDP sender stopped${NC}"
echo -e "${BLUE}[INFO] Cleaning up receiver process...${NC}"
kill $RECEIVER_PID 2>/dev/null
wait $RECEIVER_PID 2>/dev/null