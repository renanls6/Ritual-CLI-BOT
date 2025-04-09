#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print error and exit if necessary
function exit_with_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Display header
display_header() {
    clear  # Clear terminal screen
    echo -e "${MAGENTA}"
    echo -e "    ██████╗ ██╗  ██╗    ██████╗ ███████╗███╗   ██╗ █████╗ ███╗   ██╗"
    echo -e "    ██╔═████╗╚██╗██╔╝    ██╔══██╗██╔════╝████╗  ██║██╔══██╗████╗  ██║"
    echo -e "    ██║██╔██║ ╚███╔╝     ██████╔╝█████╗  ██╔██╗ ██║███████║██╔██╗ ██║"
    echo -e "    ████╔╝██║ ██╔██╗     ██╔══██╗██╔══╝  ██║╚██╗██║██╔══██║██║╚██╗██║"
    echo -e "    ╚██████╔╝██╔╝ ██╗    ██║  ██║███████╗██║ ╚████║██║  ██║██║ ╚████║"
    echo -e "     ╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝"
    echo -e "${MAGENTA}======================================================="
    echo -e "${MAGENTA}       ✨ Ritual Installation Script ✨${NC}"
    echo -e "${MAGENTA}======================================================="
    echo -e "🔗 Curtiu o Bot? Me siga lá no Twitter: https://x.com/0x_renan"
}

# Check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}This script requires root privileges.${NC}"
        echo -e "${YELLOW}Please try running with 'sudo -i' to switch to root user, then run this script again.${NC}"
        exit 1
    fi
}

# Install necessary system packages
install_system_packages() {
    echo -e "${YELLOW}System update and installing necessary packages...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential screen python3 python3-pip
}

# Install or upgrade Python packages
install_python_packages() {
    echo -e "${CYAN}[Info] Upgrading pip3 and installing infernet-cli / infernet-client${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client
}

# Check if Docker is installed, and install if not
install_docker() {
    echo -e "${YELLOW}Checking Docker installation...${NC}"
    if command -v docker &> /dev/null; then
        echo -e "${GREEN} - Docker is already installed, skipping.${NC}"
    else
        echo -e "${YELLOW} - Docker not found, installing...${NC}"
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
        echo -e "${GREEN}Docker installation complete, current version:${NC}"
        docker --version
    fi
}

# Install Docker Compose if not installed
install_docker_compose() {
    echo -e "${YELLOW}Checking Docker Compose installation...${NC}"
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW} - Docker Compose not found, installing...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN} - Docker Compose already installed, skipping.${NC}"
    fi
}

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

# Install Ritual Node function (Refactor and handle Docker installations)
install_ritual_node() {
    display_header
    install_system_packages
    install_python_packages
    install_docker
    install_docker_compose

    # Install Foundry and set up environment variables
    echo -e "${YELLOW}Installing Foundry...${NC}"
    if pgrep anvil &>/dev/null; then
        echo -e "${YELLOW}[Warning] anvil is running, stopping to update Foundry.${NC}"
        pkill anvil
        sleep 2
    fi

    cd ~ || exit_with_error "Failed to change directory"
    mkdir -p foundry
    cd foundry
    curl -L https://foundry.paradigm.xyz | bash
    $HOME/.foundry/bin/foundryup

    echo -e "${CYAN}[Verify] forge version:${NC}"
    forge --version || exit_with_error "Could not find forge command or installation failed."

    # Remove /usr/bin/forge to prevent ZOE error
    if [ -f /usr/bin/forge ]; then
        echo -e "${CYAN}[Info] Removing /usr/bin/forge...${NC}"
        sudo rm /usr/bin/forge
    fi

    echo -e "${GREEN}[Info] Foundry installation and environment setup complete.${NC}"
}

# View Ritual Node logs function
view_logs() {
    display_header
    echo -e "${YELLOW}Viewing Ritual Node logs...${NC}"
    docker logs -f infernet-node
}

# Remove Ritual Node function
remove_ritual_node() {
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

# Run the main menu function
check_root
main_menu
