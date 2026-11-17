#!/usr/bin/env bash
# Build The AllCraft Ani browser bundle and stage it in $ROOT/dist/anicraft-web-<version>/
set -euo pipefail
# shellcheck source=../env.sh
. "$(dirname "${BASH_SOURCE[0]}")/../env.sh"
cd "$ROOT"

WANT="$(awk '/^name = "wasm-bindgen"$/ { getline; gsub(/version = |"/, ""); print; exit }' Cargo.lock)"
if ! command -v wasm-bindgen >/dev/null || [[ "$(wasm-bindgen --version | awk '{ print $2 }')" != "$WANT" ]]; then
  cargo install wasm-bindgen-cli --version "$WANT" --locked
fi

scripts/build-web.sh
for f in index.html anicraft.js anicraft_bg.wasm anicraft.png guide/index.html; do
  [[ -s "web/$f" ]] || { echo "error: web/$f is missing or empty" >&2; exit 1; }
done

python3 packaging/web/pack_wasm.py "$ROOT/web"

MAX_FILE_BYTES=$((10#${ANICRAFT_WEB_MAX_FILE_BYTES:-25165824})) # 24 MiB
size() { wc -c <"$1" | tr -d ' '; }
largest=0
while IFS= read -r file; do
  bytes=$(size "$file")
  [[ "$bytes" -le "$largest" ]] || largest=$bytes
  if [[ "$bytes" -gt "$MAX_FILE_BYTES" ]]; then
    echo "error: ${file#"$ROOT/web/"} is $bytes bytes, over the $MAX_FILE_BYTES-byte limit" >&2
    exit 1
  fi
done < <(find "$ROOT/web" -type f)
echo "largest file in the site: $largest bytes (limit $MAX_FILE_BYTES)"

NAME="anicraft-web-$VERSION"
rm -rf "$ROOT/dist/$NAME"
mkdir -p "$ROOT/dist/$NAME"
cp -R "$ROOT/web/." "$ROOT/dist/$NAME/"
echo "staged directory $ROOT/dist/$NAME"

if command -v zip >/dev/null 2>&1; then
  mkdir -p "$DIST"
  ZIP="$DIST/$NAME.zip"
  rm -f "$ZIP"
  (cd web && zip -q -r -X "$ZIP" .)
  echo "$ZIP: $(( $(wc -c <"$ZIP" | tr -d ' ') / 1024 )) KB"
fi
