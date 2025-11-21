#!/bin/bash

# Script to run haptic forward traffic sender
# Sends haptic packets from UE to ext-dn using haptic_sender.py
# Reads from haptic_dataset.csv via dataset_reader.py
# This is a forward (one-way) communication mode

DOCKER_COMPOSE_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"
SRC_PY_DIR="src/traffic_predictor"
DATA_DIR="data"
UE_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ue-shared"
EXT_DN_SHARED_DIR="${DOCKER_COMPOSE_DIR}/ext-dn-shared"
UE_CONTAINER="rfsim5g-oai-nr-ue"
EXT_DN_CONTAINER="rfsim5g-oai-ext-dn"
TIME_SCALE=1.0
LISTEN_PORT=5001
EXT_DN_IP="192.168.72.135"
EXT_DN_PORT=5000
UE_SRC_IP="12.1.1.2"
UE_IFACE="oaitun_ue1"
VERBOSE=true

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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

echo -e "${BLUE}[INFO] ===== COPYING REQUIRED FILES TO UE SHARED VOLUME =====${NC}"

# ===== COPY FILE 1: dataset_reader.py =====
echo -e "${BLUE}[INFO] Copying dataset_reader.py to UE shared volume...${NC}"
cp "${SRC_PY_DIR}/dataset_reader.py" "${UE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] dataset_reader.py copied to ${UE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy dataset_reader.py${NC}"
    exit 1
fi

# ===== COPY FILE 2: haptic_sender.py =====
echo -e "${BLUE}[INFO] Copying haptic_sender.py to UE shared volume...${NC}"
cp "${SRC_PY_DIR}/haptic_sender.py" "${UE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] haptic_sender.py copied to ${UE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy haptic_sender.py${NC}"
    exit 1
fi

# ===== COPY FILE 3: haptic_dataset.csv =====
echo -e "${BLUE}[INFO] Copying haptic_dataset.csv to UE shared volume...${NC}"
cp "${DATA_DIR}/haptic_dataset.csv" "${UE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] haptic_dataset.csv copied to ${UE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy haptic_dataset.csv${NC}"
    exit 1
fi

echo -e "${GREEN}[SUCCESS] All required files copied to UE shared volume${NC}"

# ===== SETUP RECEIVER (ext-dn) =====
echo -e "\n${BLUE}[INFO] ===== COPYING HAPTIC RECEIVER TO EXT-DN =====${NC}"
echo -e "${BLUE}[INFO] Copying haptic_receiver.py to ext-dn shared volume...${NC}"
cp "${SRC_PY_DIR}/haptic_receiver.py" "${EXT_DN_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] haptic_receiver.py copied to ${EXT_DN_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy haptic_receiver.py${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO] Starting haptic receiver in ext-dn container: ${EXT_DN_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Listening on ${EXT_DN_IP}:${EXT_DN_PORT}, echoing to UE (${UE_SRC_IP}:${LISTEN_PORT})${NC}"

docker exec ${EXT_DN_CONTAINER} python3 /ext-dn-shared/haptic_receiver.py \
  --listen-port ${EXT_DN_PORT} \
  --response-ip ${UE_SRC_IP} \
  --response-port ${LISTEN_PORT} \
  --listen-ip ${EXT_DN_IP} &

RECEIVER_PID=$!
sleep 2  # Give receiver time to start

# ===== EXECUTE HAPTIC SENDER (UE) =====
echo -e "\n${BLUE}[INFO] ===== EXECUTING HAPTIC SENDER =====${NC}"
echo -e "${BLUE}[INFO] Container: ${UE_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Sending to ext-dn (${EXT_DN_IP}:${EXT_DN_PORT})${NC}"
echo -e "${BLUE}[INFO] Source: UE (${UE_SRC_IP}) on interface ${UE_IFACE}${NC}"
echo -e "${BLUE}[INFO] Listen port: ${LISTEN_PORT}${NC}"
echo -e "${BLUE}[INFO] CSV dataset: /ue-shared/haptic_dataset.csv${NC}"
echo -e "${BLUE}[INFO] Time scale: ${TIME_SCALE}x${NC}"

VERBOSE_FLAG=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_FLAG="--verbose"
fi

docker exec -it ${UE_CONTAINER} python3 /ue-shared/haptic_sender.py \
  --ip ${EXT_DN_IP} \
  --port ${EXT_DN_PORT} \
  --csv /ue-shared/haptic_dataset.csv \
  --src-ip ${UE_SRC_IP} \
  --iface ${UE_IFACE} \
  --listen-port ${LISTEN_PORT} \
  --time-scale ${TIME_SCALE} \
  ${VERBOSE_FLAG}

echo -e "${BLUE}[INFO] haptic_sender stopped${NC}"
echo -e "${BLUE}[INFO] Cleaning up receiver process...${NC}"
kill $RECEIVER_PID 2>/dev/null
wait $RECEIVER_PID 2>/dev/null

