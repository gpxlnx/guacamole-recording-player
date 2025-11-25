# 📋 Guia de Instalação On-Premise - Debian 13

## 🔍 Análise do Projeto Docker

### O que o Docker faz:

1. **Build Stage (Maven + OpenJDK 8)**:
   - Compila o projeto Java/Maven
   - Processa templates AngularJS
   - Minifica JavaScript e CSS
   - Empacota dependências (jQuery, AngularJS, Guacamole JS)
   - Gera arquivo final em `target/apache-guacamole-player-1.1.0-1/`

2. **Production Stage (Nginx Alpine)**:
   - Copia os arquivos compilados para `/usr/share/nginx/html`
   - Configura Nginx com suporte a rotas AngularJS
   - Expõe porta 80
   - Serve a aplicação web estática

### Estrutura do Projeto:
- **Tecnologias**: Maven, AngularJS, Nginx
- **Build Tool**: Maven 3.8
- **Java**: OpenJDK 8
- **Web Server**: Nginx
- **Porta**: 80 (mapeada para 8080 no Docker)

---

## 🚀 Instalação no Debian 13 On-Premise

### Pré-requisitos

- Servidor Debian 13 (Bookworm)
- Acesso root ou sudo
- Conexão com internet para download de pacotes
- Git (para clonar o repositório, se necessário)

---

## 📦 Passo 1: Instalar Dependências do Sistema

### 1.1 Atualizar o sistema

```bash
sudo apt update
sudo apt upgrade -y
```

**Explicação**: Atualiza a lista de pacotes e o sistema para garantir que temos as versões mais recentes e seguras.

### 1.2 Instalar Java

**⚠️ IMPORTANTE**: No Debian 13 (Trixie), o OpenJDK 8 não está mais disponível nos repositórios padrão. O projeto funciona com versões mais recentes do Java.

**Opção A: Usar o script automatizado (Recomendado)**

O script `install-debian.sh` detecta automaticamente e instala uma versão disponível do Java:
- Tenta OpenJDK 8 primeiro (se disponível)
- Se não disponível, tenta OpenJDK 11, 17 ou 21 (LTS)
- Como último recurso, instala `default-jdk`

**Opção B: Instalação manual**

Tente instalar na seguinte ordem:

```bash
# Tentar Java 8 primeiro
sudo apt install -y openjdk-8-jdk

# Se não disponível, tentar Java 11 (LTS)
sudo apt install -y openjdk-11-jdk

# Ou Java 17 (LTS)
sudo apt install -y openjdk-17-jdk

# Ou Java 21 (LTS mais recente)
sudo apt install -y openjdk-21-jdk

# Como último recurso
sudo apt install -y default-jdk
```

**Explicação**: O projeto foi originalmente compilado com Java 8 no Docker, mas funciona perfeitamente com versões mais recentes do Java, pois apenas usa Maven para processar templates e minificar código (não há código Java sendo executado).

**Verificar instalação**:
```bash
java -version
# Deve mostrar a versão instalada (ex: openjdk version "11.0.x" ou "17.0.x")
```

### 1.3 Instalar Maven

```bash
sudo apt install -y maven
```

**Explicação**: Maven é a ferramenta de build que compila o projeto, processa templates, minifica código e gerencia dependências.

**Verificar instalação**:
```bash
mvn -version
# Deve mostrar: Apache Maven 3.x.x
```

### 1.4 Instalar Nginx

```bash
sudo apt install -y nginx
```

**Explicação**: Nginx será o servidor web que serve os arquivos estáticos da aplicação.

**Verificar instalação**:
```bash
nginx -v
# Deve mostrar: nginx version: nginx/1.x.x
```

### 1.5 Instalar Git (se necessário)

```bash
sudo apt install -y git
```

**Explicação**: Necessário se você precisar clonar o repositório do projeto.

---

## 🔨 Passo 2: Preparar o Projeto

### 2.1 Obter o código-fonte

Se você já tem o projeto na pasta atual, pule para o próximo passo.

Se precisar clonar:
```bash
cd /opt
sudo git clone https://github.com/Thomas-McKanna/guacamole-recording-player.git
cd guacamole-recording-player
```

**Explicação**: Clona o repositório para `/opt` (local comum para aplicações) ou use o diretório de sua preferência.

### 2.2 Navegar para o diretório do projeto

```bash
cd /home/gxavier/tstsh/guacamole-recording-player
```

**Explicação**: Ajuste o caminho conforme a localização do seu projeto.

---

## 🏗️ Passo 3: Compilar o Projeto

### 3.1 Configurar Proxy (se necessário)

Se você está em um ambiente corporativo com proxy, configure as variáveis de ambiente antes de compilar:

```bash
export http_proxy=http://seu-proxy:porta
export https_proxy=http://seu-proxy:porta
export HTTP_PROXY=$http_proxy
export HTTPS_PROXY=$https_proxy
```

**Explicação**: O Maven precisa acessar repositórios remotos para baixar dependências e plugins. Se você está atrás de um proxy, essas variáveis devem estar configuradas.

**Nota**: O script `install-debian.sh` detecta automaticamente essas variáveis e configura o Maven para usar o proxy.

### 3.2 Compilar com Maven

```bash
mvn clean package
```

**Explicação**: 
- `clean`: Remove arquivos de builds anteriores
- `package`: Compila o projeto, processa templates, minifica código e cria o pacote final

**Tempo estimado**: 2-5 minutos (primeira vez pode demorar mais devido ao download de dependências)

**Se houver erro de conexão**:
1. Verifique se as variáveis de proxy estão configuradas
2. Teste conectividade: `curl -I https://repo.maven.apache.org/maven2/`
3. Configure manualmente o Maven (veja seção de Troubleshooting)

**O que acontece**:
1. Maven baixa dependências (jQuery, AngularJS, Guacamole JS, etc.)
2. Processa templates HTML do AngularJS
3. Minifica JavaScript e CSS
4. Copia recursos estáticos (imagens, fontes)
5. Gera o pacote em `target/apache-guacamole-player-1.1.0-1/`

### 3.2 Verificar o build

```bash
ls -la target/apache-guacamole-player-1.1.0-1/
```

**Explicação**: Verifica se o diretório com os arquivos compilados foi criado corretamente. Você deve ver arquivos como `index.html`, `guac-player.js`, `guac-player.css`, `lib/`, etc.

---

## 🌐 Passo 4: Configurar Nginx

### 4.1 Criar diretório para a aplicação

```bash
sudo mkdir -p /var/www/guacamole-player
```

**Explicação**: Cria o diretório onde o Nginx servirá os arquivos da aplicação. `/var/www` é o local padrão para sites web no Debian.

### 4.2 Copiar arquivos compilados

```bash
sudo cp -r target/apache-guacamole-player-1.1.0-1/* /var/www/guacamole-player/
```

**Explicação**: Copia todos os arquivos compilados para o diretório do Nginx.

### 4.3 Ajustar permissões

```bash
sudo chown -R www-data:www-data /var/www/guacamole-player
sudo chmod -R 755 /var/www/guacamole-player
```

**Explicação**: 
- `www-data` é o usuário padrão do Nginx no Debian
- `755` permite leitura e execução para todos, escrita apenas para o dono

### 4.4 Criar configuração do Nginx

```bash
sudo nano /etc/nginx/sites-available/guacamole-player
```

**Conteúdo do arquivo**:

```nginx
server {
    listen 80;
    server_name localhost;  # Altere para seu domínio ou IP
    
    root /var/www/guacamole-player;
    index index.html;

    # Logs
    access_log /var/log/nginx/guacamole-player-access.log;
    error_log /var/log/nginx/guacamole-player-error.log;

    # Handle Angular routes (SPA - Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache para arquivos estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Explicação**:
- `listen 80`: Nginx escuta na porta 80 (HTTP)
- `server_name`: Nome do servidor (altere para seu domínio ou IP)
- `root`: Diretório raiz dos arquivos
- `try_files`: Redireciona todas as rotas para `index.html` (necessário para SPAs AngularJS)
- Cache: Otimiza carregamento de arquivos estáticos

### 4.5 Habilitar o site

```bash
sudo ln -s /etc/nginx/sites-available/guacamole-player /etc/nginx/sites-enabled/
```

**Explicação**: Cria um link simbólico para habilitar o site. O Nginx lê apenas arquivos em `sites-enabled/`.

### 4.6 Remover site padrão (opcional)

```bash
sudo rm /etc/nginx/sites-enabled/default
```

**Explicação**: Remove a página padrão do Nginx se você não precisar dela.

### 4.7 Testar configuração do Nginx

```bash
sudo nginx -t
```

**Explicação**: Valida a sintaxe da configuração do Nginx antes de reiniciar.

**Saída esperada**: `nginx: configuration file /etc/nginx/nginx.conf test is successful`

### 4.8 Reiniciar Nginx

```bash
sudo systemctl restart nginx
```

**Explicação**: Reinicia o Nginx para aplicar as novas configurações.

### 4.9 Verificar status do Nginx

```bash
sudo systemctl status nginx
```

**Explicação**: Verifica se o Nginx está rodando corretamente.

---

## 🔥 Passo 5: Configurar Firewall (se necessário)

### 5.1 Permitir porta 80 (HTTP)

Se você usa `ufw`:
```bash
sudo ufw allow 80/tcp
sudo ufw reload
```

Se você usa `iptables`:
```bash
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables-save
```

**Explicação**: Abre a porta 80 no firewall para permitir acesso HTTP à aplicação.

---

## ✅ Passo 6: Verificar Instalação

### 6.1 Testar localmente

```bash
curl http://localhost
```

**Explicação**: Testa se o Nginx está servindo a aplicação corretamente.

### 6.2 Acessar via navegador

Abra seu navegador e acesse:
- `http://seu-ip-do-servidor` ou
- `http://seu-dominio`

**Explicação**: A aplicação deve carregar e você deve ver a interface do Guacamole Recording Player.

---

## 🔄 Passo 7: Atualizar a Aplicação (quando necessário)

Quando houver atualizações no código:

```bash
# 1. Atualizar código (se usando git)
cd /home/gxavier/tstsh/guacamole-recording-player
git pull

# 2. Recompilar
mvn clean package

# 3. Copiar novos arquivos
sudo cp -r target/apache-guacamole-player-1.1.0-1/* /var/www/guacamole-player/

# 4. Ajustar permissões
sudo chown -R www-data:www-data /var/www/guacamole-player

# 5. Recarregar Nginx (não precisa reiniciar)
sudo systemctl reload nginx
```

**Explicação**: Processo completo para atualizar a aplicação sem downtime significativo.

---

## 🛠️ Configurações Avançadas

### Configurar HTTPS (SSL/TLS)

Para produção, é recomendado usar HTTPS. Você pode usar Let's Encrypt:

```bash
# Instalar Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obter certificado SSL
sudo certbot --nginx -d seu-dominio.com

# Renovação automática (já configurado)
sudo certbot renew --dry-run
```

**Explicação**: Certbot obtém e renova automaticamente certificados SSL gratuitos do Let's Encrypt.

### Configurar porta personalizada

Se quiser usar uma porta diferente de 80, edite `/etc/nginx/sites-available/guacamole-player`:

```nginx
server {
    listen 8080;  # Altere para a porta desejada
    # ... resto da configuração
}
```

E ajuste o firewall:
```bash
sudo ufw allow 8080/tcp
```

### Configurar múltiplos sites

Se você tem múltiplos sites, use diferentes `server_name`:

```nginx
server {
    listen 80;
    server_name player.exemplo.com;
    # ... configuração
}
```

---

## 📊 Monitoramento e Logs

### Ver logs de acesso

```bash
sudo tail -f /var/log/nginx/guacamole-player-access.log
```

### Ver logs de erro

```bash
sudo tail -f /var/log/nginx/guacamole-player-error.log
```

### Verificar uso de recursos

```bash
# CPU e memória
htop

# Espaço em disco
df -h

# Processos do Nginx
ps aux | grep nginx
```

---

## 🐛 Troubleshooting

### Nginx não inicia

```bash
# Verificar erros
sudo nginx -t
sudo journalctl -u nginx -n 50
```

### Aplicação não carrega

1. Verificar se os arquivos estão no lugar:
   ```bash
   ls -la /var/www/guacamole-player/
   ```

2. Verificar permissões:
   ```bash
   ls -la /var/www/guacamole-player/index.html
   ```

3. Verificar logs do Nginx:
   ```bash
   sudo tail -f /var/log/nginx/guacamole-player-error.log
   ```

### Erro 403 Forbidden

```bash
# Verificar permissões
sudo chown -R www-data:www-data /var/www/guacamole-player
sudo chmod -R 755 /var/www/guacamole-player
```

### Erro 404 Not Found

Verifique se o `root` no Nginx aponta para o diretório correto:
```bash
sudo cat /etc/nginx/sites-available/guacamole-player | grep root
```

### Erro do Maven: "Could not transfer artifact" ou "transfer failed"

Este erro geralmente indica problemas de conectividade ou proxy:

1. **Verificar conectividade com Maven Central**:
   ```bash
   curl -I https://repo.maven.apache.org/maven2/
   ```

2. **Configurar proxy do Maven manualmente**:
   
   Se você está atrás de um proxy, crie/edite `~/.m2/settings.xml` (ou `/root/.m2/settings.xml` se root):
   
   ```bash
   mkdir -p ~/.m2
   nano ~/.m2/settings.xml
   ```
   
   Adicione:
   ```xml
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
               <host>seu-proxy.com</host>
               <port>8080</port>
               <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
           </proxy>
           <proxy>
               <id>https-proxy</id>
               <active>true</active>
               <protocol>https</protocol>
               <host>seu-proxy.com</host>
               <port>8080</port>
               <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
           </proxy>
       </proxies>
   </settings>
   ```
   
   Substitua `seu-proxy.com` e `8080` pelos valores do seu proxy.

3. **Usar variáveis de ambiente de proxy**:
   ```bash
   export http_proxy=http://proxy:porta
   export https_proxy=http://proxy:porta
   export HTTP_PROXY=$http_proxy
   export HTTPS_PROXY=$https_proxy
   mvn clean package
   ```

4. **Verificar certificados SSL** (se houver erro de certificado):
   ```bash
   sudo apt install -y ca-certificates
   sudo update-ca-certificates
   ```

5. **Executar Maven com debug para mais informações**:
   ```bash
   mvn clean package -X
   ```

### Erro: "A required class was missing: org.codehaus.plexus.util.DirectoryScanner"

Este erro indica incompatibilidade entre o plugin `minify-maven-plugin:1.7.6` e Maven 3.9+.

**Solução aplicada automaticamente**: O `pom.xml` foi atualizado para incluir a dependência `plexus-utils:3.0.24` que resolve este problema.

**Se o erro persistir após a correção**:

1. **Limpar cache do Maven**:
   ```bash
   rm -rf ~/.m2/repository/com/samaxes/maven/minify-maven-plugin
   mvn clean package
   ```

2. **Instalar Maven 3.8 manualmente** (compatível com Docker):
   ```bash
   # Baixar Maven 3.8.8
   cd /tmp
   wget https://archive.apache.org/dist/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.tar.gz
   tar -xzf apache-maven-3.8.8-bin.tar.gz
   sudo mv apache-maven-3.8.8 /opt/maven-3.8.8
   
   # Configurar alternativas ou PATH
   sudo update-alternatives --install /usr/bin/mvn mvn /opt/maven-3.8.8/bin/mvn 1
   sudo update-alternatives --set mvn /opt/maven-3.8.8/bin/mvn
   
   # Verificar versão
   mvn -version
   ```

3. **Verificar se a correção foi aplicada**:
   ```bash
   grep -A 5 "plexus-utils" pom.xml
   ```
   
   Deve mostrar:
   ```xml
   <dependency>
       <groupId>org.codehaus.plexus</groupId>
       <artifactId>plexus-utils</artifactId>
       <version>3.0.24</version>
   </dependency>
   ```

---

## 📝 Resumo dos Comandos Principais

```bash
# 1. Instalar dependências
sudo apt update && sudo apt install -y openjdk-8-jdk maven nginx git

# 2. Compilar projeto
cd /home/gxavier/tstsh/guacamole-recording-player
mvn clean package

# 3. Copiar arquivos
sudo mkdir -p /var/www/guacamole-player
sudo cp -r target/apache-guacamole-player-1.1.0-1/* /var/www/guacamole-player/
sudo chown -R www-data:www-data /var/www/guacamole-player

# 4. Configurar Nginx
sudo nano /etc/nginx/sites-available/guacamole-player
# (cole a configuração do arquivo acima)

# 5. Habilitar e reiniciar
sudo ln -s /etc/nginx/sites-available/guacamole-player /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# 6. Configurar firewall
sudo ufw allow 80/tcp
```

---

## 🎯 Diferenças entre Docker e Instalação On-Premise

| Aspecto | Docker | On-Premise |
|---------|--------|------------|
| **Isolamento** | Container isolado | Instalação direta no sistema |
| **Build** | Multi-stage no Docker | Maven direto no sistema |
| **Servidor Web** | Nginx Alpine (leve) | Nginx completo do Debian |
| **Porta** | 8080 (mapeada) | 80 (ou configurável) |
| **Gerenciamento** | Docker commands | Systemd + Nginx |
| **Atualização** | Rebuild da imagem | Recompilar e copiar arquivos |
| **Logs** | Docker logs | Nginx logs + systemd |

---

## 📚 Referências

- [Apache Guacamole](https://guacamole.apache.org/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Maven Documentation](https://maven.apache.org/guides/)
- [Debian Administration](https://www.debian.org/doc/manuals/debian-handbook/)

---

**Documento criado para instalação on-premise no Debian 13**

