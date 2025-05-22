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

# Verifica se script está sendo executado como root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script requer privilégios de root.${NC}"
    echo -e "${YELLOW}Use 'sudo -i' para mudar para root e execute novamente.${NC}"
    exit 1
fi

# Caminho padrão do script
SCRIPT_PATH="$HOME/Ritual.sh"

# Menu principal
main_menu() {
    while true; do
        display_header
        echo -e "${BLUE}Para sair, pressione Ctrl+C${NC}"
        echo -e "${YELLOW}Selecione uma opção:${NC}"
        echo -e "1) ${GREEN}Instalar Ritual Node${NC}"
        echo -e "2) ${CYAN}Ver logs do Ritual Node${NC}"
        echo -e "3) ${RED}Remover Ritual Node${NC}"
        echo -e "4) ${MAGENTA}Sair do script${NC}"
        read -p "$(echo -e "${BLUE}Sua escolha: ${NC}")" choice

        case $choice in
            1) install_ritual_node ;;
            2) view_logs ;;
            3) remove_ritual_node ;;
            4) echo -e "${GREEN}Saindo!${NC}"; exit 0 ;;
            *) echo -e "${RED}Opção inválida, tente novamente.${NC}" ;;
        esac

        echo -e "${YELLOW}Pressione qualquer tecla para continuar...${NC}"
        read -n 1 -s
    done
}

# Instalação do Ritual Node
install_ritual_node() {
    display_header
    echo -e "${YELLOW}Atualizando o sistema e instalando pacotes necessários...${NC}"
    apt update && apt upgrade -y
    apt -qy install curl git jq lz4 build-essential screen python3 python3-pip

    echo -e "${CYAN}[Info] Instalando infernet-cli e infernet-client...${NC}"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    echo -e "${YELLOW}Verificando Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker && systemctl start docker
    fi

    echo -e "${YELLOW}Verificando Docker Compose...${NC}"
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi

    echo -e "${YELLOW}Instalando Foundry...${NC}"
    cd ~
    mkdir -p foundry && cd foundry
    curl -L https://foundry.paradigm.xyz | bash
    $HOME/.foundry/bin/foundryup

    if [[ ":$PATH:" != *":$HOME/.foundry/bin:"* ]]; then
        export PATH="$HOME/.foundry/bin:$PATH"
        echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
    fi

    if [ -f /usr/bin/forge ]; then
        echo -e "${CYAN}[Info] Removendo forge em /usr/bin (possível conflito)...${NC}"
        rm /usr/bin/forge
    fi

    forge --version || {
        echo -e "${RED}[Erro] forge não encontrado após instalação.${NC}"
        exit 1
    }

    cd ~
    rm -rf infernet-container-starter
    git clone https://github.com/ritual-net/infernet-container-starter
    cd infernet-container-starter || { echo -e "${RED}Falha ao entrar no repositório.${NC}"; exit 1; }

    docker pull ritualnetwork/hello-world-infernet:latest

    if screen -list | grep -q "ritual"; then
        screen -S ritual -X quit
    fi
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'

    echo
    read -p "$(echo -e "${BLUE}Digite sua Private Key (0x...): ${NC}")" PRIVATE_KEY
    RPC_URL="https://base-rpc.publicnode.com"
    REGISTRY="0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
    SLEEP=3
    START_SUB_ID=160000
    BATCH_SIZE=800
    TRAIL_HEAD_BLOCKS=3

    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" deploy/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" deploy/config.json
    sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$RPC_URL\"|" deploy/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" deploy/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" deploy/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" deploy/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" deploy/config.json

    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" projects/hello-world/container/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" projects/hello-world/container/config.json
    sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$RPC_URL\"|" projects/hello-world/container/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" projects/hello-world/container/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" projects/hello-world/container/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" projects/hello-world/container/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" projects/hello-world/container/config.json

    sed -i "s|\(registry\s*=\s*\).*|\1$REGISTRY;|" projects/hello-world/contracts/script/Deploy.s.sol
    sed -i "s|\(RPC_URL\s*=\s*\).*|\1\"$RPC_URL\";|" projects/hello-world/contracts/script/Deploy.s.sol

    sed -i 's|ritualnetwork/infernet-node:[^"]*|ritualnetwork/infernet-node:latest|' deploy/docker-compose.yaml

    sed -i "s|^sender := .*|sender := $PRIVATE_KEY|"  projects/hello-world/contracts/Makefile
    sed -i "s|^RPC_URL := .*|RPC_URL := $RPC_URL|"    projects/hello-world/contracts/Makefile

    cd ~/infernet-container-starter || exit 1
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d

    echo
    echo -e "${YELLOW}Instalando bibliotecas com forge...${NC}"
    cd projects/hello-world/contracts || exit 1
    rm -rf lib/forge-std lib/infernet-sdk
    forge install --no-commit foundry-rs/forge-std
    forge install --no-commit ritual-net/infernet-sdk

    cd ~/infernet-container-starter || exit 1
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d

    echo
    echo -e "${YELLOW}Deploying project contracts...${NC}"
    DEPLOY_OUTPUT=$(project=hello-world make deploy-contracts 2>&1)
    echo "$DEPLOY_OUTPUT"

    NEW_ADDR=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed SaysHello:\s+\K0x[0-9a-fA-F]{40}')
    if [ -n "$NEW_ADDR" ]; then
        echo -e "${GREEN}[Info] Novo contrato implantado: $NEW_ADDR${NC}"
    else
        echo -e "${YELLOW}[Aviso] Endereço do contrato não encontrado.${NC}"
    fi
}

# Chamando menu principal
main_menu
