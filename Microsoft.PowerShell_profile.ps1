# ============================================================
# Ubuntu-ish PowerShell profile (bash-like UX on Windows) — pwsh 7.x
# Paste into: $PROFILE
# ============================================================

# --- Basics ---
$PSStyle.OutputRendering = 'Ansi' 2>$null
$env:LC_ALL = "C.UTF-8"
$env:LANG   = "C.UTF-8"

# Make sure our rm function is used (PowerShell has an rm alias by default)
Remove-Item -Path Alias:rm -Force -ErrorAction SilentlyContinue
Remove-Item -Path Alias:ls -Force -ErrorAction SilentlyContinue

Set-Variable -Name HOME -Value $HOME -Option ReadOnly -ErrorAction SilentlyContinue

# --- PSReadLine: quiet typing + bash-like keys ---
try {
    Import-Module PSReadLine -ErrorAction Stop

    # No “history UI” while typing
    Set-PSReadLineOption -PredictionSource None

    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -BellStyle None

    # prefix history search on up/down
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Ctrl+r reverse history search
    Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -Function ReverseSearchHistory

    # menu completion (paths)
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

function rm {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

    if (-not $Args -or $Args.Count -eq 0) { return }

    $force = $false
    $recurse = $false
    $interactive = $false
    $verbose = $false
    $dryRun = $false
    $paths = @()
    $stopOpts = $false

    foreach ($a in $Args) {
        if ($stopOpts) { $paths += $a; continue }

        if ($a -eq '--') { $stopOpts = $true; continue }

        # Long options
        if ($a -like '--*') {
            switch ($a) {
                '--force'       { $force = $true; continue }
                '--recursive'   { $recurse = $true; continue }
                '--interactive' { $interactive = $true; continue }
                '--verbose'     { $verbose = $true; continue }
                '--dry-run'     { $dryRun = $true; continue }
                '--help' {
                    @"
rm (Linux-ish)
  -f, --force         ignore missing files, never prompt
  -r, -R, --recursive remove directories and their contents
  -i, --interactive   prompt before every removal
  -v, --verbose       explain what is being done
  -n, --dry-run       show what would be removed
  --                 end of options (paths can start with -)
Examples:
  rm -rf build
  rm -r -f build
  rm -- -weirdname
"@ | Write-Host
                    return
                }
                default { Write-Error "rm: unknown option '$a'"; return }
            }
        }

        # Short options (bundled): -rf, -frv, etc.
        if ($a -like '-*' -and $a -ne '-') {
            $bundle = $a.Substring(1)
            $allFlagsKnown = $true
            foreach ($ch in $bundle.ToCharArray()) {
                switch ($ch) {
                    'f' { $force = $true }
                    'r' { $recurse = $true }
                    'R' { $recurse = $true }
                    'i' { $interactive = $true }
                    'v' { $verbose = $true }
                    'n' { $dryRun = $true }
                    default { $allFlagsKnown = $false; break }
                }
            }
            if ($allFlagsKnown) { continue }
            # If it doesn't look like a pure flag bundle, treat as a path
        }

        $paths += $a
    }

    if ($paths.Count -eq 0) { Write-Error "rm: missing operand"; return }

    $ea = if ($force) { 'SilentlyContinue' } else { 'Continue' }

    foreach ($p in $paths) {
        if ($interactive) {
            $ans = Read-Host "rm: remove '$p'? [y/N]"
            if ($ans -notin @('y','Y','yes','YES')) { continue }
        }

        if ($dryRun) {
            if ($verbose) { Write-Host "[dry-run] would remove: $p" }
            else { Write-Host $p }
            continue
        }

        try {
            # Allow globbing like rm *.txt, but use LiteralPath when the path exists literally
            if (Test-Path -LiteralPath $p) {
                Remove-Item -LiteralPath $p -Recurse:$recurse -Force:$force -Confirm:$false -ErrorAction $ea
            } else {
                Remove-Item -Path $p -Recurse:$recurse -Force:$force -Confirm:$false -ErrorAction $ea
            }

            if ($verbose) { Write-Host "removed '$p'" }
        } catch {
            if (-not $force) { Write-Error $_ }
        }
    }
}


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
        $cmd = Get-Command $a -All -ErrorAction SilentlyContinue
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
    param(
        [Alias('n')]
        [int]$Lines = 10,

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Path
    )
    if (-not $Path -or $Path.Count -eq 0) { return }
    Get-Content -LiteralPath $Path -TotalCount $Lines
}

function tail {
    param(
        [Alias('n')]
        [int]$Lines = 10,

        [Alias('f')]
        [switch]$Follow,

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Path
    )
    if (-not $Path -or $Path.Count -eq 0) { return }
    if ($Follow) { Get-Content -LiteralPath $Path -Tail $Lines -Wait }
    else         { Get-Content -LiteralPath $Path -Tail $Lines }
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
    if ($target -like "~*") { $target = $target -replace '^~', $HOME }
    $global:__LAST_DIR = $PWD.Path
    Set-Location -LiteralPath $target
}

function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }

# --- ls that supports -a -l -h -t -r (PowerShell-style flags) ---
function ls {
    param(
        [Alias('a')]
        [switch]$All,

        [Alias('l')]
        [switch]$Long,

        [Alias('h')]
        [switch]$Human,

        [Alias('t')]
        [switch]$Time,

        [Alias('r')]
        [switch]$Reverse,

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Path
    )

    # If eza exists, use it (native flags like -alh will work there)
    if (_HasCmd "eza") {
        $nativeArgs = @()
        if ($All)    { $nativeArgs += "-a" }
        if ($Long)   { $nativeArgs += "-l" }
        if ($Human)  { $nativeArgs += "-h" }
        if ($Time)   { $nativeArgs += "-t" }
        if ($Reverse){ $nativeArgs += "-r" }
        if ($Path -and $Path.Count -gt 0) { $nativeArgs += $Path }
        & eza @nativeArgs
        return
    }

    if (-not $Path -or $Path.Count -eq 0) { $Path = @(".") }

    $items = Get-ChildItem -LiteralPath $Path -Force:$All -ErrorAction SilentlyContinue

    $prop = if ($Time) { 'LastWriteTime' } else { 'Name' }
    $desc = $Time
    if ($Reverse) { $desc = -not $desc }
    $items = $items | Sort-Object -Property $prop -Descending:$desc

    if ($Long) {
        if ($Human) {
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

# --- cat (use bat if available) ---
function cat {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if (_HasCmd "bat") { & bat @Args; return }
    if ($Args.Count -eq 0) { return }
    Get-Content -LiteralPath $Args
}

# --- grep (use rg if available; else Select-String) ---
function grep {
    param(
        [Alias('i')] [switch]$IgnoreCase,
        [Alias('n')] [switch]$LineNumbers,
        [Alias('r')] [switch]$Recurse,
        [Alias('v')] [switch]$InvertMatch,

        [Parameter(Mandatory=$true, Position=0)]
        [string]$Pattern,

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Path
    )

    if (_HasCmd "rg") {
        $nativeArgs = @()
        if ($IgnoreCase) { $nativeArgs += "-i" }
        if ($LineNumbers){ $nativeArgs += "-n" }
        if ($Recurse)    { $nativeArgs += "-r" }
        if ($InvertMatch){ $nativeArgs += "-v" }
        $nativeArgs += $Pattern
        if ($Path -and $Path.Count -gt 0) { $nativeArgs += $Path }
        & rg @nativeArgs
        return
    }

    if (-not $Path -or $Path.Count -eq 0) { $Path = @(".") }

    $ssArgs = @{
        Pattern     = $Pattern
        Path        = $Path
        ErrorAction = 'SilentlyContinue'
    }
    if ($IgnoreCase) { $ssArgs.CaseSensitive = $false }
    if ($Recurse)    { $ssArgs.Recurse = $true }
    if ($InvertMatch){ $ssArgs.NotMatch = $true }

    foreach ($m in (Select-String @ssArgs)) {
        if ($LineNumbers) { "{0}:{1}:{2}" -f $m.Path, $m.LineNumber, $m.Line.TrimEnd() }
        else              { "{0}:{1}" -f $m.Path, $m.Line.TrimEnd() }
    }
}

# --- rm/cp/mv with bash-ish flags (PowerShell-style) ---

function cp {
    param(
        [Alias('r','R')] [switch]$Recurse,
        [Alias('f')] [switch]$Force,

        [Parameter(Mandatory=$true, Position=0)]
        [string[]]$Src,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$Dest
    )

    foreach ($s in $Src) {
        Copy-Item -LiteralPath $s -Destination $Dest -Recurse:$Recurse -Force:$Force
    }
}

function mv {
    param(
        [Alias('f')] [switch]$Force,

        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [string[]]$Args
    )
    if ($Args.Count -lt 2) { Write-Error "mv: need SRC... DEST"; return }

    $dest = $Args[-1]
    $srcs = $Args[0..($Args.Count-2)]

    foreach ($s in $srcs) {
        Move-Item -LiteralPath $s -Destination $dest -Force:$Force
    }
}

# --- df / du (rough equivalents) ---
function df {
    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.TotalSize -gt 0 }
    $drives |
        Select-Object `
            @{Name="Name";  Expression={ $_.Name.TrimEnd('\') }},
            @{Name="Root";  Expression={ $_.RootDirectory.FullName }},
            @{Name="Used";  Expression={ _HumanSize([long]($_.TotalSize - $_.AvailableFreeSpace)) }},
            @{Name="Free";  Expression={ _HumanSize([long]($_.AvailableFreeSpace)) }},
            @{Name="Total"; Expression={ _HumanSize([long]($_.TotalSize)) }} |
        Format-Table -AutoSize
}

function du {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Path)
    if (-not $Path -or $Path.Count -eq 0) { $Path = @(".") }
    foreach ($p in $Path) {
        $sum = (Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Measure-Object -Property Length -Sum).Sum
        "{0}`t{1}" -f (_HumanSize([long]$sum)), $p
    }
}

# --- sudo (best effort): opens an elevated pwsh and runs the command there ---
function sudo {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if (-not $Args -or $Args.Count -eq 0) { Write-Error "sudo: missing command"; return }

    $shell = if (_HasCmd "pwsh") { "pwsh" } else { "powershell" }

    $cwd = $PWD.Path -replace "'", "''"
    $qArgs = $Args | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }

    $cmd = "Set-Location -LiteralPath '$cwd'; & $($qArgs[0])"
    if ($qArgs.Count -gt 1) { $cmd += " " + (($qArgs | Select-Object -Skip 1) -join " ") }

    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process -Verb RunAs -FilePath $shell -ArgumentList @("-NoExit","-EncodedCommand",$enc)
}

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

    $user  = $env:USERNAME
    $hostn = $env:COMPUTERNAME

    $path = $PWD.Path
    if ($path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = "~" + $path.Substring($HOME.Length)
    }

    $git = _GitInfo

    $cUser  = "`e[1;32m"
    $cPath  = "`e[1;34m"
    $cGit   = "`e[0;33m"
    $cReset = "`e[0m"

    $symbol = "$"

    if ($git) {
        return "$wtCwd${cUser}${user}@${hostn}${cReset}:${cPath}${path}${cReset} ${cGit}${git}${cReset}$symbol "
    } else {
        return "$wtCwd${cUser}${user}@${hostn}${cReset}:${cPath}${path}${cReset}$symbol "
    }
}
