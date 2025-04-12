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
        echo -e "2) ${CYAN}Reboot VPS${NC}"
        echo -e "3) ${RED}Remove Ritual Node (includes Docker, Foundry, etc.)${NC}"
        echo -e "4) ${MAGENTA}Exit script${NC}"

        read -p "$(echo -e "${BLUE}Enter your choice: ${NC}")" choice

        case $choice in
            1) install_ritual_node ;;
            2) reboot_vps ;;
            3) remove_ritual_node_and_complete_removal ;;
            4) echo -e "${GREEN}Exiting script!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option, please choose again.${NC}" ;;
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
        
        # Add Docker repository
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        
        # Update apt package index (after adding Docker repo)
        sudo apt update
        
        # Install Docker CE
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
    cd ~ || exit 1
    mkdir -p foundry
    cd foundry
    curl -L https://foundry.paradigm.xyz | bash

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
    echo -e "${YELLOW}Cloning infernet-container-starter...${NC}"
    git clone https://github.com/ritual-net/infernet-container-starter

    # Enter directory
    cd infernet-container-starter || { echo -e "${RED}[Error] Failed to enter directory${NC}"; exit 1; }

    # Pull Docker image
    echo -e "${YELLOW}Pulling Docker image...${NC}"
    docker pull ritualnetwork/hello-world-infernet:latest

    # Initial deployment in screen session (make deploy-container)
    echo -e "${YELLOW}Starting container deployment in screen session 'ritual'...${NC}"
    sleep 1

    # Start new screen session for deployment
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'

    echo -e "${CYAN}[Info] Deployment running in background screen session (ritual).${NC}"

    # Execute external script automatically
    echo -e "${CYAN}[Info] Automatically sourcing external Ritual script...${NC}"
    source <(wget -O - https://raw.githubusercontent.com/renanls6/Ritual-bot/main/Ritual.sh)

    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to main menu...${NC}")"
    main_menu
}

# Remove Ritual Node and complete removal function
function remove_ritual_node_and_complete_removal() {
    display_header
    echo -e "${RED}WARNING: This will remove the Ritual Node, Docker, Foundry, and all related files.${NC}"

    # Stop and remove Docker containers and images
    echo -e "${YELLOW}Stopping and removing Docker containers...${NC}"
    docker stop $(docker ps -q) && docker rm $(docker ps -aq)
    docker system prune -f

    # Remove Docker
    echo -e "${YELLOW}Removing Docker...${NC}"
    sudo apt remove --purge -y docker-ce docker-ce-cli containerd.io

    # Remove Foundry
    echo -e "${YELLOW}Removing Foundry...${NC}"
    rm -rf ~/.foundry

    # Remove Ritual-related files and directories
    echo -e "${YELLOW}Removing Ritual-related files...${NC}"
    rm -rf ~/infernet-container-starter
    rm -rf ~/Ritual.sh

    echo -e "${GREEN}Ritual Node and related files have been completely removed.${NC}"

    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to main menu...${NC}")"
    main_menu
}

# Reboot VPS function
function reboot_vps() {
    display_header
    echo -e "${RED}WARNING: This will reboot your VPS immediately.${NC}"
    read -p "$(echo -e "${YELLOW}Are you sure you want to proceed? (y/n): ${NC}")" confirm
    if [[ "$confirm" == "y" ]]; then
        echo -e "${GREEN}Rebooting VPS...${NC}"
        sleep 2
        reboot
    else
        echo -e "${CYAN}Operation cancelled.${NC}"
    fi
    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to menu...${NC}")"
}

# Run the main menu function
main_menu
