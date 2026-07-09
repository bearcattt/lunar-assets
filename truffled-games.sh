echo "Creating new entries..."
OUTDIR="truffled"
OUTJSON="games.json"

TMP=$(mktemp)

curl -fsSL "https://truffled.lol/js/json/g.json" -o "$TMP"
NEWJSON=$(mktemp)

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
' "$TMP" > "$NEWJSON"

echo "Updating games.json..."

if [[ -f "$OUTJSON" ]]; then

    jq --slurpfile new "$NEWJSON" '
        map(
            select(
                (.logo // "")
                | startswith("truffled/")
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
echo "Images -> truffled/"
echo "Updated -> games.json"