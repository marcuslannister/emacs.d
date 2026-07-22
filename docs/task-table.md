# Task Table

`M-x my/vulpea-task-table` opens all indexed Open Tasks through Vulpea UI's
Collection View. It requires Emacs 29.1 or newer, Vulpea, Vulpea UI, and a
readable Vulpea database.

The table uses one derived database per machine at
`var/vulpea/vulpea.db`. The repository ignores `var/`, including SQLite WAL
and shared-memory files. Syncthing must carry only canonical Org files. Never
add the database, `-wal`, or `-shm` files to a synchronized directory.

Vulpea scans the configured Org directory asynchronously at startup. An
existing committed index remains available during that scan and worker
updates refresh the table later. An empty index while the worker is busy is
reported as synchronization in progress. Startup, query, refresh, and worker
failures preserve Emacs startup and existing table rows, then name
`M-x vulpea-doctor` as the first recovery step.

## Controls

| Key | Action |
| --- | --- |
| `RET` | Visit the selected Task by stable Org ID |
| `e` | Edit TODO state or Priority in the canonical Org heading |
| `g` | Re-query and refresh |
| `f t` | Filter by TODO state |
| `f p` | Filter by Priority, including `None` |
| `f x` | Filter by Task or Source text |
| `f s` | Filter by Source text |
| `f b` | Limit to the Org file that launched the table |
| `f c` | Clear all filters |

Native column headers sort in either direction. Refreshes preserve filters,
sort direction, launch scope, and selection by stable Task ID.

## Automated Verification

Startup gate:

```sh
./test-startup.sh
```

Package-free deterministic and adapter suite:

```sh
emacs -Q --batch -l tests/init-local-vulpea-tests.el -f ert-run-tests-batch-and-exit
```

Real public-API integration suite, using only packages already installed for
the running Emacs version:

```sh
tests/run-vulpea-integration.sh
```

The integration suite skips with an explicit reason on Emacs older than 29.1
or when Vulpea dependencies are absent. Tests never install packages or use
the network. CI enforces one collection query per refresh and rejects per-row
database reads.

## Performance Proof

Run:

```sh
emacs -Q --batch -l tests/init-local-vulpea-benchmark.el
```

The benchmark generates 5,000 Task snapshots and reports the median of five
warm runs. It measures the public Collection View end to end: opening and
painting the buffer, native `tabulated-list` sorting, filtering and repainting,
and editing followed by a query and repaint.

Recorded 2026-07-21 on a Mac mini (M1, arm64), macOS 26.5.1, Emacs 31.0.50:

| Operation | Median | Limit |
| --- | ---: | ---: |
| Initial query/render | 587.390 ms | < 200 ms (not met) |
| Sort | 518.836 ms | < 100 ms (not met) |
| Filter | 47.470 ms | < 100 ms |
| Edit-triggered refresh | 1,277.412 ms | < 100 ms (not met) |

These limits are advisory engineering targets, not release gates. Query-count
and per-row-read assertions remain deterministic CI gates. The public Vulpea
UI Collection View currently misses the open, sort, and edit targets at 5,000
Tasks; separate renderer work may improve them without blocking Task Table
synchronization. See [ADR 0001](adr/0001-task-table-performance-targets.md).

## Manual Verification

Before relying on synchronization changes:

1. Run `M-x vulpea-doctor`; confirm database health.
2. Open from an Org buffer and a non-Org buffer. Exercise every filter and
   both sort directions.
3. Edit TODO and Priority. Confirm immediate source save, re-query, and done
   Task disappearance.
4. Move a Task while retaining its ID, then delete it. Confirm navigation
   follows the move and a stale row disappears safely.
5. Change a canonical Org file on another Syncthing machine. Confirm running
   Emacs reindexes it and refreshes the visible table.
6. Restart during an incomplete initial scan. Confirm startup succeeds, an
   existing index opens, and an empty index reports synchronization progress.
