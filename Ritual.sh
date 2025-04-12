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
    # System update and essential package installation (including Python and pip)
    echo -e "${YELLOW}System update and installing necessary packages...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential screen python3 python3-pip

    # Install or upgrade Python packages
    echo -e "${CYAN}[Info] Upgrading pip3 and installing infernet-cli / infernet-client${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    # Check if Docker is installed
    echo -e "${YELLOW}Checking Docker installation...${NC}"
    if command -v docker &> /dev/null; then
        echo -e "${GREEN} - Docker is already installed, skipping.${NC}"
    else
        echo -e "${YELLOW} - Docker not found, installing...${NC}"
        
        # Update apt package index
        sudo apt update
        
        # Install packages to allow apt to use HTTPS
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - 
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        
        # Install Docker CE
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        
        # Enable and start Docker service
        sudo systemctl enable docker
        sudo systemctl start docker
        
        # Verify Docker version
        echo -e "${GREEN}Docker installation complete, current version:${NC}"
        docker --version
    fi

    # Check Docker Compose installation
    echo -e "${YELLOW}Checking Docker Compose installation...${NC}"
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW} - Docker Compose not found, installing...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" \
             -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN} - Docker Compose already installed, skipping.${NC}"
    fi

    echo -e "${CYAN}[Verify] Docker Compose version:${NC}"
    docker compose version || docker-compose version

    # Install Foundry and set up environment variables
    echo
    echo -e "${YELLOW}Installing Foundry...${NC}"
    # Stop anvil if running
    if pgrep anvil &>/dev/null; then
        echo -e "${YELLOW}[Warning] anvil is running, stopping to update Foundry.${NC}"
        pkill anvil
        sleep 2
    fi

    cd ~ || exit 1
    mkdir -p foundry
    cd foundry
    curl -L https://foundry.paradigm.xyz | bash

    # Install or update
    $HOME/.foundry/bin/foundryup

    # Add ~/.foundry/bin to PATH
    if [[ ":$PATH:" != *":$HOME/.foundry/bin:"* ]]; then
        export PATH="$HOME/.foundry/bin:$PATH"
    fi

    echo -e "${CYAN}[Verify] forge version:${NC}"
    forge --version || {
        echo -e "${RED}[Error] Could not find forge command, ~/.foundry/bin may not be in PATH or installation failed.${NC}"
        exit 1
    }

    # Remove /usr/bin/forge to prevent ZOE error
    if [ -f /usr/bin/forge ]; then
        echo -e "${CYAN}[Info] Removing /usr/bin/forge...${NC}"
        sudo rm /usr/bin/forge
    fi

    echo -e "${GREEN}[Info] Foundry installation and environment setup complete.${NC}"
    cd ~ || exit 1

    # Clone infernet-container-starter
    # Check if directory exists and remove if it does
    if [ -d "infernet-container-starter" ]; then
        echo -e "${YELLOW}Directory infernet-container-starter exists, removing...${NC}"
        rm -rf "infernet-container-starter"
        echo -e "${GREEN}Directory infernet-container-starter removed.${NC}"
    fi

    # Clone repository
    echo -e "${YELLOW}Cloning infernet-container-starter...${NC}"
    git clone https://github.com/ritual-net/infernet-container-starter

    # Enter directory
    cd infernet-container-starter || { echo -e "${RED}[Error] Failed to enter directory${NC}"; exit 1; }

    # Pull Docker image
    echo -e "${YELLOW}Pulling Docker image...${NC}"
    docker pull ritualnetwork/hello-world-infernet:latest

    # Initial deployment in screen session (make deploy-container)
    echo -e "${YELLOW}Checking for existing screen session 'ritual'...${NC}"

    # Check if 'ritual' session exists
    if screen -list | grep -q "ritual"; then
        echo -e "${YELLOW}[Info] Found existing ritual session, terminating...${NC}"
        screen -S ritual -X quit
        sleep 1
    fi

    echo -e "${YELLOW}Starting container deployment in screen session 'ritual'...${NC}"
    sleep 1

    # Start new screen session for deployment
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'

    echo -e "${CYAN}[Info] Deployment running in background screen session (ritual).${NC}"

    # User input (Private Key)
    echo
    echo -e "${YELLOW}Configuring Ritual Node files...${NC}"

    read -p "$(echo -e "${BLUE}Enter your Private Key (0x...): ${NC}")" private_key
    read -p "$(echo -e "${BLUE}Enter your RPC URL: ${NC}")" rpc_url
    read -p "$(echo -e "${BLUE}Enter your network (e.g., goerli, mainnet): ${NC}")" network

    # Add private key to .env file
    echo -e "PRIVATE_KEY=$private_key" >> .env
    echo -e "RPC_URL=$rpc_url" >> .env
    echo -e "NETWORK=$network" >> .env

    echo -e "${GREEN}[Info] Ritual Node installation complete.${NC}"
    seed
}

# Seed function
function seed() {
    # Extract newly deployed contract address (e.g.: Deployed SaysHello:  0x...)
    NEW_ADDR=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed SaysHello:\s+\K0x[0-9a-fA-F]{40}')
    if [ -z "$NEW_ADDR" ]; then
        echo -e "${YELLOW}[Warning] Could not find new contract address. May need to manually update CallContract.s.sol.${NC}"
    else
        echo -e "${GREEN}[Info] Deployed SaysHello address: $NEW_ADDR${NC}"
        # Replace old address with new address in CallContract.s.sol
        # Example: SaysGM saysGm = SaysGM(0x13D69Cf7...) -> SaysGM saysGm = SaysGM(0xA529dB3c9...)
        sed -i "s|SaysGM saysGm = SaysGM(0x[0-9a-fA-F]\+);|SaysGM saysGm = SaysGM($NEW_ADDR);|" \
            projects/hello-world/contracts/script/CallContract.s.sol
    fi
}

# View logs function
function view_logs() {
    display_header
    echo -e "${YELLOW}Viewing Ritual Node logs...${NC}"
    screen -S ritual -X logfile /tmp/ritual_logs.txt
    screen -S ritual -X log on
    tail -f /tmp/ritual_logs.txt
}

# Remove Ritual Node function
function remove_ritual_node() {
    display_header
    echo -e "${RED}Removing Ritual Node...${NC}"

    # Stop running Docker containers
    docker stop ritual-container

    # Remove the container
    docker rm ritual-container

    # Remove associated images
    docker rmi ritualnetwork/hello-world-infernet:latest

    # Delete project directory
    rm -rf infernet-container-starter

    # Remove environment file
    rm -f .env

    # Remove screen session
    screen -S ritual -X quit

    echo -e "${GREEN}[Info] Ritual Node removal complete.${NC}"
}

# Run main menu
main_menu
