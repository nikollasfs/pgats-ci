# 🖥️ Self-Hosted Runners/Agents - Análise e Implementação

## 📊 O Que São Self-Hosted Runners?

Um **self-hosted runner** é uma máquina que você configurar e gerenciar para executar workflows do GitHub Actions. Em vez de usar os servidores do GitHub (ubuntu-latest, windows-latest, etc.), você usa sua própria infraestrutura.

---

## 🎯 Quando Faz Sentido Usar?

### ✅ **Casos de Uso Ideais:**

| Cenário | Por Quê? | Exemplo |
|---------|---------|---------|
| **Testes de Integração Locais** | Acesso a BD local, serviços internos | Conectar à database em dev/staging |
| **Grande Volume de Testes** | Github-hosted é limitado (6 cores, 7GB RAM) | Mutation testing + E2E paralelo |
| **Dependências Específicas** | Hardware ou software customizado | GPU para testes, ou software proprietário |
| **Conformidade/Segurança** | Dados sensíveis não saem da rede | Testes em repositório privado com dados reais |
| **Redução de Custos** | Máquina já existe na empresa | Usar servidor interno ocioso |
| **Builds mais Rápidos** | Cache local, melhor hardware | Repositório com histórico grande |
| **Latência Crítica** | On-premises no mesmo datacenter | Deploy para produção local |

### ❌ **Quando NÃO Usar:**

| Cenário | Alternativa |
|---------|------------|
| Projeto pequeno/hobby | Github-hosted (gratuito) |
| Sem infra própria | Cloud runners (AWS, Azure, GCP) |
| Equipe sem ops | GitHub-hosted + cloud integrations |
| Segurança crítica | Máquinas dedicadas na cloud |

---

## 🔄 Comparação: Plataformas Similares

### **GitHub Actions (Self-Hosted)**
- ✅ Fácil integração com GitHub
- ✅ Gratuito (você paga a máquina)
- ✅ Controle total
- ❌ Você gerencia tudo
- 💰 Custo: Apenas infraestrutura

### **GitLab Runners**
- ✅ Alternativa melhor documentada
- ✅ Suporta Docker, Kubernetes
- ✅ Mais opções de autoscaling
- ✅ Integração nativa com GitLab
- 💰 Custo: Livre (self-hosted) ou pay-per-use (SaaS)

### **Jenkins Agents**
- ✅ Padrão da indústria
- ✅ Altamente customizável
- ✅ Masterful orchestration
- ❌ Curva de aprendizado alta
- 💰 Custo: Livre + infraestrutura

### **CircleCI Orbs**
- ✅ SaaS elegante
- ✅ Fácil setup
- ❌ Sem self-hosted (usa cloud deles)
- 💰 Custo: $15+/mês por projeto

### **Cloud Runners (AWS CodePipeline, Azure Pipelines)**
- ✅ Escala automática
- ✅ Sem gerenciar máquinas
- ✅ Pay-per-use
- ❌ Mais caro
- 💰 Custo: ~$0.70+ por job

---

## 🛠️ Arquivo: Workflow com Self-Hosted Runner

Crie este arquivo para usar o self-hosted runner:

**`.github/workflows/03-self-hosted-tests.yaml`**

```yaml
# CI Pipeline - Executada em Self-Hosted Runner
name: 'Testes em Self-Hosted Runner'

on:
  workflow_dispatch:
  # Descomente para executar em todo push
  # push:
  #   branches: [master, main]

permissions:
  contents: write
  checks: write
  pull-requests: write
  pages: write
  id-token: write

jobs:
  test-on-self-hosted:
    # Use a label do seu runner
    runs-on: [self-hosted, linux]  # Ajuste conforme sua máquina
    
    steps:
      - name: Validar Ambiente
        run: |
          echo "🖥️ Runner: $(hostname)"
          echo "📍 OS: $(uname -s)"
          echo "💾 Cores: $(nproc)"
          echo "📦 Node: $(node --version)"
          echo "🧶 Yarn: $(yarn --version)"
      
      - uses: actions/checkout@v4
      
      - name: Cache de Dependências
        uses: actions/cache@v3
        with:
          path: |
            node_modules
            .yarn-cache
          key: ${{ runner.os }}-yarn-${{ hashFiles('**/yarn.lock') }}
          restore-keys: |
            ${{ runner.os }}-yarn-
      
      - name: Instalar Dependências
        run: yarn install --prefer-offline
      
      - name: Testes Unitários
        run: yarn test -- --coverage
      
      - name: Testes de Mutação
        run: yarn test:mutation
      
      - name: Testes E2E
        run: yarn run e2e
      
      - name: Upload Artefatos
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: self-hosted-reports
          path: |
            coverage/
            reports/
            playwright-report/
          retention-days: 30
      
      - name: Publicar Resultados
        if: always()
        uses: EnricoMi/publish-unit-test-result-action@v2
        with:
          files: results.xml
          check_name: 📊 Testes Self-Hosted

  # Comparação: Runner GitHub vs Self-Hosted
  benchmark:
    runs-on: [self-hosted, linux]
    steps:
      - name: Medir Performance
        run: |
          echo "⏱️ Tempo de Execução Medido"
          echo "---"
          df -h | grep -E '(Filesystem|/$)'
          free -h | grep -E '(total|Mem:)'
```

---

## 📋 Passo 1: Preparar a Máquina

Você precisa de:
- **Linux**: Ubuntu 22.04+ ou Debian
- **Windows**: Windows Server 2019+ ou Windows 10+
- **macOS**: 10.13+
- **Requisitos**: Node.js, Git, Docker (opcional)

### Preparação - Linux (Ubuntu/Debian)

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y \
  curl \
  wget \
  git \
  build-essential \
  libssl-dev

# Instalar Node.js 24.x
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs

# Instalar Yarn
sudo npm install -g yarn

# Instalar Docker (opcional, para Playwright)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### Preparação - Windows

```powershell
# PowerShell como Admin
# Instalar Node.js (via chocolatey)
choco install nodejs yarn -y

# Ou manualmente:
# Download em https://nodejs.org/
# Depois: npm install -g yarn
```

---

## 📋 Passo 2: Registrar o Runner

### No GitHub - Na Página do Repositório:

1. **Settings** → **Actions** (sidebar) → **Runners**
2. **New self-hosted runner**
3. Selecione seu OS e arquitetura
4. Você vai receber instruções com um token

### Via Terminal (Linux/macOS)

```bash
# 1. Criar diretório
mkdir -p ~/actions-runner
cd ~/actions-runner

# 2. Download do runner (substitua VERSION)
VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')
curl -o actions-runner-linux-x64-${VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz

# 3. Extrair
tar xzf actions-runner-linux-x64-${VERSION}.tar.gz

# 4. Configurar (substitua os valores)
./config.sh \
  --url https://github.com/seu-usuario/seu-repo \
  --token SEU_TOKEN_AQUI \
  --name meu-runner \
  --labels linux,self-hosted,testes

# 5. Testar
./run.sh
```

### Via Terminal - Windows (PowerShell como Admin)

```powershell
# 1. Criar diretório
mkdir C:\actions-runner
cd C:\actions-runner

# 2. Download (substitua VERSION)
$LATEST = (Invoke-WebRequest 'https://api.github.com/repos/actions/runner/releases/latest').Content | ConvertFrom-Json
$VERSION = $LATEST.tag_name -replace 'v'
$URL = "https://github.com/actions/runner/releases/download/v$VERSION/actions-runner-win-x64-$VERSION.zip"
Invoke-WebRequest -Uri $URL -OutFile "runner-$VERSION.zip"

# 3. Extrair
Expand-Archive -Path "runner-$VERSION.zip" -DestinationPath .

# 4. Configurar
.\config.cmd `
  --url https://github.com/seu-usuario/seu-repo `
  --token SEU_TOKEN_AQUI `
  --name meu-runner `
  --labels windows,self-hosted

# 5. Instalar como Serviço
.\config.cmd --service install

# 6. Iniciar o serviço
Start-Service GitHub-Runner
```

---

## 📋 Passo 3: Executar o Runner_service

### Linux - Como Serviço

```bash
# Instalar como serviço do systemd
sudo /home/seu-usuario/actions-runner/svc.sh install

# Iniciar
sudo /home/seu-usuario/actions-runner/svc.sh start

# Ver status
sudo /home/seu-usuario/actions-runner/svc.sh status

# Logs
sudo journalctl -u github-runner -f

# Parar
sudo /home/seu-usuario/actions-runner/svc.sh stop
```

### Windows - Como Serviço

```powershell
# Já instalado no passo anterior
Get-Service GitHub-Runner

# Ver status
Get-Service GitHub-Runner | Select-Object Status, DisplayName

# Logs
Get-EventLog -LogName Application -Source GitHub-Runner -Newest 10
```

### macOS - Como Serviço (LaunchAgent)

```bash
# Instalar
~/actions-runner/svc.sh install

# Iniciar
~/actions-runner/svc.sh start

# Logs
log stream --predicate 'process == "Microsoft.VisualStudio.Services.GitHubRunner"'
```

---

## 📋 Passo 4: Validar no GitHub

Após iniciar o runner:

1. Vá para **Settings** → **Actions** → **Runners**
2. Procure seu runner na lista
3. Status deve ser **Idle** (em aguardo)
4. Label deve aparecer na lista

---

## 🧪 Teste a Pipeline

1. Vá para **Actions**
2. Clique em **"Testes em Self-Hosted Runner"**
3. **Run workflow** → **Run workflow**

Observe em "Runner" qual máquina executou (deve ser seu self-hosted runner).

---

## 📊 Monitoramento

### Ver Runners Registrados

```bash
# No repositório Settings → Actions → Runners
# Ou via API:
curl -H "Authorization: token SEU_TOKEN_GITHUB" \
  https://api.github.com/repos/seu-usuario/seu-repo/actions/runners
```

### Logs do Runner

```bash
# Linux
tail -f ~/actions-runner/_diag/Runner_*.log

# Windows
Get-Content "C:\actions-runner\_diag\Runner_*.log" -Tail 50

# Arquivo de trace
cat ~/actions-runner/_diag/Worker_*.log
```

### Performance

```bash
# Verificar recursos enquanto teste roda
# Linux
watch -n 1 'ps aux | grep runner'
free -h
df -h

# Windows
Get-Process | Where-Object {$_.ProcessName -like '*runner*'}
```

---

## 🔒 Segurança

### ⚠️ **Aviso Crítico:**
- **Nunca use self-hosted runners com repositórios públicos!**
- Um PR malicioso poderia executar código na sua máquina
- Se precisar usar público, isole em container/VM

### Boas Práticas

```yaml
# 1. Use labels para destinar jobs
runs-on: [self-hosted, linux, isolated]

# 2. Limite quem pode disparar
on:
  workflow_dispatch:
  push:
    branches: [master, main]  # Apenas branches protegidos

# 3. Use secrets para dados sensíveis
env:
  DATABASE_URL: ${{ secrets.DB_CONNECTION_STRING }}

# 4. Valide credenciais
- name: Validar Configuração
  run: |
    # Não exiba secrets em logs!
    if [ -z "${{ secrets.API_KEY }}" ]; then
      echo "❌ API_KEY não configurada"
      exit 1
    fi
    echo "✅ Secrets carregados"
```

---

## 🛠️ Troubleshooting

### "Unable to contact GitHub"
```bash
# Verifique conectividade
curl -v https://api.github.com

# Verifique firewall
sudo ufw status (Linux)
Get-NetFirewallProfile (Windows)
```

### "Token expirado"
```bash
# Gere novo token em Settings → Runners
./config.sh --reconfigure
```

### "Runner inativo/offline"
```bash
# Reinicie o serviço
sudo systemctl restart github-runner (Linux)
Restart-Service GitHub-Runner (Windows)

# Verifique logs
journalctl -u github-runner -n 50 (Linux)
```

### "Permissão negada a diretórios"
```bash
# Linux - Adicione usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Windows - Execute PowerShell como Admin
```

---

## 📈 Escalabilidade

Para múltiplos runners (parallelização):

```yaml
# Configurar vários labels
runs-on: [self-hosted, linux, testes-1]  # Runner 1
runs-on: [self-hosted, linux, testes-2]  # Runner 2

# Ou matriz
strategy:
  matrix:
    runner: [testes-1, testes-2]
jobs:
  test:
    runs-on: [self-hosted, linux, "${{ matrix.runner }}"]
```

---

## 📚 Referências

- [GitHub Docs - Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Runner Release Notes](https://github.com/actions/runner/releases)
- [Security Hardening](https://docs.github.com/en/actions/security-for-github-actions)

---

💜⚡️
