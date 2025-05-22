#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Header display
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

# Check root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Please run this script as root (sudo -i).${NC}"
    exit 1
fi

# Install Ritual Node
install_ritual_node() {
    display_header
    echo -e "${YELLOW}Starting Ritual Node installation...${NC}"

    echo -e "${YELLOW}Updating system and installing base dependencies...${NC}"
    apt update && apt upgrade -y
    apt -qy install curl git jq lz4 build-essential screen python3 python3-pip docker docker-compose

    echo -e "${YELLOW}Installing Python packages infernet-cli and infernet-client...${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    # Instalar Foundry (Forge)
    echo -e "${YELLOW}Installing Foundry (forge)...${NC}"
    curl -L https://foundry.paradigm.xyz | bash

    # Setar PATH para Foundry
    export PATH="$HOME/.foundry/bin:$PATH"
    if ! grep -q 'export PATH="$HOME/.foundry/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
    fi

    # Remover forge antigo se existir em /usr/bin/forge (para evitar conflito)
    if [ -f "/usr/bin/forge" ]; then
        echo -e "${YELLOW}Removing old forge binary at /usr/bin/forge...${NC}"
        rm -f /usr/bin/forge
    fi

    # Source para pegar o PATH atualizado no shell atual
    source ~/.bashrc

    # Criar diretório do projeto
    if [ ! -d "$HOME/infernet-container-starter" ]; then
        echo -e "${YELLOW}Cloning infernet-container-starter repo via SSH...${NC}"
        if git clone git@github.com:infernet-hq/infernet-container-starter.git "$HOME/infernet-container-starter"; then
            echo -e "${GREEN}Repo cloned successfully via SSH.${NC}"
        else
            echo -e "${RED}Failed to clone repo via SSH.${NC}"
            echo -e "${YELLOW}Please make sure you have your SSH key added to GitHub and ssh-agent running.${NC}"
            echo -e "${YELLOW}Alternatively, clone the repo manually or configure HTTPS access with a token.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}infernet-container-starter directory already exists. Pulling latest changes...${NC}"
        cd "$HOME/infernet-container-starter"
        git pull
    fi

    cd "$HOME/infernet-container-starter"

    # Criar o arquivo config.json com chaves e configuração necessárias
    echo -e "${YELLOW}Creating config.json...${NC}"
    read -p "Enter your Infernet API key: " API_KEY
    read -p "Enter your Ritual wallet address (0x...): " WALLET_ADDRESS
    read -p "Enter the RPC endpoint (e.g. wss://base-rpc.publicnode.com): " RPC_ENDPOINT

    cat > config.json <<EOF
{
  "wallet": "${WALLET_ADDRESS}",
  "api_key": "${API_KEY}",
  "rpc_url": "${RPC_ENDPOINT}",
  "rest_url": "https://base.rest",
  "node_config": {
    "max_connections": 40,
    "max_request_body_size": 10485760
  }
}
EOF

    # Build do container
    echo -e "${YELLOW}Building and deploying docker container with docker-compose...${NC}"

    docker compose build

    # Rodar container em screen para rodar em background e você poder desconectar
    screen -dmS ritual_node docker compose up

    # Deploy dos contratos com Foundry
    echo -e "${YELLOW}Deploying contracts with forge...${NC}"

    # Certificar que está no diretório correto para deploy dos contratos
    # Exemplo: ~/infernet-container-starter/contracts
    cd contracts || {
        echo -e "${RED}Contracts directory not found! Skipping contracts deploy.${NC}"
        return
    }

    forge build

    # Corrigindo PATH pra forge
    export PATH="$HOME/.foundry/bin:$PATH"

    # Atenção: substitua "SUA_CHAVE_PRIVADA_AQUI" pela chave real no deploy
    forge create --rpc-url "$RPC_ENDPOINT" --private-key "SUA_CHAVE_PRIVADA_AQUI" src/MyContract.sol:MyContract

    echo -e "${GREEN}Installation and deployment completed successfully!${NC}"
    echo -e "${CYAN}You can now view logs or remove the node from the menu.${NC}"

    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to main menu...${NC}")"
}

# View logs function
view_logs() {
    display_header
    echo -e "${YELLOW}Showing logs from Ritual Node...${NC}"

    # Ajuste o caminho se seu docker-compose.yaml estiver em outro local
    docker compose -f ~/infernet-container-starter/deploy/docker-compose.yaml logs -f
}

# Remove ritual node
remove_ritual_node() {
    display_header
    echo -e "${RED}Removing Ritual Node...${NC}"

    if [ -d "$HOME/infernet-container-starter" ]; then
        cd "$HOME/infernet-container-starter"
        echo -e "${YELLOW}Stopping docker containers...${NC}"
        docker compose down
        echo -e "${YELLOW}Removing project directory...${NC}"
        cd ~
        rm -rf "$HOME/infernet-container-starter"
        echo -e "${YELLOW}Removing ritualnetwork docker image...${NC}"
        docker rmi ritualnetwork/hello-world-infernet:latest
        echo -e "${GREEN}Ritual Node removed successfully.${NC}"
    else
        echo -e "${RED}Ritual Node directory not found, nothing to remove.${NC}"
    fi

    read -n 1 -s -r -p "$(echo -e "${YELLOW}Press any key to return to main menu...${NC}")"
}

# Main menu
main_menu() {
    while true; do
        display_header
        echo -e "${BLUE}To exit the script, press Ctrl+C${NC}"
        echo -e "${YELLOW}Choose an option:${NC}"
        echo -e "1) ${GREEN}Install Ritual Node${NC}"
        echo -e "2) ${CYAN}View Ritual Node logs${NC}"
        echo -e "3) ${RED}Remove Ritual Node${NC}"
        echo -e "4) ${MAGENTA}Exit${NC}"
        read -p "$(echo -e "${BLUE}Enter your choice: ${NC}")" choice

        case $choice in
            1) install_ritual_node ;;
            2) view_logs ;;
            3) remove_ritual_node ;;
            4) echo -e "${GREEN}Bye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac

        echo -e "${YELLOW}Press any key to continue...${NC}"
        read -n 1 -s
    done
}

# Start script
main_menu
