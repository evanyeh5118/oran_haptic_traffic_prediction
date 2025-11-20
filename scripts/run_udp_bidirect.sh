#!/bin/bash

# Script to run UDP bidirectional communication test
# Sends packets from UE to ext-dn and receives echo responses

DOCKER_COMPOSE_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"
SRC_PY_DIR="src/udp/"
UE_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ue-shared"
EXT_DN_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ext-dn-shared"
UE_CONTAINER="rfsim5g-oai-nr-ue"
EXT_DN_CONTAINER="rfsim5g-oai-ext-dn"
SENDER_INTERVAL=1

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
cp ${SRC_PY_DIR}/udp_receiver_bidirect.py "${EXT_DN_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Receiver script copied to ${EXT_DN_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy receiver script${NC}"
    exit 1
fi

# ===== CHECK AND INSTALL PYTHON3 =====
echo -e "${BLUE}[INFO] Checking if Python3 exists in ext-dn container...${NC}"
docker exec ${EXT_DN_CONTAINER} which python3 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Python3 already installed${NC}"
else
    echo -e "${YELLOW}[INFO] Python3 not found, installing...${NC}"
    echo -e "${BLUE}[INFO] Running: apt-get update && apt-get install -y python3${NC}"
    docker exec ${EXT_DN_CONTAINER} bash -c "apt-get update && apt-get install -y python3"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS] Python3 installation command completed${NC}"
    else
        echo -e "${RED}[ERROR] Failed to install Python3${NC}"
        echo -e "${RED}[ERROR] Please check if the container is running and has internet access${NC}"
        exit 1
    fi
    
    # Verify Python3 is installed and ready
    echo -e "${BLUE}[INFO] Verifying Python3 installation...${NC}"
    sleep 2  # Wait a moment for installation to complete
    
    MAX_RETRIES=10
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        docker exec ${EXT_DN_CONTAINER} which python3 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[SUCCESS] Python3 verified and ready${NC}"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -e "${YELLOW}[INFO] Waiting for Python3 to be ready... (attempt $RETRY_COUNT/$MAX_RETRIES)${NC}"
        sleep 1
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}[ERROR] Python3 verification failed after multiple attempts${NC}"
        exit 1
    fi
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

docker exec -it ${UE_CONTAINER} python3 /ue-shared/udp_sender_bidirect.py \
  --ip 192.168.72.135 \
  --port 5000 \
  --listen-port 5001 \
  --src-ip 12.1.1.2 \
  --interval ${SENDER_INTERVAL} \
  --iface oaitun_ue1

echo -e "${BLUE}[INFO] UDP sender stopped${NC}"
echo -e "${BLUE}[INFO] Cleaning up receiver process...${NC}"
kill $RECEIVER_PID 2>/dev/null
wait $RECEIVER_PID 2>/dev/null

