#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export PATH="$HOME/.local/share/mise/shims:$PATH"

APP_TITLE="${APP_TITLE:-Love Exemplar}"

echo "Zipping game files into game.love..."
zip -r game.love main.lua conf.lua assets/ core/ game/

echo "Running love.js to build web output..."
npx love.js game.love web/ --title "$APP_TITLE" --compatibility -m 67108864

echo "Cleaning up game.love..."
rm game.love

echo "Copying web-template assets..."
cp web-template/controls.js web/

echo "Injecting controls.js into index.html..."
sed -i 's|</body>|<script src="controls.js"></script>\n</body>|' web/index.html

# --- SAVES: uncomment the block below if your game uses lua/core/save.lua ---
# echo "Patching love.js to sync saves to IndexedDB immediately on write..."
# python3 - <<'PYEOF'
# import sys
#
# content = open('web/love.js').read()
# marker = 'Module["FS_unlink"]=FS.unlink;'
# if marker not in content:
#     print('ERROR: marker not found in love.js — patch failed', file=sys.stderr)
#     sys.exit(1)
#
# # Hook FS.close and FS.writeFile: whenever save.dat is written,
# # trigger FS.syncfs(false) immediately while the game is still running,
# # so the data reaches IndexedDB before the user reloads.
# hook = (
#     'Module["FS_syncfs"]=FS.syncfs.bind(FS);'
#     '(function(){'
#       'var _t=null;'
#       'function _sync(p){'
#         'if(p&&p.indexOf("save.dat")!==-1){'
#           'clearTimeout(_t);'
#           '_t=setTimeout(function(){'
#             'FS.syncfs(false,function(e){if(e)console.warn("[save] IDBFS sync error:",e);});'
#           '},100);'
#         '}'
#       '}'
#       'var _oc=FS.close.bind(FS);'
#       'FS.close=function(s){var r=_oc(s);_sync(s&&s.path);return r;};'
#       'var _owf=FS.writeFile.bind(FS);'
#       'FS.writeFile=function(p,d,o){var r=_owf(p,d,o);_sync(p);return r;};'
#     '})();'
# )
#
# patched = content.replace(marker, marker + hook)
# open('web/love.js', 'w').write(patched)
# n = patched.count('FS_syncfs')
# print(f'Patched {n} location(s)')
# PYEOF
# --- end SAVES ---

echo "Build complete. Output is in web/"
