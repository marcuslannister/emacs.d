# Vulpea v2 Task data and lifecycle APIs

Research date: 2026-07-20. Claims below are pinned to Vulpea commit
[`f94a74a`](https://github.com/d12frosted/vulpea/commit/f94a74a5ec555f76808c19c15812d07ba95f14ff),
the head of `master` on that date. The latest published release was
[`v2.6.0`](https://github.com/d12frosted/vulpea/releases/tag/v2.6.0).

## Answer

The accepted Task Table does **not** need a Vulpea extractor or plugin. Current Vulpea v2 already
indexes every required display value for an ID-bearing Org heading:

| Task Table value | Public Vulpea value | Stored shape | Source |
| --- | --- | --- | --- |
| TODO state | `vulpea-note-todo` | String, or `nil` | The core heading extractor reads Org's `:todo-keyword` and stores it as `:todo`. [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-extract.el#L785-L846)] |
| Priority | `vulpea-note-priority` | Character, or `nil` when no cookie exists | The same extractor reads Org's `:priority` and stores it as `:priority`. [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-extract.el#L785-L846)] |
| Task heading text | `vulpea-note-title` | String | Heading `:raw-value` is converted to display text and stripped of emphasis before becoming `:title`. [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-extract.el#L753-L756)] |
| Source note title | `vulpea-note-file-title` | String | `#+TITLE` is used when present, otherwise the filename base; each heading receives that `file-title`. [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-extract.el#L584-L597)] [[assignment](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-extract.el#L836-L856)] |
| Heading location | `vulpea-note-id`, `vulpea-note-path`, `vulpea-note-level`, `vulpea-note-pos` | Stable ID, absolute path, heading level, last-indexed buffer position | All four are public struct slots. [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-note.el#L42-L89)] |

The official API reference also documents TODO, Priority, file title, path, and level as
`vulpea-note` accessors. [[API reference](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/docs/api-reference.org#L6-L31)]
Vulpea defines a note as any file or heading with an `ID`; heading indexing is enabled by default
through `vulpea-db-index-heading-level`. [[README](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/README.org#L57-L64)]
[[option](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db.el#L98-L109)]

Therefore a Task predicate is simply a heading-level note whose `vulpea-note-todo` is non-`nil`.
No duplicate Task table or metadata field is needed.

## Read path

Use the public `vulpea-db-query` with an Elisp predicate. It returns `vulpea-note` structs and is
the documented escape hatch for compound filters; its full scan is explicitly supported, whereas
specialized queries are only necessary when a filter already has a public indexed query.
[[API](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/docs/api-reference.org#L88-L170)]
[[implementation and performance notes](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-query.el#L142-L176)]

```elisp
(vulpea-db-query
 (lambda (note)
   (and (> (vulpea-note-level note) 0)
        (vulpea-note-todo note))))
```

There is no public TODO-specific SQL query. That is not a reason to query the database tables
directly: Vulpea explicitly calls its schema an implementation detail and says applications should
use functions and data structures. [[design contract](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/README.org#L43-L51)]

### Two Org semantics not stored by Vulpea

Vulpea stores the TODO keyword, but not the keyword's per-buffer workflow position or whether Org
classifies it as a done state. Org keeps those facts in buffer-local `org-todo-keywords-1`,
`org-not-done-keywords`, and `org-done-keywords`.
[[Org source](https://github.com/bzg/org-mode/blob/3c855d51aa121957227d9fd351f467c2c53c241b/lisp/org.el#L1997-L2017)]

Consequences:

- With this configuration's single shared Org workflow, the Task Table can classify Open Tasks and
  sort TODO states from that configured workflow without extra database data.
- If files may define different `#+TODO` sequences, exact done-state classification and workflow
  ordering require visiting each source buffer or adding derived fields through a custom extractor.
  The current core note alone cannot answer those two questions.
- A missing priority remains `nil` in Vulpea. Displaying it as B is correct Org behavior: Org's
  default priority is B and an entry without a cookie is treated as B.
  [[Org manual](https://orgmode.org/manual/Priorities.html)]
  [[Org source](https://github.com/bzg/org-mode/blob/3c855d51aa121957227d9fd351f467c2c53c241b/lisp/org.el#L2533-L2548)]

## Location, visit, and writeback

Treat `vulpea-note-pos` as a last-indexed hint, not stable identity: edits before the heading can
move it before Vulpea re-indexes. Use the ID-based public APIs instead.

- `vulpea-visit` accepts a note or ID, opens its file, searches for the current `:ID:`, and moves to
  the heading. [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea.el#L929-L960)]
- `vulpea-utils-with-note` opens the source without changing the selected window and locates a
  heading by `org-find-entry-with-id`.
  [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-utils.el#L152-L162)]
- `vulpea-utils-with-note-sync` does the same, then saves and synchronously calls
  `vulpea-db-update-file`. The database is current when the macro returns.
  [[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-utils.el#L164-L196)]

Recommended Task Table write path:

```elisp
(vulpea-utils-with-note-sync note
  (org-todo new-state))

(vulpea-utils-with-note-sync note
  (org-priority new-priority))
```

`org-todo` accepts a state string programmatically and validates it against the workflow active in
that source buffer. [[Org source](https://github.com/bzg/org-mode/blob/3c855d51aa121957227d9fd351f467c2c53c241b/lisp/org.el#L9661-L9698)]
`org-priority` accepts an uppercase priority character programmatically.
[[Org source](https://github.com/bzg/org-mode/blob/3c855d51aa121957227d9fd351f467c2c53c241b/lisp/org.el#L11442-L11450)]
This preserves Org as canonical, runs Org's state-change/logging behavior, saves immediately, and
provides deterministic re-query/refresh after each Task Table edit.

For a jump-only command, `vulpea-visit` is the shortest public path. For background edits,
`vulpea-utils-with-note-sync` avoids relying on the stale position and avoids mutating database rows.

## Extractor and plugin hooks

Plugins are supported through `make-vulpea-extractor`, `vulpea-db-register-extractor`,
`vulpea-db-unregister-extractor`, and `vulpea-db-get-extractor`. An extractor receives existing
note data including `:id`, `:path`, `:level`, `:pos`, `:title`, `:todo`, and `:priority`; it can add
its own tables or contribute to persistent core fields.
[[plugin guide](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/docs/plugin-guide.org#L33-L103)]
[[registration API](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/docs/plugin-guide.org#L722-L752)]

No plugin is justified for the accepted columns. Adding one would duplicate core data, increase
schema and migration surface, and may affect async extraction. In particular, an extractor that
requires the AST disables async extraction for every file; a note-data-only extractor should state
`:requires-ast nil`, and a worker-side extractor also needs `:worker-safe t` plus `:worker-lib`.
[[async extractor contract](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/docs/plugin-guide.org#L289-L339)]

`vulpea-db-note-index-filter-functions` is **not** an update notification. It is a pre-insert veto:
every handler must return non-`nil` or the note is omitted. The note passed to it is also only
partially populated and does not include TODO, Priority, or position.
[[hook contract](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-extract.el#L1352-L1390)]

## Database lifecycle and refresh

Public update entry points:

- `vulpea-db-update-file`: immediate, synchronous update.
- `vulpea-db-sync-update-file`: queues asynchronously when `vulpea-db-autosync-mode` is enabled;
  otherwise calls the immediate updater.
- `vulpea-db-sync-full-scan` and `vulpea-db-sync-update-directory`: collection updates.

These are documented together in the API reference.
[[sync API](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/docs/api-reference.org#L1054-L1077)]

Current Vulpea exposes one post-work abnormal hook,
`vulpea-db-worker-done-functions`. It receives `(PATH STATUS COUNT)` with statuses including
`applied`, `unchanged`, `stale`, `requeued`, `missing`, and `error`.
[[source](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-worker.el#L159-L168)]
It is specifically a **worker completion** hook. The ordinary synchronous path calls
`vulpea-db-update-file` directly and does not run it, so it cannot provide a mode-independent
"database changed" notification.
[[sync path](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-sync.el#L826-L842)]
[[worker hook call](https://github.com/d12frosted/vulpea/blob/f94a74a5ec555f76808c19c15812d07ba95f14ff/vulpea-db-worker.el#L785-L815)]

No public, mode-independent after-commit hook exists at this revision. Therefore:

1. Refresh immediately after Task Table writeback; `vulpea-utils-with-note-sync` guarantees the
   re-query sees the new state.
2. Keep `g` as the authoritative manual refresh.
3. `vulpea-db-worker-done-functions` can supplement refresh for background-worker updates, but must
   not be presented as complete coverage.
4. Full automatic refresh for every external/synchronous database mutation requires either an
   upstream after-update hook or an explicitly accepted fallback such as polling. Advising private
   update internals would create a fragile coupling.

## Private surfaces to avoid

- Do not query or mutate Vulpea's core SQL tables. The README explicitly declares the schema
  internal. Use `vulpea-db-query`, `vulpea-note` accessors, and the public update functions.
- Do not call double-hyphen functions or variables such as `vulpea-db--row-to-note`,
  `vulpea-db--update-note-fields`, `vulpea-db--delete-file-notes`, `vulpea-db--extract-*`,
  `vulpea-db-sync--enqueue`, or `vulpea-db-sync--process-queue`.
- Do not depend on `vulpea-db--extractors` or core schema column order. Register plugins through the
  public registry if a later requirement truly needs derived data.
- Do not use `vulpea-db-note-index-filter-functions` for observation; it can suppress notes.
- Do not mutate `vulpea-note` structs and expect persistence. They are query results; write the Org
  source and sync it.

## Implementation-facing conclusion

Build the Task Table on `vulpea-db-query` plus public `vulpea-note` accessors. Jump with
`vulpea-visit`. Edit with `vulpea-utils-with-note-sync` wrapping `org-todo` or `org-priority`, then
re-query. No Task extractor, custom table, or raw SQL. The only unresolved contract is universal
automatic refresh: current Vulpea offers worker completion events, not a general after-update event.
