#!/bin/bash

###############################################################################
# Script para Configurar Autenticação HTTP Basic no Guacamole Recording Player
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
AUTH_FILE="/etc/nginx/.htpasswd"
NGINX_CONFIG="/etc/nginx/sites-available/guacamole-player"

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

# Verificar se apache2-utils está instalado
check_dependencies() {
    if ! command -v htpasswd &> /dev/null; then
        print_info "Instalando apache2-utils (necessário para gerar senhas)..."
        apt update -qq
        apt install -y apache2-utils
    fi
}

# Criar arquivo de senha
create_password_file() {
    print_info "Configurando autenticação HTTP Basic..."
    
    # Criar diretório se não existir
    mkdir -p "$(dirname "$AUTH_FILE")"
    
    # Se o arquivo já existe, fazer backup
    if [ -f "$AUTH_FILE" ]; then
        print_warn "Arquivo de senha já existe. Fazendo backup..."
        cp "$AUTH_FILE" "${AUTH_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Solicitar usuário e senha
    echo ""
    print_info "Vamos criar o primeiro usuário para autenticação."
    read -p "Digite o nome de usuário: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        print_error "Nome de usuário não pode ser vazio!"
        exit 1
    fi
    
    # Verificar se usuário já existe
    if [ -f "$AUTH_FILE" ] && grep -q "^${USERNAME}:" "$AUTH_FILE"; then
        print_warn "Usuário '$USERNAME' já existe."
        read -p "Deseja alterar a senha? (s/n): " CHANGE_PASS
        if [ "$CHANGE_PASS" = "s" ] || [ "$CHANGE_PASS" = "S" ]; then
            htpasswd "$AUTH_FILE" "$USERNAME"
            print_info "Senha do usuário '$USERNAME' atualizada!"
        else
            print_info "Senha não alterada."
        fi
    else
        # Criar novo usuário
        read -sp "Digite a senha: " PASSWORD
        echo ""
        read -sp "Confirme a senha: " PASSWORD_CONFIRM
        echo ""
        
        if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            print_error "As senhas não coincidem!"
            exit 1
        fi
        
        if [ -z "$PASSWORD" ]; then
            print_error "Senha não pode ser vazia!"
            exit 1
        fi
        
        # Criar arquivo de senha
        echo "$PASSWORD" | htpasswd -ci "$AUTH_FILE" "$USERNAME"
        print_info "Usuário '$USERNAME' criado com sucesso!"
    fi
    
    # Ajustar permissões
    chmod 644 "$AUTH_FILE"
    chown root:www-data "$AUTH_FILE"
    
    print_info "Arquivo de senha criado em: $AUTH_FILE"
}

# Adicionar usuário adicional
add_user() {
    if [ -z "$1" ]; then
        read -p "Digite o nome de usuário: " USERNAME
    else
        USERNAME="$1"
    fi
    
    if [ -z "$USERNAME" ]; then
        print_error "Nome de usuário não pode ser vazio!"
        exit 1
    fi
    
    if [ ! -f "$AUTH_FILE" ]; then
        print_error "Arquivo de senha não existe. Execute primeiro: $0 --setup"
        exit 1
    fi
    
    if grep -q "^${USERNAME}:" "$AUTH_FILE"; then
        print_warn "Usuário '$USERNAME' já existe."
        read -p "Deseja alterar a senha? (s/n): " CHANGE_PASS
        if [ "$CHANGE_PASS" = "s" ] || [ "$CHANGE_PASS" = "S" ]; then
            htpasswd "$AUTH_FILE" "$USERNAME"
            print_info "Senha do usuário '$USERNAME' atualizada!"
        else
            print_info "Senha não alterada."
        fi
    else
        read -sp "Digite a senha: " PASSWORD
        echo ""
        read -sp "Confirme a senha: " PASSWORD_CONFIRM
        echo ""
        
        if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            print_error "As senhas não coincidem!"
            exit 1
        fi
        
        echo "$PASSWORD" | htpasswd -i "$AUTH_FILE" "$USERNAME"
        print_info "Usuário '$USERNAME' adicionado com sucesso!"
    fi
}

# Remover usuário
remove_user() {
    if [ -z "$1" ]; then
        read -p "Digite o nome de usuário para remover: " USERNAME
    else
        USERNAME="$1"
    fi
    
    if [ -z "$USERNAME" ]; then
        print_error "Nome de usuário não pode ser vazio!"
        exit 1
    fi
    
    if [ ! -f "$AUTH_FILE" ]; then
        print_error "Arquivo de senha não existe!"
        exit 1
    fi
    
    if ! grep -q "^${USERNAME}:" "$AUTH_FILE"; then
        print_error "Usuário '$USERNAME' não encontrado!"
        exit 1
    fi
    
    htpasswd -D "$AUTH_FILE" "$USERNAME"
    print_info "Usuário '$USERNAME' removido com sucesso!"
}

# Listar usuários
list_users() {
    if [ ! -f "$AUTH_FILE" ]; then
        print_error "Arquivo de senha não existe!"
        exit 1
    fi
    
    print_info "Usuários configurados:"
    cut -d: -f1 "$AUTH_FILE"
}

# Atualizar configuração do Nginx
update_nginx_config() {
    if [ ! -f "$NGINX_CONFIG" ]; then
        print_error "Configuração do Nginx não encontrada: $NGINX_CONFIG"
        exit 1
    fi
    
    if [ ! -f "$AUTH_FILE" ]; then
        print_error "Arquivo de senha não existe. Execute primeiro: $0 --setup"
        exit 1
    fi
    
    print_info "Atualizando configuração do Nginx..."
    
    # Verificar se autenticação já está configurada
    if grep -q "auth_basic" "$NGINX_CONFIG"; then
        print_warn "Autenticação já está configurada no Nginx."
        read -p "Deseja reconfigurar? (s/n): " RECONFIG
        if [ "$RECONFIG" != "s" ] && [ "$RECONFIG" != "S" ]; then
            print_info "Configuração mantida."
            return 0
        fi
    fi
    
    # Fazer backup
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Adicionar autenticação antes do location /
    sed -i '/location \/ {/i\
    # HTTP Basic Authentication\
    auth_basic "Guacamole Recording Player";\
    auth_basic_user_file '"$AUTH_FILE"';' "$NGINX_CONFIG"
    
    print_info "Configuração do Nginx atualizada!"
    
    # Testar configuração
    if nginx -t; then
        print_info "Configuração do Nginx válida!"
        print_info "Reiniciando Nginx..."
        systemctl reload nginx
        print_info "Nginx reiniciado com sucesso!"
    else
        print_error "Erro na configuração do Nginx!"
        print_warn "Restaurando backup..."
        mv "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" "$NGINX_CONFIG"
        exit 1
    fi
}

# Remover autenticação
remove_auth() {
    if [ ! -f "$NGINX_CONFIG" ]; then
        print_error "Configuração do Nginx não encontrada!"
        exit 1
    fi
    
    if ! grep -q "auth_basic" "$NGINX_CONFIG"; then
        print_warn "Autenticação não está configurada."
        return 0
    fi
    
    print_warn "Removendo autenticação do Nginx..."
    
    # Fazer backup
    cp "$NGINX_CONFIG" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Remover linhas de autenticação
    sed -i '/# HTTP Basic Authentication/,/auth_basic_user_file/d' "$NGINX_CONFIG"
    
    # Testar configuração
    if nginx -t; then
        print_info "Configuração do Nginx válida!"
        print_info "Reiniciando Nginx..."
        systemctl reload nginx
        print_info "Autenticação removida com sucesso!"
    else
        print_error "Erro na configuração do Nginx!"
        exit 1
    fi
}

# Mostrar ajuda
show_help() {
    echo "Uso: $0 [opção]"
    echo ""
    echo "Opções:"
    echo "  --setup          Configurar autenticação (criar primeiro usuário e atualizar Nginx)"
    echo "  --add [user]     Adicionar novo usuário"
    echo "  --remove [user]  Remover usuário"
    echo "  --list           Listar usuários"
    echo "  --update-nginx   Atualizar configuração do Nginx (após criar usuários)"
    echo "  --remove-auth    Remover autenticação do Nginx"
    echo "  --help           Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 --setup                    # Configurar autenticação pela primeira vez"
    echo "  $0 --add admin               # Adicionar usuário 'admin'"
    echo "  $0 --add                     # Adicionar usuário (solicita nome)"
    echo "  $0 --remove admin            # Remover usuário 'admin'"
    echo "  $0 --list                    # Listar todos os usuários"
}

# Função principal
main() {
    check_root
    check_dependencies
    
    case "${1:-}" in
        --setup)
            create_password_file
            update_nginx_config
            print_info ""
            print_info "Autenticação configurada com sucesso!"
            print_info "A aplicação agora requer login e senha para acessar."
            ;;
        --add)
            add_user "$2"
            ;;
        --remove)
            remove_user "$2"
            ;;
        --list)
            list_users
            ;;
        --update-nginx)
            update_nginx_config
            ;;
        --remove-auth)
            remove_auth
            ;;
        --help|"")
            show_help
            ;;
        *)
            print_error "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
}

# Executar
main "$@"


