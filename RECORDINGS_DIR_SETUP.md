# 📁 Configuração de Diretórios de Gravações

Este guia explica como mapear diretórios do servidor para que os arquivos de gravação apareçam na interface web.

## 📋 Visão Geral

Com esta funcionalidade, você pode:
- ✅ Listar arquivos `.guac` de diretórios do servidor
- ✅ Acessar gravações sem fazer upload manual
- ✅ Organizar gravações em diretórios (ex: `/gravacoes/bi/bi`)
- ✅ Ver informações dos arquivos (tamanho, data de modificação)

## 🚀 Configuração Rápida

### Passo 1: Executar script de configuração

```bash
sudo ./setup-recordings-dir.sh /gravacoes/bi/bi
```

Ou use o diretório padrão:
```bash
sudo ./setup-recordings-dir.sh
```

O script irá:
1. Instalar Python3 (se necessário)
2. Instalar script de listagem
3. Criar serviço systemd
4. Configurar Nginx
5. Mapear diretório de gravações

### Passo 2: Colocar arquivos de gravação

Coloque seus arquivos `.guac` no diretório configurado:

```bash
# Exemplo: copiar arquivos para o diretório
sudo cp /caminho/para/gravacoes/*.guac /gravacoes/bi/bi/

# Ajustar permissões
sudo chown -R www-data:www-data /gravacoes/bi/bi
sudo chmod -R 755 /gravacoes/bi/bi
```

### Passo 3: Acessar na interface

Abra a aplicação no navegador. Você verá:
- **Lista de arquivos do servidor** (no topo)
- **Seleção de arquivos locais** (abaixo)

Clique em qualquer arquivo da lista do servidor para reproduzir.

## 📂 Estrutura de Diretórios

### Exemplo de organização:

```
/gravacoes/
├── bi/
│   ├── bi/
│   │   ├── gravacao1.guac
│   │   ├── gravacao2.guac
│   │   └── subdir/
│   │       └── gravacao3.guac
│   └── outros/
│       └── gravacao4.guac
└── outros/
    └── gravacao5.guac
```

Todos os arquivos `.guac` serão listados recursivamente.

## 🔧 Configuração Avançada

### Mapear múltiplos diretórios

Para mapear múltiplos diretórios, você pode:

1. **Usar links simbólicos**:
   ```bash
   sudo mkdir -p /gravacoes
   sudo ln -s /gravacoes/bi/bi /gravacoes/bi-bi
   sudo ln -s /outro/diretorio /gravacoes/outros
   sudo ./setup-recordings-dir.sh /gravacoes
   ```

2. **Configurar diretório base e organizar dentro**:
   ```bash
   sudo ./setup-recordings-dir.sh /gravacoes
   # Todos os subdiretórios serão listados automaticamente
   ```

### Alterar diretório após configuração

```bash
# 1. Parar serviço
sudo systemctl stop guacamole-list-files

# 2. Editar serviço
sudo systemctl edit guacamole-list-files

# 3. Adicionar override:
[Service]
ExecStart=
ExecStart=/usr/local/bin/list-files.py --port 8888 --dir /novo/diretorio

# 4. Recarregar e reiniciar
sudo systemctl daemon-reload
sudo systemctl restart guacamole-list-files
```

### Verificar status do serviço

```bash
# Status
sudo systemctl status guacamole-list-files

# Logs
sudo journalctl -u guacamole-list-files -f

# Reiniciar
sudo systemctl restart guacamole-list-files
```

## 🔍 Verificação

### Testar API diretamente

```bash
# Listar arquivos
curl http://localhost/api/list-files

# Com diretório específico
curl "http://localhost/api/list-files?dir=/gravacoes/bi/bi"
```

### Verificar no navegador

1. Abra a aplicação
2. Você deve ver a seção "Recordings from Server"
3. Os arquivos devem aparecer na lista

## 🛠️ Troubleshooting

### Arquivos não aparecem na lista

1. **Verificar se o serviço está rodando**:
   ```bash
   sudo systemctl status guacamole-list-files
   ```

2. **Verificar permissões do diretório**:
   ```bash
   ls -la /gravacoes/bi/bi
   # Deve ser acessível por www-data
   sudo chown -R www-data:www-data /gravacoes
   ```

3. **Verificar extensão dos arquivos**:
   - Apenas arquivos `.guac` e `.cast` são listados
   - Verifique se os arquivos têm a extensão correta

4. **Verificar logs**:
   ```bash
   sudo journalctl -u guacamole-list-files -n 50
   ```

### Erro 404 ao acessar API

1. **Verificar configuração do Nginx**:
   ```bash
   sudo nginx -t
   sudo grep -A 5 "location /api/list-files" /etc/nginx/sites-available/guacamole-player
   ```

2. **Verificar se o serviço está escutando**:
   ```bash
   sudo netstat -tlnp | grep 8888
   # ou
   sudo ss -tlnp | grep 8888
   ```

### Erro de permissão

```bash
# Ajustar permissões do diretório
sudo chown -R www-data:www-data /gravacoes
sudo chmod -R 755 /gravacoes

# Ajustar permissões do script
sudo chmod +x /usr/local/bin/list-files.py
sudo chown root:root /usr/local/bin/list-files.py
```

### Serviço não inicia

```bash
# Verificar logs detalhados
sudo journalctl -u guacamole-list-files -n 100 --no-pager

# Verificar se Python3 está instalado
python3 --version

# Testar script manualmente
sudo -u www-data /usr/local/bin/list-files.py --port 8888 --dir /gravacoes
```

## 📝 Arquivos e Localizações

- **Script de listagem**: `/usr/local/bin/list-files.py`
- **Serviço systemd**: `/etc/systemd/system/guacamole-list-files.service`
- **Configuração Nginx**: `/etc/nginx/sites-available/guacamole-player`
- **Diretório padrão**: `/gravacoes`
- **Porta do serviço**: `8888` (localhost apenas)

## 🔄 Atualizar após mudanças no código

Se você modificou o código e precisa recompilar:

```bash
# 1. Recompilar projeto
mvn clean package

# 2. Copiar novos arquivos
sudo cp -r target/apache-guacamole-player-1.1.0-1/* /var/www/guacamole-player/

# 3. Ajustar permissões
sudo chown -R www-data:www-data /var/www/guacamole-player

# 4. Recarregar Nginx
sudo systemctl reload nginx
```

## 🔐 Segurança

### Boas Práticas

1. **Restringir acesso ao diretório**:
   ```bash
   # Apenas www-data pode ler
   sudo chmod 750 /gravacoes
   sudo chown www-data:www-data /gravacoes
   ```

2. **Usar autenticação HTTP Basic** (já configurada):
   ```bash
   sudo ./setup-auth.sh --setup
   ```

3. **Limitar diretórios acessíveis**:
   - O script só lista arquivos dentro do diretório configurado
   - Não permite acesso a diretórios fora do mapeado

4. **Revisar permissões regularmente**:
   ```bash
   sudo find /gravacoes -type f ! -perm 644 -ls
   ```

## 📚 Referências

- [Nginx Proxy Pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Python HTTP Server](https://docs.python.org/3/library/http.server.html)
- [Systemd Service](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

---

**Documento criado para configuração de diretórios de gravações**


