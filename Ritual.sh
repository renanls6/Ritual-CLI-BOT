#!/bin/bash

#======================#
#      COLOR CODES     #
#======================#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#======================#
#       HEADER         #
#======================#
display_header() {
    clear
    echo -e "${CYAN}"
    echo -e " ${BLUE} ██████╗ ██╗  ██╗    ██████╗ ███████╗███╗   ██╗ █████╗ ███╗   ██╗${NC}"
    echo -e " ${BLUE}██╔═████╗╚██╗██╔╝    ██╔══██╗██╔════╝████╗  ██║██╔══██╗████╗  ██║${NC}"
    echo -e " ${BLUE}██║██╔██║ ╚███╔╝     ██████╔╝█████╗  ██╔██╗ ██║███████║██╔██╗ ██║${NC}"
    echo -e " ${BLUE}████╔╝██║ ██╔██╗     ██╔══██╗██╔══╝  ██║╚██╗██║██╔══██║██║╚██╗██║${NC}"
    echo -e " ${BLUE}╚██████╔╝██╔╝ ██╗    ██║  ██║███████╗██║ ╚████║██║  ██║██║ ╚████║${NC}"
    echo -e " ${BLUE}╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${GREEN}       ✨ Ritual Network Infernet Node Script ✨${NC}"
    echo -e "${BLUE}=======================================================${NC}"
}

#======================#
#      CHECK ROOT      #
#======================#
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}⚠️  Please run this script as root (sudo -i).${NC}"
    exit 1
fi

#======================#
#     INSTALL NODE     #
#======================#
install_ritual_node() {
    display_header
    echo -e "${YELLOW}🚀 Starting Ritual Network Infernet installation...${NC}"

    echo -e "${CYAN}🔧 Updating system and installing dependencies...${NC}"
    apt update && apt upgrade -y
    apt install -y curl git jq lz4 build-essential screen docker.io docker-compose

    echo -e "${CYAN}🐳 Installing Docker Compose...${NC}"
    systemctl enable docker --now

    # Input user keys
    echo -e "${YELLOW}🔐 Enter your Private Key (starts with 0x):${NC}"
    read -s PRIVATE_KEY
    if [[ ! $PRIVATE_KEY =~ ^0x ]]; then
        PRIVATE_KEY="0x$PRIVATE_KEY"
    fi

    echo -e "${YELLOW}🌐 Enter your RPC URL (e.g., https://mainnet.base.org):${NC}"
    read RPC_URL

    # Clone Repository
    echo -e "${CYAN}📥 Cloning repository...${NC}"
    git clone https://github.com/ritual-net/infernet-container-starter.git
    cd infernet-container-starter

    # Create config.json
    echo -e "${CYAN}⚙️  Creating configuration...${NC}"
    cat > deploy/config.json <<EOL
{
  "log_path": "infernet_node.log",
  "server": {
    "port": 4000,
    "rate_limit": {
      "num_requests": 100,
      "period": 100
    }
  },
  "chain": {
    "enabled": true,
    "trail_head_blocks": 3,
    "rpc_url": "${RPC_URL}",
    "registry_address": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170",
    "wallet": {
      "max_gas_limit": 4000000,
      "private_key": "${PRIVATE_KEY}",
      "allowed_sim_errors": []
    },
    "snapshot_sync": {
      "sleep": 3,
      "batch_size": 10000,
      "starting_sub_id": 180000,
      "sync_period": 30
    }
  },
  "startup_wait": 1.0,
  "redis": {
    "host": "redis",
    "port": 6379
  },
  "forward_stats": true,
  "containers": [
    {
      "id": "hello-world",
      "image": "ritualnetwork/hello-world-infernet:latest",
      "external": true,
      "port": "3000",
      "command": "--bind=0.0.0.0:3000 --workers=2"
    }
  ]
}
EOL

    echo -e "${CYAN}🐳 Starting Docker containers...${NC}"
    docker compose -f deploy/docker-compose.yaml up -d

    echo -e "${GREEN}✅ Ritual Node installed and running!${NC}"
    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to the main menu...${NC}")"
}

#======================#
#        LOGS          #
#======================#
view_logs() {
    display_header
    echo -e "${CYAN}📜 Showing Ritual Node logs...${NC}"
    docker compose -f ~/infernet-container-starter/deploy/docker-compose.yaml logs -f
}

#======================#
#       UNINSTALL      #
#======================#
uninstall_ritual_node() {
    display_header
    echo -e "${RED}⚠️  Removing Ritual Node...${NC}"
    docker compose -f ~/infernet-container-starter/deploy/docker-compose.yaml down
    rm -rf ~/infernet-container-starter
    echo -e "${GREEN}✅ Ritual Node removed successfully.${NC}"
    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to the main menu...${NC}")"
}

#======================#
#      MAIN MENU       #
#======================#
main_menu() {
    while true; do
        display_header
        echo -e "${BLUE}To exit, press Ctrl+C${NC}"
        echo -e "${YELLOW}Choose an option:${NC}"
        echo -e "1) ${GREEN}Install Ritual Node${NC}"
        echo -e "2) ${CYAN}View Logs${NC}"
        echo -e "3) ${RED}Remove Ritual Node${NC}"
        echo -e "4) ${MAGENTA}Exit${NC}"
        read -p "$(echo -e "${BLUE}Enter your choice: ${NC}")" choice

        case $choice in
            1) install_ritual_node ;;
            2) view_logs ;;
            3) uninstall_ritual_node ;;
            4) echo -e "${GREEN}Bye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
    done
}

#======================#
#    START SCRIPT      #
#======================#
main_menu
