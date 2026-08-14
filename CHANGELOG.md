# Changelog

Notable changes to this Emacs configuration, newest first. Loosely follows
[Keep a Changelog](https://keepachangelog.com/); this config rolls
continuously, so changes land under "Unreleased".

## Unreleased

### Fixed
- Clone the missing async-installer Git packages from `ml-update-all-packages` in `lisp/init-local.el` before the update pass runs, and block that pass when a clone failed but left its directory behind. `async-installer-git--update-one` skips a package whose `external-packages/` directory is absent and counts it a failure, so a deleted clone never repaired itself. The install pass is no safer on its own: `async-installer-git--make-clone-script` runs `mkdir -p` before `git clone`, so a failed clone leaves an empty directory that `async-installer-git--install-one` accepts on `file-directory-p` alone, and the update pass then discards the exit status of `git pull` and `git checkout` and writes the target into `.gitcommit` regardless — after which every later run reports `Already at` and skips the package for good. The new `ml--async-installer-broken-clones` detects that shape and stops the chain. Both passes are asynchronous, so the install callback chains the update rather than running the two side by side.
- Require `init-local-hel`, `init-local-shell`, `blinko`, and `init-local-program` ahead of `init-local-ai` in `lisp/init-local.el`, with `(require 'init-local-ai nil t)` moved down to just above `(provide 'init-local)`. `lisp/init-local-ai.el` hard-requires `anvil`, so a missing `external-packages/anvil.el` clone raised `file-missing` and aborted `init-local.el` mid-load, taking Hel, Ghostel, and blinko down with it; the NOERROR flag on that `require` — and on `init.el`'s `(require 'init-local nil t)` — only covers a missing feature file, not an error signalled while loading one, so the breakage never reached `*Messages*`. With the AI module last, a broken Anvil clone costs only itself.
- Add `M-1`..`M-9` to `ghostel-keymap-exceptions` in `lisp/init-local-shell.el` so the global tab-bar tab-select bindings still reach Emacs from a Ghostel terminal; semi-char mode binds every `M-<printable>` to the terminal, and `ghostel-semi-char-mode-map` is rebuilt wholesale from the exceptions list, so the list — set with `customize-set-variable`, because the rebuild runs from the option's `:set` function — is the only durable place to register them. Char mode still sends `M-<digit>` to the terminal.
- Set `anvil-modules` and `anvil-optional-modules` before `anvil-enable` in `lisp/init-local-ai.el`, not after it. `anvil-enable` reads both to decide what to load, so it was seeing the defaults: `anvil-modules` defaults to a list that includes `org` (`anvil.el:62`), so the org module loaded despite being left out — 94 `anvil-org-*` functions were live and the org MCP tools were exposed, which is the race with interactive org buffers that the Syncthing sync-conflict entry below was meant to stop. `anvil-optional-modules` defaults to nil, so `xlsx`, `pdf`, `http`, `cron` and `browser` never loaded from this setting either.
- Set `diff-hl-dired-extra-indicators` to nil in `lisp/init-dired.el`. The ignored-files pass started a second Git process (`git ls-files -o -i`) whose buffer `diff-hl-dired-update` then killed while the process was still live, so every Dired refresh raised a repeating process-kill confirmation on Emacs 31; only the grey indicators for Git-ignored files are lost.
- Restore the legacy `SPC c` clock bindings through hel-leader's native Control translation.
- Keep Magit buffers in Hel Emacs state with mode-local `hjkl` movement, preserving all other Magit commands.
- Load the MELPA `ghostel` (dakra) on macOS/Linux instead of the Windows-only kiennq fork. The Windows branch's `use-package :load-path` added the fork's checkout to `load-path` at macro-expansion time — and Emacs expands both arms of the `IS-WINDOWS` `if` when the file loads — so the fork shadowed the MELPA build on macOS/Linux and its native-module download 404'd against dakra's `.dylib`-only release assets. The Windows branch now adds the fork to `load-path` at runtime under `IS-WINDOWS`, which the `if` actually gates.
- Keep Dired `hjkl` as cursor and row movement in both Hel Normal and Emacs states; Dired still starts in Normal so `SPC` remains available.
- Set `supertag-data-directory` before `(require 'org-supertag)` in `lisp/init-local-org.el` so `supertag-db-file` derives the synced `~/org/org-supertag/` path at load time; the late setq had let it freeze at the default and load a stale local DB on machines with a leftover `~/.emacs.d/org-supertag/supertag-db.el`.
- Drop `org` from `anvil-modules` in `lisp/init-local-ai.el`. The Anvil worker pool's org tools (`org-add-todo`, `org-update-todo-state`, etc.) wrote to `~/org` files independently of interactive Emacs buffers on the same files, racing with them and triggering repeated Syncthing sync-conflict storms on `ai.org`, `software.org`, `network.org`, and `refile.org`.

### Added
- Add org-gtd 4.6.1 as the capture/clarify/organize/engage process in `lisp/init-local-gtd.el`, pinned by Git tag in `lisp/package-list.el`. Topic files under `~/org/` stay the store; single actions and projects prompt for a heading, and `C-c c` / `C-c o e` / `C-c o k` open the command centre, engage, and clarify. The module installs org-gtd's ELPA dependencies, acknowledges 4.6.1 before load, refreshes `org-agenda-files` after capture and after refile, and degrades with a reason when a dependency is missing. `gtd-keyword-rewrite.el` is the record of the 20-heading `HOLD`/`WAITING`/`CANCELLED` rewrite.
- Record the org-gtd pipeline plan in `docs/org-gtd-pipeline-spec.md`: the decision-complete specification for adding org-gtd as the capture/clarify/organize/engage layer while the topic files under `~/org/` stay the store, covering the 4.6.1 tag pin, the new `lisp/init-local-gtd.el`, the edits to five existing files, the 20-heading keyword rewrite with its run order and rollback, and the verification plan.
- Open a Ghostel terminal in the current project root with `C-c g p` (`SPC g p`).
- Install `proofread` (context-aware LLM proofreading) at the pinned `proofread-v0.2.0` tag, with an `english` profile in `lisp/init-local-ai.el` whose LLM checker reaches the sone Gemini endpoint through GNU ELPA `llm`; the API key resolves lazily from `~/.authinfo` at request time.
- Copy the current buffer's full file path with `SPC b y`.
- Create or retrieve the current Org heading ID with `C-c o i c` or `SPC o i c`.
- Paste from the kill ring with `C-v` in Hel Normal, Insert, and Emacs states.
- Open the scratch buffer with `SPC s b`.
- Add the Vulpea leader group under `SPC v`, with `SPC v t` opening the Task Table.
- Keep the complete Task Table usable during asynchronous synchronization, warn actionably on worker failures, and add an advisory end-to-end 5,000-Task benchmark with deterministic query-count checks.
- Edit Task Table TODO state and Priority with `e`, writing through Org commands inside Vulpea's public note-sync helper and refreshing Open Tasks immediately.
- Preserve Task Table filters, native sort, launch scope, and Task-ID selection across manual and worker refreshes, with nearest-row/header fallbacks and atomic failure recovery.
- Navigate from Task Table rows by stable Org ID, refreshing and failing safely when a Task disappeared.
- Add guarded Vulpea/Vulpea UI indexing and the read-only `my/vulpea-task-table` Collection View for ID-bearing Open Tasks, with combinable ephemeral TODO, Priority, text, Source, and Org-launch filters.

### Changed
- Pin `hel-leader` to the `v2.1` tag instead of a raw commit in `lisp/package-list.el`; the two commits between that tag and the former pin are documentation only, so the code is unchanged. `hel` keeps its commit pin, which sits 12 commits ahead of `v0.12.0` and carries fixes a tag pin would give up: multiple-cursors keys lost on a major-mode change, three scroll fixes, a search variable used out of scope, and a duplicated advice.
- Move `my/git-push` from `C-c g p` to `C-c g u`, freeing `C-c g p` for `ghostel-project`.
- Move the proofread setup out of `lisp/init-local-ai.el` into `lisp/init-local-proofread.el`, reading the endpoint URL, model, and auth-source coordinates from a gitignored `lisp/init-local-proofread-config.el` scaffolded from a committed `.template`; the private endpoint host now stays out of the repository, and the module installs `llm` through `maybe-require-package` only once that config supplies an endpoint, so a checkout without one loads clean.
- Disable org-supertag startup, synchronization, capture integration, and installation.
- Swap Hel Normal-state `p` and `P`, making lowercase paste linewise content above the current line.
- Swap Hel Normal-state `d` and `D`, making delete-without-kill the lowercase default.
- Remove the org-supertag leader group under `SPC s`.
- Add pinned `hel-leader` native key translation; keep Git on `SPC g`, move C-M- to `SPC G`, and move the former `SPC c` group to `SPC a`.
- Replace Meow with Hel, installed at a pinned Git commit through a shared GUI/TUI async-installer bootstrap, while preserving the personal `SPC` leader map in Hel Normal and Emacs states.
- Render org-supertag inline `#tags` as plain bold text (`org-priority` color, heading-matched height via font-lock `prepend`) instead of SVG pill badges, by disabling `supertag-svg-tag-enable` and restyling `supertag-inline-face` in `lisp/init-local-org.el`.
- Bump bundled `anvil.el` to **v1.3.0** and drop the now-extracted `ide` module from `anvil-optional-modules`.
- Source the anvil MCP stdio bridge (`anvil-stdio.sh`) via `M-x anvil-server-install` into `~/.emacs.d/` as a gitignored per-machine artifact, instead of tracking a vendored copy.
- Document the anvil version-bump procedure inline in `lisp/package-list.el`.
