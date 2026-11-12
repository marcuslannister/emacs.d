# Windows setup

## New Windows PC

On a new Windows 10 or 11 PC, download the setup script and run it. It works in Windows PowerShell 5.1 and in PowerShell 7:

```powershell
irm https://raw.githubusercontent.com/marcuslannister/emacs.d-nn/refs/heads/main/scripts/windows-setup.ps1 -OutFile windows-setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows-setup.ps1
```

The URL has `refs/heads/main` because the Upstream has a tag that is also named `main`.

The script does these steps. Each one checks first and skips work that is done, so a second run changes nothing. It prints `done`, `skip`, or `FAILED` with the reason for each step. It never deletes or overwrites, and it does not start Emacs.

- Sets the user variable `HOME` to your user folder, if it is not set. Emacs needs it before `early-init.el` runs. Open a new window after this step.
- Installs Scoop (with its official installer) when it is missing, and sets the execution policy to `RemoteSigned` for the current user.
- Adds the Scoop buckets `extras` and `nerd-fonts`.
- Installs `git`, `emacs`, `ripgrep`, `fd`, and `pwsh`, unless the command is already on `PATH`.
- Installs MSYS2 and the MINGW64 `gcc` and `libgccjit` (see Native compilation below). If MSYS2 asks for a restart of its shell, the step fails: run the script again.
- Clones this fork to `~\.emacs.d`, or runs `git pull --ff-only` when it is already the fork. If `~\.emacs.d` exists and is not a clone of the fork, the step fails and the script does not touch the folder: move it yourself.
- Clones `auto-save` to `~\github\auto-save`.
- Installs the Scoop font `NerdFontsSymbolsOnly`. The fork uses Aporetic Sans Mono first on Windows (from https://github.com/protesilaos/aporetic), and MonoLisa second (licensed). The script cannot download them: it tells you if one is missing. Download the font, then run the script with `-FontDir <folder of the .ttf files>` to install it for the current user.
- Makes `~\.local\bin\anvil-stdio.cmd`, the command that clients use to start the Anvil bridge (see the Anvil section), when it is missing. It writes the full path of the `bash.exe` of the Git on `PATH`. It never overwrites the file. It also adds `~\.local\bin` to the user `PATH` when it is missing. If that `PATH` has `%VARIABLES%`, the script leaves it alone and prints what to do.
- Prints a note about Herdr (optional) and the next steps.

Then start Emacs. The first start installs the packages and takes several minutes. Run `M-x ghostel` and pick Download. The server has the default name, so plain `emacsclient` reaches it. Anvil (the AI tools) starts with Emacs; see the Anvil section below to point Codex or Claude at it.

The steps below are the manual way, for a PC where you want to do it by hand.

Use the official GNU Emacs build from Scoop:

```powershell
scoop install extras/emacs
```

## Native compilation

The official build ships no `libgccjit`. It needs the MSYS2 MINGW64 toolchain. The UCRT64 toolchain does not work: its `libgccjit` crashes every native compile. Git for Windows has no compiler.

```powershell
scoop install msys2
```

Then open an MSYS2 shell (run `msys2`) and install the MINGW64 compiler and `libgccjit`:

```sh
pacman -Syu
pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-libgccjit
```

`pacman -Syu` updates MSYS2 first. If it says to close the shell, close it, open `msys2` again, and run both commands again.

`user-lisp/init-local-windows-native-comp.el`, loaded from `early-init.el`, finds `mingw64/bin` in Scoop's MSYS2, or in any MSYS2 install that has one of its `bin` folders on `PATH` (such as `ucrt64\bin` or `usr\bin`), and puts it first on the `PATH` of Emacs only. If it finds none, it turns native compilation off and shows a warning at startup. Emacs then runs packages as byte code.

To check a machine, start Emacs and look for a `windows-native-comp` warning in `*Warnings*`. No warning means the toolchain was found.

The ERT suites run with `emacs -Q`, which does not load this helper. On a machine whose `PATH` has only the UCRT64 toolchain, a test that stubs or advises a built-in function (such as `file-exists-p` or `upcase-region`) then fails with a `native-compiler-error`. Add `--eval "(setq native-comp-enable-subr-trampolines nil)"` before `-l` to run the suites there.

## Ghostel

Ghostel comes from MELPA. On the first `M-x ghostel`, pick Download. It fetches the Windows module, `conpty.dll` and OpenConsole into the Ghostel package folder. Do this once for each machine, and again when the package updates.

`user-lisp/init-local-ghostel.el` sets the shell. If `C:/Program Files/PowerShell/7/pwsh.exe` exists, Ghostel runs it with `-NoLogo`. PowerShell 7 is a native Windows program, so it reports `C:\` paths, which Claude Code and the native `git` and `rg` expect. The default, `cmd.exe`, is worse. PowerShell has no OSC-133 shell integration, so Ghostel does not mark prompts or follow the directory there.

For Unix-style work, run `M-x my/ghostel-bash`. It starts `bash.exe` from `PATH` as a login shell. Put the `usr/bin` folder of Git for Windows on `PATH` first. Do not use `git-bash.exe`, which opens a separate window.

Herdr works on Windows too when the `herdr` program is on `PATH` (the module sets it up on macOS and Windows, and does nothing elsewhere).

## Anvil

Anvil gives AI clients (Claude, Codex) tools that run inside Emacs. On Windows it starts by itself a moment after Emacs starts (`my/anvil-enabled` is on there). The `worker` and `org` modules are off.

The clients start a bridge script, `~\.emacs.d\var\anvil-stdio.sh`. Anvil copies it there the first time it runs, and `my/update-all-packages` refreshes it. The server has the default name, so the bridge needs no `--socket` option.

A client cannot run a `.sh` file by itself. It needs one small command file, `~\.local\bin\anvil-stdio.cmd`, with `~\.local\bin` on `PATH`. The setup script makes both when they are missing. To make them by hand, write the file:

```bat
@echo off
"C:\Program Files\Git\bin\bash.exe" "%USERPROFILE%\.emacs.d\var\anvil-stdio.sh" %*
```

The path of `bash.exe` depends on how Git was installed. The Git for Windows installer puts it at `C:\Program Files\Git\bin\bash.exe`. Scoop's Git puts it at `<Scoop folder>\apps\git\current\bin\bash.exe`. To find it for the Git on your `PATH`, run `git --exec-path` and go up three folders: `bin\bash.exe` is in that folder. Use the full path, not plain `bash`: on some PCs `bash` starts WSL.

Then point the client at the command. For Codex, in `~\.codex\config.toml`:

```toml
[mcp_servers.anvil]
command = "anvil-stdio.cmd"
args = [
    "--server-id=anvil",
    "--init-function=anvil-enable",
    "--stop-function=anvil-disable",
]

[mcp_servers.anvil.tools.emacs-eval]
approval_mode = "approve"

[mcp_servers.emacs-eval]
command = "anvil-stdio.cmd"
args = ["--server-id=emacs-eval"]
```

There are two servers because Anvil has two tool sets. `anvil` holds the eval tools (`emacs-eval` and its async partners). `emacs-eval` holds all other tools (files, Git, HTTP, and more). The `approval_mode` line is optional: it lets Codex run `emacs-eval` without asking. Other clients use the same command and arguments in their own config format.

The clients need a running Emacs: with none, the bridge waits about six seconds and then fails. When the bridge of the `anvil` server exits, it runs `anvil-disable`, so Anvil is off until a client connects again. Emacs does not need a restart for that.
