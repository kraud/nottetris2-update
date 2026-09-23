#!/usr/bin/env bash
set -euo pipefail

# Builds the browser (love.js) export of Not Tetris 2 into web/.
# Single-player only: no multiplayer relay, no room form. This is the
# desktop game running unmodified inside a browser via love.js.
# (The online-multiplayer version of this script is described, but not yet
# built, in .context/web-migration.md.)

cd "$(dirname "$0")"

# TODO: pin this to a specific version once you've confirmed it produces a
# working build (see the "tool version pinning" note in
# .context/web-migration.md) — left unpinned rather than guessing a version
# number that might not exist.
LOVE_JS_VERSION="latest"

rm -rf build web
mkdir -p build

# Package the Lua source + assets into a .love archive, files at the archive
# root, matching the flat layout LÖVE expects.
zip -r -q build/game.love \
    main.lua conf.lua controls.lua failed.lua \
    gameA.lua gameB.lua gameBdebug.lua gameBmulti.lua \
    menu.lua rocket.lua \
    graphics sounds

# Run the love.js packager (Davidobot fork) in compatibility mode:
# -c runs single-threaded (no SharedArrayBuffer), so it needs no special
#    Cross-Origin-Opener-Policy/Cross-Origin-Embedder-Policy headers — this
#    keeps deployment simple on static hosts that don't let you set headers.
npx --yes "love.js@${LOVE_JS_VERSION}" -c -t "Not Tetris 2" build/game.love web

echo "Build complete: web/"
