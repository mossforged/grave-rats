#!/bin/bash
# One-time setup on John's Mac for the QA GPU lane:
#   bash ~/Projects/grave-rats-qa/tools/qa-runner/install.sh
set -e
REPO="$HOME/Projects/grave-rats-qa"
[ -d "$REPO/.git" ] || git clone https://github.com/mossforged/grave-rats "$REPO"
command -v claude >/dev/null || { echo "Claude Code isn't installed. See https://code.claude.com/docs/en/setup, then run 'claude' once to log in, then run this again."; exit 1; }
[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ] || { echo "Godot isn't at /Applications/Godot.app; install Godot 4.7 there, then run this again."; exit 1; }
git -C "$REPO" config user.name mossforged
git -C "$REPO" config user.email mossforged@users.noreply.github.com
SCRIPT="$REPO/tools/qa-runner/run.sh"
chmod +x "$SCRIPT"
PLIST="$HOME/Library/LaunchAgents/com.mossforged.grave-rats-qa.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.mossforged.grave-rats-qa</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$SCRIPT</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$(dirname "$(command -v claude)"):/Applications/Godot.app/Contents/MacOS:$(dirname "$(command -v git)"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
</dict></plist>
PL
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"
echo "QA runner installed: it checks docs/queue/qa.txt every 10 minutes."
echo "Log: ~/Library/Logs/grave-rats-qa-runner.log"
echo "Pause it: launchctl bootout gui/\$(id -u) $PLIST   (run this installer again to resume)"
