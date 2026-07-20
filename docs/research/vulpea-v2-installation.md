# Vulpea v2 installation in this Emacs configuration

Researched 2026-07-20 for [Map Vulpea v2 installation in this Emacs
configuration](https://github.com/marcuslannister/emacs.d/issues/3).

## Decision

Install Vulpea through this repository's existing `package.el` + MELPA path, from inside
`lisp/init-local-vulpea-task-table.el`. Do not add Vulpea to `package-list.el` or manually manage
its load path. The only required wiring outside the accepted single local module is one optional
require in `lisp/init-local.el`, immediately after `init-local-org`:

```elisp
(require 'init-local-org)
(require 'init-local-vulpea-task-table nil t)
```

That order matters: Vulpea computes its default sync directory from `org-directory` when it loads,
and this repo sets `org-directory` in `init-local-org`.[^getting-started] Loading the Task Table module
optionally also preserves startup if the local file is absent.

Inside the Task Table module:

1. Refuse initialization below Emacs 29.1 with a warning, not an error.
2. Set Vulpea variables before `(require 'vulpea)`.
3. Call `(maybe-require-package 'vulpea "2.6.0")`; only require and configure Vulpea when it
   succeeds.
4. Wrap the subsequent require and autosync activation in `condition-case`, reducing a Vulpea
   runtime failure to a warning so the rest of Emacs still starts.
5. Always provide `init-local-vulpea-task-table`. The command can report a clear `user-error` if
   Vulpea is unavailable.

Recommended baseline configuration:

```elisp
(setq vulpea-db-sync-directories
      (list (file-name-as-directory (expand-file-name org-directory)))
      vulpea-db-location
      (expand-file-name "var/vulpea/vulpea.db" user-emacs-directory)
      vulpea-db-index-heading-level t
      vulpea-db-sync-scan-on-enable 'async)

(cond
 ((version< emacs-version "29.1")
  (message "Vulpea disabled: Emacs 29.1 or newer required"))
 ((maybe-require-package 'vulpea "2.6.0")
  (condition-case err
      (progn
        (require 'vulpea)
        (vulpea-db-autosync-mode +1))
    (error
     (message "Vulpea unavailable: %S" err)))))
```

`var/` is already ignored by this repo, so the database and any WAL sidecars stay local and do not
dirty Git. Vulpea creates the database's parent directory itself.[^db-source] Explicitly setting
`vulpea-db-index-heading-level` documents a hard Task Table requirement: Tasks are ID-bearing Org
headings, and heading indexing is otherwise only an upstream default.[^db-source]

Enabling autosync is sufficient for first use. Its default async scan returns without blocking; an
empty database forces an initial async scan even if scanning were otherwise disabled.[^sync-source]
No startup-time call to the blocking full-scan API is needed.

## Why package.el, not async-installer

Vulpea's official installation path includes MELPA with `package.el`, and MELPA carries all required
Emacs dependencies.[^readme] This repo already adds MELPA and exposes `maybe-require-package`, which
catches install failures and returns nil instead of aborting startup.[^local-elpa] Therefore
package.el needs no new registry file or load-path code.

By contrast, this repo uses async-installer for Git packages and notes that multi-file Git packages
may need explicit dependency installation and startup load-path wiring.[^package-list] Adding Vulpea
there would require at least a `package-list.el` registration, dependency installation, and local
load-path setup. That is more wiring for no functional gain.

One tradeoff: this repo enables ordinary MELPA, not MELPA Stable. As of the research date, ordinary
MELPA offers snapshot `20260720.611`, while MELPA Stable offers release `2.6.0`.[^melpa-archive]
`maybe-require-package` will therefore install a current master snapshot, with `"2.6.0"` acting as a
minimum rather than a pin. Pinning the release would require adding and prioritizing MELPA Stable or
using the Git installer; neither is justified by the accepted smallest-wiring goal. If reproducible
release pinning becomes a requirement, that is a separate package-policy decision.

## Configuration boundaries

Keep the initial configuration narrow:

- Index only the configured `org-directory` explicitly.
- Store the database under ignored local `var/`, not the synced Org tree. Full async extraction uses
  SQLite WAL sidecars and upstream warns that mode is unsuitable for a database on a network
  filesystem.[^async-config]
- Preserve Vulpea's default `temp-buffer` parse method and plain-link indexing for the first
  implementation. Changing either affects every future Vulpea consumer, not only the Task Table.
- Enable heading indexing and autosync; both directly serve the accepted Task model.
- Run `M-x vulpea-doctor` after installation. Upstream documents it as the end-to-end configuration
  and performance check.[^readme]

Do **not** enable `vulpea-db-async-extraction` in this installation decision yet. A custom Task
extractor may need Org AST data. Vulpea disables async extraction globally for AST-reading
extractors, while a non-AST extractor needs explicit `:worker-safe` and `:worker-lib` declarations to
run inside a `full` worker.[^async-config] The Task data/API research and later architecture ticket
should decide this after choosing whether a custom extractor is needed. At the current collection
size (31 Org files), correctness-first defaults do not threaten the accepted table latency target.

## Compatibility and dependency health

The operational minimum is **Emacs 29.1**. Vulpea's README still says Emacs 27.2+, but the v2.6.0
`Package-Requires` header and both MELPA archives require 29.1.[^readme][^package-header][^melpa-archive]
Package metadata is what `package.el` enforces, and upstream CI currently tests Emacs 30.2 and the
snapshot build, so 29.1 is the safe declared floor.[^ci] This repo advertises Emacs 27.1 support;
the explicit version gate plus optional initialization preserves that broader startup contract.
The target workstation reports Emacs 31.0.50, so it is compatible.

Required package dependencies at v2.6.0 are Org 9.4.4+, EmacSQL 4.3.0+, `s` 1.12+, and Dash
2.19+.[^package-header] Current MELPA metadata satisfies all four: the archive has EmacSQL
`20260601.1722`, `s` `20220902.1511`, and Dash `20260221.1346`; MELPA Stable has EmacSQL 4.4.1,
`s` 1.13.0, and Dash 2.20.0.[^melpa-archive] `package.el` resolves these transitively. EmacSQL's
repository was updated in June 2026, `s.el` in May 2026, and Dash in February 2026; all repositories
remain unarchived.[^emacsql-health][^s-health][^dash-health] No dependency-health blocker found.

`fd` and `fswatch` are optional, not load requirements. Vulpea falls back from `fswatch` to polling
and from `fd` to a slower file finder; upstream strongly recommends both for external-change
detection and scan speed.[^readme] Both executables are present on the target workstation.

## Upstream activity

Vulpea is actively maintained. v2.6.0 shipped on 2026-07-10, after v2.5.0 on 2026-07-02, v2.4.0 on
2026-06-19, and v2.3.0 on 2026-06-12.[^releases] Master received code and documentation commits on
2026-07-20, and the corresponding CI runs passed.[^commits][^runs] Fast release cadence increases
the value of the guarded startup path and reinforces that a release pin, if later desired, should be
an explicit policy choice.

## Verification for implementation

After implementation:

1. Start with Vulpea absent and network unavailable; `./test-startup.sh` must still pass with a
   warning.
2. Start on Emacs 29.1+ with packages available; confirm `vulpea-version`,
   `vulpea-db-sync-directories`, `vulpea-db-location`, and `vulpea-db-autosync-mode`.
3. Confirm `var/vulpea/vulpea.db` exists and `git status -sb` remains clean.
4. Run `M-x vulpea-doctor` and a full scan once; verify indexed ID-bearing headings.
5. Run `./test-startup.sh` again and the Task Table's focused tests.

[^getting-started]: [Vulpea v2.6.0 Getting Started: directory setup](https://github.com/d12frosted/vulpea/blob/v2.6.0/docs/getting-started.org#step-1-configure-directories)
[^readme]: [Vulpea v2.6.0 README: quick start, installation, and dependencies](https://github.com/d12frosted/vulpea/blob/v2.6.0/README.org)
[^package-header]: [Vulpea v2.6.0 package header](https://github.com/d12frosted/vulpea/blob/v2.6.0/vulpea.el#L1-L9)
[^db-source]: [Vulpea v2.6.0 database settings and initialization](https://github.com/d12frosted/vulpea/blob/v2.6.0/vulpea-db.el)
[^sync-source]: [Vulpea v2.6.0 autosync settings and startup](https://github.com/d12frosted/vulpea/blob/v2.6.0/vulpea-db-sync.el)
[^async-config]: [Vulpea v2.6.0 configuration: async extraction and plugins](https://github.com/d12frosted/vulpea/blob/v2.6.0/docs/configuration.org#async-extraction)
[^ci]: [Vulpea CI matrix](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/.github/workflows/main.yml)
[^melpa-archive]: [MELPA archive metadata](https://melpa.org/packages/archive-contents) and [MELPA Stable archive metadata](https://stable.melpa.org/packages/archive-contents), checked 2026-07-20; [Vulpea's MELPA recipe](https://github.com/melpa/melpa/blob/master/recipes/vulpea) tracks `d12frosted/vulpea`.
[^local-elpa]: This repo's [MELPA and optional-install helper](../../lisp/init-elpa.el).
[^package-list]: This repo's [Git package registry and multi-file package note](../../lisp/package-list.el).
[^emacsql-health]: [magit/emacsql repository activity](https://github.com/magit/emacsql), checked 2026-07-20.
[^s-health]: [magnars/s.el repository activity](https://github.com/magnars/s.el), checked 2026-07-20.
[^dash-health]: [magnars/dash.el repository activity](https://github.com/magnars/dash.el), checked 2026-07-20.
[^releases]: [Vulpea releases](https://github.com/d12frosted/vulpea/releases).
[^commits]: [Vulpea master commits](https://github.com/d12frosted/vulpea/commits/master/).
[^runs]: [Vulpea CI runs](https://github.com/d12frosted/vulpea/actions/workflows/main.yml).
