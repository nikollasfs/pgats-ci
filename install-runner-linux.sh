#!/bin/bash
# Script de Instalação Automatizada - Self-Hosted Runner para GitHub Actions
# Uso: bash install-runner.sh <GITHUB_URL> <GITHUB_TOKEN> <RUNNER_NAME>

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validar argumentos
if [ $# -lt 3 ]; then
    print_error "Argumentos insuficientes!"
    echo "Uso: bash install-runner.sh <GITHUB_URL> <GITHUB_TOKEN> <RUNNER_NAME>"
    echo ""
    echo "Exemplo:"
    echo "  bash install-runner.sh https://github.com/seu-usuario/seu-repo ghp_1234567890 meu-runner"
    exit 1
fi

GITHUB_URL="$1"
GITHUB_TOKEN="$2"
RUNNER_NAME="$3"
RUNNER_DIR="${HOME}/actions-runner"
RUNNER_LABELS="self-hosted,linux,automation-tests"

# Início
print_header "Instalação do Self-Hosted Runner"
print_info "URL: $GITHUB_URL"
print_info "Nome: $RUNNER_NAME"
print_info "Diretório: $RUNNER_DIR"
print_info "Labels: $RUNNER_LABELS"
echo ""

# 1. Validar OS
print_header "1️⃣ Validar Sistema Operacional"
if [ "$(uname)" != "Linux" ]; then
    print_error "Este script é para Linux apenas"
    print_info "Para Windows/macOS, veja SELF-HOSTED-RUNNERS.md"
    exit 1
fi
print_success "Sistema: $(uname -s) $(uname -r)"

# 2. Instalar dependências
print_header "2️⃣ Instalar Dependências"

if ! command -v git &> /dev/null; then
    print_info "Instalando Git..."
    sudo apt update && sudo apt install -y git
    print_success "Git instalado"
else
    print_success "Git já instalado: $(git --version)"
fi

if ! command -v curl &> /dev/null; then
    print_info "Instalando curl..."
    sudo apt install -y curl
    print_success "curl instalado"
else
    print_success "curl já instalado"
fi

if ! command -v node &> /dev/null; then
    print_info "Instalando Node.js 24.x..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt install -y nodejs
    print_success "Node.js instalado: $(node --version)"
else
    print_success "Node.js já instalado: $(node --version)"
fi

if ! command -y yarn &> /dev/null; then
    print_info "Instalando Yarn..."
    sudo npm install -g yarn
    print_success "Yarn instalado: $(yarn --version)"
else
    print_success "Yarn já instalado: $(yarn --version)"
fi

# 3. Validar Conectividade
print_header "3️⃣ Validar Conectividade com GitHub"
if curl -s -I "https://api.github.com" | grep -q "200\|301"; then
    print_success "Conectado ao GitHub"
else
    print_error "Sem conexão com GitHub"
    exit 1
fi

# 4. Criar diretório
print_header "4️⃣ Preparar Diretório"
if [ -d "$RUNNER_DIR" ]; then
    print_warning "Diretório $RUNNER_DIR já existe"
    read -p "Deseja continuar? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    print_info "Criando diretório $RUNNER_DIR..."
    mkdir -p "$RUNNER_DIR"
    print_success "Diretório criado"
fi

cd "$RUNNER_DIR"

# 5. Download do Runner
print_header "5️⃣ Download do GitHub Actions Runner"
print_info "Obtendo versão mais recente..."

VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')
RUNNER_FILE="actions-runner-linux-x64-${VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${VERSION}/${RUNNER_FILE}"

print_info "Versão: v$VERSION"
print_info "Downloading: $RUNNER_FILE"

if [ -f "$RUNNER_FILE" ]; then
    print_warning "Arquivo já existe, pulando download"
else
    curl -L -o "$RUNNER_FILE" "$RUNNER_URL"
    if [ -f "$RUNNER_FILE" ]; then
        print_success "Download concluído"
    else
        print_error "Falha no download"
        exit 1
    fi
fi

# 6. Extrair arquivos
print_header "6️⃣ Extrair Arquivos"
print_info "Extraindo $RUNNER_FILE..."
tar xzf "$RUNNER_FILE"
print_success "Extração concluída"

# 7. Configurar Runner
print_header "7️⃣ Configurar Runner"
print_info "Registrando runner com GitHub..."
print_warning "Token expira em 1 hora - configure agora!"

./config.sh \
  --url "$GITHUB_URL" \
  --token "$GITHUB_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --replace \
  --unattended

print_success "Runner configurado"

# 8. Instalar como Serviço
print_header "8️⃣ Instalar como Serviço"
print_info "Instalando serviço systemd..."

sudo ./svc.sh install
print_success "Serviço instalado"

# 9. Iniciar Serviço
print_header "9️⃣ Iniciar Serviço"
print_info "Iniciando GitHub Actions Runner..."

sudo ./svc.sh start
sleep 2

if sudo ./svc.sh status | grep -q "active (running)"; then
    print_success "Serviço em execução"
else
    print_warning "Verificar status com: sudo systemctl status github-runner"
fi

# 10. Resumo
print_header "✅ Instalação Concluída"
echo ""
echo "📋 Próximos Passos:"
echo ""
echo "1. Verifique o runner no GitHub:"
echo "   Settings → Actions → Runners"
echo ""
echo "2. Veja os logs:"
echo "   sudo journalctl -u github-runner -f"
echo ""
echo "3. Teste a pipeline:"
echo "   GitHub → Actions → 'Testes em Self-Hosted Runner' → Run workflow"
echo ""
echo "4. Para gerenciar o serviço:"
echo "   sudo systemctl start/stop/restart github-runner"
echo "   sudo systemctl status github-runner"
echo ""
echo "5. Para desinstalar:"
echo "   cd $RUNNER_DIR"
echo "   sudo ./svc.sh stop"
echo "   sudo ./svc.sh uninstall"
echo ""
print_success "Runner pronto para uso!"
