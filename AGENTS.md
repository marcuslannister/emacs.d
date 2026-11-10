# Repository Guidelines

This repository is a fork of `zHaOdANiuu/.emacs.d` (the Base). The user's own modules are the Local layer. Read `CONTEXT.md` for these terms and `docs/adr/0001-fork-b-as-base.md` for the reasons.

## Project Structure
- `early-init.el`, `init.el`, `nn.el`, `user-lisp/init-*.el`, `user-lisp/local/`, `snippets/`: Base files.
- `user-lisp/init-local*.el`: the Local layer. All new Lisp configuration goes here. Scripts, workflows, tests, and docs live elsewhere.
- `user-lisp/custom.el`: machine-local values (name, mail, SMTP, `org-directory`). Git ignores it. Never commit it.
- `elpa/`, `var/`, `eln-cache/`, `tree-sitter/`, `server/`: generated state. Git ignores them. Do not edit them.

## Changing Base files
- Make only removals and value changes.
- Mark each hunk with a `;; emacs.d-nn:` comment.
- The one exception is a single `(require 'init-local)` line in `init.el`. It loads the Local layer. It is also the one eager `require` that the Concept rules allow.
- Do not copy code from the Purcell-derived files of the earlier configuration. This fork is GPL-3.0. Write the same idea again in your own words.

## Build, Test, and Development Commands
- `./test-startup.sh`: loads the config in batch Emacs, in the order of `startup.el`. It runs the startup hooks and the Base's deferred hooks, then prints the startup warnings. `EMACS=/path/to/emacs ./test-startup.sh` uses another binary.
- `emacs -Q --batch -l tests/<file>.el -f ert-run-tests-batch-and-exit`: run one ERT file. A module brings its tests in the same commit.
- To try the fork next to another Emacs, start a separate process: `open -n -a Emacs --args --init-directory ~/Projects/emacs.d-nn`. Never load fork files into another Emacs session.
- A plain `emacs --batch --init-directory DIR` does not load the init files. Use `./test-startup.sh`.

## Coding Style
- Use `lexical-binding: t`, two-space indent, and lines of at most 100 columns.
- Name new modules `init-local-<feature>.el`.
- The Base uses `nn-` for its framework and `my-` for helper commands. The Local layer uses `my/`. Prefix every new function and variable in the Local layer with `my/`.
- Follow the Concept rules: small modules, built-in features first, a package only if used weekly, deferred loading with no eager `require`. Named exceptions are in the ADR.
- The Base sets `use-package-always-defer t`. A form that must run at startup needs `:demand t`.
- Write `use-package` forms. Do not add `require-package` or `maybe-require-package`.

## Configuration and Safety
- The config needs Emacs 31.1 or later.
- Guard macOS-only code (Herdr, Anvil, the PATH import) with `(eq system-type 'darwin)`.
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
