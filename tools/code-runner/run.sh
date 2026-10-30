#!/bin/bash
# Grave Rats code runner (lead-owned infra): the Mac code-builder lane.
# Every 10 minutes (launchd) it pulls main in the code clone. For each packet ID in
# docs/queue/code.txt that hasn't run on this Mac yet, it runs Claude Code in print
# mode with the "auto" permission mode (Claude Code's safety classifier reviews
# every action; no permission bypass), with Godot on the real GPU, then pushes the branch for the lead to review.
set -u
# a `godot` command on PATH for the agent and this script
SHIM="$HOME/.local/grave-rats-bin"; mkdir -p "$SHIM"
ln -sf /Applications/Godot.app/Contents/MacOS/Godot "$SHIM/godot"
export PATH="$SHIM:$PATH"
main() {
REPO="$HOME/Projects/grave-rats-code"
LOG="$HOME/Library/Logs/grave-rats-code-runner.log"
LOCK="/tmp/grave-rats-code-runner.lock"
MAXMIN="${CODE_MAX_MINUTES:-240}"
exec >>"$LOG" 2>&1
mkdir "$LOCK" 2>/dev/null || return 0
trap 'rmdir "$LOCK"' EXIT
cd "$REPO" || { echo "$(date) no repo at $REPO"; return 1; }
if ! claude --help 2>&1 | grep -q '"auto"'; then
  echo "$(date) this Claude Code has no auto permission mode; not running (update Claude Code)"; return 1
fi
git checkout -q main && git pull -q --ff-only || { echo "$(date) pull failed"; return 1; }
DONE="$REPO/.git/code-runner-done"
touch "$DONE"
QUEUE=$(grep -vE '^[[:space:]]*(#|$)' docs/queue/code.txt 2>/dev/null)
for ID in $QUEUE; do
  grep -qx "$ID" "$DONE" && continue
  if [ -n "$(find "$REPO/.git" -maxdepth 1 -name "code-runner-empty-$ID" -mmin -60 2>/dev/null)" ]; then continue; fi
  PACKET=$(ls docs/tasks/"$ID"-*.md 2>/dev/null | head -1)
  [ -z "$PACKET" ] && { echo "$(date) $ID: no packet file"; continue; }
  BR="auto/$(echo "$ID" | tr 'A-Z' 'a-z')-mac"
  echo "$(date) starting $ID ($PACKET) on $BR, limit ${MAXMIN} min"
  git checkout -q -B "$BR" main
  godot --headless --path . --import >/dev/null 2>&1 || true
  caffeinate -i -w $$ &
  claude -p --permission-mode auto "You are the code builder for Grave Rats on John's Mac. Unattended run: nobody will answer questions. You are in $REPO on branch $BR (already created from main; do not create another branch). Read CLAUDE.md and follow it, then docs/STATUS.md and $PACKET, and do that packet completely. Godot is at /Applications/Godot.app/Contents/MacOS/Godot (also on PATH as godot); windowed captures run on the real GPU. Stay inside the modules the packet names and never edit assets/source/. Before finishing: the headless tests pass and the project imports without errors, then write docs/handoffs/auto-$ID.md and update STATUS. Commit as you go (author mossforged <mossforged@users.noreply.github.com>); do not push, never merge to main, never force anything: the runner pushes. If something needs a human decision, write it in the handoff and stop." </dev/null &
  CPID=$!
  ( sleep $((MAXMIN*60)); kill "$CPID" 2>/dev/null && echo "$(date) $ID: hit the time limit" ) &
  WPID=$!
  wait "$CPID"; echo "$(date) claude exit $?"
  kill "$WPID" 2>/dev/null
  git add -A . ':!assets/source' 2>/dev/null
  git diff --cached --quiet || git commit -q -m "$ID: code (runner commit of remaining files)"
  if [ "$(git rev-list --count main.."$BR")" = "0" ]; then
    echo "$(date) $ID produced no commits; will retry after 1h"; touch "$REPO/.git/code-runner-empty-$ID"
    git checkout -q main; continue
  fi
  if git push -q -u origin "$BR"; then echo "$ID" >> "$DONE"; echo "$(date) pushed $BR"; else echo "$(date) push failed for $BR"; fi
  git checkout -q main
done
}
main "$@"
