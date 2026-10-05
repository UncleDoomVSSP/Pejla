#!/usr/bin/env bash
# Downloads the IEEE OUI registry so release builds can name device vendors.
# Falls back to Wireshark's manufacturer list converted to the same CSV shape.
# Never fails the build: without the file the app uses its built-in table.
# Usage: Scripts/fetch-oui.sh dist/oui.csv
set -uo pipefail

OUTPUT="$1"
UA="Pejla-build (https://github.com/UncleDoomVSSP/Pejla)"

if curl -fsSL --retry 3 --max-time 120 -A "$UA" "https://standards-oui.ieee.org/oui/oui.csv" -o "$OUTPUT.tmp" \
   && grep -q '^MA-L,' "$OUTPUT.tmp"; then
  mv "$OUTPUT.tmp" "$OUTPUT"
  echo "Fetched IEEE registry: $(grep -c '^MA-L,' "$OUTPUT") entries"
  exit 0
fi
rm -f "$OUTPUT.tmp"

if curl -fsSL --retry 3 --max-time 120 -A "$UA" "https://www.wireshark.org/download/automated/data/manuf" -o "$OUTPUT.manuf"; then
  {
    echo "Registry,Assignment,Organization Name,Organization Address"
    awk -F'\t' '
      $1 ~ /^[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]$/ {
        prefix = toupper($1); gsub(":", "", prefix)
        name = ($3 != "") ? $3 : $2
        gsub("\"", "\"\"", name)
        printf "MA-L,%s,\"%s\",\n", prefix, name
      }' "$OUTPUT.manuf"
  } > "$OUTPUT"
  rm -f "$OUTPUT.manuf"
  echo "Fetched Wireshark manuf list: $(grep -c '^MA-L,' "$OUTPUT") entries"
  exit 0
fi

echo "Could not download a vendor list; the built-in table will be used." >&2
rm -f "$OUTPUT"
exit 0
