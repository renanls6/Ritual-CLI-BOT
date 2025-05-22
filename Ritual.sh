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

# Script save path (if needed)
SCRIPT_PATH="$HOME/Ritual.sh"

# Main menu function
main_menu() {
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
install_ritual_node() {
    display_header
    echo -e "${YELLOW}Starting Ritual Node installation...${NC}"

    # System update and install essential packages
    echo -e "${YELLOW}Updating system and installing dependencies...${NC}"
    apt update && apt upgrade -y
    apt install -qy curl git jq lz4 build-essential screen python3 python3-pip apt-transport-https ca-certificates software-properties-common

    # Upgrade pip and install infernet CLI and client
    echo -e "${CYAN}[Info] Installing/upgrading Python packages...${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    # Docker installation check
    echo -e "${YELLOW}Checking Docker installation...${NC}"
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker is already installed.${NC}"
    else
        echo -e "${YELLOW}Installing Docker...${NC}"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker
        systemctl start docker
        echo -e "${GREEN}Docker installed successfully.${NC}"
    fi

    # Docker Compose installation check
    echo -e "${YELLOW}Checking Docker Compose...${NC}"
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Installing Docker Compose...${NC}"
        curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN}Docker Compose is already installed.${NC}"
    fi

    docker compose version || docker-compose version

    # Foundry install and setup
    echo -e "${YELLOW}Installing Foundry...${NC}"
    if pgrep anvil &>/dev/null; then
        echo -e "${YELLOW}Stopping running anvil instance...${NC}"
        pkill anvil
        sleep 2
    fi

    cd ~ || exit 1
    mkdir -p foundry && cd foundry
    curl -L https://foundry.paradigm.xyz | bash
    $HOME/.foundry/bin/foundryup

    if [[ ":$PATH:" != *":$HOME/.foundry/bin:"* ]]; then
        export PATH="$HOME/.foundry/bin:$PATH"
    fi

    if ! command -v forge &> /dev/null; then
        echo -e "${RED}Forge not found after installation. Please check installation.${NC}"
        exit 1
    fi

    # Remove conflicting /usr/bin/forge if exists
    if [ -f /usr/bin/forge ]; then
        echo -e "${CYAN}Removing conflicting /usr/bin/forge...${NC}"
        rm /usr/bin/forge
    fi

    echo -e "${GREEN}Foundry installed and configured.${NC}"

    # Clone infernet-container-starter repo
    cd ~ || exit 1
    if [ -d "infernet-container-starter" ]; then
        echo -e "${YELLOW}Removing old infernet-container-starter directory...${NC}"
        rm -rf infernet-container-starter
    fi

    echo -e "${YELLOW}Cloning infernet-container-starter repo...${NC}"
    git clone https://github.com/ritual-net/infernet-container-starter
    cd infernet-container-starter || exit 1

    echo -e "${YELLOW}Pulling Ritual Docker image...${NC}"
    docker pull ritualnetwork/hello-world-infernet:latest

    # Stop existing screen session if any
    if screen -list | grep -q "ritual"; then
        echo -e "${YELLOW}Stopping existing screen session 'ritual'...${NC}"
        screen -S ritual -X quit
        sleep 1
    fi

    echo -e "${YELLOW}Starting new screen session 'ritual' for deployment...${NC}"
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'

    echo -e "${CYAN}Deployment started in background (screen session 'ritual').${NC}"

    # User inputs
    echo
    read -p "$(echo -e "${BLUE}Enter your Private Key (0x...): ${NC}")" PRIVATE_KEY

    # Default config values
    RPC_URL="https://base-rpc.publicnode.com"
    REGISTRY="0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
    SLEEP=3
    START_SUB_ID=160000
    BATCH_SIZE=800
    TRAIL_HEAD_BLOCKS=3
    INFERNET_VERSION="1.4.0"

    # Modify config files with user input and defaults
    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" deploy/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" deploy/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" deploy/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" deploy/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" deploy/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" deploy/config.json
    sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$RPC_URL\"|" deploy/config.json

    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" deploy/config-inf.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" deploy/config-inf.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" deploy/config-inf.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" deploy/config-inf.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" deploy/config-inf.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" deploy/config-inf.json
    sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$RPC_URL\"|" deploy/config-inf.json
    sed -i "s|\"infernet_version\": \".*\"|\"infernet_version\": \"$INFERNET_VERSION\"|" deploy/config-inf.json

    echo -e "${GREEN}Configuration files updated.${NC}"

    # Build and deploy contracts with Foundry
    echo -e "${YELLOW}Deploying contracts with Foundry...${NC}"
    make deploy-contracts

    # Launch ritual node in screen session (if not already)
    if ! screen -list | grep -q "ritual"; then
        screen -S ritual -dm bash -c 'make start'
        echo -e "${GREEN}Ritual node started in a new screen session named 'ritual'.${NC}"
    else
        echo -e "${YELLOW}Screen session 'ritual' is already running.${NC}"
    fi

    echo -e "${GREEN}Installation finished! Use the menu to view logs or remove node.${NC}"
}

# View logs function
view_logs() {
    display_header
    if screen -list | grep -q "ritual"; then
        echo -e "${CYAN}Attaching to screen session 'ritual' logs...${NC}"
        screen -r ritual
    else
        echo -e "${RED}No active screen session named 'ritual' found.${NC}"
    fi
}

# Remove ritual node function
remove_ritual_node() {
    display_header
    echo -e "${RED}Removing Ritual Node...${NC}"

    # Stop screen session
    if screen -list | grep -q "ritual"; then
        screen -S ritual -X quit
        echo -e "${YELLOW}Stopped screen session 'ritual'.${NC}"
    else
        echo -e "${YELLOW}No screen session 'ritual' found.${NC}"
    fi

    # Remove docker containers
    echo -e "${YELLOW}Removing Ritual Docker containers...${NC}"
    docker ps -a --filter "ancestor=ritualnetwork/hello-world-infernet" -q | xargs -r docker rm -f

    # Remove docker images (optional)
    # docker images | grep ritualnetwork/hello-world-infernet | awk '{print $3}' | xargs -r docker rmi -f

    # Remove local folders
    if [ -d "$HOME/infernet-container-starter" ]; then
        rm -rf "$HOME/infernet-container-starter"
        echo -e "${YELLOW}Removed infernet-container-starter directory.${NC}"
    fi

    echo -e "${GREEN}Ritual Node removed successfully.${NC}"
}

# Start the script
main_menu
