#!/bin/bash
set -e

BASE_DIR="3kh0"
OUT="games.json"

mapfile -t FOLDERS < <(find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d | sort)

echo "["  > "$OUT"

TOTAL=${#FOLDERS[@]}
for (( i=0; i<TOTAL; i++ )); do
    dir="${FOLDERS[$i]}"
    name=$(basename "$dir")
    name_escaped="${name//\"/\\\"}"
    name_display="${name_escaped//-/ }"

    entry="  {\"gamename\": \"$name_display\", \"logo\": \"$BASE_DIR/$name_escaped/img.webp\", \"url\": \"$BASE_DIR/$name_escaped/index.html\"}"

    if (( i < TOTAL - 1 )); then
        echo "$entry,"  >> "$OUT"
    else
        echo "$entry"   >> "$OUT"
    fi
done

echo "]" >> "$OUT"

echo "Done."
