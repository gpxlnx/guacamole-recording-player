#!/bin/bash

###############################################################################
# Script de Instalação On-Premise - Guacamole Recording Player
# Para Debian 13 (Bookworm)
###############################################################################

# Não usar set -e aqui, precisamos tratar erros de instalação de Java manualmente

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_DIR="/var/www/guacamole-player"
NGINX_CONFIG="/etc/nginx/sites-available/guacamole-player"
NGINX_ENABLED="/etc/nginx/sites-enabled/guacamole-player"
PORT="${PORT:-80}"
SERVER_NAME="${SERVER_NAME:-localhost}"

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

# Verificar sistema operacional
check_os() {
    if [ ! -f /etc/debian_version ]; then
        print_error "Este script é apenas para Debian/Ubuntu"
        exit 1
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version)
    print_info "Sistema detectado: Debian $DEBIAN_VERSION"
}

# Instalar Java (tenta múltiplas versões)
install_java() {
    print_info "Verificando versões de Java disponíveis..."
    
    # Tentar Java 8 primeiro
    if apt-cache show openjdk-8-jdk &>/dev/null; then
        print_info "Instalando OpenJDK 8..."
        if apt install -y openjdk-8-jdk; then
            print_info "OpenJDK 8 instalado com sucesso"
            return 0
        fi
    fi
    
    # Tentar Java 11 (LTS)
    if apt-cache show openjdk-11-jdk &>/dev/null; then
        print_warn "OpenJDK 8 não disponível. Tentando OpenJDK 11..."
        if apt install -y openjdk-11-jdk; then
            print_info "OpenJDK 11 instalado com sucesso"
            return 0
        fi
    fi
    
    # Tentar Java 17 (LTS)
    if apt-cache show openjdk-17-jdk &>/dev/null; then
        print_warn "OpenJDK 11 não disponível. Tentando OpenJDK 17..."
        if apt install -y openjdk-17-jdk; then
            print_info "OpenJDK 17 instalado com sucesso"
            return 0
        fi
    fi
    
    # Tentar Java 21 (LTS mais recente)
    if apt-cache show openjdk-21-jdk &>/dev/null; then
        print_warn "OpenJDK 17 não disponível. Tentando OpenJDK 21..."
        if apt install -y openjdk-21-jdk; then
            print_info "OpenJDK 21 instalado com sucesso"
            return 0
        fi
    fi
    
    # Última tentativa: default-jdk
    print_warn "Tentando instalar default-jdk..."
    if apt install -y default-jdk; then
        print_info "Java (default-jdk) instalado com sucesso"
        return 0
    fi
    
    print_error "Não foi possível instalar Java. Por favor, instale manualmente."
    return 1
}

# Instalar dependências do sistema
install_dependencies() {
    print_info "Atualizando lista de pacotes..."
    apt update -qq
    
    print_info "Instalando Java..."
    if ! install_java; then
        print_error "Falha ao instalar Java"
        exit 1
    fi
    
    print_info "Instalando outras dependências (Maven, Nginx, Git, Curl)..."
    if ! apt install -y maven nginx git curl ca-certificates wget; then
        print_error "Falha ao instalar dependências"
        exit 1
    fi
    
    # Verificar versão do Maven e instalar 3.8 se necessário
    MAVEN_VERSION=$(mvn -version 2>&1 | grep "Apache Maven" | sed 's/.*Apache Maven \([0-9]\+\.[0-9]\+\).*/\1/')
    MAVEN_MAJOR=$(echo "$MAVEN_VERSION" | cut -d. -f1)
    MAVEN_MINOR=$(echo "$MAVEN_VERSION" | cut -d. -f2)
    
    # Se Maven 3.9+, instalar Maven 3.8 para compatibilidade
    if [ -n "$MAVEN_MAJOR" ] && [ "$MAVEN_MAJOR" -ge 3 ] && [ -n "$MAVEN_MINOR" ] && [ "$MAVEN_MINOR" -ge 9 ]; then
        print_warn "Maven $MAVEN_VERSION detectado. O plugin minify-maven-plugin pode ter problemas."
        print_warn "O pom.xml foi atualizado com dependência adicional para compatibilidade."
        print_warn "Se ainda houver problemas, considere usar Maven 3.8 (compatível com Docker)."
    fi
    
    # Verificar e informar sobre proxy
    if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ]; then
        print_info "Proxy detectado: ${http_proxy:-${HTTP_PROXY}}"
        print_info "O Maven será configurado automaticamente para usar o proxy"
    fi
    
    print_info "Dependências instaladas com sucesso"
    
    # Verificar instalações
    print_info "Verificando instalações..."
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    print_info "Java: $JAVA_VERSION"
    Maven_VERSION=$(mvn -version | head -n 1)
    print_info "Maven: $Maven_VERSION"
    nginx -v
}

# Configurar proxy do Maven
configure_maven_proxy() {
    # Verificar se há variáveis de proxy definidas
    if [ -n "$http_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$https_proxy" ] || [ -n "$HTTPS_PROXY" ]; then
        print_info "Configurando proxy do Maven..."
        
        # Usar http_proxy se disponível, senão HTTP_PROXY
        PROXY_URL="${http_proxy:-${HTTP_PROXY}}"
        HTTPS_PROXY_URL="${https_proxy:-${HTTPS_PROXY:-${PROXY_URL}}}"
        
        # Extrair host e porta do proxy
        # Remove http:// ou https:// se presente
        PROXY_URL_CLEAN="${PROXY_URL#http://}"
        PROXY_URL_CLEAN="${PROXY_URL_CLEAN#https://}"
        
        if [[ "$PROXY_URL_CLEAN" =~ ^([^:/]+):([0-9]+) ]]; then
            PROXY_HOST="${BASH_REMATCH[1]}"
            PROXY_PORT="${BASH_REMATCH[2]}"
            
            # Criar diretório .m2 se não existir
            MAVEN_HOME_DIR="${HOME}/.m2"
            if [ "$EUID" -eq 0 ]; then
                MAVEN_HOME_DIR="/root/.m2"
            fi
            mkdir -p "$MAVEN_HOME_DIR"
            
            # Criar ou atualizar settings.xml
            SETTINGS_FILE="$MAVEN_HOME_DIR/settings.xml"
            
            if [ -f "$SETTINGS_FILE" ]; then
                print_warn "Arquivo settings.xml já existe. Fazendo backup..."
                cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
            fi
            
            # Criar settings.xml com configuração de proxy
            cat > "$SETTINGS_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
          http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <proxies>
        <proxy>
            <id>http-proxy</id>
            <active>true</active>
            <protocol>http</protocol>
            <host>${PROXY_HOST}</host>
            <port>${PROXY_PORT}</port>
            <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
        </proxy>
        <proxy>
            <id>https-proxy</id>
            <active>true</active>
            <protocol>https</protocol>
            <host>${PROXY_HOST}</host>
            <port>${PROXY_PORT}</port>
            <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
        </proxy>
    </proxies>
</settings>
EOF
            print_info "Proxy do Maven configurado: ${PROXY_HOST}:${PROXY_PORT}"
        else
            print_warn "Formato de proxy não reconhecido: $PROXY_URL"
        fi
    else
        print_info "Nenhuma variável de proxy detectada. Maven usará conexão direta."
    fi
}

# Compilar o projeto
build_project() {
    print_info "Navegando para o diretório do projeto: $PROJECT_DIR"
    cd "$PROJECT_DIR" || {
        print_error "Não foi possível acessar o diretório do projeto"
        exit 1
    }
    
    # Configurar proxy do Maven se necessário
    configure_maven_proxy
    
    print_info "Compilando projeto com Maven..."
    print_warn "Isso pode levar alguns minutos na primeira execução..."
    
    # Tentar build com mais verbosidade se falhar
    if ! mvn clean package -q; then
        print_warn "Build falhou com modo silencioso. Tentando com mais detalhes..."
        if ! mvn clean package; then
            print_error "Falha no build do projeto"
            print_warn ""
            print_warn "Possíveis causas:"
            print_warn "  1. Problema de conectividade/proxy"
            print_warn "  2. Incompatibilidade do plugin minify-maven-plugin com Maven 3.9+"
            print_warn ""
            print_warn "Soluções:"
            print_warn "  - O pom.xml foi atualizado com dependência adicional (plexus-utils)"
            print_warn "  - Se o erro persistir, tente limpar o cache do Maven:"
            print_warn "    rm -rf ~/.m2/repository/com/samaxes/maven/minify-maven-plugin"
            print_warn "    mvn clean package"
            print_warn "  - Ou instale Maven 3.8 manualmente (compatível com Docker)"
            print_warn ""
            print_warn "Para debug completo, execute: mvn clean package -X"
            exit 1
        fi
    fi
    
    # Verificar se o diretório de build existe
    if [ ! -d "target/apache-guacamole-player-1.1.0-1" ]; then
        print_error "Diretório de build não encontrado!"
        exit 1
    fi
    
    print_info "Arquivos compilados em: target/apache-guacamole-player-1.1.0-1/"
}

# Configurar Nginx
setup_nginx() {
    print_info "Configurando Nginx..."
    
    # Criar diretório
    print_info "Criando diretório: $NGINX_DIR"
    mkdir -p "$NGINX_DIR"
    
    # Copiar arquivos
    print_info "Copiando arquivos compilados..."
    cp -r "$PROJECT_DIR/target/apache-guacamole-player-1.1.0-1"/* "$NGINX_DIR/"
    
    # Ajustar permissões
    print_info "Ajustando permissões..."
    chown -R www-data:www-data "$NGINX_DIR"
    chmod -R 755 "$NGINX_DIR"
    
    # Criar configuração do Nginx
    print_info "Criando configuração do Nginx..."
    cat > "$NGINX_CONFIG" <<EOF
server {
    listen ${PORT};
    server_name ${SERVER_NAME};
    
    root ${NGINX_DIR};
    index index.html;

    # Logs
    access_log /var/log/nginx/guacamole-player-access.log;
    error_log /var/log/nginx/guacamole-player-error.log;

    # Handle Angular routes (SPA - Single Page Application)
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Cache para arquivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # Habilitar site
    print_info "Habilitando site..."
    if [ -L "$NGINX_ENABLED" ]; then
        rm "$NGINX_ENABLED"
    fi
    ln -s "$NGINX_CONFIG" "$NGINX_ENABLED"
    
    # Remover site padrão (opcional)
    if [ -L "/etc/nginx/sites-enabled/default" ]; then
        print_warn "Removendo site padrão do Nginx..."
        rm /etc/nginx/sites-enabled/default
    fi
    
    # Testar configuração
    print_info "Testando configuração do Nginx..."
    if nginx -t; then
        print_info "Configuração do Nginx válida!"
    else
        print_error "Erro na configuração do Nginx!"
        exit 1
    fi
    
    # Reiniciar Nginx
    print_info "Reiniciando Nginx..."
    systemctl restart nginx
    
    # Verificar status
    if systemctl is-active --quiet nginx; then
        print_info "Nginx está rodando!"
    else
        print_error "Nginx não está rodando!"
        exit 1
    fi
}

# Configurar firewall
setup_firewall() {
    print_info "Configurando firewall..."
    
    # Verificar se ufw está instalado
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_info "UFW está ativo, permitindo porta ${PORT}..."
            ufw allow ${PORT}/tcp
            print_info "Porta ${PORT} permitida no firewall"
        else
            print_warn "UFW não está ativo, pulando configuração de firewall"
        fi
    else
        print_warn "UFW não encontrado, configure o firewall manualmente se necessário"
    fi
}

# Verificar instalação
verify_installation() {
    print_info "Verificando instalação..."
    
    # Testar localmente
    sleep 2
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT} | grep -q "200"; then
        print_info "✓ Aplicação está respondendo corretamente!"
    else
        print_warn "Aplicação pode não estar respondendo corretamente"
    fi
    
    # Verificar arquivos
    if [ -f "$NGINX_DIR/index.html" ]; then
        print_info "✓ Arquivos instalados corretamente"
    else
        print_error "Arquivos não encontrados!"
        exit 1
    fi
}

# Mostrar informações finais
show_summary() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
    echo "=========================================="
    echo ""
    echo "Informações da instalação:"
    echo "  - Diretório da aplicação: $NGINX_DIR"
    echo "  - Configuração Nginx: $NGINX_CONFIG"
    echo "  - Porta: $PORT"
    echo "  - Server Name: $SERVER_NAME"
    echo ""
    echo "Acesse a aplicação em:"
    echo "  - http://localhost:${PORT}"
    echo "  - http://${SERVER_NAME}:${PORT}"
    echo ""
    echo "Comandos úteis:"
    echo "  - Ver logs: sudo tail -f /var/log/nginx/guacamole-player-access.log"
    echo "  - Reiniciar Nginx: sudo systemctl restart nginx"
    echo "  - Status Nginx: sudo systemctl status nginx"
    echo ""
    echo "🔐 Configurar autenticação (opcional):"
    echo "  - Configurar login/senha: sudo ./setup-auth.sh --setup"
    echo "  - Ver documentação: cat AUTH_SETUP.md"
    echo ""
}

# Função principal
main() {
    echo "=========================================="
    echo "Instalação Guacamole Recording Player"
    echo "Debian 13 On-Premise"
    echo "=========================================="
    echo ""
    
    check_root
    check_os
    install_dependencies
    build_project
    setup_nginx
    setup_firewall
    verify_installation
    show_summary
}

# Executar
main

