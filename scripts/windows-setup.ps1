# windows-setup.ps1 - set up a new Windows PC for this Emacs configuration.
#
# Run it in Windows PowerShell 5.1 or PowerShell 7:
#   powershell -NoProfile -ExecutionPolicy Bypass -File windows-setup.ps1
# Optional: -FontDir <folder with .ttf files> installs those fonts for the current user.
# Use it for Aporetic Sans Mono (the default font on Windows, from
# https://github.com/protesilaos/aporetic) and for MonoLisa (the second choice; it is
# licensed, so the script cannot download it).
#
# Each step checks first and skips work that is done, so a second run changes nothing.
# It never deletes or overwrites a file or folder, and it opens no Emacs window.
# See docs/windows-setup.md.

param(
    [string]$FontDir = ""
)

$ErrorActionPreference = "Stop"
$script:Failures = 0
$ForkUrl = "https://github.com/marcuslannister/emacs.d"
$AutoSaveUrl = "https://github.com/manateelazycat/auto-save"

function Write-Step {
    param([string]$Name, [string]$Status, [string]$Detail = "")
    if ($Status -eq "FAILED") { $script:Failures++ }
    Write-Host ("{0,-7} {1}  {2}" -f $Status, $Name, $Detail)
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Run a native program and return its exit code, without stopping on its stderr text
# (Windows PowerShell 5.1 turns native stderr into errors under "Stop").
function Invoke-Native {
    param([scriptblock]$Command)
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command 2>&1 | ForEach-Object { "$_" } | Out-Host
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
}

function Get-NativeOutput {
    param([scriptblock]$Command)
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        return (& $Command 2>&1 | Out-String).Trim()
    } finally {
        $ErrorActionPreference = $old
    }
}

# ---- Home folder -----------------------------------------------------------------
# Emacs looks for ~\.emacs.d before early-init.el runs, so the HOME variable must be
# set already: the fix in the Base would come too late.
$UserHome = [Environment]::GetEnvironmentVariable("HOME", "User")
if ([string]::IsNullOrEmpty($UserHome)) {
    [Environment]::SetEnvironmentVariable("HOME", $env:USERPROFILE, "User")
    $env:HOME = $env:USERPROFILE
    Write-Step "HOME" "done" "set the user variable HOME to $env:USERPROFILE (restart Emacs and shells)"
} else {
    if ([string]::IsNullOrEmpty($env:HOME)) { $env:HOME = $UserHome }
    Write-Step "HOME" "skip" "already $UserHome"
}
$HomeDir = $env:HOME

# ---- 1. Scoop --------------------------------------------------------------------
if (Test-Command "scoop") {
    Write-Step "scoop" "skip" "installed"
} else {
    Write-Host "Installing Scoop (a command line installer) with its official script."
    Write-Host "This sets the execution policy to RemoteSigned for the current user only."
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        $installer = Invoke-RestMethod -Uri "https://get.scoop.sh"
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
                   ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) {
            Invoke-Expression "& { $installer } -RunAsAdmin"
        } else {
            Invoke-Expression $installer
        }
        $env:PATH = (Join-Path $env:USERPROFILE "scoop\shims") + ";" + $env:PATH
        if (Test-Command "scoop") { Write-Step "scoop" "done" "installed" }
        else { Write-Step "scoop" "FAILED" "the installer ran, but scoop is not on PATH; open a new window and run this script again" }
    } catch {
        Write-Step "scoop" "FAILED" $_.Exception.Message
    }
}
if (-not (Test-Command "scoop")) {
    Write-Host "Cannot go on without Scoop."
    exit 1
}

# ---- 2. Buckets ------------------------------------------------------------------
$buckets = @(scoop bucket list 2>$null | ForEach-Object { if ($_.Name) { $_.Name } else { "$_" } })
foreach ($bucket in @("extras", "nerd-fonts")) {
    if ($buckets -match "(^|\s)$bucket(\s|$)") {
        Write-Step "bucket $bucket" "skip" "added"
    } else {
        $code = Invoke-Native { scoop bucket add $bucket }
        if ($code -eq 0) { Write-Step "bucket $bucket" "done" "" }
        else { Write-Step "bucket $bucket" "FAILED" "scoop bucket add exit code $code" }
    }
}

# ---- 3. Programs -----------------------------------------------------------------
# name to install, command that proves it is there
$programs = @(
    @("git", "git"),
    @("extras/emacs", "emacs"),
    @("ripgrep", "rg"),
    @("fd", "fd"),
    @("pwsh", "pwsh")
)
foreach ($program in $programs) {
    $package = $program[0]
    $command = $program[1]
    if (Test-Command $command) {
        Write-Step $package "skip" "$command is on PATH"
    } else {
        $code = Invoke-Native { scoop install $package }
        if ($code -eq 0 -and (Test-Command $command)) { Write-Step $package "done" "" }
        elseif ($code -eq 0) { Write-Step $package "done" "installed; $command may need a new window" }
        else { Write-Step $package "FAILED" "scoop install exit code $code" }
    }
}

# ---- 4. The fork -----------------------------------------------------------------
$forkDir = Join-Path $HomeDir ".emacs.d"
if (-not (Test-Command "git")) {
    Write-Step "fork" "FAILED" "git is not on PATH yet; open a new window and run this script again"
} elseif (-not (Test-Path $forkDir)) {
    $code = Invoke-Native { git clone $ForkUrl $forkDir }
    if ($code -eq 0) { Write-Step "fork" "done" "cloned to $forkDir" }
    else { Write-Step "fork" "FAILED" "git clone exit code $code" }
} elseif (Test-Path (Join-Path $forkDir ".git")) {
    $remote = Get-NativeOutput { git -C $forkDir remote get-url origin }
    # The old name emacs.d-nn counts too: GitHub redirects it, and a clone made before the
    # rename still has it.  The earlier configuration is emacs.d.old now, and does not match.
    # The URL alone is not enough: a clone of the earlier configuration made from the emacs.d URL
    # has the same URL. Only this configuration has user-lisp\init-local.el.
    if (($remote -match 'marcuslannister/emacs\.d(-nn)?(\.git)?/?$') -and (Test-Path (Join-Path $forkDir "user-lisp\init-local.el"))) {
        $out = Get-NativeOutput { git -C $forkDir pull --ff-only }
        if ($LASTEXITCODE -ne 0) { Write-Step "fork" "FAILED" "git pull --ff-only: $out" }
        elseif ($out -match "Already up to date") { Write-Step "fork" "skip" "up to date" }
        else { Write-Step "fork" "done" "pulled" }
    } else {
        Write-Step "fork" "FAILED" "$forkDir is a Git clone of $remote, not of the fork. Move or rename it yourself, then run this script again. The script never moves it."
    }
} else {
    Write-Step "fork" "FAILED" "$forkDir exists and is not a Git clone. Move or rename it yourself, then run this script again. The script never moves it."
}

# ---- 5. auto-save ----------------------------------------------------------------
$autoSaveDir = Join-Path $HomeDir "github\auto-save"
if (Test-Path $autoSaveDir) {
    Write-Step "auto-save" "skip" $autoSaveDir
} elseif (-not (Test-Command "git")) {
    Write-Step "auto-save" "FAILED" "git is not on PATH yet"
} else {
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $autoSaveDir))
    $code = Invoke-Native { git clone $AutoSaveUrl $autoSaveDir }
    if ($code -eq 0) { Write-Step "auto-save" "done" $autoSaveDir }
    else { Write-Step "auto-save" "FAILED" "git clone exit code $code" }
}

# ---- 6. Fonts --------------------------------------------------------------------
$installed = Get-NativeOutput { scoop list }
if ($installed -match "NerdFontsSymbolsOnly") {
    Write-Step "NerdFontsSymbolsOnly" "skip" "installed"
} else {
    $code = Invoke-Native { scoop install nerd-fonts/NerdFontsSymbolsOnly }
    if ($code -eq 0) { Write-Step "NerdFontsSymbolsOnly" "done" "" }
    else { Write-Step "NerdFontsSymbolsOnly" "FAILED" "scoop install exit code $code" }
}

$fontKeys = @("HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts",
              "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")
function Test-FontInstalled {
    param([string]$Pattern)
    foreach ($key in $fontKeys) {
        if ((Get-ItemProperty $key -ErrorAction SilentlyContinue).PSObject.Properties.Name -match $Pattern) {
            return $true
        }
    }
    return $false
}
# The fork uses Aporetic Sans Mono first on Windows, and MonoLisa second.
if ($FontDir -ne "") {
    $files = @(Get-ChildItem -Path $FontDir -Filter "*.ttf" -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-Step "fonts from -FontDir" "FAILED" "no .ttf files in $FontDir"
    } else {
        $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        [void](New-Item -ItemType Directory -Force -Path $fontDir)
        $userKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        $count = 0
        foreach ($file in $files) {
            $target = Join-Path $fontDir $file.Name
            if (-not (Test-Path $target)) {
                Copy-Item -Path $file.FullName -Destination $target
                New-ItemProperty -Path $userKey -Name ($file.BaseName + " (TrueType)") -Value $target -PropertyType String -Force | Out-Null
                $count++
            }
        }
        if ($count -gt 0) { Write-Step "fonts from -FontDir" "done" "$count files for the current user" }
        else { Write-Step "fonts from -FontDir" "skip" "all files are already there" }
    }
}
if (Test-FontInstalled "Aporetic") {
    Write-Step "Aporetic Sans Mono" "skip" "installed"
} else {
    Write-Step "Aporetic Sans Mono" "skip" "not installed (the default font on Windows). Download it from https://github.com/protesilaos/aporetic, then run this script with -FontDir <folder of the .ttf files>"
}
if (Test-FontInstalled "MonoLisa") {
    Write-Step "MonoLisa" "skip" "installed"
} else {
    Write-Step "MonoLisa" "skip" "not installed (the second choice; it is licensed). Optional: run this script with -FontDir <folder of its .ttf files>"
}

# ---- 7. Herdr --------------------------------------------------------------------
if (Test-Command "herdr") {
    Write-Step "herdr" "skip" "on PATH"
} else {
    Write-Step "herdr" "skip" "not on PATH. It is optional: install the Windows build of Herdr and put herdr.exe on PATH, then the fork finds it"
}

# ---- 8. Anvil bridge command -----------------------------------------------------
# MCP clients (Codex, Pi, Claude Code) cannot run a .sh file, so they start a small command
# file that runs the bridge of Anvil with the bash of Git.  Anvil writes the bridge to the
# config root (anvil-stdio.sh) at its first start.  The command file is never overwritten.
function Find-GitBash {
    # git --exec-path prints <Git folder>\<toolchain>\libexec\git-core, so the Git folder is
    # three folders up, and bash.exe is in its bin folder.  Get-Command git does not help:
    # the Scoop shim for git.exe is not in the Git folder.
    if (-not (Test-Command "git")) { return $null }
    $exec = Get-NativeOutput { git --exec-path }
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($exec)) { return $null }
    $root = [IO.Path]::GetFullPath((Join-Path $exec "..\..\.."))
    # A Scoop version folder goes away at the next update. Its "current" link stays.
    $current = $root -replace '(\\apps\\git\\)[^\\]+$', '${1}current'
    if (Test-Path (Join-Path $current "bin\bash.exe")) { $root = $current }
    $bash = Join-Path $root "bin\bash.exe"
    if (Test-Path $bash) { return $bash }
    return $null
}

function Test-PathEntry {
    param([string]$Dir, [string]$PathValue)
    foreach ($entry in ($PathValue -split ";")) {
        if ($entry.Trim().TrimEnd("\") -ieq $Dir.TrimEnd("\")) { return $true }
    }
    return $false
}

$binDir = Join-Path $HomeDir ".local\bin"
$cmdFile = Join-Path $binDir "anvil-stdio.cmd"
if (Test-Path $cmdFile) {
    Write-Step "anvil-stdio.cmd" "skip" "$cmdFile exists, so the script leaves it alone"
} else {
    $bash = Find-GitBash
    $bridge = Join-Path $forkDir "anvil-stdio.sh"
    if (-not $bash) {
        Write-Step "anvil-stdio.cmd" "FAILED" "no bin\bash.exe next to the Git on PATH. Make the file yourself: see the Anvil section of docs/windows-setup.md"
    } else {
        $text = "@echo off`r`n`"$bash`" `"$bridge`" %*`r`n"
        if ($text -match '[^\x00-\x7F]') {
            Write-Step "anvil-stdio.cmd" "FAILED" "a path has characters that are not ASCII. Make the file yourself: see the Anvil section of docs/windows-setup.md"
        } else {
            [void](New-Item -ItemType Directory -Force -Path $binDir)
            [IO.File]::WriteAllText($cmdFile, $text, (New-Object System.Text.ASCIIEncoding))
            Write-Step "anvil-stdio.cmd" "done" $cmdFile
        }
    }
}

# The clients start the file by its name, so its folder must be on PATH.
# Read the user PATH as stored. Reading it expanded and writing it back would replace every
# %VARIABLE% in it with its value. The stored value also shows an entry that a first run of
# this script added, when this window still has the old PATH.
$envKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment")
$rawPath = [string]$envKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$envKey.Close()
if ((Test-PathEntry $binDir $env:PATH) -or (Test-PathEntry $binDir $rawPath)) {
    Write-Step "PATH $binDir" "skip" "already on PATH"
} elseif ($rawPath.Contains("%")) {
    Write-Step "PATH $binDir" "skip" "your user PATH has %VARIABLES%, so the script leaves it alone. Add $binDir to it yourself, or give the clients the full path $cmdFile"
} else {
    $newPath = if ($rawPath -eq "") { $binDir } else { $rawPath.TrimEnd(";") + ";" + $binDir }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    $env:PATH = $env:PATH.TrimEnd(";") + ";" + $binDir
    Write-Step "PATH $binDir" "done" "added to the user PATH (open a new window)"
}

# ---- 9. Next steps ---------------------------------------------------------------
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Start Emacs. The first start installs the packages and can take several minutes."
Write-Host "  2. Run M-x ghostel, and pick Download when it asks for the native module."
Write-Host "  3. Reach the running Emacs from a shell with:  emacsclient -n <file>"
Write-Host "  4. Anvil (the AI tools) starts with Emacs. The clients start $cmdFile. Add the Codex or Pi entries from the Anvil section of docs/windows-setup.md."
Write-Host "  5. If HOME or PATH was changed above, open a new window before you start Emacs."
Write-Host "  6. For Markdown styling, run scoop install gcc, then follow the Markdown grammars section of README.org once in Emacs, then restart Emacs. See also the Markdown grammars section of docs/windows-setup.md."

if ($script:Failures -gt 0) {
    Write-Host ""
    Write-Host "$script:Failures step(s) FAILED. Fix the cause and run this script again."
    exit 1
}
exit 0
