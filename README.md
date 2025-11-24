# Codebase Structure Overview

This document provides a high-level explanation of the `@scripts` directory and the `@src` directory (specifically `openairinterface5g/openair1/PHY/nr_phy_common/src`).

## 1. Scripts Directory (`/scripts`)

The `scripts` directory contains Bash scripts primarily used for orchestrating the OpenAirInterface (OAI) 5G RF simulator environment. These are categorized by their function below.

### 1. Launching/Ending
Scripts to manage the lifecycle of the OAI 5G emulation stack.

| Script Name | Description |
|:---|:---|
| **`run_start_oai.sh`** | Orchestrates the startup of the full 5G emulation stack (Core Network, gNB, UE) using Docker Compose. It waits for services to become healthy before proceeding. |
| **`run_end_oai.sh`** | Stops and cleans up the OAI services started by the start script. |

### 2. Configure UPF for Mirror
Scripts to set up traffic mirroring from the Core Network (UPF) to an edge node.

| Script Name | Description |
|:---|:---|
| **`run_mirrow_to_edge.sh`** | Configures traffic mirroring from the User Plane Function (UPF) to the edge container. It copies the setup script (`upf_mirror_to_edge.sh`) into the UPF container and executes it. |
| **`upf_mirror_to_edge.sh`** | Run *inside* the UPF container. It uses `iptables` (specifically the `TEE` target) to clone UDP packets destined for the external data network and send a copy to the edge server. |
| **`run_reset_iptables.sh`** | Clears the `iptables` rules, effectively removing the traffic mirroring configuration. |

### 3. UDP Experiment
Scripts for running generic UDP traffic experiments.

| Script Name | Description |
|:---|:---|
| **`run_udp_edge.sh`** | Deploys a general UDP edge receiver (`udp_edge.py`) to listen for traffic in the `oai-edge` container. |
| **`run_udp_bidirect.sh`** | Orchestrates a bidirectional UDP traffic experiment, managing traffic flow in both directions. |

### 4. Haptic Experiment
Scripts for running context-aware haptic traffic experiments.

| Script Name | Description |
|:---|:---|
| **`run_haptic_edge.sh`** | Deploys and runs a traffic prediction application (`context_aware_traffic_predictor`) inside the `oai-edge` container. It handles copying files and setting up the Python environment. |
| **`run_haptic_bidirect.sh`** | Orchestrates a bidirectional haptic traffic experiment. |

