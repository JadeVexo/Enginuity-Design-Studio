#Requires -Version 5.1
<#
.SYNOPSIS
    Enginuity Design Studio Installer
.DESCRIPTION
    Downloads and installs Enginuity Design Studio from GitHub releases
.PARAMETER Version
    Specific version to install (default: latest)
.PARAMETER InstallPath
    Custom installation path (default: $env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio)
.EXAMPLE
    irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1 | iex
#>

param(
    [string]$Version = "latest",
    [string]$InstallPath = "$env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio"
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$GITHUB_REPO = "JadeVexo/Enginuity-Design-Studio"
$PRODUCT_NAME = "Enginuity Design Studio"
$COMPANY_NAME = "Enginuity Labs"

# Colors for output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n▶ $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

# Banner
Clear-Host
Write-ColorOutput @"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║       Enginuity Design Studio Installer           ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
"@ "Cyan"

# Check if running as admin (warn but don't require)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-ColorOutput "⚠ Warning: Running as Administrator. Installation will proceed in user context." "Yellow"
}

# Validate installation path
Write-Step "Validating installation path..."
if ($InstallPath -like "*Program Files*") {
    Write-Error "Cannot install in Program Files. Using default location."
    $InstallPath = "$env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio"
}
Write-ColorOutput "Installation path: $InstallPath" "Gray"

# Check for existing installation
if (Test-Path $InstallPath) {
    Write-ColorOutput "`n⚠ Existing installation found at: $InstallPath" "Yellow"
    $response = Read-Host "Do you want to upgrade/reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-ColorOutput "Installation cancelled." "Yellow"
        exit 0
    }
    
    Write-Step "Stopping running processes..."
    Get-Process -Name "enginuity_launcher","enginuity_local_server","enginuity_design_studio" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Get download URL
Write-Step "Fetching latest release information..."
try {
    if ($Version -eq "latest") {
        $releaseUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    } else {
        $releaseUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$Version"
    }
    
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{
        "User-Agent" = "EnginuityInstaller/1.0"
    }
    
    $asset = $release.assets | Where-Object { $_.name -like "*Deploy*.zip" } | Select-Object -First 1
    
    if (-not $asset) {
        throw "No deployment package found in release"
    }
    
    $downloadUrl = $asset.browser_download_url
    $version = $release.tag_name
    
    Write-Success "Found version: $version"
    Write-ColorOutput "Package: $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)" "Gray"
    
} catch {
    Write-Error "Failed to fetch release information: $_"
    exit 1
}

# Create temporary directory
$tempDir = Join-Path $env:TEMP "enginuity_install_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Success "Created temporary directory"

try {
    # Download package
    Write-Step "Downloading $PRODUCT_NAME..."
    $zipPath = Join-Path $tempDir "enginuity_deploy.zip"
    
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "EnginuityInstaller/1.0")
    
    # Progress tracking
    Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged -Action {
        Write-Progress -Activity "Downloading" -Status "$($EventArgs.ProgressPercentage)% complete" -PercentComplete $EventArgs.ProgressPercentage
    } | Out-Null
    
    $webClient.DownloadFile($downloadUrl, $zipPath)
    Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged -ErrorAction SilentlyContinue
    Write-Progress -Activity "Downloading" -Completed
    
    Write-Success "Download completed"
    
    # Extract package
    Write-Step "Extracting package..."
    $extractPath = Join-Path $tempDir "extracted"
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    
    # Find the deploy directory
    $deployDir = Get-ChildItem -Path $extractPath -Filter "Enginuity_Deploy_*" -Directory | Select-Object -First 1
    if (-not $deployDir) {
        throw "Deploy directory not found in package"
    }
    
    Write-Success "Package extracted"
    
    # Create installation directories
    Write-Step "Creating installation directories..."
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$InstallPath\logs\launcher_logs" -Force | Out-Null
    New-Item -ItemType Directory -Path "$InstallPath\logs\server_logs" -Force | Out-Null
    New-Item -ItemType Directory -Path "$InstallPath\logs\app_logs" -Force | Out-Null
    Write-Success "Directories created"
    
    # Copy files
    Write-Step "Installing files..."
    
    # Launcher
    Copy-Item -Path "$($deployDir.FullName)\enginuity_launcher.exe" -Destination $InstallPath -Force
    
    # Server
    $serverPath = "$InstallPath\server"
    New-Item -ItemType Directory -Path $serverPath -Force | Out-Null
    Copy-Item -Path "$($deployDir.FullName)\server\enginuity_local_server.exe" -Destination $serverPath -Force
    
    # Flutter app
    $appPath = "$InstallPath\enginuity_design_studio"
    if (Test-Path $appPath) {
        Remove-Item -Path $appPath -Recurse -Force
    }
    Copy-Item -Path "$($deployDir.FullName)\enginuity_design_studio" -Destination $InstallPath -Recurse -Force
    
    Write-Success "Files installed"
    
    # Create shortcuts
    Write-Step "Creating shortcuts..."
    
    $WshShell = New-Object -ComObject WScript.Shell
    
    # Start Menu
    $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$PRODUCT_NAME"
    New-Item -ItemType Directory -Path $startMenuPath -Force | Out-Null
    
    $shortcut = $WshShell.CreateShortcut("$startMenuPath\$PRODUCT_NAME.lnk")
    $shortcut.TargetPath = "$InstallPath\enginuity_launcher.exe"
    $shortcut.WorkingDirectory = $InstallPath
    $shortcut.Description = $PRODUCT_NAME
    $shortcut.Save()
    
    # Desktop
    $shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\$PRODUCT_NAME.lnk")
    $shortcut.TargetPath = "$InstallPath\enginuity_launcher.exe"
    $shortcut.WorkingDirectory = $InstallPath
    $shortcut.Description = $PRODUCT_NAME
    $shortcut.Save()
    
    Write-Success "Shortcuts created"
    
    # Registry entries
    Write-Step "Registering application..."
    
    $regPath = "HKCU:\Software\$COMPANY_NAME\$PRODUCT_NAME"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "InstallDir" -Value $InstallPath
    Set-ItemProperty -Path $regPath -Name "Version" -Value $version
    
    # Uninstall registry
    $uninstallPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EnginuityDesignStudio"
    New-Item -Path $uninstallPath -Force | Out-Null
    Set-ItemProperty -Path $uninstallPath -Name "DisplayName" -Value $PRODUCT_NAME
    Set-ItemProperty -Path $uninstallPath -Name "DisplayVersion" -Value $version
    Set-ItemProperty -Path $uninstallPath -Name "Publisher" -Value $COMPANY_NAME
    Set-ItemProperty -Path $uninstallPath -Name "InstallLocation" -Value $InstallPath
    Set-ItemProperty -Path $uninstallPath -Name "UninstallString" -Value "powershell -ExecutionPolicy Bypass -File `"$InstallPath\uninstall.ps1`""
    Set-ItemProperty -Path $uninstallPath -Name "DisplayIcon" -Value "$InstallPath\enginuity_launcher.exe,0"
    
    Write-Success "Application registered"
    
    # Create uninstaller script
    Write-Step "Creating uninstaller..."
    $uninstallScript = @"
# Enginuity Design Studio Uninstaller
`$ErrorActionPreference = "Stop"

Write-Host "Uninstalling $PRODUCT_NAME..." -ForegroundColor Cyan

# Stop processes
Get-Process -Name "enginuity_launcher","enginuity_local_server","enginuity_design_studio" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Remove files
Remove-Item -Path "$InstallPath\enginuity_design_studio" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$InstallPath\server" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$InstallPath\enginuity_launcher.exe" -Force -ErrorAction SilentlyContinue

`$response = Read-Host "Remove log files? (y/N)"
if (`$response -eq 'y' -or `$response -eq 'Y') {
    Remove-Item -Path "$InstallPath\logs" -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove shortcuts
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$PRODUCT_NAME" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\Desktop\$PRODUCT_NAME.lnk" -Force -ErrorAction SilentlyContinue

# Remove registry
Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EnginuityDesignStudio" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKCU:\Software\$COMPANY_NAME\$PRODUCT_NAME" -Recurse -Force -ErrorAction SilentlyContinue

# Remove installation directory
Remove-Item -Path "$InstallPath" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✓ Uninstallation completed!" -ForegroundColor Green
"@
    
    Set-Content -Path "$InstallPath\uninstall.ps1" -Value $uninstallScript
    Write-Success "Uninstaller created"
    
} catch {
    Write-Error "Installation failed: $_"
    exit 1
} finally {
    # Cleanup
    Write-Step "Cleaning up..."
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Cleanup completed"
}

# Success message
Write-ColorOutput @"

╔═══════════════════════════════════════════════════╗
║                                                   ║
║     ✓ Installation Completed Successfully!        ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

"@ "Green"

Write-ColorOutput "Installed to: $InstallPath" "Gray"
Write-ColorOutput "Version: $version" "Gray"

$response = Read-Host "`nLaunch $PRODUCT_NAME now? (Y/n)"
if ($response -ne 'n' -and $response -ne 'N') {
    Start-Process "$InstallPath\enginuity_launcher.exe"
}