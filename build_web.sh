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

# love.js's own generated index.html/love.css are its stock demo template
# (light-blue background image, a decorative <h1>, a "Built with love.js"
# credit line). Strip that chrome down to a blank black background and a
# bare fullscreen button, keeping the actual Module/canvas boot logic
# untouched. Since web/ is regenerated from scratch every run, this has to
# be a patch step here, not a one-off hand edit.
python3 <<'PYEOF'
import pathlib

html_path = pathlib.Path("web/index.html")
html = html_path.read_text()

old_h1 = "    <h1>Not Tetris 2</h1>\n"
if old_h1 not in html:
    print("WARNING: expected <h1> line not found in index.html; frame patch skipped for it (love.js template may have changed)")
else:
    html = html.replace(old_h1, "")

old_footer_p = '      <p>Built with <a href="https://github.com/Davidobot/love.js">love.js</a> <button onclick="goFullScreen();">Go Fullscreen</button><br>Hint: Reload the page if screen is blank</p>\n'
new_footer_p = '      <p><button onclick="goFullScreen();">Fullscreen</button></p>\n'
if old_footer_p not in html:
    print("WARNING: expected <footer> paragraph not found in index.html; frame patch skipped for it (love.js template may have changed)")
else:
    html = html.replace(old_footer_p, new_footer_p)

html_path.write_text(html)

css_path = pathlib.Path("web/theme/love.css")
css = css_path.read_text()

old_body = """body {
    background-image: url(bg.png);
    background-repeat: no-repeat;
    font-family: arial;
    margin: 0;
    padding: none;
    background-color: rgb( 154, 205, 237 );
    color: rgb( 28, 78, 104 );
}"""
new_body = """body {
    font-family: arial;
    margin: 0;
    padding: none;
    background-color: #000;
    color: #fff;
}"""
if old_body not in css:
    print("WARNING: expected body{} rule not found in love.css; frame patch skipped for it (love.js template may have changed)")
else:
    css = css.replace(old_body, new_body)

css_path.write_text(css)
PYEOF

# Guard against `wrangler deploy` writing its own local cache/state (account
# info, a generated no-op worker stub) into this directory and publishing it
# as a public site asset — confirmed happening with wrangler 4.137.0 when
# deploying an assets-only Worker. Belt-and-suspenders: remove any leftover
# .wrangler dir from a previous deploy, and recreate .assetsignore every
# build (this whole directory is deleted and regenerated above, so anything
# placed in web/ by hand does not survive a rebuild).
rm -rf web/.wrangler
cat > web/.assetsignore <<'EOF'
.wrangler
.wrangler/**
EOF

echo "Build complete: web/"
