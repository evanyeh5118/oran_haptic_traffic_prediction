#!/bin/bash

# Script to run edge traffic prediction
# Runs edge.py in the oai-edge container
# Listens for incoming UDP traffic on the configured IP and port
# Uses context_aware_traffic_predictor for traffic pattern prediction

DOCKER_COMPOSE_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"
CONTEXT_PREDICTOR_DIR="context_aware_traffic_predictor"
OAI_EDGE_SHARED_DIR="${DOCKER_COMPOSE_DIR}/oai-edge-shared"
OAI_EDGE_CONTAINER="rfsim5g-oai-edge"
EDGE_IP="192.168.72.136"
EDGE_PORT=5000
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
    echo -e "${BLUE}[INFO] All processes stopped${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

echo -e "${BLUE}[INFO] ===== MANAGING CONTEXT_AWARE_TRAFFIC_PREDICTOR =====${NC}"

# Check if context_aware_traffic_predictor already exists in oai-edge-shared
if [ -d "${OAI_EDGE_SHARED_DIR}/context_aware_traffic_predictor" ]; then
    echo -e "${YELLOW}[WARNING] context_aware_traffic_predictor already exists in ${OAI_EDGE_SHARED_DIR}${NC}"
    echo -e "${BLUE}[INFO] Deleting existing context_aware_traffic_predictor...${NC}"
    rm -rf "${OAI_EDGE_SHARED_DIR}/context_aware_traffic_predictor"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS] Deleted existing context_aware_traffic_predictor${NC}"
    else
        echo -e "${RED}[ERROR] Failed to delete existing context_aware_traffic_predictor${NC}"
        exit 1
    fi
fi

# Copy context_aware_traffic_predictor from project root to oai-edge-shared
echo -e "${BLUE}[INFO] Copying context_aware_traffic_predictor to oai-edge-shared...${NC}"
cp -r "${CONTEXT_PREDICTOR_DIR}" "${OAI_EDGE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] context_aware_traffic_predictor copied to ${OAI_EDGE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy context_aware_traffic_predictor${NC}"
    exit 1
fi

echo -e "${GREEN}[SUCCESS] context_aware_traffic_predictor setup complete${NC}"

# ===== EXECUTE EDGE PREDICTOR =====
echo -e "\n${BLUE}[INFO] ===== EXECUTING EDGE PREDICTOR =====${NC}"
echo -e "${BLUE}[INFO] Container: ${OAI_EDGE_CONTAINER}${NC}"
echo -e "${BLUE}[INFO] Listening on IP: ${EDGE_IP}${NC}"
echo -e "${BLUE}[INFO] Listening on port: ${EDGE_PORT}${NC}"
echo -e "${BLUE}[INFO] Predictor location: /oai-edge-shared/context_aware_traffic_predictor/src/network/edge.py${NC}"

VERBOSE_FLAG=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_FLAG="--verbose"
fi

docker exec -it ${OAI_EDGE_CONTAINER} bash -lc \
  "(ip addr show dev eth0 | grep -q 192.168.72.135 || ip addr add 192.168.72.135/24 dev eth0 || true) && source /opt/conda/etc/profile.d/conda.sh && conda activate torch222 && python3 -u /oai-edge-shared/context_aware_traffic_predictor/src/network/edge.py \
  --listen-port ${EDGE_PORT} \
  --listen-ip 0.0.0.0 \
  ${VERBOSE_FLAG}"

echo -e "${BLUE}[INFO] edge predictor stopped${NC}"


