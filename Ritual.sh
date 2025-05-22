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
    echo -e "${YELLOW}Please run with 'sudo -i' to switch to root user, then run this script again.${NC}"
    exit 1
fi

# Script save path (not used in current script)
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
        
        read -rp "$(echo -e "${BLUE}Enter your choice: ${NC}")" choice

        case $choice in
            1) install_ritual_node ;;
            2) view_logs ;;
            3) remove_ritual_node ;;
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

    echo -e "${YELLOW}Updating system and installing necessary packages...${NC}"
    apt update && apt upgrade -y
    apt install -qy curl git jq lz4 build-essential screen python3 python3-pip

    echo -e "${CYAN}[Info] Upgrading pip3 and installing infernet-cli and infernet-client...${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    echo -e "${YELLOW}Checking Docker installation...${NC}"
    if command -v docker &>/dev/null; then
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
        echo -e "${GREEN}Docker installation complete:${NC}"
        docker --version
    fi

    echo -e "${YELLOW}Checking Docker Compose installation...${NC}"
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        echo -e "${YELLOW} - Docker Compose not found, installing...${NC}"
        curl -L "https://github.com/docker/compose/releases/download/v2.36.1/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN} - Docker Compose already installed, skipping.${NC}"
    fi

    echo -e "${CYAN}[Verify] Docker Compose version:${NC}"
    docker compose version || docker-compose version

    echo -e "${YELLOW}Installing Foundry...${NC}"

    # Stop anvil if running
    if pgrep anvil &>/dev/null; then
        echo -e "${YELLOW}[Warning] anvil is running, stopping it for Foundry update.${NC}"
        pkill anvil
        sleep 2
    fi

    cd "$HOME" || exit 1
    mkdir -p foundry
    cd foundry || exit 1
    curl -L https://foundry.paradigm.xyz | bash

    "$HOME/.foundry/bin/foundryup"

    # Add Foundry bin to PATH if not already there, and export for current session
    if [[ ":$PATH:" != *":$HOME/.foundry/bin:"* ]]; then
        echo -e "${CYAN}[Info] Adding ~/.foundry/bin to PATH...${NC}"
        export PATH="$HOME/.foundry/bin:$PATH"
        # Add to ~/.profile for persistence
        if ! grep -q 'export PATH="$HOME/.foundry/bin:$PATH"' "$HOME/.profile"; then
            echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> "$HOME/.profile"
        fi
    fi

    # Remove /usr/bin/forge if it exists to avoid conflicts
    if [ -f /usr/bin/forge ]; then
        echo -e "${CYAN}[Info] Removing /usr/bin/forge to prevent forge conflicts...${NC}"
        rm -f /usr/bin/forge
    fi

    echo -e "${CYAN}[Verify] forge version:${NC}"
    if ! command -v forge &>/dev/null; then
        echo -e "${RED}[Error] forge command not found after installation. Please check your PATH.${NC}"
        exit 1
    else
        forge --version
    fi

    # Clone infernet-container-starter repository
    cd "$HOME" || exit 1
    if [ -d "infernet-container-starter" ]; then
        echo -e "${YELLOW}Removing existing infernet-container-starter directory...${NC}"
        rm -rf "infernet-container-starter"
    fi

    echo -e "${YELLOW}Cloning infernet-container-starter repository...${NC}"
    git clone https://github.com/ritual-net/infernet-container-starter || {
        echo -e "${RED}[Error] Git clone failed.${NC}"
        exit 1
    }

    cd infernet-container-starter || { echo -e "${RED}[Error] Failed to enter directory infernet-container-starter.${NC}"; exit 1; }

    echo -e "${YELLOW}Pulling latest Docker image ritualnetwork/hello-world-infernet:latest...${NC}"
    docker pull ritualnetwork/hello-world-infernet:latest

    # Manage screen session for deployment
    echo -e "${YELLOW}Checking for existing 'ritual' screen session...${NC}"
    if screen -list | grep -q "ritual"; then
        echo -e "${YELLOW}Existing 'ritual' session found. Terminating it...${NC}"
        screen -S ritual -X quit
        sleep 1
    fi

    echo -e "${YELLOW}Starting new screen session 'ritual' to deploy container...${NC}"
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'

    echo -e "${CYAN}Deployment running in background screen session 'ritual'.${NC}"

    echo
    echo -e "${GREEN}✅ Ritual Node installation and deployment initiated successfully!${NC}"
}

# View logs function
view_logs() {
    display_header
    echo -e "${YELLOW}Displaying logs for Ritual Node container...${NC}"
    # Adjust path to docker-compose.yaml if needed
    local compose_file="$HOME/infernet-container-starter/docker-compose.yaml"
    if [ ! -f "$compose_file" ]; then
        echo -e "${RED}Docker Compose file not found at $compose_file${NC}"
        echo -e "${YELLOW}Make sure you have installed the Ritual Node first.${NC}"
        return
    fi

    # Use docker compose logs if available, else fallback to docker-compose
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        docker compose -f "$compose_file" logs -f
    elif command -v docker-compose &>/dev/null; then
        docker-compose -f "$compose_file" logs -f
    else
        echo -e "${RED}Neither docker compose nor docker-compose command found.${NC}"
    fi
}

# Remove Ritual Node function
remove_ritual_node() {
    display_header
    echo -e "${RED}You are about to remove the Ritual Node.${NC}"
    read -rp "$(echo -e "${YELLOW}Are you sure? (y/n): ${NC}")" confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing Ritual Node...${NC}"

        # Stop and remove docker containers from compose
        local compose_file="$HOME/infernet-container-starter/docker-compose.yaml"
        if [ -f "$compose_file" ]; then
            if command -v docker &>/dev/null && docker compose version &>/dev/null; then
                docker compose -f "$compose_file" down
            elif command -v docker-compose &>/dev/null; then
                docker-compose -f "$compose_file" down
            fi
        fi

        # Remove screen session
        if screen -list | grep -q "ritual"; then
            screen -S ritual -X quit
        fi

        # Remove directory
        rm -rf "$HOME/infernet-container-starter"

        echo -e "${GREEN}Ritual Node removed successfully.${NC}"
    else
        echo -e "${CYAN}Aborted removal.${NC}"
    fi
}

# Run main menu
main_menu
