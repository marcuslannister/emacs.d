# Treat Task Table timings as engineering targets

The 5,000-Task wall-clock thresholds are engineering targets, not release
gates. Task Table synchronization work is accepted when its user-visible
behavior and deterministic query-count guards pass; end-to-end timings remain
advisory evidence, and renderer performance work is scoped separately because
the accepted public Vulpea UI Collection View owns buffer painting.

The separate performance effort may replace the rendering layer. It must keep
Vulpea's public database/query boundary, canonical Org writes, stable-ID
navigation and editing, and the established Task Table behavior.

After a canonical Org edit saves successfully, the Task Table may update or
remove the affected row immediately and reconcile the complete collection
asynchronously. Full re-query and repaint are not part of the blocking edit
latency.

If asynchronous reconciliation fails after a successful canonical write, the
immediate row state remains. The Task Table warns with the existing Vulpea
recovery path instead of restoring stale indexed data.

Any replacement renderer must support Emacs 29.1. Prototypes start with
built-in capabilities; a new renderer dependency requires both a clear
benchmark improvement and the repository's dependency-health check.

Performance evidence separates blocking edit feedback from asynchronous full
reconciliation. Edit feedback measures canonical save plus affected-row
update against a 100 ms engineering target; full query and repaint are
reported independently and never block the edit command.

Open/render keeps a 200 ms engineering target; sort and filter keep 100 ms
targets. These remain advisory. Clickable column headers and both sort
directions are user-facing contracts, but `tabulated-list-print` is not.

The renderer may virtualize the viewport. The complete Task collection must
still participate in filtering and sorting, without user-visible pagination.

Asynchronous reconciliation requests are coalesced. Only the newest refresh
generation may apply results, so an older query cannot overwrite newer edits,
selection, filters, or sort state.
