<#
unix-like-powershell test runner (v3)
------------------------------------
- Dot-sources a profile file in MAIN scope (so functions persist)
- Runs smoke tests for ls/grep/rm/head/tail/touch/export/which/mkdir/cd-/prompt
- Writes test-report.txt + test-report.json in a temporary work dir

Run (recommended, avoids signing errors):
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\test-unixlike-profile.v3.ps1 -ProfilePath "$PROFILE"

Or test a specific profile file:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\test-unixlike-profile.v3.ps1 -ProfilePath "C:\path\to\Microsoft.PowerShell_profile.ps1"
#>

[CmdletBinding()]
param(
  [string]$ProfilePath = $PROFILE,
  [string]$WorkDir,
  [switch]$KeepWorkDir
)

Set-StrictMode -Version Latest

function New-WorkDir {
  param([string]$Base)
  if ($Base) {
    New-Item -ItemType Directory -Path $Base -Force | Out-Null
    return (Resolve-Path $Base).Path
  }
  $p = Join-Path $env:TEMP ("unixlike_profile_test_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $p -Force | Out-Null
  return $p
}

function Assert-True {
  param(
    [Parameter(Mandatory=$true)][object]$Cond,
    [string]$Msg = "assertion failed"
  )
  # Treat arrays as truthy if non-empty (useful for expressions like: ($o -match 'x')).
  $truth = $false
  if ($null -eq $Cond) {
    $truth = $false
  } elseif ($Cond -is [bool]) {
    $truth = $Cond
  } elseif ($Cond -is [System.Array]) {
    $truth = ($Cond.Count -gt 0)
  } elseif ($Cond -is [string]) {
    $truth = ($Cond.Length -gt 0)
  } else {
    try { $truth = [bool]$Cond } catch { $truth = $true }
  }
  if (-not $truth) { throw $Msg }
}

$wd = New-WorkDir -Base $WorkDir
$logPath  = Join-Path $wd "test-report.txt"
$jsonPath = Join-Path $wd "test-report.json"

# ---- Load profile in MAIN scope ----
if (-not (Test-Path -LiteralPath $ProfilePath)) { throw "ProfilePath not found: $ProfilePath" }
. $ProfilePath

# ---- Test harness ----
$global:TestResults = New-Object System.Collections.Generic.List[object]

function Run-Test {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][scriptblock]$Body
  )

  $start = Get-Date
  $pass = $true
  $err  = ""
  $out  = ""

  try { $out = (& $Body 2>&1 | Out-String) }
  catch { $pass = $false; $err = ($_ | Out-String) }

  $dur = (Get-Date) - $start
  $global:TestResults.Add([pscustomobject]@{
    Name     = $Name
    Pass     = $pass
    Seconds  = [math]::Round($dur.TotalSeconds, 3)
    Output   = $out.TrimEnd()
    Error    = $err.TrimEnd()
  }) | Out-Null
}

try {
  Run-Test "System info" {
    "PSVersion:  $($PSVersionTable.PSVersion)"
    "OS:         $([System.Environment]::OSVersion.VersionString)"
    "Host:       $($Host.Name)"
    "WorkDir:    $wd"
    "Profile:    $ProfilePath"
  }

  Run-Test "Command resolution (Get-Command -All)" {
    $names = @("ls","rm","grep","head","tail","touch","export","which","mkdir","cd","prompt")
    foreach ($n in $names) {
      $cmds = Get-Command $n -All -ErrorAction SilentlyContinue
      if (-not $cmds) { "{0,-7} : (missing)" -f $n; continue }
      "{0,-7} : {1}" -f $n, (($cmds | ForEach-Object { "$($_.CommandType)@$($_.Source)" }) -join " | ")
    }
    "`nExpected: ls/rm/grep/head/tail/touch/export/which/mkdir should be Function (not Alias)."
  }

  # Sandbox
  $tRoot = Join-Path $wd "_sandbox"
  New-Item -ItemType Directory -Path $tRoot -Force | Out-Null
  Set-Location -LiteralPath $tRoot

  1..50 | Set-Content -Path (Join-Path $tRoot "_numbers.txt") -Encoding utf8
  @(
    "alpha"
    "apple"
    "APPLE"
    "banana"
    "debug: hello"
    "INFO: ok"
  ) | Set-Content -Path (Join-Path $tRoot "_words.txt") -Encoding utf8

  # mkdir -p / -v
  Run-Test "mkdir -p / -v (Linux-ish)" {
    # should not error when creating nested paths; should not error if it already exists
    mkdir -p -v "a\b\c" | Out-String | Write-Output
    Assert-True (Test-Path -LiteralPath "a\b\c") "mkdir -p failed to create nested path"
    mkdir -p "a\b\c" | Out-Null
    "mkdir ok"
  }

  # ls
  Run-Test "ls basic" { ls }
  Run-Test "ls -a" { ls -a }
  Run-Test "ls -l" { ls -l }
  Run-Test "ls -l -h" { ls -l -h }
  Run-Test "ls -t" { ls -t }
  Run-Test "ls -t -r" { ls -t -r }
  Run-Test "ls -lrth (bundled)" { ls -lrth }
  Run-Test "ls -ls (bundled)" { ls -ls }

  # head/tail
  Run-Test "head -n 5" {
    $o = head -n 5 (Join-Path $tRoot "_numbers.txt")
    Assert-True ($o.Count -eq 5) "head expected 5 lines, got $($o.Count)"
    Assert-True ($o[0] -eq "1") "head first line expected 1, got $($o[0])"
    $o
  }

  Run-Test "tail -n 5" {
    $o = tail -n 5 (Join-Path $tRoot "_numbers.txt")
    Assert-True ($o.Count -eq 5) "tail expected 5 lines, got $($o.Count)"
    Assert-True ($o[0] -eq "46") "tail first returned line expected 46, got $($o[0])"
    $o
  }

  # grep
  Run-Test "grep basic" {
    $p = Join-Path $tRoot "_words.txt"
    $o = grep apple $p
    Assert-True ($o -match "apple") "grep basic didn't match apple"
    $o
  }

  Run-Test "grep -i (ignore case)" {
    $p = Join-Path $tRoot "_words.txt"
    $o = grep -i apple $p
    Assert-True ($o -match "APPLE") "grep -i didn't include APPLE"
    $o
  }

  Run-Test "grep -n (line numbers)" {
    $p = Join-Path $tRoot "_words.txt"
    $o = grep -n apple $p
    Assert-True ($o -match ":\d+:") "grep -n didn't look like path:line:content"
    $o
  }

  Run-Test "grep -r (recurse)" {
    mkdir -p logs | Out-Null
    "error: something" | Set-Content -Path .\logs\run1.grep_test.txt -Encoding utf8
    "ok"              | Set-Content -Path .\logs\run2.grep_test.txt -Encoding utf8
    $o = grep -r error .
    Assert-True ($o -match "run1\.grep_test\.txt") "grep -r didn't find run1.grep_test.txt"
    $o
  }

  Run-Test "grep -v (invert match)" {
    $p = Join-Path $tRoot "_words.txt"
    $o = grep -v debug $p
    Assert-True (-not ($o -match "debug:")) "grep -v still contains debug"
    $o
  }

  # export / which / touch
  Run-Test "export NAME=value" {
    export UNIXLIKE_TESTVAR=hello
    Assert-True ($env:UNIXLIKE_TESTVAR -eq "hello") "export didn't set env var"
    "UNIXLIKE_TESTVAR=$env:UNIXLIKE_TESTVAR"
  }

  Run-Test "which pwsh" {
    $o = which pwsh
    Assert-True ($o -and ($o -match "pwsh")) "which pwsh returned nothing"
    $o
  }

  Run-Test "touch create+update" {
    $p = Join-Path $tRoot "_touch.txt"
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
    touch $p
    Assert-True (Test-Path -LiteralPath $p) "touch didn't create file"
    $t1 = (Get-Item -LiteralPath $p).LastWriteTimeUtc
    Start-Sleep -Milliseconds 1100
    touch $p
    $t2 = (Get-Item -LiteralPath $p).LastWriteTimeUtc
    Assert-True ($t2 -gt $t1) "touch didn't update timestamp"
    "t1=$t1"
    "t2=$t2"
  }

  # rm -rf
  Run-Test "rm -n -rv (dry-run) + rm -rf" {
    $p = Join-Path $tRoot "_rmtest"
    mkdir -p "$p\sub" | Out-Null
    "x" | Set-Content -Path (Join-Path $p "a.txt") -Encoding utf8
    "y" | Set-Content -Path (Join-Path $p "sub\b.txt") -Encoding utf8
    Assert-True (Test-Path -LiteralPath $p) "setup failed"

    rm -n -rv $p | Out-String | Write-Output
    Assert-True (Test-Path -LiteralPath $p) "dry-run deleted folder"

    rm -rf $p
    Assert-True (-not (Test-Path -LiteralPath $p)) "rm -rf failed"
    "rm ok"
  }

  # cd -
  Run-Test "cd - (previous dir) [skips if cd is Alias]" {
    $cdCmd = Get-Command cd -ErrorAction SilentlyContinue
    if (-not $cdCmd -or $cdCmd.CommandType -ne "Function") {
      "SKIP: cd is not a Function (likely Alias to Set-Location)."
      return
    }
    $d1 = Join-Path $tRoot "_cd1"
    $d2 = Join-Path $tRoot "_cd2"
    mkdir -p $d1 | Out-Null
    mkdir -p $d2 | Out-Null
    cd $d1; $p1 = (Get-Location).Path
    cd $d2; $p2 = (Get-Location).Path
    cd - ; $pBack = (Get-Location).Path
    Assert-True ($pBack -eq $p1) "cd - expected $p1 got $pBack"
    "cd - OK"
  }

  Run-Test "prompt output (sanity)" {
    $s = prompt
    $s
  }

} finally {
  # Write report
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("unix-like-powershell profile test report")
  $lines.Add("Generated: $(Get-Date -Format o)")
  $lines.Add("WorkDir:   $wd")
  $lines.Add("Profile:   $ProfilePath")
  $lines.Add("")

  foreach ($r in $global:TestResults) {
    $status = if ($r.Pass) { "PASS" } else { "FAIL" }
    $lines.Add(("[" + $status + "] " + $r.Name + " (" + $r.Seconds + "s)"))
    if ($r.Output) {
      $lines.Add("  Output:")
      $r.Output.Split("`n") | ForEach-Object { $lines.Add("    " + $_.TrimEnd()) }
    }
    if ($r.Error) {
      $lines.Add("  Error:")
      $r.Error.Split("`n") | ForEach-Object { $lines.Add("    " + $_.TrimEnd()) }
    }
    $lines.Add("")
  }

  $lines | Set-Content -Path $logPath -Encoding utf8
  $global:TestResults | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding utf8

  Write-Host ""
  Write-Host "=== Summary ==="
  $global:TestResults | Select-Object Name, Pass, Seconds | Format-Table -AutoSize
  Write-Host ""
  Write-Host "Report written to:"
  Write-Host "  $logPath"
  Write-Host "  $jsonPath"

  if (-not $KeepWorkDir) {
    $sandbox = Join-Path $wd "_sandbox"
    if (Test-Path -LiteralPath $sandbox) {
      Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
