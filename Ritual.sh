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

    read -p "$(echo -e "${BLUE}Enter your Private Key (0x...): ${NC}")" PRIVATE_KEY

    # Default settings
    RPC_URL="https://base-rpc.publicnode.com"
    RPC_URL_SUB="https://base-rpc.publicnode.com"
    # Replace registry address
    REGISTRY="0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
    SLEEP=3
    START_SUB_ID=160000
    BATCH_SIZE=800  # Recommended to use public RPC
    TRAIL_HEAD_BLOCKS=3
    INFERNET_VERSION="1.4.0"  # infernet image tag

    # Modify config files
    # Modify deploy/config.json
    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" deploy/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" deploy/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" deploy/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" deploy/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" deploy/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" deploy/config.json
    sed -i 's|"rpc_url": ".*"|"rpc_url": ""https://base-rpc.publicnode.com""|' deploy/config.json
    sed -i 's|"rpc_url": ".*"|"rpc_url": ""https://base-rpc.publicnode.com""|' projects/hello-world/container/config.json

    # Modify projects/hello-world/container/config.json
    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" projects/hello-world/container/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" projects/hello-world/container/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" projects/hello-world/container/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" projects/hello-world/container/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" projects/hello-world/container/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" projects/hello-world/container/config.json

    # Modify Deploy.s.sol
    sed -i "s|\(registry\s*=\s*\).*|\1$REGISTRY;|" projects/hello-world/contracts/script/Deploy.s.sol
    sed -i "s|\(RPC_URL\s*=\s*\).*|\1\"$RPC_URL\";|" projects/hello-world/contracts/script/Deploy.s.sol

    # Use latest node image
    sed -i 's|ritualnetwork/infernet-node:[^"]*|ritualnetwork/infernet-node:latest|' deploy/docker-compose.yaml

    # Modify Makefile (sender, RPC_URL)
    MAKEFILE_PATH="projects/hello-world/contracts/Makefile"
    sed -i "s|^sender := .*|sender := $PRIVATE_KEY|"  "$MAKEFILE_PATH"
    sed -i "s|^RPC_URL := .*|RPC_URL := $RPC_URL|"    "$MAKEFILE_PATH"

    # Enter project directory
    cd ~/infernet-container-starter || exit 1

    # Restart containers
    echo
    echo -e "${YELLOW}Running docker compose down & up...${NC}"
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d

    echo
    echo -e "${CYAN}[Info] Containers running in background (-d).${NC}"
    echo -e "${YELLOW}Use 'docker ps' to check status. View logs with: docker logs infernet-node${NC}"

    # Install Forge libraries (resolve conflicts)
    echo
    echo -e "${YELLOW}Installing Forge (project dependencies)${NC}"
    cd projects/hello-world/contracts || exit 1
    rm -rf lib/forge-std
    rm -rf lib/infernet-sdk

    forge install --no-commit foundry-rs/forge-std
    forge install --no-commit ritual-net/infernet-sdk

    # Restart containers
    echo
    echo -e "${YELLOW}Restarting docker compose...${NC}"
    cd ~/infernet-container-starter || exit 1
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d
    echo -e "${CYAN}[Info] View infernet-node logs: docker logs infernet-node${NC}"

    # Deploy project contracts
    echo
    echo -e "${YELLOW}Deploying project contracts...${NC}"
    DEPLOY_OUTPUT=$(project=hello-world make deploy-contracts 2>&1)
    echo "$DEPLOY_OUTPUT"

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

        # Execute call-contract
        echo
        echo -e "${YELLOW}Executing call-contract with new address...${NC}"
        project=hello-world make call-contract
    fi

    echo
    echo -e "${GREEN}===== Ritual Node Setup Complete =====${NC}"

    # Prompt to return to main menu
    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to main menu...${NC}")"
    main_menu
}

# View Ritual Node logs function
function view_logs() {
    display_header
    echo -e "${YELLOW}Viewing Ritual Node logs...${NC}"
    docker compose -f infernet-container-starter/deploy/docker-compose.yaml up
}

# Remove Ritual Node function
function remove_ritual_node() {
    display_header
    echo -e "${RED}Removing Ritual Node...${NC}"

    # Stop and remove Docker containers
    echo -e "${YELLOW}Stopping and removing Docker containers...${NC}"
    cd /root/infernet-container-starter
    docker compose down

    # Remove repository files
    echo -e "${YELLOW}Removing related files...${NC}"
    rm -rf ~/infernet-container-starter

    # Remove Docker image
    echo -e "${YELLOW}Removing Docker image...${NC}"
    docker rmi ritualnetwork/hello-world-infernet:latest

    echo -e "${GREEN}Ritual Node successfully removed!${NC}"
}

# Call main menu function
main_menu

# Call main menu function
main_menu
