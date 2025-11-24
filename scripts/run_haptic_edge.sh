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


# Copy haptic_edge.py to oai-edge-shared
echo -e "${BLUE}[INFO] Copying haptic_edge.py to oai-edge-shared...${NC}"
cp "src/traffic_predictor/haptic_edge.py" "${OAI_EDGE_SHARED_DIR}/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] haptic_edge.py copied to ${OAI_EDGE_SHARED_DIR}/${NC}"
else
    echo -e "${RED}[ERROR] Failed to copy haptic_edge.py${NC}"
    exit 1
fi

VERBOSE_FLAG=""
if [ "$VERBOSE" = true ]; then
    VERBOSE_FLAG="--verbose"
fi

docker exec -it ${OAI_EDGE_CONTAINER} bash -lc \
  "source /opt/conda/etc/profile.d/conda.sh && conda activate torch222 && python3 -u /oai-edge-shared/haptic_edge.py \
  --listen-port ${EDGE_PORT} \
  --listen-ip ${EDGE_IP} \
  ${VERBOSE_FLAG}"

echo -e "${BLUE}[INFO] edge predictor stopped${NC}"


