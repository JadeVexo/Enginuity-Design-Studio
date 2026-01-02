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
.PARAMETER Action
    Action to perform: install, update, repair, uninstall (default: menu)
.EXAMPLE
    irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1 | iex
.EXAMPLE
    irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1 | iex -Action install
#>

param(
    [string]$Version = "latest",
    [string]$InstallPath = "$env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio",
    [ValidateSet("menu", "install", "update", "repair", "uninstall")]
    [string]$Action = "menu"
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = 'Continue'

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

function Write-ErrorMsg {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

# Banner
function Show-Banner {
    Clear-Host
    Write-ColorOutput @"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║       Enginuity Design Studio Installer           ║
║                  v1.0.0                           ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
"@ "Cyan"
}

# Main Menu
function Show-Menu {
    param([bool]$IsInstalled = $false)
    
    Show-Banner
    
    if ($IsInstalled) {
        $installedVersion = Get-InstalledVersion
        Write-ColorOutput "`n📦 Status: Installed (Version: $installedVersion)" "Green"
    } else {
        Write-ColorOutput "`n📦 Status: Not Installed" "Yellow"
    }
    
    Write-ColorOutput "`n═══════════════════════════════════════════════════" "Gray"
    Write-ColorOutput "  Please select an option:" "White"
    Write-ColorOutput "═══════════════════════════════════════════════════" "Gray"
    
    if (-not $IsInstalled) {
        Write-ColorOutput "  [1] Install Enginuity Design Studio" "Cyan"
        Write-ColorOutput "  [2] Exit" "Gray"
    } else {
        Write-ColorOutput "  [1] Update to Latest Version" "Cyan"
        Write-ColorOutput "  [2] Repair Installation" "Yellow"
        Write-ColorOutput "  [3] Uninstall" "Red"
        Write-ColorOutput "  [4] Exit" "Gray"
    }
    
    Write-ColorOutput "═══════════════════════════════════════════════════`n" "Gray"
    
    $choice = Read-Host "Enter your choice"
    
    if (-not $IsInstalled) {
        switch ($choice) {
            "1" { return "install" }
            "2" { exit 0 }
            default { 
                Write-ColorOutput "`n⚠ Invalid choice. Please try again." "Red"
                Start-Sleep -Seconds 2
                return Show-Menu -IsInstalled $IsInstalled
            }
        }
    } else {
        switch ($choice) {
            "1" { return "update" }
            "2" { return "repair" }
            "3" { return "uninstall" }
            "4" { exit 0 }
            default { 
                Write-ColorOutput "`n⚠ Invalid choice. Please try again." "Red"
                Start-Sleep -Seconds 2
                return Show-Menu -IsInstalled $IsInstalled
            }
        }
    }
}

# Check if already installed
function Test-Installation {
    return Test-Path $InstallPath
}

# Get installed version
function Get-InstalledVersion {
    try {
        $regPath = "HKCU:\Software\$COMPANY_NAME\$PRODUCT_NAME"
        if (Test-Path $regPath) {
            $version = Get-ItemProperty -Path $regPath -Name "Version" -ErrorAction SilentlyContinue
            if ($version) {
                return $version.Version
            }
        }
        return "Unknown"
    } catch {
        return "Unknown"
    }
}

# Get latest release info
function Get-ReleaseInfo {
    param([string]$TargetVersion = "latest")
    
    Write-Step "Fetching release information from GitHub..."
    try {
        if ($TargetVersion -eq "latest") {
            $releaseUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        } else {
            $releaseUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$TargetVersion"
        }
        
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{
            "User-Agent" = "EnginuityInstaller/1.0"
        }
        
        $asset = $release.assets | Where-Object { $_.name -like "*Deploy*.zip" } | Select-Object -First 1
        
        if (-not $asset) {
            throw "No deployment package found in release"
        }
        
        Write-Success "Found version: $($release.tag_name)"
        Write-ColorOutput "Package: $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)" "Gray"
        
        return @{
            Version = $release.tag_name
            DownloadUrl = $asset.browser_download_url
            FileName = $asset.name
            Size = $asset.size
        }
        
    } catch {
        Write-ErrorMsg "Failed to fetch release information: $_"
        throw
    }
}

# Download with progress bar
function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$FileName
    )
    
    Write-Step "Downloading $FileName..."
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "EnginuityInstaller/1.0")
        
        # Register progress event
        $progressId = Get-Random
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier "WebClient.Progress.$progressId" -Action {
            $percent = $EventArgs.ProgressPercentage
            $received = [math]::Round($EventArgs.BytesReceived / 1MB, 2)
            $total = [math]::Round($EventArgs.TotalBytesToReceive / 1MB, 2)
            
            Write-Progress -Activity "Downloading $using:FileName" `
                           -Status "$received MB / $total MB" `
                           -PercentComplete $percent `
                           -Id $using:progressId
        } | Out-Null
        
        # Download the file
        $webClient.DownloadFile($Url, $Destination)
        
        # Clean up
        Unregister-Event -SourceIdentifier "WebClient.Progress.$progressId" -ErrorAction SilentlyContinue
        Write-Progress -Activity "Downloading $FileName" -Completed -Id $progressId
        
        $webClient.Dispose()
        
        Write-Success "Download completed"
        
    } catch {
        Write-ErrorMsg "Download failed: $_"
        throw
    }
}

# Stop running processes
function Stop-EnginuityProcesses {
    Write-Step "Stopping running processes..."
    $processes = @("enginuity_launcher", "enginuity_local_server", "enginuity_design_studio")
    
    foreach ($proc in $processes) {
        $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($running) {
            Write-ColorOutput "  Stopping $proc..." "Gray"
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        }
    }
    
    Start-Sleep -Seconds 2
    Write-Success "Processes stopped"
}

# Install/Update/Repair function
function Install-Enginuity {
    param(
        [string]$Mode = "install"  # install, update, repair
    )
    
    Show-Banner
    
    # Check if running as admin (warn but don't require)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-ColorOutput "`n⚠ Warning: Running as Administrator. Installation will proceed in user context." "Yellow"
    }
    
    # Validate installation path
    Write-Step "Validating installation path..."
    if ($InstallPath -like "*Program Files*") {
        Write-ErrorMsg "Cannot install in Program Files. Using default location."
        $InstallPath = "$env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio"
    }
    Write-ColorOutput "Installation path: $InstallPath" "Gray"
    
    # Check for existing installation
    if ((Test-Path $InstallPath) -and $Mode -eq "install") {
        Write-ColorOutput "`n⚠ Existing installation found at: $InstallPath" "Yellow"
        $response = Read-Host "Do you want to upgrade? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-ColorOutput "Installation cancelled." "Yellow"
            return
        }
        $Mode = "update"
    }
    
    # Stop processes if updating/repairing
    if ($Mode -ne "install") {
        Stop-EnginuityProcesses
    }
    
    # Get release info
    $releaseInfo = Get-ReleaseInfo -TargetVersion $Version
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "enginuity_install_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    try {
        # Download package
        $zipPath = Join-Path $tempDir "enginuity_deploy.zip"
        Download-File -Url $releaseInfo.DownloadUrl -Destination $zipPath -FileName $releaseInfo.FileName
        
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
        Set-ItemProperty -Path $regPath -Name "Version" -Value $releaseInfo.Version
        
        # Uninstall registry
        $uninstallPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EnginuityDesignStudio"
        New-Item -Path $uninstallPath -Force | Out-Null
        Set-ItemProperty -Path $uninstallPath -Name "DisplayName" -Value $PRODUCT_NAME
        Set-ItemProperty -Path $uninstallPath -Name "DisplayVersion" -Value $releaseInfo.Version
        Set-ItemProperty -Path $uninstallPath -Name "Publisher" -Value $COMPANY_NAME
        Set-ItemProperty -Path $uninstallPath -Name "InstallLocation" -Value $InstallPath
        Set-ItemProperty -Path $uninstallPath -Name "UninstallString" -Value "powershell -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/$GITHUB_REPO/main/install.ps1 | iex -Action uninstall`""
        Set-ItemProperty -Path $uninstallPath -Name "DisplayIcon" -Value "$InstallPath\enginuity_launcher.exe,0"
        
        Write-Success "Application registered"
        
        # Create uninstaller script (kept for backward compatibility)
        $uninstallScript = @"
# Enginuity Design Studio Uninstaller
# You can also run: irm https://raw.githubusercontent.com/$GITHUB_REPO/main/install.ps1 | iex -Action uninstall

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
        
    } catch {
        Write-ErrorMsg "Installation failed: $_"
        Read-Host "`nPress Enter to exit"
        exit 1
    } finally {
        # Cleanup
        Write-Step "Cleaning up..."
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Cleanup completed"
    }
    
    # Success message
    $modeText = switch ($Mode) {
        "install" { "Installation" }
        "update" { "Update" }
        "repair" { "Repair" }
    }
    
    Write-ColorOutput @"

╔═══════════════════════════════════════════════════╗
║                                                   ║
║     ✓ $modeText Completed Successfully!           ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

"@ "Green"
    
    Write-ColorOutput "Installed to: $InstallPath" "Gray"
    Write-ColorOutput "Version: $($releaseInfo.Version)" "Gray"
    
    $response = Read-Host "`nLaunch $PRODUCT_NAME now? (Y/n)"
    if ($response -ne 'n' -and $response -ne 'N') {
        Start-Process "$InstallPath\enginuity_launcher.exe"
    }
}

# Uninstall function
function Uninstall-Enginuity {
    Show-Banner
    
    if (-not (Test-Path $InstallPath)) {
        Write-ColorOutput "`n⚠ Enginuity Design Studio is not installed." "Yellow"
        Read-Host "`nPress Enter to exit"
        return
    }
    
    Write-ColorOutput "`n⚠ WARNING: This will remove Enginuity Design Studio from your system." "Yellow"
    Write-ColorOutput "Installation path: $InstallPath`n" "Gray"
    
    $confirm = Read-Host "Are you sure you want to uninstall? (yes/no)"
    if ($confirm -ne "yes") {
        Write-ColorOutput "`nUninstallation cancelled." "Yellow"
        return
    }
    
    try {
        # Stop processes
        Stop-EnginuityProcesses
        
        # Remove files
        Write-Step "Removing application files..."
        Remove-Item -Path "$InstallPath\enginuity_design_studio" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$InstallPath\server" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$InstallPath\enginuity_launcher.exe" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$InstallPath\uninstall.ps1" -Force -ErrorAction SilentlyContinue
        
        # Ask about logs
        $response = Read-Host "`nRemove log files? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Remove-Item -Path "$InstallPath\logs" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Success "Files removed"
        
        # Remove shortcuts
        Write-Step "Removing shortcuts..."
        Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$PRODUCT_NAME" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:USERPROFILE\Desktop\$PRODUCT_NAME.lnk" -Force -ErrorAction SilentlyContinue
        Write-Success "Shortcuts removed"
        
        # Remove registry
        Write-Step "Removing registry entries..."
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EnginuityDesignStudio" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\$COMPANY_NAME\$PRODUCT_NAME" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKCU:\Software\$COMPANY_NAME" -Force -ErrorAction SilentlyContinue
        Write-Success "Registry cleaned"
        
        # Remove installation directory
        Remove-Item -Path "$InstallPath" -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-ColorOutput @"

╔═══════════════════════════════════════════════════╗
║                                                   ║
║     ✓ Uninstallation Completed Successfully!      ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

"@ "Green"
        
        Write-ColorOutput "Thank you for using Enginuity Design Studio!" "Cyan"
        
    } catch {
        Write-ErrorMsg "Uninstallation failed: $_"
        Read-Host "`nPress Enter to exit"
        exit 1
    }
    
    Read-Host "`nPress Enter to exit"
}

# Main execution
try {
    # If action is specified via parameter, skip menu
    if ($Action -ne "menu") {
        switch ($Action) {
            "install" { Install-Enginuity -Mode "install" }
            "update" { Install-Enginuity -Mode "update" }
            "repair" { Install-Enginuity -Mode "repair" }
            "uninstall" { Uninstall-Enginuity }
        }
    } else {
        # Show menu
        $isInstalled = Test-Installation
        $selectedAction = Show-Menu -IsInstalled $isInstalled
        
        switch ($selectedAction) {
            "install" { Install-Enginuity -Mode "install" }
            "update" { Install-Enginuity -Mode "update" }
            "repair" { Install-Enginuity -Mode "repair" }
            "uninstall" { Uninstall-Enginuity }
        }
    }
} catch {
    Write-ErrorMsg "`nAn unexpected error occurred: $_"
    Read-Host "`nPress Enter to exit"
    exit 1
}