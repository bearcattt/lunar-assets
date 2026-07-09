#!/bin/bash

echo "Creating new entries..."

OUTDIR="wasmrip"
OUTJSON="games.json"

TMP=$(mktemp)
NEWJSON=$(mktemp)

mkdir -p "$OUTDIR"

echo "Downloading wasm.rip game list..."

curl -fsSL "https://wasm.rip/games.json" -o "$TMP"

if [[ ! -s "$TMP" ]]; then
    echo "Failed to download games.json"
    exit 1
fi

echo "Generating games.json entries..."

jq '
[
  .[]
  | {
      gamename: .name,
      logo: (
        "wasmrip/" +
        (
          .name
          | ascii_downcase
          | gsub("[^a-z0-9]+"; "-")
        ) +
        "/" +
        (
          .imageUrl
          | split("/")[-1]
        )
      ),
      url: ("wasm.rip/" + .gameUrl),
      image: .imageUrl
    }
]
' "$TMP" > "$NEWJSON"


echo "Downloading images..."

jq -c '.[]' "$NEWJSON" | while read -r game; do

    LOGO=$(echo "$game" | jq -r '.logo')
    IMAGE=$(echo "$game" | jq -r '.image')

    DIR=$(dirname "$LOGO")

    mkdir -p "$DIR"

    echo "Downloading $IMAGE"

    curl -fsSL \
        "https://wasm.rip/$IMAGE" \
        -o "$LOGO" || true

done


echo "Updating games.json..."

if [[ -f "$OUTJSON" ]]; then

    jq --slurpfile new "$NEWJSON" '
        map(
            select(
                (.logo // "")
                | startswith("wasmrip/")
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
echo "Images -> wasmrip/"
echo "Updated -> games.json"