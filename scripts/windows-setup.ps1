# windows-setup.ps1 - set up a new Windows PC for the emacs.d-nn fork.
#
# Run it in Windows PowerShell 5.1 or PowerShell 7:
#   powershell -NoProfile -ExecutionPolicy Bypass -File windows-setup.ps1
# Optional: -MonoLisaDir <folder with the MonoLisa .ttf files> installs that font for
# the current user (MonoLisa is licensed, so the script cannot download it).
#
# Each step checks first and skips work that is done, so a second run changes nothing.
# It never deletes or overwrites a file or folder, and it does not start Emacs.
# See docs/windows-setup.md.

param(
    [string]$MonoLisaDir = ""
)

$ErrorActionPreference = "Stop"
$script:Failures = 0
$ForkUrl = "https://github.com/marcuslannister/emacs.d-nn"
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

# ---- 4. MSYS2 and the MINGW64 toolchain -------------------------------------------
# Native compilation needs libgccjit of the MINGW64 toolchain, not UCRT64: its libgccjit
# crashes every native compile.  The helper of the fork puts mingw64\bin on the PATH of
# Emacs only.
function Find-Msys2Root {
    $candidates = @()
    $scoopRoot = $env:SCOOP
    if ([string]::IsNullOrEmpty($scoopRoot)) { $scoopRoot = Join-Path $env:USERPROFILE "scoop" }
    $candidates += (Join-Path $scoopRoot "apps\msys2\current")
    $candidates += "C:\msys64"
    foreach ($entry in ($env:PATH -split ";")) {
        if ($entry -match "^(.*[\\/]msys[^\\/]*)[\\/](usr|mingw64|ucrt64|clang64|mingw32)[\\/]bin[\\/]?$") {
            $candidates += $Matches[1]
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate "usr\bin\bash.exe")) { return $candidate }
    }
    return $null
}

$msysRoot = Find-Msys2Root
if (-not $msysRoot) {
    $code = Invoke-Native { scoop install msys2 }
    if ($code -eq 0) { $msysRoot = Find-Msys2Root }
    if ($msysRoot) { Write-Step "msys2" "done" $msysRoot }
    else { Write-Step "msys2" "FAILED" "scoop install msys2 did not give an MSYS2 folder" }
} else {
    Write-Step "msys2" "skip" $msysRoot
}
if ($msysRoot) {
    $dll = Join-Path $msysRoot "mingw64\bin\libgccjit-0.dll"
    if (Test-Path $dll) {
        Write-Step "mingw64 gcc + libgccjit" "skip" "found"
    } else {
        $bash = Join-Path $msysRoot "usr\bin\bash.exe"
        Write-Host "Installing the MINGW64 toolchain; the first MSYS2 start sets up its keyring."
        # The first update can ask to close the shell and run again, so update first, then
        # install; run this script again when the check below fails.
        [void](Invoke-Native { & $bash -lc "pacman -Syu --noconfirm" })
        $code = Invoke-Native { & $bash -lc "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-libgccjit" }
        if (Test-Path $dll) { Write-Step "mingw64 gcc + libgccjit" "done" "" }
        else { Write-Step "mingw64 gcc + libgccjit" "FAILED" "pacman exit code $code; MSYS2 may have asked for a restart, so run this script again" }
    }
}

# ---- 6. The fork -----------------------------------------------------------------
$forkDir = Join-Path $HomeDir ".emacs.d"
if (-not (Test-Command "git")) {
    Write-Step "fork" "FAILED" "git is not on PATH yet; open a new window and run this script again"
} elseif (-not (Test-Path $forkDir)) {
    $code = Invoke-Native { git clone $ForkUrl $forkDir }
    if ($code -eq 0) { Write-Step "fork" "done" "cloned to $forkDir" }
    else { Write-Step "fork" "FAILED" "git clone exit code $code" }
} elseif (Test-Path (Join-Path $forkDir ".git")) {
    $remote = Get-NativeOutput { git -C $forkDir remote get-url origin }
    if ($remote -match "marcuslannister/emacs\.d-nn") {
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

# ---- 7. auto-save ----------------------------------------------------------------
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

# ---- 8. Fonts --------------------------------------------------------------------
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
$monoLisaThere = $false
foreach ($key in $fontKeys) {
    if ((Get-ItemProperty $key -ErrorAction SilentlyContinue).PSObject.Properties.Name -match "MonoLisa") {
        $monoLisaThere = $true
    }
}
if ($monoLisaThere) {
    Write-Step "MonoLisa" "skip" "installed"
} elseif ($MonoLisaDir -ne "") {
    $files = @(Get-ChildItem -Path $MonoLisaDir -Filter "*.ttf" -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-Step "MonoLisa" "FAILED" "no .ttf files in $MonoLisaDir"
    } else {
        $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        [void](New-Item -ItemType Directory -Force -Path $fontDir)
        $userKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        foreach ($file in $files) {
            $target = Join-Path $fontDir $file.Name
            if (-not (Test-Path $target)) {
                Copy-Item -Path $file.FullName -Destination $target
                New-ItemProperty -Path $userKey -Name ($file.BaseName + " (TrueType)") -Value $target -PropertyType String -Force | Out-Null
            }
        }
        Write-Step "MonoLisa" "done" "$($files.Count) files for the current user"
    }
} else {
    Write-Step "MonoLisa" "skip" "not installed. It is licensed: buy it, then run this script with -MonoLisaDir <folder of the .ttf files>"
}

# ---- 9. Herdr --------------------------------------------------------------------
if (Test-Command "herdr") {
    Write-Step "herdr" "skip" "on PATH"
} else {
    Write-Step "herdr" "skip" "not on PATH. It is optional: install the Windows build of Herdr and put herdr.exe on PATH, then the fork finds it"
}

# ---- 10. Next steps --------------------------------------------------------------
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Start Emacs. The first start installs the packages and can take several minutes."
Write-Host "  2. Run M-x ghostel, and pick Download when it asks for the native module."
Write-Host "  3. Reach the running Emacs from a shell with:  emacsclient -n <file>"
Write-Host "  4. Anvil (the AI tools) is not on for Windows yet."
Write-Host "  5. If HOME was set above, open a new window before you start Emacs."

if ($script:Failures -gt 0) {
    Write-Host ""
    Write-Host "$script:Failures step(s) FAILED. Fix the cause and run this script again."
    exit 1
}
exit 0
