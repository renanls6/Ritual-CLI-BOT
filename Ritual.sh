#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

# Banner
banner=" 
    ${BLUE} ██████╗ ██╗  ██╗    ██████╗ ███████╗███╗   ██╗ █████╗ ███╗   ██╗${NC}
    ${BLUE}██╔═████╗╚██╗██╔╝    ██╔══██╗██╔════╝████╗  ██║██╔══██╗████╗  ██║${NC}
    ${BLUE}██║██╔██║ ╚███╔╝     ██████╔╝█████╗  ██╔██╗ ██║███████║██╔██╗ ██║${NC}
    ${BLUE}████╔╝██║ ██╔██╗     ██╔══██╗██╔══╝  ██║╚██╗██║██╔══██║██║╚██╗██║${NC}
    ${BLUE}╚██████╔╝██╔╝ ██╗    ██║  ██║███████╗██║ ╚████║██║  ██║██║ ╚████║${NC}
    ${BLUE}╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝${NC}
"

# Função para exibir o banner
display_header() {
    clear
    echo -e "${CYAN}"
    echo -e "$banner"
    echo -e "${BLUE}=====================================================================================${NC}"
    echo -e "${GREEN}🔗 Curtiu o Bot? Me siga lá no Twitter: https://x.com/0x_renan ${NC}"
    echo -e "${BLUE}=====================================================================================${NC}"
}

# Função principal do menu
main_menu() {
    while true; do
        display_header
        echo -e "${YELLOW}Por favor, selecione uma operação:${NC}"
        echo -e "1) ${GREEN}Instalar Node Ritual${NC}"
        echo -e "2) ${CYAN}Ver logs do Node Ritual${NC}"
        echo -e "3) ${RED}Remover Node Ritual${NC}"
        echo -e "4) ${MAGENTA}Sair do script${NC}"
        
        read -p "$(echo -e "${BLUE}Digite sua escolha: ${NC}")" choice

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
                echo -e "${GREEN}Saindo do script!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opção inválida, tente novamente.${NC}"
                ;;
        esac

        echo -e "${YELLOW}Pressione qualquer tecla para continuar...${NC}"
        read -n 1 -s
    done
}

# Função para instalar o Node Ritual
install_ritual_node() {
    display_header
    echo -e "${YELLOW}Instalando o Node Ritual...${NC}"

    # Aqui você colocaria os comandos reais para instalar o Node Ritual
    # Exemplo básico de instalação de Node (ajuste conforme o necessário para o seu caso):
    
    echo -e "${CYAN}Baixando dependências...${NC}"
    # Suponhamos que o Node.js e dependências necessárias sejam baixadas:
    sudo apt update
    sudo apt install -y nodejs npm

    echo -e "${CYAN}Instalando Node Ritual...${NC}"
    # Simulação de instalação do Node Ritual
    # Exemplo: git clone ou download de arquivos específicos
    git clone https://github.com/exemplo/node-ritual.git /opt/node-ritual
    cd /opt/node-ritual
    npm install

    # Verificando se a instalação foi bem-sucedida
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Node Ritual instalado com sucesso!${NC}"
    else
        echo -e "${RED}Erro na instalação do Node Ritual.${NC}"
    fi
    
    main_menu
}

# Função para visualizar os logs do Node Ritual
view_logs() {
    display_header
    echo -e "${YELLOW}Exibindo logs do Node Ritual...${NC}"

    # Aqui você pode adicionar o comando para visualizar os logs do Node Ritual
    # Por exemplo:
    tail -n 50 /var/log/node-ritual.log

    main_menu
}

# Função para remover o Node Ritual
remove_ritual_node() {
    display_header
    echo -e "${RED}Removendo o Node Ritual...${NC}"

    # Comando para remover a instalação do Node Ritual
    sudo rm -rf /opt/node-ritual

    # Verificando se foi removido
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Node Ritual removido com sucesso!${NC}"
    else
        echo -e "${RED}Erro na remoção do Node Ritual.${NC}"
    fi
    
    main_menu
}

# Chama a função principal
main_menu
