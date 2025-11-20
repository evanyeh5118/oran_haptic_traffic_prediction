#!/bin/bash
set -euo pipefail

########################################
# 0. Flush iptables chain
########################################
docker exec -it rfsim5g-oai-upf iptables -t mangle -F UPF_MIRROR_TO_EDGE 2>/dev/null || true

