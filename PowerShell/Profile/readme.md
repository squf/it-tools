My good friend Gemini put this readme together for YOU! Say thank you Gemini.

---

# 🚀 squf's Bash-Like PowerShell Profile

A lightweight, high-performance PowerShell configuration designed for Systems Administrators and Cloud Architects. This profile focuses on **transient execution**, **dependency isolation**, and **Linux-style ergonomics**.

---

## ✨ Key Features

* **Dependency Isolation:** Includes the `run` command to execute scripts in clean, non-persistent processes—eliminating the "Assembly already loaded" errors common in Microsoft Graph development.
* **Linux Ergonomics:** Native aliases for `touch`, `grep`, `which`, and `ll` to maintain muscle memory across Windows and Linux/WSL2 environments.
* **The `man` Experience:** Custom `man` function that skips the dry technical definitions and jumps straight to the **examples** for any cmdlet.
* **The `how` Engine:** A built-in, extensible cheat sheet system for quick access to Graph, Entra ID, and UPN standardization syntax.
* **Minimalist Prompt:** A clean, color-coded `[folder] >` prompt using ANSI 256-color codes for a modern terminal feel.
* **Syntax Highlighting:** Real-time command colorization (Cyan for commands, Gray for parameters).

---

## 🛠️ Custom Functions

### `run <script.ps1>`
The core of this profile. Instead of running scripts in your main terminal, `run` launches a fresh `pwsh` instance with `-NoProfile`. This ensures every script execution starts from a "Known Good" state and prevents DLL collisions between different module versions.

### `how <topic>`
Access internal cheat sheets for common tasks.
* `how graph`: Microsoft Graph connection and filtering tips.
* `how entraid`: Group and membership lookup syntax.
* `how upn`: Specific commands for UPN standardization projects.
* `how aliases`: A reminder of the Linux-style aliases included in this profile.

### `man <cmdlet>`
A surgical strike on the help system. It reaches into the help object and returns **only** the example blocks in high-visibility yellow.

---

## 🧠 Intelligent Autocomplete

This profile leverages **PSReadLine Predictive IntelliSense** to provide a high-performance, visual completion experience directly in the shell.

### Features:
* **Predictive Suggestions:** As you type, the shell suggests commands based on your local history and installed module capabilities.
* **List View Navigation:** Instead of cycling through commands one-by-one, hit the **Up Arrow** or start typing to see a "Floating List" of possibilities beneath your cursor.
* **Context Awareness:** Highly effective for complex Microsoft Graph and Entra ID cmdlets, reducing the need to memorize long parameter strings.

### Key Commands in Profile:
```powershell
# Set suggestions to pull from history and plugins
Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# Change the view from 'Inline' to 'ListView' for better visibility
Set-PSReadLineOption -PredictionViewStyle ListView
```
---

## 📂 Included Aliases

| Command | PowerShell Equivalent | Function |
| :--- | :--- | :--- |
| `touch` | `New-Item` | Create a new empty file |
| `grep` | `Select-String` | Search for strings in files |
| `which` | `Get-Command` | Locate the path/source of a cmdlet |
| `ll` | `Get-ChildItem` | List files in a detailed format |
| `run` | `pwsh -NoProfile` | Run script in a clean sandbox |
| `man` | `Get-Help -Examples`| View usage examples only |

---

## 🚀 Installation

1.  **Deploy Profile:** Copy the contents of `Microsoft.PowerShell_profile.ps1` into your `$PROFILE` path.
2.  **Module Hygiene:** For best results, install your `Microsoft.Graph` modules to `C:\Program Files\PowerShell\Modules` rather than the OneDrive-synced Documents folder.
3.  **Recommended Font:** Use a [Nerd Font](https://www.nerdfonts.com/) (like Cascadia Code) in Windows Terminal to ensure all UI elements render correctly.

---

## 🛡️ Microsoft Graph SDK Tips
This profile was born out of the frustration of managing `Microsoft.Graph` module versions. For a stable environment, it is recommended to:
1.  Install modules to the **AllUsers** scope: `Install-Module Microsoft.Graph -Scope AllUsers`.
2.  Avoid installing modules into your OneDrive-synced Documents folder.
3.  Use the `run` command to prevent DLL collisions between different script versions.
