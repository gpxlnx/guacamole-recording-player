#!/bin/bash

###############################################################################
# Script para Configurar Mapeamento de Diretórios de Gravações
# Mapeia diretórios do host para serem acessíveis via web
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
NGINX_CONFIG="/etc/nginx/sites-available/guacamole-player"
RECORDINGS_BASE="/gravacoes"
API_SCRIPT="/usr/local/bin/list-files.py"

# Função para imprimir mensagens
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Por favor, execute como root ou com sudo"
        exit 1
    fi
}

# Verificar dependências
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        print_info "Instalando Python3..."
        apt update -qq
        apt install -y python3
    fi
}

# Instalar script de listagem
install_list_script() {
    print_info "Instalando script de listagem de arquivos..."
    
    # Copiar script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/list-files.py" ]; then
        cp "$SCRIPT_DIR/list-files.py" "$API_SCRIPT"
        chmod +x "$API_SCRIPT"
        chown root:root "$API_SCRIPT"
        print_info "Script instalado em: $API_SCRIPT"
    else
        print_error "Arquivo list-files.py não encontrado!"
        exit 1
    fi
}

# Configurar diretório de gravações
setup_recordings_directory() {
    local RECORDINGS_DIR="${1:-$RECORDINGS_BASE}"
    
    print_info "Configurando diretório de gravações: $RECORDINGS_DIR"
    
    # Criar diretório se não existir
    if [ ! -d "$RECORDINGS_DIR" ]; then
        print_warn "Diretório não existe. Criando: $RECORDINGS_DIR"
        mkdir -p "$RECORDINGS_DIR"
    fi
    
    # Ajustar permissões
    chown -R www-data:www-data "$RECORDINGS_DIR"
    chmod -R 755 "$RECORDINGS_DIR"
    
    print_info "Diretório configurado: $RECORDINGS_DIR"
    print_info "Permissões: www-data:www-data, 755"
}

# Atualizar configuração do Nginx
update_nginx_config() {
    local RECORDINGS_BASE_DIR="${1:-$RECORDINGS_BASE}"
    
    if [ ! -f "$NGINX_CONFIG" ]; then
        print_error "Configuração do Nginx não encontrada: $NGINX_CONFIG"
        exit 1
    fi
    
    print_info "Atualizando configuração do Nginx..."
    
    # Fazer backup
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Verificar se já está configurado
    if grep -q "location /api/list-files" "$NGINX_CONFIG"; then
        print_warn "API de listagem já está configurada."
        read -p "Deseja reconfigurar? (s/n): " RECONFIG
        if [ "$RECONFIG" != "s" ] && [ "$RECONFIG" != "S" ]; then
            print_info "Configuração mantida."
            return 0
        fi
        # Remover configuração antiga
        sed -i '/# API para listar arquivos/,/^[[:space:]]*}/d' "$NGINX_CONFIG"
        sed -i '/# Servir arquivos de gravação/,/^[[:space:]]*}/d' "$NGINX_CONFIG"
    fi
    
    # Adicionar configuração antes do último }
    # Encontrar última linha do server block
    sed -i '/^}$/i\
    # API para listar arquivos de gravação\
    location /api/list-files {\
        proxy_pass http://127.0.0.1:8888/api/list-files;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
    }\
\
    # Servir arquivos de gravação\
    location /recordings {\
        alias '"$RECORDINGS_BASE_DIR"';\
        autoindex off;\
        add_header Content-Disposition "attachment";\
    }' "$NGINX_CONFIG"
    
    print_info "Configuração do Nginx atualizada!"
}

# Criar serviço systemd para o servidor de listagem
create_systemd_service() {
    print_info "Criando serviço systemd para servidor de listagem..."
    
    local SERVICE_FILE="/etc/systemd/system/guacamole-list-files.service"
    local RECORDINGS_DIR="${1:-$RECORDINGS_BASE}"
    
    # Determinar diretório base (pai do diretório de gravações)
    # Se RECORDINGS_DIR é /gravacoes/bi, base deve ser /gravacoes
    local BASE_DIR="$RECORDINGS_BASE"
    if [ "$RECORDINGS_DIR" != "$RECORDINGS_BASE" ]; then
        # Se o diretório especificado não é o base, usar o base como referência
        BASE_DIR="$RECORDINGS_BASE"
    fi
    
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Guacamole Recording Files List Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$(dirname "$API_SCRIPT")
Environment="RECORDINGS_BASE_DIR=$BASE_DIR"
Environment="RECORDINGS_DIR=$RECORDINGS_DIR"
ExecStart=$API_SCRIPT --port 8888 --dir $RECORDINGS_DIR
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable guacamole-list-files
    systemctl restart guacamole-list-files
    
    print_info "Serviço systemd criado e iniciado"
}

# Função principal
main() {
    local RECORDINGS_DIR="${1:-$RECORDINGS_BASE}"
    
    echo "=========================================="
    echo "Configuração de Diretórios de Gravações"
    echo "=========================================="
    echo ""
    
    # Determinar diretório base
    # Se RECORDINGS_DIR é /gravacoes/bi, base deve ser /gravacoes
    if [ "$RECORDINGS_DIR" != "$RECORDINGS_BASE" ] && [[ "$RECORDINGS_DIR" == "$RECORDINGS_BASE"/* ]]; then
        # O diretório especificado está dentro do base, usar o base
        RECORDINGS_BASE_DIR="$RECORDINGS_BASE"
    else
        # Se o diretório especificado é diferente, usar o diretório pai como base
        RECORDINGS_BASE_DIR="$(dirname "$RECORDINGS_DIR")"
        if [ "$RECORDINGS_BASE_DIR" = "/" ]; then
            RECORDINGS_BASE_DIR="$RECORDINGS_DIR"
        fi
    fi
    
    # Atualizar variável global
    RECORDINGS_BASE="$RECORDINGS_BASE_DIR"
    
    check_root
    check_dependencies
    install_list_script
    setup_recordings_directory "$RECORDINGS_DIR"
    create_systemd_service "$RECORDINGS_DIR"
    update_nginx_config "$RECORDINGS_BASE_DIR"
    
    # Testar configuração
    print_info "Testando configuração do Nginx..."
    if nginx -t; then
        print_info "Configuração do Nginx válida!"
        print_info "Reiniciando Nginx..."
        systemctl reload nginx
        print_info "Nginx reiniciado com sucesso!"
    else
        print_error "Erro na configuração do Nginx!"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Configuração concluída com sucesso!${NC}"
    echo "=========================================="
    echo ""
    echo "Diretório de gravações: $RECORDINGS_DIR"
    echo "API de listagem: /api/list-files"
    echo "Acesso aos arquivos: /recordings"
    echo ""
    echo "Coloque seus arquivos .guac em: $RECORDINGS_DIR"
    echo "Eles aparecerão automaticamente na interface web."
    echo ""
}

# Executar
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Uso: $0 [diretório]"
    echo ""
    echo "Configura mapeamento de diretórios de gravações."
    echo ""
    echo "Argumentos:"
    echo "  diretório    Diretório base de gravações (padrão: /gravacoes)"
    echo ""
    echo "Exemplos:"
    echo "  $0                    # Usa /gravacoes (padrão)"
    echo "  $0 /gravacoes/bi/bi  # Usa diretório específico"
    exit 0
fi

main "$@"

