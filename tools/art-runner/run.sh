#!/bin/bash
# Grave Rats art runner (lead-owned infra).
# Every few minutes (via launchd) it pulls main in the art clone, and for each
# packet ID listed in docs/queue/art.txt that hasn't run on this Mac yet, it runs
# Codex unattended on its own branch and pushes the result for the lead to review.
set -u
# Wrapped in a function so bash parses the whole file before running it
# (the script pulls new versions of itself mid-run).
main() {
REPO="$HOME/Projects/grave-rats-art"
LOG="$HOME/Library/Logs/grave-rats-art-runner.log"
LOCK="/tmp/grave-rats-art-runner.lock"
exec >>"$LOG" 2>&1
mkdir "$LOCK" 2>/dev/null || return 0        # a run is already in progress
trap 'rmdir "$LOCK"' EXIT
cd "$REPO" || { echo "$(date) no repo at $REPO"; return 1; }
# Leftovers a run wrote outside the committed folders would block every later pull: set them aside (stash), log it.
if [ -n "$(git status --porcelain)" ]; then git stash push -u -q -m "art-runner leftovers $(date +%F-%H%M)" && echo "$(date) stashed leftover changes (git stash list)"; fi
git checkout -q main && git pull -q --ff-only || { echo "$(date) pull failed"; return 1; }
DONE="$REPO/.git/art-runner-done"
touch "$DONE"
QUEUE=$(grep -vE '^[[:space:]]*(#|$)' docs/queue/art.txt 2>/dev/null)
for ID in $QUEUE; do
  grep -qx "$ID" "$DONE" && continue
  # after an empty run, wait an hour before retrying so a broken setup doesn't loop
  if [ -n "$(find "$REPO/.git" -maxdepth 1 -name "art-runner-empty-$ID" -mmin -60 2>/dev/null)" ]; then continue; fi
  PACKET=$(ls docs/tasks/"$ID"-*.md 2>/dev/null | head -1)
  [ -z "$PACKET" ] && { echo "$(date) $ID: no packet file"; continue; }
  BR="auto/$(echo "$ID" | tr 'A-Z' 'a-z')"
  echo "$(date) starting $ID ($PACKET) on $BR"
  git checkout -q -B "$BR" main
  # Codex CLI flags differ between versions: pick what this one supports.
  HELP=$(codex exec --help 2>&1)
  FLAGS=()
  if grep -q -- '--full-auto' <<<"$HELP"; then FLAGS+=(--full-auto)
  elif grep -q -- '--sandbox' <<<"$HELP"; then FLAGS+=(--sandbox workspace-write); fi
  if grep -q -- '--ask-for-approval' <<<"$HELP"; then FLAGS+=(--ask-for-approval never); fi
  if grep -q -- '--skip-git-repo-check' <<<"$HELP"; then FLAGS+=(--skip-git-repo-check); fi
  echo "$(date) codex $(codex --version 2>&1 | head -1); flags: ${FLAGS[*]}"
  codex exec "${FLAGS[@]}" "You are the art builder for Grave Rats. This is an UNATTENDED run: nobody will answer questions. Read AGENTS.md, docs/STATUS.md and $PACKET, then do that packet completely. Do not run git at all (your sandbox cannot write .git); the runner commits and pushes everything you leave in assets/source, docs/screens and docs/handoffs. If an image is refused, note it in docs/handoffs/auto-$ID.md, skip it and continue. If something needs a human decision, write it in the handoff and stop." </dev/null
  RC=$?
  echo "$(date) codex exit $RC"
  if [ "$RC" != "0" ]; then
    echo "$(date) $ID: codex failed; not pushing, will retry after a 1h cool-down"
    touch "$REPO/.git/art-runner-empty-$ID"
    git checkout -q main; continue
  fi
  git add -A assets/source docs/screens docs/handoffs 2>/dev/null
  git diff --cached --quiet || git commit -q -m "$ID: art (runner commit of remaining files)"
  if [ "$(git rev-list --count main.."$BR")" = "0" ]; then
    echo "$(date) $ID produced no commits; NOT marking done (will retry next cycle after a 1h cool-down)"
    touch "$REPO/.git/art-runner-empty-$ID"
    git checkout -q main; continue
  fi
  if git push -q -u origin "$BR"; then echo "$ID" >> "$DONE"; echo "$(date) pushed $BR"; else echo "$(date) push failed for $BR"; fi
  git checkout -q main
done
}
main "$@"
