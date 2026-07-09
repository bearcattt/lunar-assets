#!/usr/bin/env bash

set -euo pipefail

ZONES_URL="https://cdn.jsdelivr.net/gh/freebuisness/assets@latest/zones.json"
COVERS_URL="https://cdn.jsdelivr.net/gh/freebuisness/covers@main"
HTML_COMMITS="https://api.github.com/repos/freebuisness/html/commits"

OUTDIR="gn-math"
OUTJSON="games.json"

MAX_JOBS=8

echo "Cleaning gn-math..."
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

TMP=$(mktemp)

echo "Downloading zones..."
curl -fsSL "$ZONES_URL" -o "$TMP"

echo "Getting HTML version..."

HASH=$(curl -fsSL "$HTML_COMMITS" | jq -r '.[0].sha' 2>/dev/null || true)

if [[ -n "$HASH" && "$HASH" != "null" ]]; then
    HTML_BASE="https://cdn.jsdelivr.net/gh/freebuisness/html@$HASH"
else
    HTML_BASE="https://cdn.jsdelivr.net/gh/freebuisness/html@main"
fi

echo "HTML: $HTML_BASE"

download_cover() {
    local URL="$1"
    local FILE="$2"

    curl \
        --http1.1 \
        --retry 5 \
        --retry-all-errors \
        --retry-delay 1 \
        -fsSL \
        "$URL" \
        -o "$FILE"
}

echo "Downloading covers..."

: > retry.list

jq -r '
.[]
| select(.id != null and .cover != null)
| "\(.id)\t\(.name)\t\(.cover)"
' "$TMP" |
while IFS=$'\t' read -r ID NAME COVER; do

(
    mkdir -p "$OUTDIR/$ID"

    URL="${COVER//\{COVER_URL\}/$COVERS_URL}"

    if ! download_cover "$URL" "$OUTDIR/$ID/img.png"; then
        echo "$URL|$OUTDIR/$ID/img.png|$NAME" >> retry.list
    fi

) &

while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do
    wait -n
done

done

wait


if [[ -s retry.list ]]; then
    echo "Retrying failed covers..."

    while IFS='|' read -r URL FILE NAME; do
        download_cover "$URL" "$FILE" || echo "Failed: $NAME"
    done < retry.list
fi

rm -f retry.list


echo "Creating new entries..."

NEWJSON=$(mktemp)

jq --arg html "$HTML_BASE" '
[
    .[]
    | select(.id != null and .url != null)
    | {
        gamename: .name,
        logo: ("gn-math/" + (.id|tostring) + "/img.png"),
        url: (
            .url
            | sub("\\{HTML_URL\\}"; $html)
        )
    }
]
' "$TMP" > "$NEWJSON"


echo "Updating games.json..."

if [[ -f "$OUTJSON" ]]; then

    jq --slurpfile new "$NEWJSON" '
        map(
            select(
                (.logo // "")
                | startswith("gn-math/")
                | not
            )
        )
        + $new[0]
    ' "$OUTJSON" > "$OUTJSON.tmp"

    mv "$OUTJSON.tmp" "$OUTJSON"

else

    mv "$NEWJSON" "$OUTJSON"

fi

rm -f "$NEWJSON"
rm -f "$TMP"

echo
echo "Done!"
echo "Covers: $OUTDIR/"
echo "Updated: $OUTJSON"