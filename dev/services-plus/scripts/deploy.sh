#!/usr/bin/env bash
# Fast build + dual-deploy for the dev loop.
#
# Builds the UI, then mirrors dev/services-plus/ (minus dev-only ui/tests/scripts) into:
#   1. build/services-plus/  - a self-contained, installable package (README, docs,
#      sql/install.sql, everything a fresh server needs) for grabbing a finished build.
#   2. the live FiveM server resource folder, so it's immediately testable in-game.
#
# Uses robocopy /MIR so deleted/renamed files (old hashed web/assets/*.js, removed Lua
# files, etc.) are cleaned up in both destinations automatically, not just added to.
#
# Usage: bash dev/services-plus/scripts/deploy.sh

set -uo pipefail

REPO="E:/GitHub/lb-services-plus"
SRC="$REPO/dev/services-plus"
BUILD="$REPO/build/services-plus"
LIVE="E:/FiveMServer/txData/FiveMBasicServerCFXDefault_71E096.base/resources/[local]/services-plus"

echo "==> Building UI"
if ! (cd "$SRC/ui" && npm run build); then
  echo "UI build failed - aborting deploy."
  exit 1
fi

sync_target() {
  local dest="$1" label="$2"
  # robocopy exit codes 0-7 are all success (bitmask of "files copied"/"extra removed"/
  # etc.); only 8+ is a real failure. Do not treat a normal nonzero code as an error.
  # MSYS_NO_PATHCONV stops Git Bash from mangling the /MIR /XD /XF switches into paths.
  MSYS_NO_PATHCONV=1 robocopy "$SRC" "$dest" /MIR /XD ui tests scripts /XF .gitignore /NFL /NDL /NJH /NJS /NP >/dev/null
  local code=$?
  if [ "$code" -ge 8 ]; then
    echo "robocopy failed (exit $code) syncing $label"
    return 1
  fi
  echo "==> Synced $label: $dest"
  return 0
}

sync_target "$BUILD" "build/" || exit 1
sync_target "$LIVE" "live server" || exit 1

echo
echo "Done. Restart in the server console:"
echo "  restart services-plus"
