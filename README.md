# Awesome PowerShell Profile

Opinionated PowerShell profile that makes Windows PowerShell / PowerShell Core feel a lot more like a modern bash/zsh shell on Linux. It lives entirely in a single file: `Microsoft.PowerShell_profile.ps1`.

## Features

- Bash‑like UX on Windows (and Ubuntu via `pwsh`)
- Sensible PSReadLine defaults:
  - History‑based predictions in list view
  - No bell, no duplicate history entries
  - Up/Down for history search (like bash)
  - `Tab` menu completion for paths/commands
  - Familiar shortcuts: `Ctrl+A/E/K/U`, `Ctrl+L`, `Ctrl+D`
- Quality‑of‑life helpers:
  - `which`, `export`, `source`, `touch`, `head`, `tail`, `less`, `man`
  - `..` / `...` for quick directory up navigation
  - `ls` with `-a -l -h -t -r` flags, colorized output
  - `cat` that prefers `bat` if available
  - `grep` that prefers `rg` (ripgrep) if available
  - Bash‑style `rm`, `cp`, `mv` flag handling
  - Rough `df` / `du` equivalents with human‑readable sizes
  - Best‑effort `sudo` that re‑invokes an elevated `pwsh`/`powershell`
- Editor defaults:
  - Automatically sets `$env:EDITOR` to `nvim`, `vim`, or `notepad`
  - Aliases: `vi`, `vim`, and `nano`
- Prompt:
  - Bash‑ish prompt with `user@host:~/path (branch*)$`
  - Shows git branch and dirty marker `*` when inside a repo
  - Emits escape sequence so Windows Terminal “Duplicate Tab” starts in the current directory

## Installation

1. Clone or download this repo somewhere convenient:
   ```powershell
   git clone https://github.com/<you>/awesome-powershell-profile.git
   ```

2. Open PowerShell and check your profile path:
   ```powershell
   $PROFILE
   ```

3. Copy the profile into place (adjust the path if needed):
   ```powershell
   Copy-Item 'path\to\awesome-powershell-profile\Microsoft.PowerShell_profile.ps1' $PROFILE -Force
   ```

4. Restart PowerShell (or run `.& $PROFILE`) to load the profile.

This works for both Windows PowerShell and PowerShell Core (`pwsh`). If you use multiple hosts (VS Code, Windows Terminal, etc.), repeat the copy step for each host’s `$PROFILE` if desired.

## Customization

Because everything lives in a single script, customization is straightforward:

- Open `$PROFILE` in your editor:
  ```powershell
  code $PROFILE    # or use $env:EDITOR
  ```
- Tweak keybindings, helpers, or the prompt to your liking.
- Comment out or remove sections you don’t want.

If you keep this repo under version control, you can periodically pull updates and manually merge them into your own `$PROFILE`.

## Requirements

- PowerShell 5.1+ or PowerShell Core (`pwsh`)
- Optional but recommended:
  - [`PSReadLine`] for rich line editing (import is attempted automatically)
  - [`git`] for prompt git info and helpers
  - [`rg` (ripgrep)] for faster `grep` functionality
  - [`bat`] for nicer `cat` output
  - `nvim` or `vim` if you want `$env:EDITOR` to target them

The profile gracefully degrades: if a tool isn’t installed, the corresponding enhancements are simply skipped.

