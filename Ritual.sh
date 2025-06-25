#!/usr/bin/env bash

#===============================
# Multi-Node Ritual Installer
#===============================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Root check
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This script must be run as root. Use 'sudo -i'.${NC}"
    exit 1
fi

# Ensure .foundry/bin in PATH
if ! grep -q 'export PATH="$HOME/.foundry/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.foundry/bin:$PATH"

# Header
function print_banner() {
    clear
    echo -e "${CYAN}"
    echo -e "${BLUE} ██████╗ ███████╗████████╗██╗   ██╗██╗██╗     ███████╗${NC}"
    echo -e "${BLUE}██╔════╝ ██╔════╝╚══██╔══╝██║   ██║██║██║     ██╔════╝${NC}"
    echo -e "${BLUE}██║  ███╗█████╗     ██║   ██║   ██║██║██║     █████╗  ${NC}"
    echo -e "${BLUE}██║   ██║██╔══╝     ██║   ██║   ██║██║██║     ██╔══╝  ${NC}"
    echo -e "${BLUE}╚██████╔╝███████╗   ██║   ╚██████╔╝██║███████╗███████╗${NC}"
    echo -e "${BLUE} ╚═════╝ ╚══════╝   ╚═╝    ╚═════╝ ╚═╝╚══════╝╚══════╝${NC}"
    echo -e "${YELLOW}       Ritual Node Multi-Installer Script${NC}"
}

# Update system and install deps
function install_dependencies() {
    apt update && apt upgrade -y
    apt install -y curl git jq lz4 build-essential screen python3 python3-pip docker.io
    systemctl enable docker && systemctl start docker
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client
}

# Install Foundry
function install_foundry() {
    curl -L https://foundry.paradigm.xyz | bash
    $HOME/.foundry/bin/foundryup
    rm -f /usr/bin/forge
}

# Clone or update repo
function get_repository() {
    if [ -d "$HOME/infernet-container-starter" ]; then
        cd "$HOME/infernet-container-starter" && git pull
    else
        git clone https://github.com/ritual-net/infernet-container-starter.git
    fi
}

# Prepare forge libraries
function install_forge_libs() {
    cd "$HOME/infernet-container-starter/projects/hello-world/contracts"
    rm -rf lib/forge-std lib/infernet-sdk
    forge install --no-commit foundry-rs/forge-std
    forge install --no-commit ritual-net/infernet-sdk
}

# Setup multiple nodes
function setup_multi_nodes() {
    read -p "How many nodes do you want to install? " NODE_COUNT

    for i in $(seq 1 $NODE_COUNT); do
        echo -e "${CYAN}Setting up node $i...${NC}"

        read -p "Enter private key for node $i (0x...): " PRIV_KEY
        PORT_OFFSET=$((50 + i))

        cp -r "$HOME/infernet-container-starter" "$HOME/infernet-node-$i"
        cd "$HOME/infernet-node-$i"

        sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIV_KEY\"|" deploy/config.json
        sed -i "s|0.0.0.0:4000:4000|0.0.0.0:4${PORT_OFFSET}0:4000|" deploy/docker-compose.yaml
        sed -i "s|8545:3000|85${PORT_OFFSET}:3000|" deploy/docker-compose.yaml

        docker compose -f deploy/docker-compose.yaml up -d
    done
}

# Menu
function main_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}Choose an option:${NC}"
        echo -e "1) Install Ritual Node(s)"
        echo -e "2) View logs for a node"
        echo -e "3) Remove all Ritual Nodes"
        echo -e "4) Exit"
        read -p "Enter your choice: " CHOICE

        case $CHOICE in
            1) install_dependencies; install_foundry; get_repository; install_forge_libs; setup_multi_nodes;;
            2) read -p "Enter node number to view logs: " N; docker logs -f $(docker ps -qf name=infernet-node-$N);;
            3) echo "Removing all Ritual node containers..."; docker ps -aq | xargs docker rm -f;;
            4) echo "Exiting..."; exit 0;;
            *) echo -e "${RED}Invalid option.${NC}";;
        esac
        read -n 1 -s -r -p "${YELLOW}Press any key to continue...${NC}"
    done
}

main_menu
