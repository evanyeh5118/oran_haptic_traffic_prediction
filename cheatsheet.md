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


pip install torch==2.2.2+cpu --extra-index-url https://download.pytorch.org/whl/cpu


# setup environment
apt-get update && apt-get install -y wget && \
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
bash /tmp/miniconda.sh -b -p /opt/conda && \
rm /tmp/miniconda.sh \
export PATH="/opt/conda/bin:$PATH"

conda update -n base -c defaults conda && \
conda create -y -n py39 python=3.9 && \
conda clean -afy

source /opt/conda/etc/profile.d/conda.sh && \
  conda activate py39 && \
  conda install -y pandas numpy && \
  conda clean -afy

docker exec rfsim5g-oai-edge /opt/conda/bin/conda run -n torch222 python3 ../oai-edge-shared/test_torch.py

docker exec rfsim5g-oai-ext-dn /opt/conda/bin/conda run -n torch222 python3 /ext-dn-shared/udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0

python3 udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0

docker exec rfsim5g-oai-ext-dn bash -lc \
  "source /opt/conda/etc/profile.d/conda.sh && conda activate torch222 && python3 udp_receiver_bidirect.py \
  --listen-port 5000 \
  --response-ip 12.1.1.2 \
  --response-port 5001 \
  --listen-ip 0.0.0.0"
