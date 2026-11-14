# Windows setup

## New Windows PC

On a new Windows 10 or 11 PC, download the setup script and run it. It works in Windows PowerShell 5.1 and in PowerShell 7:

```powershell
irm https://raw.githubusercontent.com/marcuslannister/emacs.d/refs/heads/main/scripts/windows-setup.ps1 -OutFile windows-setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows-setup.ps1
```

The URL has `refs/heads/main` because the Upstream has a tag that is also named `main`.

The script does these steps. Each one checks first and skips work that is done, so a second run changes nothing. It prints `done`, `skip`, or `FAILED` with the reason for each step. It never deletes or overwrites, and it opens no Emacs window.

- Sets the user variable `HOME` to your user folder, if it is not set. Emacs needs it before `early-init.el` runs. Open a new window after this step.
- Installs Scoop (with its official installer) when it is missing, and sets the execution policy to `RemoteSigned` for the current user.
- Adds the Scoop buckets `extras` and `nerd-fonts`.
- Installs `git`, `emacs`, `ripgrep`, `fd`, and `pwsh`, unless the command is already on `PATH`.
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

On Windows, the fork loads byte code only. `user-lisp/init-local-windows-native-comp.el`, loaded from `early-init.el`, turns off JIT compilation and subr trampolines, and points `native-comp-eln-load-path` to a folder with no `.eln` file. So Emacs loads no `.eln` file, not even the ones that its own build ships. Windows Defender scans each `.eln` file as a DLL when Emacs loads it. On one machine, loading `org`, `org-agenda`, `transient`, and `vc-git` took 8.6 s with `.eln` files and 0.6 s with byte code (see ADR 0001). macOS and Linux keep JIT native compilation.

You do not need `libgccjit` or MSYS2 for the fork, and the setup script installs neither.

The ERT suites run with `emacs -Q`, which does not load this helper. If the `PATH` still has a GCC toolchain from an earlier setup (such as UCRT64 only), a test that stubs or advises a built-in function (such as `file-exists-p` or `upcase-region`) then fails with a `native-compiler-error`. Add `--eval "(setq native-comp-enable-subr-trampolines nil)"` before `-l` to run the suites there.

## Markdown grammars

`.md` files need two tree-sitter grammars, and Emacs builds them from source with a C compiler. The fork installs no compiler, so on each new PC run `scoop install gcc`, then follow the "Markdown grammars" section of `README.org` (a snippet that you run once in Emacs), then restart Emacs. Run `scoop uninstall gcc` afterward if you want no compiler on the `PATH`. The grammars stay in `~\.emacs.d\tree-sitter`.

## Ghostel

Ghostel comes from MELPA. On the first `M-x ghostel`, pick Download. It fetches the Windows module, `conpty.dll` and OpenConsole into the Ghostel package folder. Do this once for each machine, and again when the package updates.

`user-lisp/init-local-ghostel.el` sets the shell. If `C:/Program Files/PowerShell/7/pwsh.exe` exists, Ghostel runs it with `-NoLogo`. PowerShell 7 is a native Windows program, so it reports `C:\` paths, which Claude Code and the native `git` and `rg` expect. The default, `cmd.exe`, is worse. PowerShell has no OSC-133 shell integration, so Ghostel does not mark prompts or follow the directory there.

For Unix-style work, run `M-x my/ghostel-bash`. It starts `bash.exe` from `PATH` as a login shell. Put the `usr/bin` folder of Git for Windows on `PATH` first. Do not use `git-bash.exe`, which opens a separate window.

Herdr works on Windows too when the `herdr` program is on `PATH` (the module sets it up on macOS and Windows, and does nothing elsewhere).

## Anvil

Anvil gives AI clients (Claude, Codex) tools that run inside Emacs. It starts by itself a moment after Emacs starts (`my/anvil-enabled` is on). The `worker` module is on: it keeps four helper Emacs daemons with fixed names. An Emacs that runs as administrator gets no worker daemons ("not a safe directory", because Administrators own the server folder), so start Emacs as a normal user. The `org` module is off.

The clients start a bridge script, `~\.emacs.d\anvil-stdio.sh`, in the config root. Git ignores it. Anvil copies it there the first time it runs, and `my/update-all-packages` refreshes it. The server has the default name, so the bridge needs no `--socket` option.

A client cannot run a `.sh` file by itself. It needs one small command file, `~\.local\bin\anvil-stdio.cmd`, with `~\.local\bin` on `PATH`. The setup script makes both when they are missing. To make them by hand, write the file:

```bat
@echo off
"C:\Program Files\Git\bin\bash.exe" "%USERPROFILE%\.emacs.d\anvil-stdio.sh" %*
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
