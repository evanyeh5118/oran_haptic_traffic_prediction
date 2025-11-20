#!/bin/bash
set -e

docker exec -it rfsim5g-oai-nr-ue \
  python3 /ue-shared/udp_sender.py \
    --ip 192.168.72.135 \
    --port 5000 \
    --payload "ue-test" \
    --interval 1 \
    --iface oaitun_ue1
