#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# update-logos.sh — One-command logo replacement across all repos
#
# Usage:
#   ./scripts/update-logos.sh ~/black-logo.svg ~/white-logo.svg
#
# What it does:
#   1. Converts SVGs → PNG (988x152) and WebP using Inkscape + ImageMagick
#   2. Copies all variants to the correct locations in:
#      - callsaver-landing/public/img/
#      - callsaver-frontend/public/  (+ images/ dupe)
#      - callsaver-api/email-previews/ and public/
#   3. Prints a summary of what was updated
#
# Prerequisites:
#   - inkscape (CLI)
#   - ImageMagick (convert)
#   - SVGs should be at native 988x152 resolution
# ============================================================

BLACK_SVG="${1:?Usage: $0 <black-logo.svg> <white-logo.svg>}"
WHITE_SVG="${2:?Usage: $0 <black-logo.svg> <white-logo.svg>}"

# Resolve to absolute paths
BLACK_SVG="$(realpath "$BLACK_SVG")"
WHITE_SVG="$(realpath "$WHITE_SVG")"

# Repo roots (adjust if your layout differs)
LANDING="$HOME/callsaver-landing"
FRONTEND="$HOME/callsaver-frontend"
API="$HOME/callsaver-api"

WIDTH=988
HEIGHT=152
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "🎨 Logo Update Script"
echo "━━━━━━━━━━━━━━━━━━━━━"
echo "  Black SVG: $BLACK_SVG"
echo "  White SVG: $WHITE_SVG"
echo ""

# --- Step 1: Convert SVGs to PNG and WebP ---
echo "📐 Converting SVGs → PNG (${WIDTH}x${HEIGHT}) → WebP ..."

for variant in black white; do
  if [ "$variant" = "black" ]; then
    SRC="$BLACK_SVG"
  else
    SRC="$WHITE_SVG"
  fi

  PNG="$TMPDIR/${variant}-logo.png"
  WEBP="$TMPDIR/${variant}-logo.webp"

  # Try modern inkscape flags first, fall back to legacy
  if inkscape --export-type=png --export-filename="$PNG" -w "$WIDTH" -h "$HEIGHT" "$SRC" 2>/dev/null; then
    : # modern inkscape worked
  else
    inkscape --export-png="$PNG" -w "$WIDTH" -h "$HEIGHT" "$SRC" 2>/dev/null
  fi

  convert "$PNG" "$WEBP"
  echo "  ✅ ${variant}-logo: SVG → PNG → WebP"
done

# Also copy SVGs to temp for uniform handling
cp "$BLACK_SVG" "$TMPDIR/black-logo.svg"
cp "$WHITE_SVG" "$TMPDIR/white-logo.svg"

# --- Step 2: Distribute to repos ---
echo ""
echo "📁 Distributing to repositories..."

UPDATED=0

copy_file() {
  local src="$1" dst="$2"
  if [ -d "$(dirname "$dst")" ]; then
    cp "$src" "$dst"
    echo "  → $dst"
    UPDATED=$((UPDATED + 1))
  else
    echo "  ⚠ Skipped (dir missing): $dst"
  fi
}

# --- callsaver-landing/public/img/ ---
echo ""
echo "📦 callsaver-landing"
for ext in svg png webp; do
  copy_file "$TMPDIR/black-logo.$ext" "$LANDING/public/img/black-logo.$ext"
  copy_file "$TMPDIR/white-logo.$ext" "$LANDING/public/img/white-logo.$ext"
done

# --- callsaver-frontend/public/ ---
echo ""
echo "📦 callsaver-frontend"
for ext in svg png webp; do
  copy_file "$TMPDIR/black-logo.$ext" "$FRONTEND/public/black-logo.$ext"
  copy_file "$TMPDIR/white-logo.$ext" "$FRONTEND/public/white-logo.$ext"
done
# Duplicate in images/ subfolder
copy_file "$TMPDIR/black-logo.png" "$FRONTEND/public/images/black-logo.png"

# --- callsaver-api ---
echo ""
echo "📦 callsaver-api"
copy_file "$TMPDIR/black-logo.png" "$API/email-previews/black-logo.png"
copy_file "$TMPDIR/white-logo.svg" "$API/public/white-logo.svg"
# logo-header.png is a copy of black-logo.png used for email headers
copy_file "$TMPDIR/black-logo.png" "$API/public/logo-header.png"

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Done! Updated $UPDATED files across 3 repos."
echo ""
echo "📋 Next steps:"
echo "   1. Visually verify logos in each app"
echo "   2. Upload new logo to Stripe Dashboard → Settings → Branding"
echo "   3. Upload new logo to DocuSeal if used in template"
echo "   4. Regenerate MSA PDF: cd ~/callsaver-api && npx tsx scripts/generate-msa-pdf.ts"
