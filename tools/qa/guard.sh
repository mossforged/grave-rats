#!/bin/bash
# Q003: is anything else using the Mac's GPU or the code lane? Exit 0 = busy. Prints why.
#   tools/qa/guard.sh <exempt-path>
# Busy means: a Godot whose command line isn't under <exempt-path> (any project's, not just the code lane's; T003 of
# another game counts), or an agent working in the code lane's clone, which can start a Godot at any moment.
export PATH="$PATH:/usr/sbin:/sbin"
EXEMPT="${1:-/nonexistent}"
for pid in $(pgrep -if godot); do
  exe="$(ps -o comm= -p "$pid" 2>/dev/null)"
  case "$(basename "$exe" | tr 'A-Z' 'a-z')" in godot*) ;; *) continue ;; esac
  cmd="$(ps -o command= -p "$pid" 2>/dev/null)"
  case "$cmd" in *"$EXEMPT"*) continue ;; esac
  echo "godot $pid: ${cmd:0:120}"; exit 0
done
for pid in $(pgrep -x claude; pgrep -x codex); do
  cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
  case "$cwd" in *grave-rats-code*) echo "agent $pid in $cwd"; exit 0 ;; esac
done
exit 1
