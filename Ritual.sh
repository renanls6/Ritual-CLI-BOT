#!/bin/bash

# Ritual Node Installation Script with progress bar and spinner

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

INSTALL_DIR="$HOME/ritual-node"

# Log function
log() {
    echo -e "$1"
}

# Print banner function
print_banner() {
    clear
    echo -e "${CYAN}=============================="
    echo -e "   Ritual Node Installer"
    echo -e "==============================${RESET}"
}

# Simulated progress bar
show_progress() {
    local duration=${1:-10}  # total seconds for the progress bar
    local width=40           # progress bar width in chars
    local interval=$(awk "BEGIN {print $duration/$width}")
    echo -ne "["
    for ((i=1; i<=width; i++)); do
        echo -ne "#"
        perc=$(( i * 100 / width ))
        echo -ne "] $perc% \r["
        sleep "$interval"
    done
    echo -e "] 100%"
}

# Spinner animation for short waits
show_spinner() {
    local duration=${1:-5}
    local spin='-\|/'
    local end=$((SECONDS + duration))
    while [ $SECONDS -lt $end ]; do
        for (( i=0; i<${#spin}; i++ )); do
            echo -ne "${spin:$i:1} \r"
            sleep 0.2
        done
    done
    echo -ne "  \r"
}

install_dependencies() {
    print_banner
    log "${YELLOW}Installing dependencies (Docker, Foundry, etc.)...${RESET}"
    show_progress 8
    # Example commands below; adjust as needed for your environment
    sudo apt update && sudo apt install -y docker.io curl git
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    log "${GREEN}Dependencies installed successfully.${RESET}"
}

clone_repository() {
    print_banner
    log "${YELLOW}Cloning Ritual Node repository...${RESET}"
    show_spinner 5
    git clone https://github.com/your-org/ritual-node.git "$INSTALL_DIR"
    log "${GREEN}Repository cloned to $INSTALL_DIR.${RESET}"
}

deploy_contracts() {
    print_banner
    log "${YELLOW}Deploying contracts (make deploy-contracts)...${RESET}"
    show_progress 10
    cd "$INSTALL_DIR" || exit 1
    make deploy-contracts
    log "${GREEN}Contracts deployed successfully.${RESET}"
}

start_node() {
    print_banner
    log "${CYAN}Starting Ritual Node in a detached screen session...${RESET}"
    show_spinner 6
    cd "$INSTALL_DIR" || exit 1
    screen -dmS ritual-node ./start-node.sh
    log "${GREEN}Ritual Node started successfully in screen session 'ritual-node'.${RESET}"
}

show_help() {
    echo "Usage: $0 {install|clone|deploy|start|all}"
    echo "  install - Install dependencies"
    echo "  clone   - Clone the Ritual Node repo"
    echo "  deploy  - Deploy smart contracts"
    echo "  start   - Start the Ritual Node"
    echo "  all     - Run all steps in order"
}

# Main script logic
case "$1" in
    install)
        install_dependencies
        ;;
    clone)
        clone_repository
        ;;
    deploy)
        deploy_contracts
        ;;
    start)
        start_node
        ;;
    all)
        install_dependencies
        clone_repository
        deploy_contracts
        start_node
        ;;
    *)
        show_help
        ;;
esac
