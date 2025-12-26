# unix-like-powershell

A lightweight **PowerShell 7.5** profile for Windows that provides a more “Ubuntu-ish” / bash-like command-line experience: familiar helpers (`head`, `tail`, `grep`, `rm -rf`, `export`, `which`, `cd -`), quieter PSReadLine behavior, and a Git-aware prompt.

_Disclaimer: this is created and verified by Shaowu Pan with the help of ChatGPT 5.2._

---

## What Ubunth-ish tools I already have

- `vim` 
- `wget2` 

Note: the `apt get install` in Windows is [`winget`](https://github.com/microsoft/winget-cli). 

## Installation

1. First, create an empty profile
```
if (!(Test-Path -Path $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force
}
```
2. Type `$PROFILE` in your powershell to find the path of that profile. For example, in my case it is `C:\Users\pswpe\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`.
3. Next, copy paste the content of this `Microsoft.PowerShell_profile` to that profile you created. 
4. Reopen your powershell terminal.

For more information, check out this [page](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.5).

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

### Linux-ish command wrappers
- `which` — show resolved command paths
- `export NAME=value` — set environment variables
- `source file.ps1` — dot-source scripts
- `touch` — create/update files
- `head -n N file`
- `tail -n N file`, `tail -f file`
- `less file` — page output
- `man cmd` — PowerShell help in pager
- `grep` — uses `rg` if installed; otherwise `Select-String`
  - supports `-i`, `-n`, `-r`, `-v`
- `rm` — Linux-ish parsing and behavior
  - supports `rm -rf`, `rm -r -f`, `rm -- -weirdname`, `rm -n` (dry run), `rm -v`

### Navigation + prompt
- `cd -` returns to previous directory
- `..`, `...`, `....` quick jumps
- Prompt shows: `user@host:path (branch*)$` with ANSI colors
  - `*` indicates dirty Git repo

---

## Requirements

- **PowerShell 7.x** (`pwsh`)
- Works best in **Windows Terminal**, but not required

Optional (recommended):
- `git` (for branch in prompt)
- [`ripgrep (rg)`](https://github.com/BurntSushi/ripgrep) for faster `grep`
- [`bat`](https://github.com/sharkdp/bat) for nicer `cat` output (if you extend it)
- [`eza`](https://github.com/eza-community/eza) for a nicer `ls` (if you extend it)

---

## Install

1) Open your PowerShell profile:
```powershell
vim $PROFILE
```

2) Paste the contents of this repo’s profile script into that file.

3) Reload:

```
powershell . $PROFILE
```

---

## Important: alias overrides

PowerShell ships `ls` and `rm` as aliases (e.g., `ls -> Get-ChildItem`, `rm -> Remove-Item`).  
This profile removes those aliases so the Linux-ish functions can take over.

Verify you are using functions:
```powershell
Get-Command ls, rm
```
Expected: `CommandType` should be `Function`.

---

## Usage examples

### rm
```powershell
rm -rf build
rm -r -f build
rm -- -weirdname
rm -n -rv .\somefolder   # dry-run + verbose
```

### grep
```powershell
grep -n "TODO" -r .
grep -i "error" logfile.txt
grep -v "DEBUG" logfile.txt
```

### head / tail
```powershell
head -n 5 file.txt
tail -n 20 file.txt
tail -f file.txt
```

### cd -
```powershell
cd C:\Windows
cd -
```

---

## Smoke test

Copy/paste this after installing:

```powershell
. $PROFILE

# Confirm key functions are active
Get-Command ls, rm, head, tail, grep, which, export, touch

# Create a sandbox
mkdir _unixlike_test -Force | Out-Null
1..50 | Set-Content .\_unixlike_test\numbers.txt

# head/tail
head -n 5 .\_unixlike_test\numbers.txt
tail -n 5 .\_unixlike_test\numbers.txt

# grep
grep 7 .\_unixlike_test\numbers.txt
grep -n 7 .\_unixlike_test\numbers.txt
grep -v 7 .\_unixlike_test\numbers.txt

# rm -rf
rm -n -rv .\_unixlike_test
rm -rf .\_unixlike_test
Test-Path .\_unixlike_test
```

Expected:
- `Get-Command ls, rm` returns `Function`
- `head`/`tail` print correct lines
- `grep` finds matches
- `rm -rf` deletes the test directory
- final `Test-Path` prints `False`

---

## License

MIT
