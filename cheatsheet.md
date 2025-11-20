conda activate oran

# First step
cd openairinterface5g/ci-scripts/yaml_files/5g_rfsimulator
docker-compose up -d mysql oai-amf oai-smf oai-upf oai-ext-dn

# second step
docker-compose up -d oai-gnb
docker logs rfsim5g-oai-amf


# Others
docker ps                      # find the running container ID
docker exec -it <ID> /bin/bash # "enter" the containter

# End 
docker-compose down

# UE ping
docker exec -it rfsim5g-oai-nr-ue \
  ping -I oaitun_ue1 192.168.72.135
# DN tcmpdump
 docker exec -it rfsim5g-oai-ext-dn tcpdump -i eth0 

# UDP
python3 udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0

 python3 udp_sender_bidirect.py \
  --ip 192.168.72.135 \
  --port 5000 \
  --listen-port 5001 \
  --src-ip 12.1.1.2 \
  --interval 1.0