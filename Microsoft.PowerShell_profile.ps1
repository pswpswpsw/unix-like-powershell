# ============================================================
# Ubuntu-ish PowerShell profile (bash-like UX on Windows)
# Paste into: $PROFILE
# ============================================================

# --- Basics ---
$PSStyle.OutputRendering = 'Ansi' 2>$null
$env:LC_ALL = "C.UTF-8"
$env:LANG   = "C.UTF-8"

# Prefer modern pwsh behavior if available
Set-Variable -Name HOME -Value $HOME -Option ReadOnly -ErrorAction SilentlyContinue

# --- PSReadLine: history + keybindings closer to bash ---
try {
    Import-Module PSReadLine -ErrorAction Stop

    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -BellStyle None

    # bash-like history search on up/down
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # menu completion (nice for paths)
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # bash-ish shortcuts
    Set-PSReadLineKeyHandler -Chord 'Ctrl+l' -ScriptBlock { Clear-Host }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteCharOrExit
    Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function KillLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardKillLine
} catch {}

# --- Helpers ---
function _HasCmd([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function _HumanSize([long]$bytes) {
    if ($bytes -lt 0) { return "$bytes" }
    $units = @("B","K","M","G","T","P")
    $i = 0
    [double]$v = $bytes
    while ($v -ge 1024 -and $i -lt $units.Count-1) { $v /= 1024; $i++ }
    if ($i -eq 0) { return "{0}{1}" -f [long]$v, $units[$i] }
    return "{0:N1}{1}" -f $v, $units[$i]
}

function which {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    foreach ($a in $Args) {
        $cmd = Get-Command $a -ErrorAction SilentlyContinue
        if ($cmd) { $cmd | Select-Object -ExpandProperty Source }
    }
}

function export {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    foreach ($a in $Args) {
        if ($a -match '^(?<k>[A-Za-z_][A-Za-z0-9_]*)=(?<v>.*)$') {
            Set-Item -Path "Env:$($Matches.k)" -Value $Matches.v
        } else {
            Write-Error "export: use NAME=value"
        }
    }
}

function source {
    param([string]$Path)
    if (-not $Path) { return }
    . (Resolve-Path $Path)
}

function touch {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Paths)
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $p -Force | Out-Null
        }
    }
}

function head {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    $n = 10
    $paths = @()
    for ($i=0; $i -lt $Args.Count; $i++) {
        if ($Args[$i] -in @("-n","--lines") -and $i+1 -lt $Args.Count) { $n = [int]$Args[$i+1]; $i++; continue }
        $paths += $Args[$i]
    }
    if ($paths.Count -eq 0) { return }
    Get-Content -LiteralPath $paths -TotalCount $n
}

function tail {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    $n = 10
    $follow = $false
    $paths = @()
    for ($i=0; $i -lt $Args.Count; $i++) {
        if ($Args[$i] -in @("-n","--lines") -and $i+1 -lt $Args.Count) { $n = [int]$Args[$i+1]; $i++; continue }
        if ($Args[$i] -in @("-f","--follow")) { $follow = $true; continue }
        $paths += $Args[$i]
    }
    if ($paths.Count -eq 0) { return }
    if ($follow) {
        Get-Content -LiteralPath $paths -Tail $n -Wait
    } else {
        Get-Content -LiteralPath $paths -Tail $n
    }
}

function less {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args.Count -eq 0) { return }
    Get-Content -LiteralPath $Args | Out-Host -Paging
}

function man {
    param([string]$Cmd)
    if (-not $Cmd) { return }
    Get-Help $Cmd -Full | Out-Host -Paging
}

# --- cd with ~ and "-" (previous dir) ---
$global:__LAST_DIR = $PWD.Path
function cd {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    $target = if ($Args.Count -gt 0) { $Args[0] } else { $HOME }
    if ($target -eq "-") {
        $tmp = $PWD.Path
        Set-Location -LiteralPath $global:__LAST_DIR
        $global:__LAST_DIR = $tmp
        return
    }
    if ($target -like "~*") {
        $target = $target -replace '^~', $HOME
    }
    $global:__LAST_DIR = $PWD.Path
    Set-Location -LiteralPath $target
}

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }

# --- ls that understands -a -l -h -t -r ---
function ls {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    # If eza exists, use it for a very Ubuntu-like ls
    if (_HasCmd "eza") {
        & eza @Args
        return
    }

    $showAll = $false
    $long    = $false
    $human   = $false
    $sortTime = $false
    $reverse = $false
    $paths   = @()

    foreach ($a in $Args) {
        if ($a -like '-*') {
            if ($a -match 'a') { $showAll = $true }
            if ($a -match 'l') { $long = $true }
            if ($a -match 'h') { $human = $true }
            if ($a -match 't') { $sortTime = $true }
            if ($a -match 'r') { $reverse = $true }
        } else {
            $paths += $a
        }
    }
    if ($paths.Count -eq 0) { $paths = @(".") }

    $items = Get-ChildItem -Force:$showAll -LiteralPath $paths -ErrorAction SilentlyContinue
    if ($sortTime) { $items = $items | Sort-Object LastWriteTime -Descending }
    if ($reverse) { $items = $items | Sort-Object { $_.PSIsContainer } -Descending; $items = @($items)[-1..0] }

    if ($long) {
        if ($human) {
            $items | Select-Object Mode, LastWriteTime, @{Name="Size";Expression={
                if ($_.PSIsContainer) { "-" } else { _HumanSize $_.Length }
            }}, Name | Format-Table -AutoSize
        } else {
            $items | Format-Table -AutoSize
        }
    } else {
        foreach ($it in $items) {
            if ($it.PSIsContainer) { "$($it.Name)/" } else { $it.Name }
        }
    }
}
function ll { ls -alh @args }
function la { ls -a @args }

# --- cat (use bat if available) ---
function cat {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if (_HasCmd "bat") { & bat @Args; return }
    if ($Args.Count -eq 0) { return }
    Get-Content -LiteralPath $Args
}

# --- grep (use rg if available; else Select-String) ---
function grep {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    if (_HasCmd "rg") { & rg @Args; return }

    $ignoreCase = $false
    $lineNums   = $false
    $recurse    = $false
    $invert     = $false
    $pattern    = $null
    $paths      = @()

    foreach ($a in $Args) {
        if ($a -like '-*' -and $pattern -eq $null) {
            if ($a -match 'i') { $ignoreCase = $true }
            if ($a -match 'n') { $lineNums = $true }
            if ($a -match 'r') { $recurse = $true }
            if ($a -match 'v') { $invert = $true }
            continue
        }
        if ($pattern -eq $null) { $pattern = $a; continue }
        $paths += $a
    }

    if (-not $pattern) { Write-Error "grep: missing PATTERN"; return }
    if ($paths.Count -eq 0) { $paths = @(".") }

    $ssArgs = @{
        Pattern = $pattern
        Path    = $paths
    }
    if ($ignoreCase) { $ssArgs.CaseSensitive = $false }
    if ($recurse) { $ssArgs.Recurse = $true }

    $matches = Select-String @ssArgs
    if ($invert) {
        # Invert match: print non-matching lines (best-effort)
        foreach ($p in $paths) {
            Get-ChildItem -LiteralPath $p -Recurse:$recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $file = $_.FullName
                $all = Get-Content -LiteralPath $file
                for ($i=0; $i -lt $all.Count; $i++) {
                    if ($all[$i] -notmatch $pattern) {
                        if ($lineNums) { "{0}:{1}:{2}" -f $file, ($i+1), $all[$i] } else { "{0}:{1}" -f $file, $all[$i] }
                    }
                }
            }
        }
        return
    }

    foreach ($m in $matches) {
        if ($lineNums) { "{0}:{1}:{2}" -f $m.Path, $m.LineNumber, $m.Line.TrimEnd() }
        else { "{0}:{1}" -f $m.Path, $m.Line.TrimEnd() }
    }
}

# --- rm/cp/mv with bash-ish flags ---
function rm {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args.Count -eq 0) { return }

    $force = $false; $recurse = $false; $interactive = $false
    $paths = @()

    foreach ($a in $Args) {
        if ($a -like '-*') {
            if ($a -match 'f') { $force = $true }
            if ($a -match 'r|R') { $recurse = $true }
            if ($a -match 'i') { $interactive = $true }
        } else {
            $paths += $a
        }
    }

    foreach ($p in $paths) {
        if ($interactive) {
            $ans = Read-Host "rm: remove '$p'? [y/N]"
            if ($ans -notin @("y","Y","yes","YES")) { continue }
        }
        Remove-Item -LiteralPath $p -Recurse:$recurse -Force:$force -ErrorAction SilentlyContinue
    }
}

function cp {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args.Count -lt 2) { Write-Error "cp: need SRC... DEST"; return }

    $recurse = $false; $force = $false
    $rest = @()
    foreach ($a in $Args) {
        if ($a -like '-*') {
            if ($a -match 'r|R') { $recurse = $true }
            if ($a -match 'f') { $force = $true }
        } else { $rest += $a }
    }

    $dest = $rest[-1]
    $srcs = $rest[0..($rest.Count-2)]
    foreach ($s in $srcs) {
        Copy-Item -LiteralPath $s -Destination $dest -Recurse:$recurse -Force:$force
    }
}

function mv {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args.Count -lt 2) { Write-Error "mv: need SRC... DEST"; return }

    $force = $false
    $rest = @()
    foreach ($a in $Args) {
        if ($a -like '-*') { if ($a -match 'f') { $force = $true } }
        else { $rest += $a }
    }

    $dest = $rest[-1]
    $srcs = $rest[0..($rest.Count-2)]
    foreach ($s in $srcs) {
        Move-Item -LiteralPath $s -Destination $dest -Force:$force
    }
}

# --- df / du (rough equivalents) ---
function df {
    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name, Root,
            @{Name="Used";Expression={ _HumanSize(($_.Used)) }},
            @{Name="Free";Expression={ _HumanSize(($_.Free)) }} |
        Format-Table -AutoSize
}

function du {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Paths)
    if ($Paths.Count -eq 0) { $Paths = @(".") }
    foreach ($p in $Paths) {
        $sum = (Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Measure-Object -Property Length -Sum).Sum
        "{0}`t{1}" -f (_HumanSize([long]$sum)), $p
    }
}

# --- sudo (best effort): opens an elevated pwsh and runs the command there ---
function sudo {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if ($Args.Count -eq 0) { Write-Error "sudo: missing command"; return }
    $cmd = $Args -join ' '
    $shell = if (_HasCmd "pwsh") { "pwsh" } else { "powershell" }
    Start-Process -Verb RunAs -FilePath $shell -ArgumentList @("-NoExit","-Command", $cmd)
}

# --- Editor defaults ---
if (-not $env:EDITOR) {
    if (_HasCmd "nvim") { $env:EDITOR = "nvim" }
    elseif (_HasCmd "vim") { $env:EDITOR = "vim" }
    else { $env:EDITOR = "notepad" }
}
Set-Alias vi  ($env:EDITOR)
Set-Alias vim ($env:EDITOR)
Set-Alias nano notepad

# --- Bash-like prompt with git branch ---
function _GitInfo {
    if (-not (_HasCmd "git")) { return $null }
    try {
        $inside = git rev-parse --is-inside-work-tree 2>$null
        if ($inside -ne "true") { return $null }
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $dirty  = (git status --porcelain 2>$null)
        $mark = if ($dirty) { "*" } else { "" }
        return "($branch$mark)"
    } catch { return $null }
}

function prompt {
    $loc = $executionContext.SessionState.Path.CurrentLocation

    # Tell Windows Terminal the current working directory (so Duplicate Tab uses it)
    $wtCwd = ""
    if ($loc.Provider.Name -eq "FileSystem") {
        $esc = [char]27
        $wtCwd = "$esc]9;9;`"$($loc.ProviderPath)`"$esc\"
    }

    $user = $env:USERNAME
    $hostn = $env:COMPUTERNAME

    $path = $PWD.Path
    if ($path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = "~" + $path.Substring($HOME.Length)
    }

    $git = _GitInfo

    # Colors (safe if ANSI supported)
    $cUser = "`e[1;32m"
    $cPath = "`e[1;34m"
    $cGit  = "`e[0;33m"
    $cReset= "`e[0m"

    $symbol = if ($IsWindows) { "$" } else { "$" }

    if ($git) {
        return "$wtCwd${cUser}${user}@${hostn}${cReset}:${cPath}${path}${cReset} ${cGit}${git}${cReset}$symbol "
    } else {
        return "$wtCwd${cUser}${user}@${hostn}${cReset}:${cPath}${path}${cReset}$symbol "
    }
}
