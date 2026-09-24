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
# root, matching the flat layout LÖVE expects. Cloudflare's Workers Builds
# image has no `zip` binary (confirmed: "zip: command not found"), so this
# uses a pure-JS zipper through Node instead of a system tool that may not
# exist in the build environment. Node/npx are the one thing guaranteed
# present, since they're what runs this whole pipeline.
cat > build/_zip_love.js <<'NODEEOF'
const AdmZip = require("adm-zip");
const zip = new AdmZip();

const files = [
  "main.lua", "conf.lua", "controls.lua", "failed.lua",
  "gameA.lua", "gameB.lua", "gameBdebug.lua", "gameBmulti.lua",
  "menu.lua", "rocket.lua",
];
for (const f of files) zip.addLocalFile(f);
zip.addLocalFolder("graphics", "graphics");
zip.addLocalFolder("sounds", "sounds");

zip.writeZip("build/game.love");
console.log("Wrote build/game.love");
NODEEOF

# `npx --package=adm-zip node ...` does NOT make the module resolvable to a
# plain `require()` in a script outside npx's own temp install (tried it,
# throws MODULE_NOT_FOUND) — installing into build/ so Node's normal
# node_modules resolution finds it is the unambiguous way to do this.
(cd build && npm install --no-audit --no-fund --silent adm-zip)
node build/_zip_love.js

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
# be a patch step here, not a one-off hand edit. Plain Node (fs only, no
# extra dependency) — not python3, which build_web.sh no longer assumes is
# present either, having been wrong once already about `zip`.
cat > build/_patch_frame.js <<'NODEEOF'
const fs = require("fs");

// love.js's template output has been observed with 8-space-indented, CRLF
// ("\r\n") lines — do not match on an exact literal copy of previously
// observed output again; match on the distinctive text content instead,
// tolerant of leading whitespace and \r, so a version bump's minor
// formatting differences can't silently defeat this the way exact-string
// matching just did.
const htmlPath = "web/index.html";
let html = fs.readFileSync(htmlPath, "utf8");

const h1Re = /^[ \t]*<h1>Not Tetris 2<\/h1>[ \t]*\r?\n/m;
if (!h1Re.test(html)) {
  console.warn("WARNING: expected <h1> line not found in index.html; frame patch skipped for it (love.js template may have changed)");
} else {
  html = html.replace(h1Re, "");
}

const footerRe = /^([ \t]*)<p>Built with <a href="https:\/\/github\.com\/Davidobot\/love\.js">love\.js<\/a> <button onclick="goFullScreen\(\);">Go Fullscreen<\/button><br>Hint: Reload the page if screen is blank<\/p>[ \t]*\r?$/m;
if (!footerRe.test(html)) {
  console.warn("WARNING: expected <footer> paragraph not found in index.html; frame patch skipped for it (love.js template may have changed)");
} else {
  html = html.replace(footerRe, '$1<p><button onclick="goFullScreen();">Fullscreen</button></p>');
}

fs.writeFileSync(htmlPath, html);

const cssPath = "web/theme/love.css";
let css = fs.readFileSync(cssPath, "utf8");

// Match the whole `body { ... }` rule regardless of exact internal
// whitespace/line-endings — this file has no nested braces, so a
// non-greedy "up to the next }" is unambiguous.
const bodyRe = /body\s*\{[^}]*\}/;
if (!bodyRe.test(css)) {
  console.warn("WARNING: expected body{} rule not found in love.css; frame patch skipped for it (love.js template may have changed)");
} else {
  css = css.replace(bodyRe, "body {\n    font-family: arial;\n    margin: 0;\n    padding: none;\n    background-color: #000;\n    color: #fff;\n}");
}

fs.writeFileSync(cssPath, css);
NODEEOF

node build/_patch_frame.js

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
