# 🚀 Guia Rápido de Instalação

## Opção 1: Instalação Automatizada (Recomendado)

Execute o script de instalação automatizada:

```bash
sudo ./install-debian.sh
```

O script irá:
- ✅ Instalar todas as dependências (Java, Maven, Nginx)
- ✅ Compilar o projeto
- ✅ Configurar o Nginx
- ✅ Configurar firewall
- ✅ Verificar a instalação

### Personalizar instalação

Você pode definir variáveis de ambiente antes de executar:

```bash
# Usar porta personalizada
export PORT=8080
sudo -E ./install-debian.sh

# Usar domínio personalizado
export SERVER_NAME=player.exemplo.com
sudo -E ./install-debian.sh

# Combinar ambos
export PORT=8080
export SERVER_NAME=player.exemplo.com
sudo -E ./install-debian.sh
```

---

## Opção 2: Instalação Manual

Siga o guia completo em [INSTALL_DEBIAN.md](INSTALL_DEBIAN.md) para instalação passo a passo com explicações detalhadas.

---

## ⚡ Comandos Rápidos

### Instalação completa (copie e cole):

```bash
# 1. Instalar dependências
# Nota: No Debian 13, Java 8 pode não estar disponível. O script tenta múltiplas versões.
sudo apt update

# Tentar instalar Java (tenta múltiplas versões)
sudo apt install -y openjdk-11-jdk || \
sudo apt install -y openjdk-17-jdk || \
sudo apt install -y openjdk-21-jdk || \
sudo apt install -y default-jdk

# Instalar outras dependências
sudo apt install -y maven nginx git

# 2. Compilar projeto
cd /home/gxavier/tstsh/guacamole-recording-player
mvn clean package

# 3. Copiar arquivos
sudo mkdir -p /var/www/guacamole-player
sudo cp -r target/apache-guacamole-player-1.1.0-1/* /var/www/guacamole-player/
sudo chown -R www-data:www-data /var/www/guacamole-player

# 4. Criar configuração Nginx
sudo tee /etc/nginx/sites-available/guacamole-player > /dev/null <<'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/guacamole-player;
    index index.html;
    access_log /var/log/nginx/guacamole-player-access.log;
    error_log /var/log/nginx/guacamole-player-error.log;
    location / {
        try_files $uri $uri/ /index.html;
    }
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# 5. Habilitar e reiniciar
sudo ln -sf /etc/nginx/sites-available/guacamole-player /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

# 6. Configurar firewall (se necessário)
sudo ufw allow 80/tcp 2>/dev/null || true
```

### Verificar instalação:

```bash
curl http://localhost
```

### Acessar no navegador:

```
http://seu-ip-do-servidor
```

---

## 🔐 Configurar Autenticação (Login/Senha)

Para proteger a aplicação com autenticação HTTP Basic:

```bash
# Configurar primeiro usuário
sudo ./setup-auth.sh --setup

# Adicionar mais usuários
sudo ./setup-auth.sh --add usuario

# Listar usuários
sudo ./setup-auth.sh --list

# Remover usuário
sudo ./setup-auth.sh --remove usuario
```

**Documentação completa**: Veja [AUTH_SETUP.md](AUTH_SETUP.md)

## 🔄 Atualizar Aplicação

```bash
cd /home/gxavier/tstsh/guacamole-recording-player
mvn clean package
sudo cp -r target/apache-guacamole-player-1.1.0-1/* /var/www/guacamole-player/
sudo chown -R www-data:www-data /var/www/guacamole-player
sudo systemctl reload nginx
```

---

## 📋 Verificação Pós-Instalação

```bash
# Verificar se Nginx está rodando
sudo systemctl status nginx

# Verificar se a aplicação responde
curl -I http://localhost

# Verificar arquivos
ls -la /var/www/guacamole-player/

# Ver logs
sudo tail -f /var/log/nginx/guacamole-player-access.log
```

---

## 🆘 Problemas Comuns

### Erro: "java: command not found" ou "Unable to locate package openjdk-8-jdk"

No Debian 13, o Java 8 não está disponível. Instale uma versão mais recente:

```bash
# Tentar Java 11, 17 ou 21
sudo apt install -y openjdk-11-jdk || \
sudo apt install -y openjdk-17-jdk || \
sudo apt install -y openjdk-21-jdk || \
sudo apt install -y default-jdk
```

### Erro do Maven: "Could not transfer artifact" ou "transfer failed"

Se você está atrás de um proxy, configure antes de executar:

```bash
export http_proxy=http://proxy:porta
export https_proxy=http://proxy:porta
export HTTP_PROXY=$http_proxy
export HTTPS_PROXY=$https_proxy

# Depois execute o script ou mvn
sudo -E ./install-debian.sh
```

O script detecta automaticamente o proxy e configura o Maven.

### Erro: "A required class was missing: org.codehaus.plexus.util.DirectoryScanner"

Este erro indica incompatibilidade entre o plugin antigo e Maven 3.9+.

**Solução**: O `pom.xml` foi atualizado automaticamente com a dependência faltante. Se o erro persistir:

```bash
# Limpar cache do Maven
rm -rf ~/.m2/repository/com/samaxes/maven/minify-maven-plugin
mvn clean package
```

Ou instale Maven 3.8 (compatível com Docker) - veja INSTALL_DEBIAN.md para detalhes.

### Erro: "mvn: command not found"
```bash
sudo apt install -y maven
```

### Erro 403 Forbidden
```bash
sudo chown -R www-data:www-data /var/www/guacamole-player
sudo chmod -R 755 /var/www/guacamole-player
```

### Nginx não inicia
```bash
sudo nginx -t  # Verificar erros de configuração
sudo journalctl -u nginx -n 50  # Ver logs
```

---

Para mais detalhes, consulte [INSTALL_DEBIAN.md](INSTALL_DEBIAN.md)

