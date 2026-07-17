# Changelog

Notable changes to this Emacs configuration, newest first. Loosely follows
[Keep a Changelog](https://keepachangelog.com/); this config rolls
continuously, so changes land under "Unreleased".

## Unreleased

### Fixed
- Start Dired buffers in Hel Normal state so `SPC` leader bindings and `hjkl` navigation remain available.
- Set `supertag-data-directory` before `(require 'org-supertag)` in `lisp/init-local-org.el` so `supertag-db-file` derives the synced `~/org/org-supertag/` path at load time; the late setq had let it freeze at the default and load a stale local DB on machines with a leftover `~/.emacs.d/org-supertag/supertag-db.el`.

### Added
- Leader bindings for org-supertag under `SPC s` (search, add/remove tag, table/node/kanban/schema views, capture, reference, full rescan), with which-key labels.

### Changed
- Replace Meow with Hel, installed at a pinned Git commit through a shared GUI/TUI async-installer bootstrap, while preserving the personal `SPC` leader map in Hel Normal and Emacs states.
- Render org-supertag inline `#tags` as plain bold text (`org-priority` color, heading-matched height via font-lock `prepend`) instead of SVG pill badges, by disabling `supertag-svg-tag-enable` and restyling `supertag-inline-face` in `lisp/init-local-org.el`.
- Bump bundled `anvil.el` to **v1.3.0** and drop the now-extracted `ide` module from `anvil-optional-modules`.
- Source the anvil MCP stdio bridge (`anvil-stdio.sh`) via `M-x anvil-server-install` into `~/.emacs.d/` as a gitignored per-machine artifact, instead of tracking a vendored copy.
- Document the anvil version-bump procedure inline in `lisp/package-list.el`.
