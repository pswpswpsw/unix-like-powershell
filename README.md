# unix-like-powershell

<img src="assets/demo.gif" alt="Demo" width="800">

A lightweight **PowerShell 7.x** profile for Windows that makes the terminal feel more **Ubuntu-ish / bash-like**: familiar command names, sensible flag parsing for common cases, quieter PSReadLine behavior, and a Git-aware prompt.

> This repo provides a PowerShell **profile script** (not a module). You install it by copying it into your `$PROFILE`.

---

## Disclaimer

This profile was created and tested by **Shaowu Pan**, with assistance from **ChatGPT (GPT‑5.2)**.

**Use at your own risk.** This repository is provided for convenience and educational purposes. It may change shell behavior (e.g., command names, flags, alias overrides) and can delete files if used incorrectly (e.g., `rm -rf`). Always review the script before installing it.

If you are using a managed/work computer, make sure you have permission and that it complies with your organization’s IT/security policies. You are solely responsible for how you use this code and for any impact it may have on your system, data, or workplace environment.

No warranty is provided; see the LICENSE for details.



---

## Ubuntu commands implemented (highlights)

These are the “muscle-memory” commands that many Ubuntu users reach for first, implemented here as PowerShell functions:

### File listing / navigation
- **`ls`** — directory listing
  - supports: `-a`, `-l`, `-h`, `-t`, `-r`, `-s` and bundled forms like `ls -lrth`, `ls -alh`, `ls -ls`
- **`cd`** — supports `cd ~` and **`cd -`** (back to previous directory)
- **`..`**, **`...`**, **`....`** — quick parent directory jumps

### Viewing files
- **`cat`** — prints file contents (uses `bat` automatically if installed)
- **`head -n N file`**
- **`tail -n N file`**, **`tail -f file`**
- **`less file`** — pager
- **`man cmd`** — shows PowerShell help in a pager

### Searching text
- **`grep`** — uses `rg` (ripgrep) if available, otherwise falls back to `Select-String`
  - supports: `-i` (ignore case), `-n` (line numbers), `-r`/`-R` (recurse), `-v` (invert match), `-F` (fixed string)

### File operations / utilities
- **`rm`** — Linux-ish argument parsing (supports `rm -rf`, `rm -- -weirdname`, `rm -n` dry-run, `rm -v`)
- **`mkdir`** — supports `mkdir -p` (parents) and `mkdir -v` (verbose)
- **`touch`** — create/update files
- **`which`** — show resolved command path(s)
- **`export NAME=value`** — set environment variables
- **`source file.ps1`** — dot-source scripts
- **`open`** — “xdg-open”-style helper for opening files/URLs with default apps
- **`df`**, **`du`** — rough equivalents for disk usage

---

## Installation

1. Create your profile file (if it doesn’t exist)
```powershell
if (!(Test-Path -LiteralPath $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
```
2. Find the profile path
```powershell
$PROFILE
```
Example (Windows):
`C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

3. Copy the profile script into your `$PROFILE`
Open your profile:
```powershell
vim $PROFILE
```
Then copy/paste the contents of this repo’s `Microsoft.PowerShell_profile.ps1` into it and save.

4. Reload (or restart) your terminal
Reload without restarting:
```powershell
. $PROFILE
```
More details on profiles:
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.5

---

## Features

### PSReadLine (quiet + bash-like)
- Disables prediction UI while typing (no noisy history list)
- `Ctrl+r` reverse history search
- Up/Down arrow prefix history search
- Tab menu completion
- Common shortcuts:
  - `Ctrl+a` / `Ctrl+e` — begin/end of line
  - `Ctrl+k` / `Ctrl+u` — kill line / backward kill line
  - `Ctrl+l` — clear screen
  - `Ctrl+d` — delete char / exit

### Git-aware prompt
- Prompt shows: `user@host:path (branch*)$` with ANSI colors
- `*` indicates a dirty Git repo

---

## Requirements

- **PowerShell 7.x** (`pwsh`)
- Works best in **Windows Terminal**, but not required

Optional (recommended):
- `git` (branch display in prompt)
- `rg` (ripgrep) for faster `grep`
- `bat` for nicer `cat` output
- `eza` if you want an even nicer `ls` (this profile uses its own `ls`; `eza` is an optional alternative if you prefer it)

---

## Important: alias overrides

PowerShell resolves **aliases before functions**. Some Linux-y command names are aliases in PowerShell by default (e.g., `ls`, `rm`, `mkdir`, `cd`, `cat`).

This profile removes the aliases it re-implements so the functions can take over.

Verify you’re using functions:
```powershell
Get-Command ls, rm, mkdir, cd, cat, grep, head, tail, open
```
Expected: `CommandType` should be `Function`.

---

## Other tools I use

- `vim`
- `wget2` 
- [`winget`](https://github.com/microsoft/winget-cli)
- `fd` (alternative to `find`)

---

## Usage examples

### ls
```powershell
ls -alh
ls -lrth
ls -t -r
```

### grep
```powershell
grep -n "TODO" -r .
grep -i "error" logfile.txt
grep -v "DEBUG" logfile.txt
grep -F "literal[brackets]" file.txt
```

### head / tail
```powershell
head -n 5 file.txt
tail -n 20 file.txt
tail -f file.txt
```

### rm
```powershell
rm -rf build
rm -- -weirdname
rm -n -rv .\somefolder   # dry-run + verbose
```

### mkdir
```powershell
mkdir -p .\a\b\c
mkdir -v .\newdir
```

### open
```powershell
open .
open README.md
open "https://github.com/pswpswpsw/unix-like-powershell"
```

### cd -
```powershell
cd C:\Windows
cd -
```

---

## Smoke test (quick)

Copy/paste this after installing:

```powershell
. $PROFILE

Get-Command ls, rm, head, tail, grep, which, export, touch, mkdir, open | Format-Table -AutoSize

mkdir -p _unixlike_test | Out-Null
1..50 | Set-Content .\_unixlike_test\numbers.txt

head -n 5 .\_unixlike_test\numbers.txt
tail -n 5 .\_unixlike_test\numbers.txt

grep 7  .\_unixlike_test\numbers.txt
grep -n 7 .\_unixlike_test\numbers.txt
grep -v 7 .\_unixlike_test\numbers.txt

rm -n -rv .\_unixlike_test
rm -rf .\_unixlike_test
Test-Path .\_unixlike_test
```

Expected:
- `Get-Command` shows functions for the Linux-ish commands
- `head`/`tail` print correct lines
- `grep` finds matches
- `rm -rf` deletes the test directory
- final `Test-Path` prints `False`

---

## Automated test runner (recommended)

If you include the test script from this repo, you can run the full suite like:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\test-unixlike-profile.v4_1.ps1 -ProfilePath $PROFILE
```

This produces a human-readable `test-report.txt` and a machine-readable `test-report.json`.

---

## License

MIT.
