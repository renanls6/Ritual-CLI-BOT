#!/usr/bin/env bash
set -e

# Cores para mensagens
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Verifica se executado como root
if [ "$(id -u)" != "0" ]; then
  echo -e "${RED}Este script precisa ser executado como root (sudo -i).${NC}"
  exit 1
fi

# Caminho do repo
REPO_DIR="$HOME/infernet-container-starter"

# Funções de input via whiptail
input_box() {
  whiptail --title "$1" --inputbox "$2" 10 70 3>&1 1>&2 2>&3
}

password_box() {
  whiptail --title "$1" --passwordbox "$2" 10 70 3>&1 1>&2 2>&3
}

yes_no() {
  whiptail --title "$1" --yesno "$2" 10 60
}

msg_box() {
  whiptail --title "$1" --msgbox "$2" 10 70
}

# Instala dependências e Docker oficial + Compose
install_dependencies() {
  msg_box "Dependências" "Atualizando sistema e instalando dependências essenciais (curl, git, jq, lz4, python3, build-essential, screen)..."
  apt update && apt upgrade -y
  apt install -y curl git jq lz4 build-essential python3 python3-pip screen apt-transport-https ca-certificates gnupg lsb-release

  # Remove versões antigas docker
  apt-get remove -y docker docker-engine docker.io containerd runc || true

  # Adiciona Docker oficial
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io
  systemctl enable docker --now

  # Docker Compose oficial
  COMPOSE_VERSION="v2.29.2"
  mkdir -p ~/.docker/cli-plugins
  curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose

  docker compose version > /dev/null 2>&1 || msg_box "Erro" "Falha ao verificar docker compose. Verifique a instalação."
}

# Instala Foundry
install_foundry() {
  msg_box "Foundry" "Instalando Foundry (forge)..."
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc
  foundryup
  export PATH="$HOME/.foundry/bin:$PATH"
  if ! command -v forge > /dev/null; then
    msg_box "Erro" "Foundry não foi instalado corretamente. Abortando."
    exit 1
  fi
}

# Clona o repositório ritual infernet
clone_repo() {
  if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
  fi
  git clone https://github.com/ritual-net/infernet-container-starter.git "$REPO_DIR"
  cd "$REPO_DIR"
  docker pull ritualnetwork/hello-world-infernet:latest
}

# Configura arquivos do node
configure_files() {
  API_KEY=$(input_box "API Key" "Insira sua API Key da Infernet:")
  WALLET=$(input_box "Wallet" "Insira seu endereço da carteira (0x...):")
  RPC_URL=$(input_box "RPC" "Insira o endpoint RPC (ex: https://mainnet.base.org):")
  PRIVATE_KEY=$(password_box "Chave Privada" "Insira sua chave privada com 0x no início:")

  # Configura JSONs
  for FILE in deploy/config.json projects/hello-world/container/config.json; do
    cat > "$REPO_DIR/$FILE" <<EOF
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
      "starting_sub_id": 240000,
      "batch_size": 50,
      "sync_period": 30
    },
    "trail_head_blocks": 3
  },
  "registry": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
}
EOF
  done

  # Atualiza docker-compose.yaml
  sed -i 's#image: .*#image: ritualnetwork/hello-world-infernet:latest#' "$REPO_DIR/deploy/docker-compose.yaml"
  if ! grep -q "restart:" "$REPO_DIR/deploy/docker-compose.yaml"; then
    sed -i '/image:/a \
      restart: on-failure' "$REPO_DIR/deploy/docker-compose.yaml"
  fi

  # Atualiza Deploy.s.sol
  sed -i "s|registry = .*;|registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$REPO_DIR/projects/hello-world/contracts/script/Deploy.s.sol"
  sed -i "s|RPC_URL = .*;|RPC_URL = \"$RPC_URL\";|" "$REPO_DIR/projects/hello-world/contracts/script/Deploy.s.sol"

  # Atualiza Makefile
  sed -i "s|RPC_URL := .*|RPC_URL := $RPC_URL|" "$REPO_DIR/projects/hello-world/contracts/Makefile"
  sed -i "s|sender := .*|sender := $PRIVATE_KEY|" "$REPO_DIR/projects/hello-world/contracts/Makefile"
}

# Instala SDKs forge-std e infernet-sdk
install_sdks() {
  cd "$REPO_DIR/projects/hello-world/contracts"
  rm -rf lib/forge-std lib/infernet-sdk || true
  forge install --no-commit foundry-rs/forge-std
  forge install --no-commit ritual-net/infernet-sdk
}

# Deploy container (em screen)
deploy_container() {
  cd "$REPO_DIR"
  # Mata sessão ritual se existir
  if screen -list | grep -q "ritual"; then
    screen -S ritual -X quit
    sleep 1
  fi
  screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'
  msg_box "Deploy" "Deploy do container iniciado em tela 'screen' chamada 'ritual'.\nUse 'screen -r ritual' para acompanhar logs."
}

# Deploy contratos
deploy_contracts() {
  cd "$REPO_DIR"
  project=hello-world make deploy-contracts
}

# Call contract
call_contract() {
  cd "$REPO_DIR"
  project=hello-world make call-contract
}

# Mostra logs do node via docker compose
show_logs() {
  msg_box "Logs" "Você será direcionado para visualizar logs. Use Ctrl+C para sair."
  cd "$REPO_DIR"
  docker compose -f deploy/docker-compose.yaml logs -f
}

# Remove node Ritual
remove_node() {
  if yes_no "Remover" "Tem certeza que deseja remover o Ritual Node e todos os arquivos?"; then
    cd "$REPO_DIR"
    docker compose down
    cd "$HOME"
    rm -rf "$REPO_DIR"
    docker rmi ritualnetwork/hello-world-infernet:latest || true
    msg_box "Remoção" "Ritual Node removido com sucesso."
  fi
}

# Menu principal com whiptail
main_menu() {
  while true; do
    OPTION=$(whiptail --title "Menu Ritual Node Installer" --menu "Escolha uma opção:" 15 60 8 \
      "1" "Instalar Node Ritual Completo" \
      "2" "Ver Logs do Node" \
      "3" "Remover Node Ritual" \
      "4" "Sair" 3>&1 1>&2 2>&3)

    case "$OPTION" in
      1)
        install_dependencies
        install_foundry
        clone_repo
        configure_files
        install_sdks
        deploy_container
        deploy_contracts
        call_contract
        msg_box "Sucesso" "Node Ritual instalado e funcionando!"
        ;;
      2)
        show_logs
        ;;
      3)
        remove_node
        ;;
      4)
        clear
        exit 0
        ;;
      *)
        msg_box "Erro" "Opção inválida!"
        ;;
    esac
  done
}

main_menu
