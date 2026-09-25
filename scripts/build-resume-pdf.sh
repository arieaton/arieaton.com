#!/usr/bin/env bash
# Renders public/resume/index.html to public/resume.pdf using headless Chrome,
# so the PDF is always generated from the same source as the web page and the
# two can't drift apart. Re-run this after editing the resume.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/public/resume/index.html"
OUT="$ROOT/public/resume.pdf"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ ! -x "$CHROME" ]; then
  echo "Chrome not found at: $CHROME" >&2
  echo "Install Chrome, or open $SRC and use Cmd+P -> Save as PDF." >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "Missing $SRC" >&2
  exit 1
fi

TMP="$(mktemp -d)"
cleanup() { kill "${CHROME_PID:-0}" 2>/dev/null || true; rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

rm -f "$OUT"

# Headless Chrome doesn't reliably exit after --print-to-pdf here, so run it in
# the background, wait for the file, then stop it. --virtual-time-budget gives
# the webfont time to load so the PDF uses JetBrains Mono, not a fallback.
"$CHROME" \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=8000 \
  --user-data-dir="$TMP" \
  --print-to-pdf="$OUT" \
  "file://$SRC" >/dev/null 2>&1 &
CHROME_PID=$!

for _ in $(seq 1 60); do
  if [ -s "$OUT" ]; then sleep 1; break; fi
  sleep 0.5
done

if [ ! -s "$OUT" ]; then
  echo "PDF generation produced no output" >&2
  exit 1
fi

PAGES="$(python3 -c "
import re,sys
d=open('$OUT','rb').read()
print(len(re.findall(rb'/Type\s*/Page[^s]', d)))
" 2>/dev/null || echo '?')"

echo "Wrote $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes, $PAGES page(s))"
[ "$PAGES" = "1" ] || echo "note: resume is $PAGES pages -- tighten the @media print block to fit one" >&2
