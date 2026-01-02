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
║       Enginuity Design Studio Installer          ║
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
            "2" { return "exit" }
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
            "4" { return "exit" }
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
function Get-FileWithProgress {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$FileName
    )
    
    Write-Step "Downloading $FileName..."
    
    try {
        # Create a custom progress handler
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.UserAgent = "EnginuityInstaller/1.0"
        $request.Method = "GET"
        
        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        
        $fileStream = [System.IO.File]::Create($Destination)
        $buffer = New-Object byte[] 8192
        $totalBytesRead = 0
        $readCount = 0
        $lastUpdate = [DateTime]::Now
        $startTime = [DateTime]::Now
        
        do {
            $readCount = $responseStream.Read($buffer, 0, $buffer.Length)
            $fileStream.Write($buffer, 0, $readCount)
            $totalBytesRead += $readCount
            
            # Update progress every 200ms to reduce flicker
            $now = [DateTime]::Now
            if (($now - $lastUpdate).TotalMilliseconds -gt 200 -and $totalBytes -gt 0) {
                $percent = [math]::Round(($totalBytesRead / $totalBytes) * 100, 1)
                $downloadedMB = [math]::Round($totalBytesRead / 1MB, 2)
                $totalMB = [math]::Round($totalBytes / 1MB, 2)
                
                # Calculate speed
                $elapsed = ($now - $startTime).TotalSeconds
                $speed = if ($elapsed -gt 0) {
                    [math]::Round($totalBytesRead / 1MB / $elapsed, 2)
                } else { 0 }
                
                # Create progress bar (40 characters wide)
                $barWidth = 40
                $filledWidth = [math]::Floor($barWidth * $percent / 100)
                $emptyWidth = $barWidth - $filledWidth
                $bar = ("[" + ("█" * $filledWidth) + ("░" * $emptyWidth) + "]")
                
                # Write progress on same line
                Write-Host "`r  $bar $percent% | $downloadedMB / $totalMB MB | $speed MB/s" -NoNewline -ForegroundColor Cyan
                
                $lastUpdate = $now
            }
        } while ($readCount -gt 0)
        
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
        
        # Final progress bar at 100%
        $totalMB = [math]::Round($totalBytes / 1MB, 2)
        $elapsed = ([DateTime]::Now - $startTime).TotalSeconds
        $avgSpeed = if ($elapsed -gt 0) { [math]::Round($totalBytes / 1MB / $elapsed, 2) } else { 0 }
        $bar = ("[" + ("█" * 40) + "]")
        Write-Host "`r  $bar 100% | $totalMB / $totalMB MB | $avgSpeed MB/s" -ForegroundColor Cyan
        
        Write-Host ""  # New line
        Write-Success "Download completed"
        
    } catch {
        Write-Host ""  # New line to clear progress
        Write-ErrorMsg "Download failed: $_"
        
        # Clean up partial download
        if (Test-Path $Destination) {
            Remove-Item $Destination -Force -ErrorAction SilentlyContinue
        }
        
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
        Get-FileWithProgress -Url $releaseInfo.DownloadUrl -Destination $zipPath -FileName $releaseInfo.FileName
        
        # Extract package
        Write-Step "Extracting package..."
        $extractPath = Join-Path $tempDir "extracted"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Find the deploy directory (handles both folder structures)
        $deployDir = Get-ChildItem -Path $extractPath -Filter "Enginuity_Deploy_*" -Directory | Select-Object -First 1
        
        if (-not $deployDir) {
            # No folder found - files might be at root level
            # Check if expected files exist at root
            if ((Test-Path "$extractPath\enginuity_launcher.exe") -and 
                (Test-Path "$extractPath\server") -and 
                (Test-Path "$extractPath\enginuity_design_studio")) {
                
                Write-ColorOutput "  Using files from ZIP root..." "Gray"
                # Create a pseudo deploy directory object
                $deployDir = [PSCustomObject]@{
                    FullName = $extractPath
                }
            } else {
                throw "Deploy directory or required files not found in package. Expected structure:`n  - Enginuity_Deploy_vX.X.X.X/ (folder), OR`n  - enginuity_launcher.exe, server/, enginuity_design_studio/ at root"
            }
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
        
        try {
            $WshShell = New-Object -ComObject WScript.Shell
            
            # Start Menu
            $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$PRODUCT_NAME"
            New-Item -ItemType Directory -Path $startMenuPath -Force | Out-Null
            
            try {
                $shortcut = $WshShell.CreateShortcut("$startMenuPath\$PRODUCT_NAME.lnk")
                $shortcut.TargetPath = "$InstallPath\enginuity_launcher.exe"
                $shortcut.WorkingDirectory = $InstallPath
                $shortcut.Description = $PRODUCT_NAME
                $shortcut.Save()
                Write-ColorOutput "  Created Start Menu shortcut" "Gray"
            } catch {
                Write-ColorOutput "  Warning: Could not create Start Menu shortcut: $_" "Yellow"
            }
            
            # Desktop shortcut
            try {
                $desktopPath = [Environment]::GetFolderPath("Desktop")
                $shortcut = $WshShell.CreateShortcut("$desktopPath\$PRODUCT_NAME.lnk")
                $shortcut.TargetPath = "$InstallPath\enginuity_launcher.exe"
                $shortcut.WorkingDirectory = $InstallPath
                $shortcut.Description = $PRODUCT_NAME
                $shortcut.Save()
                Write-ColorOutput "  Created Desktop shortcut" "Gray"
            } catch {
                Write-ColorOutput "  Warning: Could not create Desktop shortcut: $_" "Yellow"
            }
            
            # Release COM object
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
            
            Write-Success "Shortcuts created"
            
        } catch {
            Write-ColorOutput "⚠ Warning: Shortcut creation failed, but installation will continue." "Yellow"
            Write-ColorOutput "  You can manually create shortcuts to: $InstallPath\enginuity_launcher.exe" "Gray"
        }
        
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
        Read-Host "`nPress Enter to continue"
        return
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
║     ✓ $modeText Completed Successfully!        ║
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
        Read-Host "`nPress Enter to continue"
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
        
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        Remove-Item -Path "$desktopPath\$PRODUCT_NAME.lnk" -Force -ErrorAction SilentlyContinue
        
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
║     ✓ Uninstallation Completed Successfully!     ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

"@ "Green"
        
        Write-ColorOutput "Thank you for using Enginuity Design Studio!" "Cyan"
        
    } catch {
        Write-ErrorMsg "Uninstallation failed: $_"
        Read-Host "`nPress Enter to continue"
        return
    }
    
    Read-Host "`nPress Enter to continue"
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
            "exit" { 
                Write-ColorOutput "`nGoodbye!" "Cyan"
                return
            }
        }
    }
} catch {
    Write-ErrorMsg "`nAn unexpected error occurred: $_"
    Read-Host "`nPress Enter to continue"
}