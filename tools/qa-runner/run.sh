#!/bin/bash
# Grave Rats QA runner (lead-owned infra): the Mac GPU lane.
# Every 10 minutes (launchd) it pulls main in the QA clone. For each packet ID in
# docs/queue/qa.txt that hasn't run on this Mac yet, it runs Claude Code in print
# mode with the "auto" permission mode (Claude Code's safety classifier reviews
# every action; no permission bypass), with Godot on the real GPU, then pushes the branch for the lead to review.
set -u
# a `godot` command on PATH for the agent and this script
SHIM="$HOME/.local/grave-rats-bin"; mkdir -p "$SHIM"
ln -sf /Applications/Godot.app/Contents/MacOS/Godot "$SHIM/godot"
export PATH="$SHIM:$PATH"
main() {
REPO="$HOME/Projects/grave-rats-qa"
LOG="$HOME/Library/Logs/grave-rats-qa-runner.log"
LOCK="/tmp/grave-rats-qa-runner.lock"
MAXMIN="${QA_MAX_MINUTES:-180}"
exec >>"$LOG" 2>&1
mkdir "$LOCK" 2>/dev/null || return 0
trap 'rmdir "$LOCK"' EXIT
cd "$REPO" || { echo "$(date) no repo at $REPO"; return 1; }
if ! claude --help 2>&1 | grep -q '"auto"'; then
  echo "$(date) this Claude Code has no auto permission mode; not running (update Claude Code)"; return 1
fi
git checkout -q main && git pull -q --ff-only || { echo "$(date) pull failed"; return 1; }
DONE="$REPO/.git/qa-runner-done"
touch "$DONE"
QUEUE=$(grep -vE '^[[:space:]]*(#|$)' docs/queue/qa.txt 2>/dev/null)
for ID in $QUEUE; do
  grep -qx "$ID" "$DONE" && continue
  if [ -n "$(find "$REPO/.git" -maxdepth 1 -name "qa-runner-empty-$ID" -mmin -60 2>/dev/null)" ]; then continue; fi
  PACKET=$(ls docs/tasks/"$ID"-*.md 2>/dev/null | head -1)
  [ -z "$PACKET" ] && { echo "$(date) $ID: no packet file"; continue; }
  BR="auto/$(echo "$ID" | tr 'A-Z' 'a-z')-mac"
  echo "$(date) starting $ID ($PACKET) on $BR, limit ${MAXMIN} min"
  git checkout -q -B "$BR" main
  godot --headless --path . --import >/dev/null 2>&1 || true
  caffeinate -i -w $$ &
  claude -p --permission-mode auto "You are the QA tester for Grave Rats on John's Mac (the GPU lane). Unattended run: nobody will answer questions. You are in $REPO on branch $BR. Read QA.md, docs/STATUS.md and $PACKET, then do that packet. Godot runs windowed on the real GPU (godot on PATH). Test and report only: change nothing outside tests/qa/, tools/, docs/qa/ and docs/screens/ unless the packet or its addendum explicitly allows a specific file (then only that file), and nothing outside this folder. Commit as you go (author mossforged <mossforged@users.noreply.github.com>); do not push, the runner pushes. If something needs a human decision, write it in the report and stop." </dev/null &
  CPID=$!
  ( sleep $((MAXMIN*60)); kill "$CPID" 2>/dev/null && echo "$(date) $ID: hit the time limit" ) &
  WPID=$!
  wait "$CPID"; echo "$(date) claude exit $?"
  kill "$WPID" 2>/dev/null
  git add -A tests/qa tools docs/qa docs/screens 2>/dev/null
  git diff --cached --quiet || git commit -q -m "$ID: QA (runner commit of remaining files)"
  if [ "$(git rev-list --count main.."$BR")" = "0" ]; then
    echo "$(date) $ID produced no commits; will retry after 1h"; touch "$REPO/.git/qa-runner-empty-$ID"
    git checkout -q main; continue
  fi
  if git push -q -u origin "$BR"; then echo "$ID" >> "$DONE"; echo "$(date) pushed $BR"; else echo "$(date) push failed for $BR"; fi
  git checkout -q main
done
}
main "$@"
