# Repository Guidelines

This repository is a fork of `zHaOdANiuu/.emacs.d` (the Base). The user's own modules are the Local layer. Read `CONTEXT.md` for these terms and `docs/adr/0001-fork-b-as-base.md` for the reasons.

## Project Structure
- `early-init.el`, `init.el`, `nn.el`, `user-lisp/init-*.el`, `user-lisp/local/`, `snippets/`: Base files.
- `user-lisp/init-local*.el`: the Local layer. All new Lisp configuration goes here. Scripts, workflows, tests, and docs live elsewhere.
- `user-lisp/custom.el`: machine-local values (name, mail, SMTP, `org-directory`). Git ignores it. Never commit it.
- `elpa/`, `var/`, `eln-cache/`, `tree-sitter/`, `server/`: generated state. Git ignores them. Do not edit them.
- `var/external-packages/`: the pinned Git packages that `async-installer` clones. The pins (a tag each) are in `user-lisp/init-local-package-list.el`. Do not bump a tag unless the task says so.

## Changing Base files
- Make only removals and value changes.
- Mark each hunk with a `;; emacs.d-nn:` comment.
- There are two exceptions, and each adds one line. The first is a single `(require 'init-local)` line in `init.el`. It loads the Local layer. It is also the one eager `require` that the Concept rules allow.
- The second exception is a single `(load ...)` line in `early-init.el`, on Windows only. It loads `user-lisp/init-local-windows-native-comp.el` before package activation. `init-local` is too late for it, because package activation can start a native compile.
- `user-lisp/init-local.el` loads each Local module. Load a module there with `require` only if it must be ready before the first command (the case guard, the PATH import). Other modules keep a deferred `use-package` form.
- Do not copy code from the Purcell-derived files of the earlier configuration. This fork is GPL-3.0. Write the same idea again in your own words.

## Build, Test, and Development Commands
- `./test-startup.sh`: loads the config in batch Emacs, in the order of `startup.el`. It runs the startup hooks and the Base's deferred hooks, then prints the startup warnings. `EMACS=/path/to/emacs ./test-startup.sh` uses another binary. The checks that run after startup live in `tests/startup/checks.el`, not in the script: a subfolder, so the CI loop over `tests/*.el` does not run it as an ERT file. Add a new startup check there.
- `emacs -Q --batch -l tests/<file>.el -f ert-run-tests-batch-and-exit`: run one ERT file. A module brings its tests in the same commit. A test that needs an installed package (the `async-installer` tests) reads it from `elpa/`, so run `./test-startup.sh` first.
- A test that stubs a function with `cl-letf` must load that function's file first. `display-warning` and `package-vc-install` start as autoloads, and their first call replaces the stub.
- Run only one Emacs with this configuration. A second process takes the same server name and the same Anvil worker names, and it breaks the first one. Test a change in batch Emacs (`./test-startup.sh`, the ERT files), not in a second GUI Emacs. Never load fork files into an Emacs session that runs another configuration.
- A plain `emacs --batch --init-directory DIR` does not load the init files. Use `./test-startup.sh`.

## Coding Style
- Use `lexical-binding: t`, two-space indent, and lines of at most 100 columns.
- Name new modules `init-local-<feature>.el`.
- The Base uses `nn-` for its framework and `my-` for helper commands. The Local layer uses `my/`. Prefix every new function and variable in the Local layer with `my/`.
- Follow the Concept rules: small modules, built-in features first, a package only if used weekly, deferred loading with no eager `require`. Named exceptions are in the ADR.
- Leader keys (the Hel leader) live in one table, `my/hel-leader-bindings`. The module that owns a command adds its keys with `my/hel-leader-bind`. A key must not point at a command that this config does not have: `./test-startup.sh` checks every entry.
- The Base sets `use-package-always-defer t`. A form that must run at startup needs `:demand t`.
- Write `use-package` forms. Do not add `require-package` or `maybe-require-package`.

## Configuration and Safety
- The config needs Emacs 31.1 or later.
- The Emacs server has the default name `server` (`my/server-name`), so plain `emacsclient` reaches it. Close any other Emacs first (for example the earlier configuration): a second server of the same name does not start.
- Anvil runs on `darwin` and `windows-nt` (`my/anvil-systems`) and starts by itself (`my/anvil-enabled`). Keep its `org` module off. Its `worker` module is on. The worker daemons have fixed names (`anvil-worker-read-1` and so on), so only one Emacs configuration may run them.
- The Anvil bridge script `anvil-stdio.sh` lives in the config root, where the MCP clients look for it. Anvil copies it there when it is missing, and `.gitignore` lists it.
- Guard macOS-only code (the PATH import) with `(eq system-type 'darwin)`.
- Keep the Base's Windows settings. Every ported module must start on Windows with no error.
- A module that needs a tool, file, or folder from this machine (`rg`, `herdr`, `~/github/...`) must skip itself and call `display-warning`. It must never stop startup.

## Testing
- Run `./test-startup.sh` before every commit. CI runs it on macOS and Windows with Emacs 31.1. Both jobs use GUI builds, which are the builds we run.
- The Base sets `inhibit-message` at startup, so a warning is quiet until `window-setup-hook` runs. `./test-startup.sh` runs that hook and prints `*Warnings*`. Read that output.
- The test skips `kill-emacs-hook`, so a run does not overwrite the history files in `var/`.

## Commits and Pull Requests
- Use Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`). One module or behavior change for each commit. Put the reason in the message body.
- Do not put personal identifiers in any file or commit message: home paths, account names, real names, or email addresses. The privacy guard blocks them. Never bypass it.
- Merge Upstream about once a month. Review the full diff first.

## Agent skills
- Issue tracker: Kanzo project `emacs-nn`. Do not use GitHub issues.
- Triage labels: none.
- Domain docs: one context. `CONTEXT.md` and `docs/adr/` at the repository root.
