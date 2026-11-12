#!/usr/bin/env bash
set -euo pipefail

# ── directories ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GTFS_DIR="$ROOT_DIR/data/raw/gtfs"
RAW_DIR="$ROOT_DIR/data/raw"
TURNSTILE_CSV="$RAW_DIR/turnstile.csv"

echo "[1/4] Creating data directories..."
mkdir -p "$GTFS_DIR"
mkdir -p "$RAW_DIR"

# ── GTFS download ─────────────────────────────────────────────────────────────
GTFS_ZIP="$GTFS_DIR/gtfs_subway.zip"
echo "[2/4] Downloading GTFS subway data..."
curl -# -L "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_subway.zip" -o "$GTFS_ZIP"
echo "      Download complete: $GTFS_ZIP"

echo "[3/4] Unzipping GTFS data..."
unzip -o "$GTFS_ZIP" -d "$GTFS_DIR"
echo "      Unzipped into $GTFS_DIR"
ls "$GTFS_DIR/"

# ── Turnstile download ────────────────────────────────────────────────────────
# Columns we need: station_complex_id, transit_timestamp, ridership
# Filter: subway only, last 2 years (from 2024-01-01)
BASE_URL="https://data.ny.gov/resource/wujg-7c2s.csv"
WHERE="\$where=transit_timestamp>='2024-01-01T00:00:00' AND transit_mode='subway'"
SELECT="\$select=station_complex_id,transit_timestamp,ridership"
LIMIT=50000
OFFSET=0
FIRST_PAGE=true
TMP_PAGE="/tmp/turnstile_page_$$.csv"
PAGE_NUM=0

echo "[4/4] Downloading MTA turnstile data (paginated)..."
# Remove any existing output file
rm -f "$TURNSTILE_CSV"

while true; do
  PAGE_NUM=$((PAGE_NUM + 1))
  URL="${BASE_URL}?${WHERE}&${SELECT}&\$limit=${LIMIT}&\$offset=${OFFSET}&\$order=transit_timestamp"
  echo "      Fetching page $PAGE_NUM (offset=$OFFSET)..."

  HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP_PAGE" --get \
    --data-urlencode "\$where=transit_timestamp>='2024-01-01T00:00:00' AND transit_mode='subway'" \
    --data-urlencode "\$select=station_complex_id,transit_timestamp,ridership" \
    --data-urlencode "\$limit=$LIMIT" \
    --data-urlencode "\$offset=$OFFSET" \
    --data-urlencode "\$order=transit_timestamp" \
    "$BASE_URL")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "      ERROR: HTTP $HTTP_CODE on page $PAGE_NUM"
    cat "$TMP_PAGE"
    exit 1
  fi

  ROW_COUNT=$(wc -l < "$TMP_PAGE")
  # Subtract 1 for header; each line is a row
  DATA_ROWS=$((ROW_COUNT - 1))
  echo "      Page $PAGE_NUM: $DATA_ROWS data rows"

  if [ "$FIRST_PAGE" = true ]; then
    # Keep header
    cat "$TMP_PAGE" >> "$TURNSTILE_CSV"
    FIRST_PAGE=false
  else
    # Skip header (first line)
    tail -n +2 "$TMP_PAGE" >> "$TURNSTILE_CSV"
  fi

  # If we got fewer than LIMIT rows, we've exhausted the dataset
  if [ "$DATA_ROWS" -lt "$LIMIT" ]; then
    echo "      Last page reached (got $DATA_ROWS < $LIMIT rows)."
    break
  fi

  OFFSET=$((OFFSET + LIMIT))

  # Safety cap: stop at 6 million rows (~6 months+ of subway data)
  TOTAL_ROWS=$(wc -l < "$TURNSTILE_CSV")
  if [ "$TOTAL_ROWS" -gt 6000000 ]; then
    echo "      Safety cap reached ($TOTAL_ROWS rows). Stopping early."
    break
  fi
done

rm -f "$TMP_PAGE"

FINAL_ROWS=$(wc -l < "$TURNSTILE_CSV")
echo "      Turnstile data saved to $TURNSTILE_CSV ($FINAL_ROWS total lines incl. header)"

echo ""
echo "Done! Summary:"
echo "  GTFS files:      $GTFS_DIR"
echo "  Turnstile CSV:   $TURNSTILE_CSV"
