#!/usr/bin/env bash
# Chromium host-requirements validation on Linux x64 reads no file.
# Run on a disposable Debian 12 x64 machine with Node.js 20+, npm and passwordless sudo.
# It moves libxkbcommon.so.0 aside and puts it back on exit.
set -u
VERSION="${1:-1.65.1}"
WORK="$(mktemp -d)"
cd "$WORK"
export PLAYWRIGHT_BROWSERS_PATH="$WORK/browsers"
npm init -y >/dev/null
npm install --no-audit --no-fund "playwright@$VERSION" >/dev/null
sudo -n env "PATH=$PATH" npx playwright install-deps chromium >/dev/null
npx playwright install chromium >/dev/null

LIB="$(readlink -f /lib/x86_64-linux-gnu/libxkbcommon.so.0)"
sudo -n mv "$LIB" "$WORK/held-lib"
trap 'sudo -n mv "$WORK/held-lib" "$LIB"' EXIT

echo "== browser folders"
ls -d "$PLAYWRIGHT_BROWSERS_PATH"/chromium*/*/
echo "== ldd"
ldd "$PLAYWRIGHT_BROWSERS_PATH"/chromium-*/chrome-linux64/chrome | grep 'not found'

rm -f "$PLAYWRIGHT_BROWSERS_PATH"/*/DEPENDENCIES_VALIDATED
echo "== cold install with libxkbcommon missing"
DEBUG=pw:install npx playwright install chromium 2>&1 | grep -E 'validat|missing dependencies'
ls "$PLAYWRIGHT_BROWSERS_PATH"/*/DEPENDENCIES_VALIDATED

rm -f "$PLAYWRIGHT_BROWSERS_PATH"/*/DEPENDENCIES_VALIDATED
echo "== launch"
node -e "require('playwright').chromium.launch().then(b => b.close())" 2>&1 | grep -E 'browserType.launch|missing dependencies|error while loading' | head -3

echo "== same check with chrome-linux pointing at the real folder"
for d in "$PLAYWRIGHT_BROWSERS_PATH"/chromium-* "$PLAYWRIGHT_BROWSERS_PATH"/chromium_headless_shell-*; do
  ln -s "$(basename "$(ls -d "$d"/*/ | head -1)")" "$d/chrome-linux"
done
rm -f "$PLAYWRIGHT_BROWSERS_PATH"/*/DEPENDENCIES_VALIDATED
DEBUG=pw:install npx playwright install chromium 2>&1 | grep -E 'validat|missing dependencies|apt-get install'
