# Enginuity Design Studio

> AI-Powered Design Automation Platform for CAD, PCB Design, and Simulations

[![Latest Release](https://img.shields.io/github/v/release/JadeVexo/Enginuity-Design-Studio)](https://github.com/JadeVexo/Enginuity-Design-Studio/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/JadeVexo/Enginuity-Design-Studio/total)](https://github.com/JadeVexo/Enginuity-Design-Studio/releases)

## 🚀 Quick Install (Windows)

Open **PowerShell** and run:
```powershell
irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1 | iex
```

That's it! The installer will:
- ✅ Download the latest version
- ✅ Install to your user directory (no admin needed)
- ✅ Create desktop & start menu shortcuts
- ✅ Register the application in Windows

## 📋 Features

- 🤖 **AI-Powered CAD** - Intelligent design automation
- 🔌 **PCB Design** - Integrated circuit board layout
- 📊 **Simulations** - Real-time design validation
- 🔗 **Integrations** - Onshape, Fusion360, KiCad
- 💾 **Cloud Sync** - Work from anywhere

## 💻 System Requirements

- **OS:** Windows 10/11 (64-bit)
- **RAM:** 8GB minimum, 16GB recommended
- **Disk:** 2GB free space
- **Internet:** Required for installation and AI features

## 📦 Installation Options

### Option 1: One-Command Install (Recommended)
```powershell
irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1 | iex
```

### Option 2: Custom Installation Path
```powershell
$params = @{
    InstallPath = "D:\MyApps\Enginuity"
}
& ([ScriptBlock]::Create((irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1))) @params
```

### Option 3: Specific Version
```powershell
$params = @{
    Version = "v0.0.0.1"
}
& ([ScriptBlock]::Create((irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1))) @params
```

### Option 4: Manual Download
Download the installer from [Releases](https://github.com/JadeVexo/Enginuity-Design-Studio/releases/latest)

## 🔄 Updating

Simply re-run the installation command:
```powershell
irm https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1 | iex
```

The installer will detect your existing installation and upgrade it.

## 🗑️ Uninstall

**Method 1:** Windows Settings
- Settings → Apps → Enginuity Design Studio → Uninstall

**Method 2:** PowerShell
```powershell
& "$env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio\uninstall.ps1"
```

## 🛡️ Security

### Script Safety
Always review scripts before running:
```powershell
# Download and inspect
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JadeVexo/Enginuity-Design-Studio/main/install.ps1" -OutFile "install.ps1"
notepad install.ps1

# Run after review
.\install.ps1
```

### Execution Policy
If you get an execution policy error:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## 🐛 Troubleshooting

### Installation Fails
1. Check internet connection
2. Verify you're not installing to Program Files
3. Close any running Enginuity processes
4. Check [Issues](https://github.com/JadeVexo/Enginuity-Design-Studio/issues)

### SmartScreen Warning
This is normal for new applications. Click "More info" → "Run anyway"

### Can't Find Downloaded Files
Check: `$env:LOCALAPPDATA\Enginuity Labs\Enginuity Design Studio`

## 📖 Documentation

- Website: [enginuitylabs.org](https://enginuitylabs.org)
- Support: support@enginuitylabs.org

## 📜 License

Copyright © 2024-2025 Enginuity Labs. All rights reserved.

## 🔗 Links

- [Official Website](https://enginuitylabs.org)
- [Releases](https://github.com/JadeVexo/Enginuity-Design-Studio/releases)

---

**Made with ❤️ by Enginuity Labs**
