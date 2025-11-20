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