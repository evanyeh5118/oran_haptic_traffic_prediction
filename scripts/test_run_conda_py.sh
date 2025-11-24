#!/bin/bash

set -x
set -e

docker exec rfsim5g-oai-ext-dn bash -lc \
  "source /opt/conda/etc/profile.d/conda.sh && conda activate torch222 && python3 -u /ext-dn-shared/udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0"