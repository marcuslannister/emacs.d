# Changelog

Notable changes to this Emacs configuration, newest first. Loosely follows
[Keep a Changelog](https://keepachangelog.com/); this config rolls
continuously, so changes land under "Unreleased".

## Unreleased

### Fixed
- Load the MELPA `ghostel` (dakra) on macOS/Linux instead of the Windows-only kiennq fork. The Windows branch's `use-package :load-path` added the fork's checkout to `load-path` at macro-expansion time — and Emacs expands both arms of the `IS-WINDOWS` `if` when the file loads — so the fork shadowed the MELPA build on macOS/Linux and its native-module download 404'd against dakra's `.dylib`-only release assets. The Windows branch now adds the fork to `load-path` at runtime under `IS-WINDOWS`, which the `if` actually gates.
- Keep Dired `hjkl` as cursor and row movement in both Hel Normal and Emacs states; Dired still starts in Normal so `SPC` remains available.
- Set `supertag-data-directory` before `(require 'org-supertag)` in `lisp/init-local-org.el` so `supertag-db-file` derives the synced `~/org/org-supertag/` path at load time; the late setq had let it freeze at the default and load a stale local DB on machines with a leftover `~/.emacs.d/org-supertag/supertag-db.el`.

### Added
- Keep the complete Task Table usable during asynchronous synchronization, warn actionably on worker failures, and verify its single-query 5,000-Task pipeline against documented performance targets.
- Edit Task Table TODO state and Priority with `e`, writing through Org commands inside Vulpea's public note-sync helper and refreshing Open Tasks immediately.
- Preserve Task Table filters, native sort, launch scope, and Task-ID selection across manual and worker refreshes, with nearest-row/header fallbacks and atomic failure recovery.
- Navigate from Task Table rows by stable Org ID, refreshing and failing safely when a Task disappeared.
- Add guarded Vulpea/Vulpea UI indexing and the read-only `my/vulpea-task-table` Collection View for ID-bearing Open Tasks, with combinable ephemeral TODO, Priority, text, Source, and Org-launch filters.
- Leader bindings for org-supertag under `SPC s` (search, add/remove tag, table/node/kanban/schema views, capture, reference, full rescan), with which-key labels.

### Changed
- Add pinned `hel-leader` native key translation; keep Git on `SPC g`, move C-M- to `SPC G`, and move the former `SPC c` group to `SPC a`.
- Replace Meow with Hel, installed at a pinned Git commit through a shared GUI/TUI async-installer bootstrap, while preserving the personal `SPC` leader map in Hel Normal and Emacs states.
- Render org-supertag inline `#tags` as plain bold text (`org-priority` color, heading-matched height via font-lock `prepend`) instead of SVG pill badges, by disabling `supertag-svg-tag-enable` and restyling `supertag-inline-face` in `lisp/init-local-org.el`.
- Bump bundled `anvil.el` to **v1.3.0** and drop the now-extracted `ide` module from `anvil-optional-modules`.
- Source the anvil MCP stdio bridge (`anvil-stdio.sh`) via `M-x anvil-server-install` into `~/.emacs.d/` as a gitignored per-machine artifact, instead of tracking a vendored copy.
- Document the anvil version-bump procedure inline in `lisp/package-list.el`.
