# Changelog

Notable changes to this Emacs configuration, newest first. Loosely follows
[Keep a Changelog](https://keepachangelog.com/); this config rolls
continuously, so changes land under "Unreleased".

## Unreleased

### Added
- Meow leader bindings for org-supertag under `SPC s` (search, add/remove tag, table/node/kanban/schema views, capture, reference, full rescan), with which-key labels.

### Changed
- Bump bundled `anvil.el` to **v1.3.0** and drop the now-extracted `ide` module from `anvil-optional-modules`.
- Source the anvil MCP stdio bridge (`anvil-stdio.sh`) via `M-x anvil-server-install` into `~/.emacs.d/` as a gitignored per-machine artifact, instead of tracking a vendored copy.
- Document the anvil version-bump procedure inline in `lisp/package-list.el`.
