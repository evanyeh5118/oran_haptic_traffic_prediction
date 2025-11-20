#!/bin/bash

# Script to run UDP bidirectional communication test
# Sends packets from UE to ext-dn and receives echo responses

DOCKER_COMPOSE_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"
UE_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ue-shared"
EXT_DN_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ext-dn-shared"
UE_CONTAINER="rfsim5g-oai-nr-ue"
EXT_DN_CONTAINER="rfsim5g-oai-ext-dn"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function to kill background processes
cleanup() {
    echo -e "\n${BLUE}[INFO] Shutting down...${NC}"
    kill $RECEIVER_PID 2>/dev/null
    wait $RECEIVER_PID 2>/dev/null
    echo -e "${BLUE}[INFO] All processes stopped${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ===== SETUP RECEIVER (ext-dn) =====
echo -e "${BLUE}[INFO] Copying UDP receiver script to ext-dn shared volume...${NC}"
cp scripts/pyscripts/udp_receiver_bidirect.py "${EXT_DN_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Receiver script copied to ${EXT_DN_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy receiver script${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO] Installing Python3 in ext-dn container...${NC}"
docker exec ${EXT_DN_CONTAINER} apt-get update -qq && apt-get install -y -qq python3 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Python3 installed${NC}"
else
    echo -e "${YELLOW}[WARNING] Could not install Python3, attempting with existing setup${NC}"
fi

echo -e "${BLUE}[INFO] Starting UDP receiver in ext-dn container: ${EXT_DN_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Listening on 192.168.72.135:5000, echoing to UE (12.1.1.2:5001)${NC}"

docker exec ${EXT_DN_CONTAINER} python3 /ext-dn-shared/udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0 &

RECEIVER_PID=$!
sleep 2  # Give receiver time to start

# ===== SETUP SENDER (UE) =====
echo -e "${BLUE}[INFO] Copying UDP sender script to UE shared volume...${NC}"
cp scripts/pyscripts/udp_sender_bidirect.py "${UE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Sender script copied to ${UE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy sender script${NC}"
    kill $RECEIVER_PID 2>/dev/null
    exit 1
fi

echo -e "${BLUE}[INFO] Executing UDP sender in UE container: ${UE_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Sending to ext-dn (192.168.72.135:5000) from UE (12.1.1.2)${NC}"

docker exec -it ${UE_CONTAINER} python3 /ue-shared/udp_sender_bidirect.py \
  --ip 192.168.72.135 \
  --port 5000 \
  --listen-port 5001 \
  --src-ip 12.1.1.2 \
  --interval 1.0 \
  --iface oaitun_ue1

echo -e "${BLUE}[INFO] UDP sender stopped${NC}"
echo -e "${BLUE}[INFO] Cleaning up receiver process...${NC}"
kill $RECEIVER_PID 2>/dev/null
wait $RECEIVER_PID 2>/dev/null

