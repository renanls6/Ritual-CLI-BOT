#!/bin/bash

set -e

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Header visual
header() {
  clear
  echo -e "${BLUE}======================================="
  echo -e "        Ritual Node Installer"
  echo -e "=======================================${NC}"
}

# Verifica root
[ "$EUID" -ne 0 ] && echo -e "${RED}Execute como root (sudo -i).${NC}" && exit 1

# Prompt interativo com whiptail
prompt_input() {
  whiptail --title "$1" --inputbox "$2" 10 70 3>&1 1>&2 2>&3
}

prompt_password() {
  whiptail --title "$1" --passwordbox "$2" 10 70 3>&1 1>&2 2>&3
}

confirm() {
  whiptail --title "$1" --yesno "$2" 10 60
}

# Instala dependências básicas + docker + docker-compose oficial
install_dependencies() {
  header
  echo -e "${YELLOW}Atualizando pacotes e instalando dependências...${NC}"
  apt update && apt upgrade -y
  apt -y install apt-transport-https ca-certificates curl gnupg lsb-release git jq lz4 build-essential screen python3 python3-pip

  # Remove docker antigo se existir
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  # Docker repo oficial
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \  
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \n    $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io
  systemctl enable docker && systemctl start docker

  # Docker Compose oficial
  COMPOSE_VERSION="v2.29.2"
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose

  docker compose version
}

# Instala Foundry (forge) e dependências
install_foundry() {
  header
  echo -e "${YELLOW}Instalando Foundry...${NC}"
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  foundryup
  export PATH="$HOME/.foundry/bin:$PATH"
}

# Clona projeto
clone_repo() {
  cd ~
  [ -d infernet-container-starter ] && rm -rf infernet-container-starter
  git clone https://github.com/ritual-net/infernet-container-starter.git
}

# Configura arquivos JSON, Makefile, Deploy.s.sol
configure_node() {
  cd ~/infernet-container-starter
  API_KEY=$(prompt_input "API Key" "Insira sua API Key da Infernet")
  WALLET=$(prompt_input "Endereço Wallet" "Insira seu endereço da carteira 0x...")
  RPC_URL=$(prompt_input "RPC" "Insira o endpoint RPC (ex: https://mainnet.base.org)")
  PRIVATE_KEY=$(prompt_password "Chave Privada" "Insira sua chave privada com 0x no início")

  for FILE in \
    deploy/config.json \
    projects/hello-world/container/config.json; do
    cat > $FILE <<EOF
{
  "wallet": "$WALLET",
  "api_key": "$API_KEY",
  "rpc_url": "$RPC_URL",
  "rest_url": "https://base.rest",
  "node_config": {
    "max_connections": 40,
    "max_request_body_size": 10485760,
    "snapshot_sync": {
      "sleep": 3,
      "starting_sub_id": 160000,
      "batch_size": 800,
      "sync_period": 30
    },
    "trail_head_blocks": 3
  },
  "registry": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
}
EOF
  done

  # Atualiza docker-compose.yaml
  sed -i 's#image: .*#image: ritualnetwork/hello-world-infernet:1.4.0#' deploy/docker-compose.yaml
  sed -i '/image:/a \
      restart: on-failure' deploy/docker-compose.yaml

  # Atualiza Deploy.s.sol
  sed -i 's/0x[a-fA-F0-9]\{40\}/0x3B1554f346DFe5c482Bb4BA31b880c1C18412170/g' projects/hello-world/contracts/script/Deploy.s.sol
  sed -i 's/0x[a-fA-F0-9]\{40\}/0x8D871Ef2826ac9001fB2e33fDD6379b6aaBF449c/g' projects/hello-world/contracts/script/Deploy.s.sol

  # Atualiza Makefile
  sed -i "s#RPC_URL=.*#RPC_URL=$RPC_URL#" projects/hello-world/contracts/Makefile
  sed -i "s#PRIVATE_KEY=.*#PRIVATE_KEY=$PRIVATE_KEY#" projects/hello-world/contracts/Makefile
}

# Build e deploy do container
run_container() {
  cd ~/infernet-container-starter
  echo -e "${YELLOW}Executando deploy do container...${NC}"
  project=hello-world make deploy-container
}

# Instala SDKs
install_sdks() {
  cd ~/infernet-container-starter/projects/hello-world/contracts
  rm -rf lib/forge-std lib/infernet-sdk || true
  forge install --no-commit foundry-rs/forge-std
  forge install --no-commit ritual-net/infernet-sdk
}

# Deploy do contrato SaysGM
deploy_contracts() {
  cd ~/infernet-container-starter
  project=hello-world make deploy-contracts
}

# Chamada ao contrato SaysGM
call_contract() {
  cd ~/infernet-container-starter
  project=hello-world make call-contract
}

# Execução principal
main() {
  header
  install_dependencies
  install_foundry
  clone_repo
  configure_node
  install_sdks
  run_container
  deploy_contracts
  call_contract
  echo -e "${GREEN}Node Ritual instalado e funcionando com sucesso!${NC}"
}

main
