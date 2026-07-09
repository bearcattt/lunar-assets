#!/usr/bin/env bash

set -euo pipefail

BASE="https://truffled.lol"
JSON_URL="$BASE/js/json/g.json"

OUTDIR="truffled"
OUTJSON="games.json"

MAX_JOBS=16

echo "Cleaning old files..."
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

TMP=$(mktemp)

echo "Downloading game database..."
curl -sL "$JSON_URL" -o "$TMP"

echo "Downloading images..."

while IFS=$'\t' read -r THUMB FOLDER; do
    (
        mkdir -p "$OUTDIR/$FOLDER"

        URL="$BASE/${THUMB#/}"
        FILE="$OUTDIR/$FOLDER/img.webp"

        curl -fsSL "$URL" -o "$FILE" || echo "Failed: $URL"
    ) &

    while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do
        wait -n
    done

done < <(
jq -r '
.games[]
| select((.name | ascii_downcase) != "random")
| [
    (.thumbnail | ltrimstr("/")),
    (
      if (.url | startswith("/gamefile/")) then
        (.url | split("/")[-1] | sub("\\.html$"; ""))
      else
        (.url | split("/")[-2])
      end
    )
  ]
| @tsv
' "$TMP"
)

wait

echo "Creating JSON..."

jq '
[
  .games[]
  | select((.name | ascii_downcase) != "random")
  | {
      gamename: .name,
      logo: (
        "truffled/" +
        (
          if (.url | startswith("/gamefile/")) then
            (.url | split("/")[-1] | sub("\\.html$"; ""))
          else
            (.url | split("/")[-2])
          end
        ) +
        "/img.webp"
      ),
      url: ("truffled.lol" + .url)
    }
]
' "$TMP" > "$OUTJSON"

rm "$TMP"

echo
echo "Finished!"
echo "Images saved: $OUTDIR/"
echo "JSON saved: $OUTJSON"