#!/bin/bash
# One-time setup on John's Mac: run from ~/Projects/grave-rats-art
set -e
REPO="$HOME/Projects/grave-rats-art"
[ -d "$REPO/.git" ] || git clone https://github.com/mossforged/grave-rats "$REPO"
git -C "$REPO" config user.name mossforged
git -C "$REPO" config user.email mossforged@users.noreply.github.com
CODEX_DIR="$(dirname "$(command -v codex)")" || { echo "codex not found on PATH"; exit 1; }
GIT_DIR_BIN="$(dirname "$(command -v git)")"
NODE_DIR="$(dirname "$(command -v node 2>/dev/null || echo /usr/local/bin/node)")"
SCRIPT="$HOME/Projects/grave-rats-art/tools/art-runner/run.sh"
chmod +x "$SCRIPT"
PLIST="$HOME/Library/LaunchAgents/com.mossforged.grave-rats-art.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.mossforged.grave-rats-art</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$SCRIPT</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$CODEX_DIR:$NODE_DIR:$GIT_DIR_BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
</dict></plist>
PL
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"
echo "Art runner installed. It checks every 10 minutes. Log: ~/Library/Logs/grave-rats-art-runner.log"
echo "To remove it: launchctl bootout gui/\$(id -u) $PLIST && rm $PLIST"
