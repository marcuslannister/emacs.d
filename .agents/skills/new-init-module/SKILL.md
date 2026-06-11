---
name: new-init-module
description: "Scaffold a new init-*.el config module and wire up its require + package deps"
---

# new-init-module

Scaffold a new Emacs config module in `lisp/` following this repo's conventions, then
register it so it actually loads. Removes the create-file + header + footer + require
boilerplate.

## When to use

User wants to add a new feature/language/integration as its own `lisp/init-*.el` file.

## Inputs to determine first

1. **Module name** — `<name>` is the bare slug (e.g. `foo`). The module kind decides the
   full feature symbol `<feature>`, which is then used identically in the filename, the
   `provide`, and the `require`:
   - Personal/machine-specific customization → `<feature>` = `init-local-<name>`, e.g.
     `lisp/init-local-foo.el`. Wired into `init-local.el`.
   - Upstream-style feature module → `<feature>` = `init-<name>`, e.g. `lisp/init-foo.el`.
     Wired into `init.el`.
   - If unclear which kind, ask. Then carry the *one* chosen `<feature>` through every step
     below — the skeleton, the `provide`, and the `require` must all use the same symbol
     (so a personal module is `init-local-foo` everywhere, never `init-foo`).
2. **Package deps** — none / ELPA package(s) / a git-hosted package.

## Steps

### 1. Create `lisp/<feature>.el`

Use this exact skeleton (match the purcell-style header used across `lisp/`). Substitute
the full `<feature>` symbol chosen above — `init-foo` for a feature module,
`init-local-foo` for a personal one:

```elisp
;;; <feature>.el --- <one-line description> -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

<body>

(provide '<feature>)
;;; <feature>.el ends here
```

- `lexical-binding: t` is mandatory — every module in this repo has it.
- Keep `;;; Commentary:` and `;;; Code:` markers; they satisfy checkdoc/byte-compile.

### 2. Pull package deps *inside the module* (not in init.el)

- **ELPA package, hard dependency:**
  ```elisp
  (when (maybe-require-package 'foo-mode)
    ...config...)
  ```
  Use `require-package` instead of `maybe-require-package` only when the module is
  useless without it and a failed install should be loud.
- **ELPA package, declarative config:** `use-package` with `:ensure t` is the common
  idiom in `init-local.el`.
- **Git-hosted package (not on ELPA):** add an entry to `lisp/package-list.el`:
  ```elisp
  (async-installer-git-add "https://github.com/OWNER/REPO.git"
                           :tag "vX.Y.Z"
                           :main "REPO.el")
  ```
  then `(require 'REPO)` from the module. `package-list.el` is **only** for git packages —
  never put `(require 'init-...)` lines there.

### 3. Register the module so it loads

Add `(require '<feature>)` — the exact same `<feature>` as the skeleton/`provide` — to the
right bootstrap file:

- **Feature module (`init-<name>`):** add `(require 'init-<name>)` to `init.el`, grouped
  with the related requires (languages near the other language modules, etc.). Use
  `(require 'init-<name> nil t)` if it should fail silently when absent.
- **Personal module (`init-local-<name>`):** add `(require 'init-local-<name>)` to
  `init-local.el`. Match the surrounding style — OS-specific or optional modules use the
  `nil t` form (e.g. `(require 'init-local-foo nil t)`).

### 4. Verify it compiles and loads

Byte-compile the new file (warnings are non-fatal here):

```bash
emacs -Q --batch -L lisp --eval "(byte-compile-file \"lisp/<feature>.el\")"
```

Then confirm startup still succeeds:

```bash
EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs ./test-startup.sh
```

Report any byte-compile warnings (unbound vars, missing `lexical-binding`, free vars) and
fix them before finishing.

## Notes

- Do **not** edit `init.el` outside the require block — it carries `no-byte-compile: t` and
  is excluded from compile-angel on purpose.
- Generated/state files (`custom.el`, `*.elc`, `recentf.eld`, `*.db`) are never hand-edited.
