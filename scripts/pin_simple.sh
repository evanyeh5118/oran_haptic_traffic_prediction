#!/bin/bash
set -e

docker exec -it rfsim5g-oai-nr-ue \
  ping -I oaitun_ue1 192.168.72.135