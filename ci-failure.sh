#!/bin/sh -e
# Print the first error of each failed job in a CI run.
# Usage: ./ci-failure.sh [RUN-ID]   (default: the latest failed CI run)
# The log download fails often (TLS timeouts, "Egress is over the account
# limit"), so it retries.
gh() { env -u GITHUB_TOKEN -u GH_TOKEN gh "$@"; }
run=${1:-$(gh run list --workflow CI --status failure --limit 1 --json databaseId --jq '.[0].databaseId')}
esc=$(printf '\033')
for job in $(gh run view "$run" --json jobs --jq '.jobs[] | select(.conclusion == "failure") | .databaseId'); do
  echo "== run $run, job $job"
  log=$(mktemp)
  for _ in 1 2 3 4 5 6; do
    gh api "repos/{owner}/{repo}/actions/jobs/$job/logs" --allow-escape-sequences 2>/dev/null |
      sed "s/$esc\[[0-9;]*[A-Za-z]//g" >"$log"
    [ "$(wc -l <"$log")" -gt 20 ] && break
    sleep 10
  done
  rg -m3 -A3 'Debugger entered|Z Error:|##\[error\]' "$log" | cut -c1-300 || echo "no error line found in $log"
  find "$log" -delete
done
