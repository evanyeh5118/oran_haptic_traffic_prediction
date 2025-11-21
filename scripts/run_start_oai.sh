#!/bin/bash

TARGET_DIR="openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator"
CORE_SERVICES=("mysql" "oai-amf" "oai-smf" "oai-upf" "oai-ext-dn" "oai-edge")
GNB_SERVICE="oai-gnb"
UE_SERVICE="oai-nr-ue"
AMF_CONTAINER_NAME="rfsim5g-oai-amf"
EXT_DN_CONTAINER="rfsim5g-oai-ext-dn"
EDGE_CONTAINER="rfsim5g-oai-edge"

wait_for_healthy() {
    local svc=$1
    echo "Waiting for $svc to be healthy..."

    while true; do
        CID=$(docker-compose ps -q "$svc")

        if [ -z "$CID" ]; then
            echo "→ $svc not started yet. Retrying..."

            sleep 2
            continue
        fi

        STATUS=$(docker inspect -f '{{.State.Health.Status}}' "$CID" 2>/dev/null || echo "starting")

        if [ "$STATUS" == "healthy" ]; then
            echo "→ $svc is healthy."
            break
        fi

        echo "→ $svc health = $STATUS. Retrying in 3 seconds..."
        sleep 3
    done
}

install_python3_in_container() {
    local CONTAINER=$1
    
    # Colors for output
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local RED='\033[0;31m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color
    
    echo -e "${BLUE}[INFO] Checking if Python3 exists in $CONTAINER container...${NC}"
    docker exec ${CONTAINER} which python3 > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS] Python3 already installed in $CONTAINER${NC}"
    else
        echo -e "${YELLOW}[INFO] Python3 not found in $CONTAINER, installing...${NC}"
        echo -e "${BLUE}[INFO] Running: apt-get update && apt-get install -y python3${NC}"
        docker exec ${CONTAINER} bash -c "apt-get update && apt-get install -y python3"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[SUCCESS] Python3 installation command completed in $CONTAINER${NC}"
        else
            echo -e "${RED}[ERROR] Failed to install Python3 in $CONTAINER${NC}"
            echo -e "${RED}[ERROR] Please check if the container is running and has internet access${NC}"
            exit 1
        fi
        
        # Verify Python3 is installed and ready
        echo -e "${BLUE}[INFO] Verifying Python3 installation in $CONTAINER...${NC}"
        sleep 2  # Wait a moment for installation to complete
        
        local MAX_RETRIES=10
        local RETRY_COUNT=0
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            docker exec ${CONTAINER} which python3 > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[SUCCESS] Python3 verified and ready in $CONTAINER${NC}"
                break
            fi
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo -e "${YELLOW}[INFO] Waiting for Python3 to be ready in $CONTAINER... (attempt $RETRY_COUNT/$MAX_RETRIES)${NC}"
            sleep 1
        done
        
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo -e "${RED}[ERROR] Python3 verification failed in $CONTAINER after multiple attempts${NC}"
            exit 1
        fi
    fi
}

cd "$TARGET_DIR"

echo "Starting core services: ${CORE_SERVICES[*]}"
docker-compose up -d "${CORE_SERVICES[@]}"

echo ""
echo "Checking health of core services..."
for svc in "${CORE_SERVICES[@]}"; do
    wait_for_healthy "$svc"
done

echo ""
echo "All core services are healthy."
echo "Starting $GNB_SERVICE..."
docker-compose up -d "$GNB_SERVICE"

wait_for_healthy "$GNB_SERVICE"

echo ""
echo "gNB is healthy. Starting $UE_SERVICE..."
docker-compose up -d "$UE_SERVICE"

wait_for_healthy "$UE_SERVICE"

echo ""
echo "UE is healthy. Fetching AMF logs..."
docker logs "$AMF_CONTAINER_NAME"

# ===== CHECK AND INSTALL PYTHON3 =====
echo ""
echo "Installing Python3 in required containers..."
install_python3_in_container "$EXT_DN_CONTAINER"
install_python3_in_container "$EDGE_CONTAINER"

echo ""
echo "All services are ready!"