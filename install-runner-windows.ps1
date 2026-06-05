# Script de Instalação Automatizada - Self-Hosted Runner para GitHub Actions (Windows)
# Uso: powershell -ExecutionPolicy Bypass -File install-runner-windows.ps1 -GithubUrl <URL> -GithubToken <TOKEN> -RunnerName <NAME>

param(
    [Parameter(Mandatory=$true)]
    [string]$GithubUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$GithubToken,
    
    [Parameter(Mandatory=$true)]
    [string]$RunnerName,
    
    [string]$RunnerDir = "C:\actions-runner",
    [string]$RunnerLabels = "self-hosted,windows,automation-tests"
)

# Verificar se é Admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ Este script deve ser executado como Administrador!" -ForegroundColor Red
    exit 1
}

# Funções
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Message" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
}

# Início
Write-Header "Instalação do Self-Hosted Runner (Windows)"
Write-Info "URL: $GithubUrl"
Write-Info "Nome: $RunnerName"
Write-Info "Diretório: $RunnerDir"
Write-Info "Labels: $RunnerLabels"

# 1. Validar Windows
Write-Header "1️⃣ Validar Sistema Operacional"
$OSVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
Write-Success "Sistema: $OSVersion"

# 2. Validar Node.js
Write-Header "2️⃣ Validar Node.js"
if (-NOT (Test-Path "C:\Program Files\nodejs\node.exe")) {
    Write-Error-Custom "Node.js não encontrado"
    Write-Info "Download: https://nodejs.org/"
    exit 1
}
$NodeVersion = & node --version
Write-Success "Node.js instalado: $NodeVersion"

# 3. Validar Git
Write-Header "3️⃣ Validar Git"
if (-NOT (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "Git não encontrado"
    Write-Info "Download: https://git-scm.com/download/win"
    exit 1
}
$GitVersion = & git --version
Write-Success "Git instalado: $GitVersion"

# 4. Testar Conectividade
Write-Header "4️⃣ Testar Conectividade com GitHub"
try {
    $response = Invoke-WebRequest -Uri "https://api.github.com" -UseBasicParsing -TimeoutSec 5
    Write-Success "Conectado ao GitHub"
} catch {
    Write-Error-Custom "Sem conexão com GitHub"
    exit 1
}

# 5. Criar diretório
Write-Header "5️⃣ Preparar Diretório"
if (Test-Path $RunnerDir) {
    Write-Warning-Custom "Diretório $RunnerDir já existe"
    $response = Read-Host "Deseja continuar? (s/n)"
    if ($response -ne "s" -and $response -ne "S") {
        exit 1
    }
} else {
    Write-Info "Criando diretório $RunnerDir..."
    New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
    Write-Success "Diretório criado"
}

Set-Location $RunnerDir

# 6. Download do Runner
Write-Header "6️⃣ Download do GitHub Actions Runner"
Write-Info "Obtendo versão mais recente..."

$LatestRelease = Invoke-WebRequest -Uri "https://api.github.com/repos/actions/runner/releases/latest" -UseBasicParsing | ConvertFrom-Json
$Version = $LatestRelease.tag_name -replace 'v'
$RunnerFile = "actions-runner-win-x64-$Version.zip"
$DownloadUrl = "https://github.com/actions/runner/releases/download/v$Version/$RunnerFile"

Write-Info "Versão: v$Version"
Write-Info "Download: $RunnerFile"

if (Test-Path $RunnerFile) {
    Write-Warning-Custom "Arquivo já existe"
} else {
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $RunnerFile -UseBasicParsing
        Write-Success "Download concluído"
    } catch {
        Write-Error-Custom "Falha no download: $_"
        exit 1
    }
}

# 7. Extrair arquivos
Write-Header "7️⃣ Extrair Arquivos"
Write-Info "Extraindo $RunnerFile..."
try {
    Expand-Archive -Path $RunnerFile -DestinationPath . -Force
    Write-Success "Extração concluída"
} catch {
    Write-Error-Custom "Falha na extração: $_"
    exit 1
}

# 8. Configurar Runner
Write-Header "8️⃣ Configurar Runner"
Write-Info "Registrando runner com GitHub..."
Write-Warning-Custom "Token expira em 1 hora - configure agora!"

& ".\config.cmd" `
    --url $GithubUrl `
    --token $GithubToken `
    --name $RunnerName `
    --labels $RunnerLabels `
    --replace `
    --runnergroup Default `
    --unattended

Write-Success "Runner configurado"

# 9. Instalar como Serviço
Write-Header "9️⃣ Instalar como Serviço"
Write-Info "Instalando serviço Windows..."

& ".\config.cmd" --service install

Write-Success "Serviço instalado"

# 10. Iniciar Serviço
Write-Header "🔟 Iniciar Serviço"
Write-Info "Iniciando GitHub Actions Runner..."

Start-Service GitHub-Runner
Start-Sleep -Seconds 2

$Service = Get-Service GitHub-Runner -ErrorAction SilentlyContinue
if ($Service.Status -eq "Running") {
    Write-Success "Serviço em execução"
} else {
    Write-Warning-Custom "Verificar status com: Get-Service GitHub-Runner"
}

# Resumo
Write-Header "✅ Instalação Concluída"
Write-Host ""
Write-Host "📋 Próximos Passos:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Verifique o runner no GitHub:"
Write-Host "   Settings → Actions → Runners"
Write-Host ""
Write-Host "2. Veja os logs do Event Viewer:"
Write-Host "   Event Viewer → Windows Logs → Application"
Write-Host "   Filtro: Source = GitHub-Runner"
Write-Host ""
Write-Host "3. Teste a pipeline:"
Write-Host "   GitHub → Actions → 'Testes em Self-Hosted Runner' → Run workflow"
Write-Host ""
Write-Host "4. Para gerenciar o serviço:"
Write-Host "   Start-Service GitHub-Runner"
Write-Host "   Stop-Service GitHub-Runner"
Write-Host "   Get-Service GitHub-Runner"
Write-Host ""
Write-Host "5. Para desinstalar:"
Write-Host "   cd $RunnerDir"
Write-Host "   .\config.cmd remove --token <TOKEN>"
Write-Host ""
Write-Success "Runner pronto para uso!"
