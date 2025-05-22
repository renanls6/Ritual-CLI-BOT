#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Display header
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
    echo -e "${GREEN}       ✨ Ritual Node Installation Script ✨${NC}"
    echo -e "${BLUE}=======================================================${NC}"
}

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This script requires root privileges.${NC}"
    echo -e "${YELLOW}Please try running with 'sudo -i' to switch to root user, then run this script again.${NC}"
    exit 1
fi

# Script save path
SCRIPT_PATH="$HOME/Ritual.sh"

# Main menu function
function main_menu() {
    while true; do
        display_header
        echo -e "${BLUE}To exit the script, press Ctrl+C${NC}"
        echo -e "${YELLOW}Please select an operation:${NC}"
        echo -e "1) ${GREEN}Install Ritual Node${NC}"
        echo -e "2) ${CYAN}View Ritual Node logs${NC}"
        echo -e "3) ${RED}Remove Ritual Node${NC}"
        echo -e "4) ${MAGENTA}Exit script${NC}"

        read -p "$(echo -e "${BLUE}Enter your choice: ${NC}")" choice

        case $choice in
            1) 
                install_ritual_node
                ;;
            2)
                view_logs
                ;;
            3)
                remove_ritual_node
                ;;
            4)
                echo -e "${GREEN}Exiting script!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option, please choose again.${NC}"
                ;;
        esac

        echo -e "${YELLOW}Press any key to continue...${NC}"
        read -n 1 -s
    done
}

# Install Ritual Node function
function install_ritual_node() {
    display_header

    echo -e "${YELLOW}System update and installing necessary packages...${NC}"
    apt update && apt upgrade -y
    apt -qy install curl git jq lz4 build-essential screen python3 python3-pip

    echo -e "${CYAN}[Info] Upgrading pip3 and installing infernet-cli / infernet-client${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    echo -e "${YELLOW}Checking Docker installation...${NC}"
    if command -v docker &> /dev/null; then
        echo -e "${GREEN} - Docker is already installed, skipping.${NC}"
    else
        echo -e "${YELLOW} - Docker not found, installing...${NC}"
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker
        systemctl start docker
        echo -e "${GREEN}Docker installation complete, current version:${NC}"
        docker --version
    fi

    echo -e "${YELLOW}Checking Docker Compose installation...${NC}"
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW} - Docker Compose not found, installing...${NC}"
        curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" \
             -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN} - Docker Compose already installed, skipping.${NC}"
    fi

    echo -e "${CYAN}[Verify] Docker Compose version:${NC}"
    docker compose version || docker-compose version

    echo
    echo -e "${YELLOW}Installing Foundry...${NC}"
    if pgrep anvil &>/dev/null; then
        echo -e "${YELLOW}[Warning] anvil is running, stopping to update Foundry.${NC}"
        pkill anvil
        sleep 2
    fi

    cd ~ || exit 1
    mkdir -p foundry
    cd foundry || exit 1
    curl -L https://foundry.paradigm.xyz | bash

    $HOME/.foundry/bin/foundryup

    # Ensure ~/.foundry/bin is in PATH for this script session
    export PATH="$HOME/.foundry/bin:$PATH"

    echo -e "${CYAN}[Verify] forge version:${NC}"
    if ! command -v forge &> /dev/null; then
        echo -e "${RED}[Error] forge command not found after installation.${NC}"
        exit 1
    fi

    # Remove /usr/bin/forge to prevent ZOE error
    if [ -f /usr/bin/forge ]; then
        echo -e "${CYAN}[Info] Removing /usr/bin/forge to avoid conflicts...${NC}"
        rm /usr/bin/forge
    fi

    echo -e "${GREEN}[Info] Foundry installation and environment setup complete.${NC}"
    cd ~ || exit 1

    # Clone infernet-container-starter repo fresh
    if [ -d "infernet-container-starter" ]; then
        echo -e "${YELLOW}Directory infernet-container-starter exists, removing...${NC}"
        rm -rf "infernet-container-starter"
        echo -e "${GREEN}Directory infernet-container-starter removed.${NC}"
    fi

    echo -e "${YELLOW}Cloning infernet-container-starter...${NC}"
    git clone https://github.com/ritual-net/infernet-container-starter

    cd infernet-container-starter || { echo -e "${RED}[Error] Failed to enter directory${NC}"; exit 1; }

    echo -e "${YELLOW}Pulling Docker image...${NC}"
    docker pull ritualnetwork/hello-world-infernet:latest

    echo -e "${YELLOW}Checking for existing screen session 'ritual'...${NC}"
    if screen -list | grep -q "ritual"; then
        echo -e "${YELLOW}[Info] Found existing ritual session, terminating...${NC}"
        screen -S ritual -X quit
        sleep 1
    fi

    echo -e "${YELLOW}Starting container deployment in screen session 'ritual'...${NC}"
    sleep 1
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'

    echo -e "${CYAN}[Info] Deployment running in background screen session (ritual).${NC}"

    echo
    echo -e "${YELLOW}Configuring Ritual Node files...${NC}"

    read -p "$(echo -e "${BLUE}Enter your Private Key (0x...): ${NC}")" PRIVATE_KEY

    RPC_URL="https://base-rpc.publicnode.com"
    REGISTRY="0x3B1554f346DFe5c482Bb4BA31b880c1C184be3a5"
    MERKLE_ROOT="0xb15a764f6c18cc47a43e9e2e456b26d5de73a4e02ae7168a1a913fe0086db8c2"
    TREASURY="0x7d3a13a2763286c2bcfb3f4d00e6283a5de4be18"
    RELAYER_URL="http://relay.ritual.network:3000"

    # Use jq to create JSON config reliably
    jq -n \
        --arg rpc "$RPC_URL" \
        --arg reg "$REGISTRY" \
        --arg merkle "$MERKLE_ROOT" \
        --arg treasury "$TREASURY" \
        --arg relayer "$RELAYER_URL" \
        --arg privkey "$PRIVATE_KEY" \
        '{rpc_url: $rpc, registry: $reg, merkle_root: $merkle, treasury: $treasury, relayer_url: $relayer, private_key: $privkey}' \
        > ritual-config.json

    echo -e "${GREEN}Ritual node configuration file created: ritual-config.json${NC}"

    echo -e "${YELLOW}Deploying contracts with foundry (forge)...${NC}"
    make deploy-contracts

    echo -e "${GREEN}Installation complete! You can now view logs or manage the ritual node.${NC}"
}

# View logs function
function view_logs() {
    display_header
    cd ~/infernet-container-starter || { echo -e "${RED}Directory infernet-container-starter not found. Please install first.${NC}"; return; }

    echo -e "${CYAN}Showing logs from ritual container (press Ctrl+C to exit)...${NC}"

    # Prefer docker compose v2 command if available
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose -f docker-compose.yaml logs -f ritual
    elif command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.yaml logs -f ritual
    else
        echo -e "${RED}Docker Compose not found. Cannot show logs.${NC}"
    fi
}

# Remove ritual node function
function remove_ritual_node() {
    display_header

    echo -e "${RED}You are about to completely remove the Ritual Node and all related files.${NC}"
    read -p "Are you sure you want to proceed? (y/N): " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            echo -e "${YELLOW}Stopping and removing ritual screen session...${NC}"
            if screen -list | grep -q "ritual"; then
                screen -S ritual -X quit
                echo -e "${GREEN}Screen session 'ritual' terminated.${NC}"
            else
                echo -e "${YELLOW}No ritual screen session found.${NC}"
            fi

            echo -e "${YELLOW}Removing infernet-container-starter directory...${NC}"
            rm -rf ~/infernet-container-starter
            echo -e "${GREEN}Directory removed.${NC}"

            echo -e "${YELLOW}Removing ritual configuration file...${NC}"
            rm -f ~/ritual-config.json
            echo -e "${GREEN}Configuration file removed.${NC}"

            echo -e "${YELLOW}Ritual Node removed successfully.${NC}"
            ;;
        *)
            echo -e "${CYAN}Removal cancelled.${NC}"
            ;;
    esac
}

# Check if the script is executed directly or sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_menu
fi
