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
#echo ""
#echo "Installing Python3 in required containers..."
#install_python3_in_container "$EXT_DN_CONTAINER"
#install_python3_in_container "$EDGE_CONTAINER"

#echo ""
#echo "Setting up Python environment in containers..."
#echo "→ Setting up $EXT_DN_CONTAINER:"
#docker exec $EXT_DN_CONTAINER bash -c "source /opt/conda/etc/profile.d/conda.sh && conda activate torch222"
#echo "→ Result: $?"

#echo "→ Setting up $EDGE_CONTAINER:"
#docker exec $EDGE_CONTAINER bash -c "source /opt/conda/etc/profile.d/conda.sh && conda activate torch222"
#echo "→ Result: $?"

echo ""
echo "All services are ready!"