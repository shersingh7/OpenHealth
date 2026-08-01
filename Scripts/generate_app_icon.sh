#!/usr/bin/env bash
# Regenerate the full-bleed OpenHealth iOS app icon from its checked-in SVG source.
# Requires ImageMagick (`magick`). The SVG uses solid fills only (no filters/strokes).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Resources/AppIconSource.svg"
OUTPUT="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
# Previews live outside the asset catalog so Xcode does not require Contents.json slots.
PREVIEW_DIR="$ROOT/Resources/icon-previews"
PREVIEW="$PREVIEW_DIR/AppIcon-preview-180.png"
MONTAGE="$PREVIEW_DIR/AppIcon-montage.png"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick ('magick') is required to regenerate the app icon." >&2
  exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing icon source: $SOURCE" >&2
  exit 1
fi

# Render SVG → opaque 1024×1024 sRGB PNG24 (no alpha).
# Explicit blue background so any transparent SVG areas never become black.
magick \
  -background '#087CF2' \
  -density 288 \
  "$SOURCE" \
  -resize '1024x1024!' \
  -alpha off \
  -colorspace sRGB \
  -type TrueColor \
  -depth 8 \
  -strip \
  "PNG24:$OUTPUT"

# Small preview + montage for visual inspection (not required by the asset catalog).
mkdir -p "$PREVIEW_DIR"
magick "$OUTPUT" -resize '180x180!' "PNG24:$PREVIEW"
magick \
  \( "$OUTPUT" -resize '256x256!' \) \
  \( "$OUTPUT" -resize '128x128!' \) \
  \( "$OUTPUT" -resize '64x64!' \) \
  +append \
  "PNG24:$MONTAGE"

# --- Mechanical validation ---
read -r WIDTH HEIGHT DEPTH COLORS OPAQUE <<<"$(
  magick identify -format '%w %h %[bit-depth] %k %[opaque]' "$OUTPUT"
)"

if [[ "$WIDTH" != "1024" || "$HEIGHT" != "1024" ]]; then
  echo "Icon size validation failed: ${WIDTH}x${HEIGHT} (expected 1024x1024)" >&2
  exit 1
fi

# %[opaque] is True when every pixel is fully opaque.
if [[ "$OPAQUE" != "True" ]]; then
  echo "Icon must be opaque (no alpha). opaque=$OPAQUE" >&2
  exit 1
fi

sample_rgb() {
  local x="$1" y="$2"
  magick "$OUTPUT" -format "%[fx:int(255*p{$x,$y}.r)],%[fx:int(255*p{$x,$y}.g)],%[fx:int(255*p{$x,$y}.b)]" info:
}

is_near_color() {
  # args: r g b expected_r expected_g expected_b max_delta
  local r="$1" g="$2" b="$3" er="$4" eg="$5" eb="$6" d="$7"
  local dr dg db
  dr=$(( r > er ? r - er : er - r ))
  dg=$(( g > eg ? g - eg : eg - g ))
  db=$(( b > eb ? b - eb : eb - b ))
  [[ $dr -le $d && $dg -le $d && $db -le $d ]]
}

is_not_black() {
  local r="$1" g="$2" b="$3"
  [[ $r -gt 20 || $g -gt 20 || $b -gt 20 ]]
}

# Corner / background → brand blue #087CF2
IFS=',' read -r br bg bb <<<"$(sample_rgb 16 16)"
if ! is_not_black "$br" "$bg" "$bb"; then
  echo "Background pixel is black/near-black: rgb($br,$bg,$bb)" >&2
  exit 1
fi
if ! is_near_color "$br" "$bg" "$bb" 8 124 242 40; then
  echo "Background is not brand blue: rgb($br,$bg,$bb) expected ~#087CF2" >&2
  exit 1
fi

# Shield interior → white
IFS=',' read -r sr sg sb <<<"$(sample_rgb 512 220)"
if ! is_near_color "$sr" "$sg" "$sb" 255 255 255 30; then
  echo "Shield pixel is not white: rgb($sr,$sg,$sb)" >&2
  exit 1
fi

# Heart → coral #EE3656
IFS=',' read -r hr hg hb <<<"$(sample_rgb 512 520)"
if ! is_near_color "$hr" "$hg" "$hb" 238 54 86 50; then
  echo "Heart pixel is not coral: rgb($hr,$hg,$hb) expected ~#EE3656" >&2
  exit 1
fi

# Arrow tip region → white
IFS=',' read -r ar ag ab <<<"$(sample_rgb 642 356)"
if ! is_near_color "$ar" "$ag" "$ab" 255 255 255 40; then
  echo "Arrow tip pixel is not white: rgb($ar,$ag,$ab)" >&2
  exit 1
fi

# Arrow shaft midpoint → white
IFS=',' read -r mr mg mb <<<"$(sample_rgb 536 462)"
if ! is_near_color "$mr" "$mg" "$mb" 255 255 255 40; then
  echo "Arrow shaft pixel is not white: rgb($mr,$mg,$mb)" >&2
  exit 1
fi

# Global statistics: reject near-black placeholders.
MEAN="$(magick "$OUTPUT" -format '%[fx:mean]' info:)"
python3 - "$MEAN" "$COLORS" <<'PY'
import sys
mean = float(sys.argv[1])
colors = int(sys.argv[2])
if mean < 0.25:
    print(f"Icon mean luminance too low ({mean:.4f}); likely black/near-black", file=sys.stderr)
    sys.exit(1)
if colors < 8:
    print(f"Icon has too few unique colors ({colors}); expected multi-color mark", file=sys.stderr)
    sys.exit(1)
print(f"stats ok: mean={mean:.4f} colors={colors}")
PY

# Confirm no alpha channel via sips when available.
if command -v sips >/dev/null 2>&1; then
  HAS_ALPHA="$(sips -g hasAlpha "$OUTPUT" 2>/dev/null | awk '/hasAlpha/ {print $2}')"
  if [[ "$HAS_ALPHA" == "yes" ]]; then
    echo "sips reports hasAlpha=yes; App Store icons must be opaque" >&2
    exit 1
  fi
fi

echo "Generated $OUTPUT (${WIDTH}x${HEIGHT}, depth=${DEPTH}, colors=${COLORS})"
echo "Preview: $PREVIEW"
echo "Montage: $MONTAGE"
echo "Samples: bg=rgb($br,$bg,$bb) shield=rgb($sr,$sg,$sb) heart=rgb($hr,$hg,$hb) arrow=rgb($ar,$ag,$ab)"
