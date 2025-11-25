# 🔐 Configuração de Autenticação HTTP Basic

Este guia explica como configurar autenticação HTTP Basic para proteger o Guacamole Recording Player.

## 📋 Visão Geral

A autenticação HTTP Basic é uma camada de segurança simples e eficaz que:
- ✅ Protege toda a aplicação com login e senha
- ✅ Não requer mudanças no código da aplicação
- ✅ Funciona com qualquer navegador
- ✅ Fácil de configurar e gerenciar

## 🚀 Configuração Rápida

### Passo 1: Configurar autenticação pela primeira vez

Execute o script de configuração:

```bash
sudo ./setup-auth.sh --setup
```

O script irá:
1. Instalar `apache2-utils` (se necessário)
2. Solicitar nome de usuário e senha
3. Criar arquivo de senhas em `/etc/nginx/.htpasswd`
4. Atualizar configuração do Nginx
5. Reiniciar o Nginx

**Exemplo:**
```bash
$ sudo ./setup-auth.sh --setup
[INFO] Configurando autenticação HTTP Basic...
[INFO] Vamos criar o primeiro usuário para autenticação.
Digite o nome de usuário: admin
Digite a senha: ********
Confirme a senha: ********
[INFO] Usuário 'admin' criado com sucesso!
[INFO] Atualizando configuração do Nginx...
[INFO] Configuração do Nginx válida!
[INFO] Nginx reiniciado com sucesso!
[INFO] Autenticação configurada com sucesso!
```

### Passo 2: Testar autenticação

Abra o navegador e acesse a aplicação. Você verá uma janela de login solicitando usuário e senha.

## 👥 Gerenciamento de Usuários

### Adicionar novo usuário

```bash
sudo ./setup-auth.sh --add
```

Ou especificar o usuário diretamente:
```bash
sudo ./setup-auth.sh --add usuario
```

### Remover usuário

```bash
sudo ./setup-auth.sh --remove usuario
```

### Listar todos os usuários

```bash
sudo ./setup-auth.sh --list
```

### Alterar senha de usuário existente

```bash
sudo ./setup-auth.sh --add usuario
# Quando perguntar se deseja alterar a senha, responda 's'
```

## 🔧 Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `--setup` | Configurar autenticação pela primeira vez |
| `--add [user]` | Adicionar ou atualizar usuário |
| `--remove [user]` | Remover usuário |
| `--list` | Listar todos os usuários |
| `--update-nginx` | Atualizar configuração do Nginx |
| `--remove-auth` | Remover autenticação |
| `--help` | Mostrar ajuda |

## 📝 Exemplos Práticos

### Exemplo 1: Configuração inicial completa

```bash
# 1. Configurar primeiro usuário (admin)
sudo ./setup-auth.sh --setup

# 2. Adicionar usuários adicionais
sudo ./setup-auth.sh --add usuario1
sudo ./setup-auth.sh --add usuario2

# 3. Verificar usuários
sudo ./setup-auth.sh --list
```

### Exemplo 2: Gerenciar múltiplos usuários

```bash
# Adicionar vários usuários
sudo ./setup-auth.sh --add admin
sudo ./setup-auth.sh --add operador
sudo ./setup-auth.sh --add visualizador

# Remover usuário
sudo ./setup-auth.sh --remove visualizador

# Alterar senha
sudo ./setup-auth.sh --add admin  # Escolha 's' quando perguntar
```

### Exemplo 3: Remover autenticação temporariamente

```bash
# Remover autenticação
sudo ./setup-auth.sh --remove-auth

# Reativar autenticação (sem criar novos usuários)
sudo ./setup-auth.sh --update-nginx
```

## 🔍 Localização dos Arquivos

- **Arquivo de senhas**: `/etc/nginx/.htpasswd`
- **Backup de senhas**: `/etc/nginx/.htpasswd.backup.*`
- **Configuração Nginx**: `/etc/nginx/sites-available/guacamole-player`
- **Backup configuração**: `/etc/nginx/sites-available/guacamole-player.backup.*`

## 🛡️ Segurança

### Boas Práticas

1. **Use senhas fortes**:
   - Mínimo de 8 caracteres
   - Combine letras, números e símbolos
   - Evite palavras comuns

2. **Proteja o arquivo de senhas**:
   ```bash
   # O arquivo já tem permissões corretas (644, root:www-data)
   ls -la /etc/nginx/.htpasswd
   ```

3. **Remova usuários não utilizados**:
   ```bash
   sudo ./setup-auth.sh --remove usuario_antigo
   ```

4. **Faça backup regular**:
   ```bash
   sudo cp /etc/nginx/.htpasswd /backup/htpasswd-$(date +%Y%m%d)
   ```

### Limitações da Autenticação HTTP Basic

- ⚠️ As credenciais são enviadas em Base64 (não criptografadas)
- ⚠️ Recomendado usar HTTPS em produção
- ⚠️ Não há proteção contra força bruta nativa

**Recomendação**: Para produção, combine com HTTPS (SSL/TLS).

## 🔄 Integração com Script de Instalação

O script `install-debian.sh` pode ser atualizado para incluir autenticação automaticamente. Por enquanto, configure manualmente após a instalação:

```bash
# 1. Instalar aplicação
sudo ./install-debian.sh

# 2. Configurar autenticação
sudo ./setup-auth.sh --setup
```

## 🐛 Troubleshooting

### Erro: "htpasswd: command not found"

```bash
sudo apt install -y apache2-utils
```

### Erro: "auth_basic_user_file: file not found"

Verifique se o arquivo de senhas existe:
```bash
ls -la /etc/nginx/.htpasswd
```

Se não existir, crie primeiro:
```bash
sudo ./setup-auth.sh --setup
```

### Autenticação não funciona após configuração

1. Verificar configuração do Nginx:
   ```bash
   sudo nginx -t
   ```

2. Verificar se autenticação está no arquivo:
   ```bash
   sudo grep -A 2 "auth_basic" /etc/nginx/sites-available/guacamole-player
   ```

3. Reiniciar Nginx:
   ```bash
   sudo systemctl restart nginx
   ```

4. Verificar logs:
   ```bash
   sudo tail -f /var/log/nginx/guacamole-player-error.log
   ```

### Esqueci a senha de um usuário

Remova e recrie o usuário:
```bash
sudo ./setup-auth.sh --remove usuario
sudo ./setup-auth.sh --add usuario
```

### Restaurar backup

Se você fez backup do arquivo de senhas:
```bash
sudo cp /etc/nginx/.htpasswd.backup.YYYYMMDD_HHMMSS /etc/nginx/.htpasswd
sudo systemctl reload nginx
```

## 📚 Referências

- [Nginx HTTP Basic Authentication](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html)
- [Apache htpasswd Documentation](https://httpd.apache.org/docs/2.4/programs/htpasswd.html)

---

**Documento criado para configuração de autenticação no Guacamole Recording Player**


