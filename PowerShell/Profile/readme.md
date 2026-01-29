My good friend Gemini put this readme together for YOU! Say thank you Gemini.

---

# 🚀 Danny's Bash-Like PowerShell Profile

A lightweight, high-performance PowerShell configuration designed for Systems Administrators and Cloud Architects. This profile focuses on **transient execution**, **dependency isolation** (specifically for the Microsoft Graph SDK), and **Linux-style ergonomics**.

## ✨ Key Features

* **Dependency Isolation:** Includes the `run` command to execute scripts in clean, non-persistent processes—eliminating the "Assembly already loaded" errors common in Microsoft Graph development.
* **Linux Ergonomics:** Native aliases for `touch`, `grep`, `which`, and `ll` to maintain muscle memory across Windows and Linux/WSL2 environments.
* **Minimalist Prompt:** A clean, color-coded `[folder] >` prompt that reduces visual clutter while providing high-contrast visibility.
* **Syntax Highlighting:** Enhanced `PSReadLine` configuration for real-time command colorization.
* **OneDrive Protection:** Includes logic to prioritize local `C:\Program Files\` modules over unstable OneDrive-synced Document folders.

---

## 🛠️ The "Run" Engine

The core of this profile is the `run` function. Instead of running scripts in your main terminal (which pollutes your session and causes module conflicts), use:

```powershell
run your-script.ps1

```

This launches a fresh `pwsh` instance with `-NoProfile`, ensuring that every script execution starts from a "Known Good" state.

---

## 🚀 Installation

### 1. Prerequisites

Ensure you are using **PowerShell 7.x** (Core). This profile is optimized for modern cross-platform PowerShell.

### 2. Set Execution Policy

Open PowerShell as Administrator and allow local scripts to run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

```

### 3. Deploy Profile

Copy the contents of `Microsoft.PowerShell_profile.ps1` from this repo into your personal profile path. You can find your path by typing:

```powershell
$PROFILE

```

Or open it directly in VS Code:

```powershell
code $PROFILE

```

### 4. Recommended Environment

For the best experience, use **Windows Terminal** with the following settings:

* **Font:** Cascadia Code or any [Nerd Font](https://www.nerdfonts.com/).
* **Color Scheme:** Dark theme (One Half Dark or similar).

---

## 📂 Included Aliases

| Command | PowerShell Equivalent | Function |
| --- | --- | --- |
| `touch` | `New-Item` | Create a new empty file |
| `grep` | `Select-String` | Search for strings in files |
| `which` | `Get-Command` | Locate the path of an executable/cmdlet |
| `ll` | `Get-ChildItem` | List files in a detailed format |
| `run` | `pwsh -NoProfile` | Run script in a clean sandbox |

---

## 🛡️ Microsoft Graph SDK Tips

This profile was born out of the frustration of managing `Microsoft.Graph` module versions. For a stable environment, it is recommended to:

1. Install modules to the **AllUsers** scope: `Install-Module Microsoft.Graph -Scope AllUsers`.
2. Avoid installing modules into your OneDrive-synced Documents folder.
3. Use the `run` command to prevent DLL collisions between different script versions.
