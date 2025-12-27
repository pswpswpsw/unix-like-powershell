# ============================================================
# unix-like-powershell — Ubuntu-ish UX for PowerShell 7.x (Windows)
# Paste into: $PROFILE
# ============================================================

# ----------------------------
# Basics
# ----------------------------
$PSStyle.OutputRendering = 'Ansi' 2>$null
$env:LC_ALL = "C.UTF-8"
$env:LANG   = "C.UTF-8"

# Keep HOME stable (best-effort)
Set-Variable -Name HOME -Value $HOME -Option ReadOnly -ErrorAction SilentlyContinue

# ----------------------------
# IMPORTANT: remove built-in aliases we override
# PowerShell resolves Aliases before Functions.
# Without this, commands like `mkdir -p` may still hit the built-in alias.
#
# We only remove aliases for commands we re-implement below.
$__unixlikeAliases = @('ls','rm','mkdir','cd','cat','man','less')
foreach ($__a in $__unixlikeAliases) {
    Remove-Item -Path ("Alias:" + $__a) -Force -ErrorAction SilentlyContinue
}

# ----------------------------
# PSReadLine: quiet typing + bash-like keys
# ----------------------------
try {
    Import-Module PSReadLine -ErrorAction Stop

    # No “history UI” while typing
    Set-PSReadLineOption -PredictionSource None
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -BellStyle None

    # Prefix history search on up/down
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Ctrl+r reverse history search
    Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -Function ReverseSearchHistory

    # Menu completion (paths)
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Bash-ish shortcuts
    Set-PSReadLineKeyHandler -Chord 'Ctrl+l' -ScriptBlock { Clear-Host }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteCharOrExit
    Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function KillLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardKillLine
} catch { }

# ----------------------------
# Helpers
# ----------------------------
function _HasCmd([string]$name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
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
    if (-not $Args -or $Args.Count -eq 0) { return }
    Get-Content -LiteralPath $Args | Out-Host -Paging
}

function man {
    param([string]$Cmd)
    if (-not $Cmd) { return }
    Get-Help $Cmd -Full | Out-Host -Paging
}

# ----------------------------
# cd with ~ and "-" (previous dir)
# ----------------------------
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

function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

# ----------------------------
# mkdir: supports -p / --parents and multiple paths
# ----------------------------
function mkdir {
    # Use $args so `mkdir -p a/b c/d` works.
    $parents = $false
    $verbose = $false
    $paths   = @()
    $stopOpts = $false

    foreach ($a in $args) {
        if ($stopOpts) { $paths += $a; continue }
        if ($a -eq '--') { $stopOpts = $true; continue }

        if ($a -like '--*') {
            switch ($a) {
                '--parents' { $parents = $true; continue }
                '--verbose' { $verbose = $true; continue }
                '--help' {
                    @"
mkdir (Linux-ish)
  -p, --parents   create parent directories as needed
  -v, --verbose   print a message for each created directory
  --              end of options
Examples:
  mkdir -p a\b\c
  mkdir -pv a\b\c d\e
"@ | Write-Host
                    return
                }
                default { $paths += $a; continue }
            }
        }

        if ($a -like '-*' -and $a -ne '-') {
            $bundle = $a.Substring(1)
            $recognized = $true
            foreach ($ch in $bundle.ToCharArray()) {
                switch ($ch) {
                    'p' { $parents = $true }
                    'v' { $verbose = $true }
                    default { $recognized = $false; break }
                }
                if (-not $recognized) { break }
            }
            if ($recognized) { continue }
        }

        $paths += $a
    }

    if ($paths.Count -eq 0) { Write-Error "mkdir: missing operand"; return }

    foreach ($p in $paths) {
        try {
            if ($parents) {
                $full = $p
                if ($PWD.Provider.Name -eq 'FileSystem') {
                    # Resolve relative paths ourselves (more reliable than Path.GetFullPath(path, base) across runtimes)
                    if (-not [System.IO.Path]::IsPathRooted($p)) {
                        $full = Join-Path -Path $PWD.Path -ChildPath $p
                    }
                    # Accept forward slashes too
                    $full = $full -replace '/', '\'
                }
                [System.IO.Directory]::CreateDirectory($full) | Out-Null
            } else {
                # mimic mkdir without -p: error if parent missing
                $parent = Split-Path -Path $p -Parent
                if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
                    Write-Error "mkdir: cannot create directory '$p': No such file or directory"
                    continue
                }
                New-Item -ItemType Directory -Path $p -Force | Out-Null
            }
            if ($verbose) { Write-Host "mkdir: created '$p'" }
        } catch {
            Write-Error $_
        }
    }
}

# ----------------------------
# ls: supports bundled flags like -lrth / -ls / -alh
# ----------------------------
function ls {
    if (_HasCmd "eza") { & eza @args; return }

    $All     = $false
    $Long    = $false
    $Human   = $false
    $Time    = $false
    $Reverse = $false
    $Blocks  = $false

    $paths    = @()
    $stopOpts = $false

    foreach ($a in $args) {
        if ($stopOpts) { $paths += $a; continue }
        if ($a -eq '--') { $stopOpts = $true; continue }

        if ($a -like '--*') {
            switch ($a) {
                '--all'            { $All = $true; continue }
                '--long'           { $Long = $true; continue }
                '--human-readable' { $Human = $true; continue }
                '--time'           { $Time = $true; continue }
                '--reverse'        { $Reverse = $true; continue }
                '--size'           { $Blocks = $true; continue } # best-effort
                default            { $paths += $a; continue }
            }
        }

        if ($a -like '-*' -and $a -ne '-') {
            $bundle = $a.Substring(1)
            $recognized = $true
            foreach ($ch in $bundle.ToCharArray()) {
                switch ($ch) {
                    'a' { $All = $true }
                    'l' { $Long = $true }
                    'h' { $Human = $true }
                    't' { $Time = $true }
                    'r' { $Reverse = $true }
                    's' { $Blocks = $true }
                    default { $recognized = $false; break }
                }
                if (-not $recognized) { break }
            }
            if ($recognized) { continue }
        }

        $paths += $a
    }

    if ($paths.Count -eq 0) { $paths = @(".") }

    $items = @()
    foreach ($p in $paths) {
        try {
            if (Test-Path -LiteralPath $p) {
                $items += Get-ChildItem -LiteralPath $p -Force:$All -ErrorAction SilentlyContinue
            } else {
                $items += Get-ChildItem -Path $p -Force:$All -ErrorAction SilentlyContinue
            }
        } catch { }
    }

    $prop = if ($Time) { 'LastWriteTime' } else { 'Name' }
    $descending = $Time  # ls -t is newest-first
    if ($Reverse) { $descending = -not $descending }

    $items = $items | Sort-Object -Property $prop -Descending:$descending

    function _Blocks1K($it) {
        if ($it.PSIsContainer) { return "-" }
        return [int][math]::Ceiling($it.Length / 1024.0)
    }

    if ($Long) {
        if ($Human) {
            if ($Blocks) {
                $items | Select-Object Mode, LastWriteTime,
                    @{Name="Blocks";Expression={ _Blocks1K $_ }},
                    @{Name="Size";Expression={ if ($_.PSIsContainer) { "-" } else { _HumanSize $_.Length } }},
                    Name | Format-Table -AutoSize
            } else {
                $items | Select-Object Mode, LastWriteTime,
                    @{Name="Size";Expression={ if ($_.PSIsContainer) { "-" } else { _HumanSize $_.Length } }},
                    Name | Format-Table -AutoSize
            }
        } else {
            if ($Blocks) {
                $items | Select-Object Mode, LastWriteTime,
                    @{Name="Blocks";Expression={ _Blocks1K $_ }},
                    Length, Name | Format-Table -AutoSize
            } else {
                $items | Format-Table -AutoSize
            }
        }
        return
    }

    foreach ($it in $items) {
        $name = if ($it.PSIsContainer) { "$($it.Name)/" } else { $it.Name }
        if ($Blocks) { "{0}`t{1}" -f (_Blocks1K $it), $name }
        else { $name }
    }
}

# ----------------------------
# grep: supports -inrvF bundles, defaults to case-sensitive like GNU grep
# ----------------------------
function grep {
    $ignoreCase = $false
    $lineNums   = $false
    $recurse    = $false
    $invert     = $false
    $fixed      = $false

    $pattern    = $null
    $paths      = @()
    $stopOpts   = $false

    foreach ($a in $args) {
        if ($stopOpts) {
            if ($pattern -eq $null) { $pattern = $a } else { $paths += $a }
            continue
        }

        if ($a -eq '--') { $stopOpts = $true; continue }

        if ($pattern -eq $null -and $a -like '-*' -and $a -ne '-') {
            if ($a -like '--*') {
                switch ($a) {
                    '--ignore-case'  { $ignoreCase = $true; continue }
                    '--line-number'  { $lineNums = $true; continue }
                    '--recursive'    { $recurse = $true; continue }
                    '--invert-match' { $invert = $true; continue }
                    '--fixed-strings'{ $fixed = $true; continue }
                    '--help' {
                        @"
grep (Linux-ish)
  -i, --ignore-case     ignore case distinctions
  -n, --line-number     print line number with output lines
  -r, -R, --recursive   read all files under each directory, recursively
  -v, --invert-match    select non-matching lines
  -F, --fixed-strings   PATTERN is a set of literal strings
  --                    end of options
Examples:
  grep apple file.txt
  grep -in apple .
  grep -r --fixed-strings "hello world" src
"@ | Write-Host
                        return
                    }
                    default { } # unknown long opts treated as non-option below
                }
            }

            $bundle = $a.Substring(1)
            $recognized = $true
            foreach ($ch in $bundle.ToCharArray()) {
                switch ($ch) {
                    'i' { $ignoreCase = $true }
                    'n' { $lineNums = $true }
                    'r' { $recurse = $true }
                    'R' { $recurse = $true }
                    'v' { $invert = $true }
                    'F' { $fixed = $true }
                    'E' { } # extended regex (default), no-op
                    default { $recognized = $false; break }
                }
                if (-not $recognized) { break }
            }
            if ($recognized) { continue }
        }

        if ($pattern -eq $null) { $pattern = $a; continue }
        $paths += $a
    }

    if (-not $pattern) { Write-Error "grep: missing PATTERN"; return }
    if ($paths.Count -eq 0) { $paths = @(".") }

    # Prefer ripgrep if installed
    if (_HasCmd "rg") {
        $rgArgs = @()

        # Make rg behave more like classic grep (don't respect .gitignore / ignore files)
        # Tip from rg man page: use -uuu for unrestricted search.
        if ($recurse) { $rgArgs += "-uuu" }

        # Keep output stable for scripts
        $rgArgs += "--color=never"
        if ($ignoreCase) { $rgArgs += "-i" }
        if ($lineNums)   { $rgArgs += "-n" }
        if ($invert)     { $rgArgs += "-v" }
        if ($fixed)      { $rgArgs += "-F" }
        if ($recurse)    { } else {
            foreach ($p in $paths) {
                if (Test-Path -LiteralPath $p -PathType Container) {
                    Write-Error ("grep: {0}: Is a directory (use -r)" -f $p)
                    return
                }
            }
        }

        $rgArgs += $pattern
        $rgArgs += $paths
        & rg @rgArgs
        return
    }

    # Fallback: Select-String
    $fileList = New-Object System.Collections.Generic.List[string]

    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) {
            if (Test-Path -LiteralPath $p -PathType Container) {
                if (-not $recurse) {
                    Write-Error ("grep: {0}: Is a directory (use -r)" -f $p)
                    return
                }
                Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $fileList.Add($_.FullName) } | Out-Null
            } else {
                $fileList.Add((Resolve-Path -LiteralPath $p).Path) | Out-Null
            }
        } else {
            # wildcard
            if ($recurse) {
                Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $fileList.Add($_.FullName) } | Out-Null
            } else {
                Get-ChildItem -Path $p -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $fileList.Add($_.FullName) } | Out-Null
            }
        }
    }

    if ($fileList.Count -eq 0) { return }

    $ssArgs = @{
        Pattern     = $pattern
        Path        = $fileList.ToArray()
        ErrorAction = 'SilentlyContinue'
        NotMatch    = $invert
    }

    # GNU grep default is case-sensitive; Select-String default is not.
    $ssArgs.CaseSensitive = -not $ignoreCase
    if ($fixed) { $ssArgs.SimpleMatch = $true }

    foreach ($m in (Select-String @ssArgs)) {
        if ($lineNums) { "{0}:{1}:{2}" -f $m.Path, $m.LineNumber, $m.Line.TrimEnd() }
        else           { "{0}:{1}"     -f $m.Path, $m.Line.TrimEnd() }
    }
}

# ----------------------------
# rm: supports bundled -rf, -n (dry run), -v (verbose), -- to end opts
# ----------------------------
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
  rm -n -rv .\somefolder
  rm -- -weirdname
"@ | Write-Host
                    return
                }
                default { Write-Error "rm: unknown option '$a'"; return }
            }
        }

        if ($a -like '-*' -and $a -ne '-') {
            $bundle = $a.Substring(1)
            $recognized = $true
            foreach ($ch in $bundle.ToCharArray()) {
                switch ($ch) {
                    'f' { $force = $true }
                    'r' { $recurse = $true }
                    'R' { $recurse = $true }
                    'i' { $interactive = $true }
                    'v' { $verbose = $true }
                    'n' { $dryRun = $true }
                    default { $recognized = $false; break }
                }
                if (-not $recognized) { break }
            }
            if ($recognized) { continue }
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

# ----------------------------
# cat: uses bat if installed
# ----------------------------
function cat {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    if (_HasCmd "bat") { & bat @Args; return }
    if (-not $Args -or $Args.Count -eq 0) { return }
    Get-Content -LiteralPath $Args
}

# ----------------------------
# df / du (rough equivalents)
# ----------------------------
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


# ----------------------------
# Prompt with git branch
# ----------------------------
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

    # Tell Windows Terminal the current working directory (Duplicate Tab uses it)
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

# ----------------------------
# Alias overrides (do this LAST so you never end up with "ls not recognized")
# ----------------------------
foreach ($name in @('ls','rm','grep','cat','man','less','mkdir','cd')) {
    if (Test-Path "Alias:$name") {
        Remove-Item -Path "Alias:$name" -Force -ErrorAction SilentlyContinue
    }
}
