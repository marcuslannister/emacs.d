# Windows setup

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

Herdr is macOS only, so Windows skips it.
