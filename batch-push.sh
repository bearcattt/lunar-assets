#!/bin/bash
set -e

BRANCH="main"
BASE_DIR="3kh0"
CHUNK=80

git config gc.auto 0               
git config core.compression 1              
git config pack.threads 0                   
git config http.postBuffer 524288000        
git config pack.deltaCacheSize 1 
git config core.preloadindex true 
git config core.fscache true

mapfile -t FOLDERS < <(find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d | sort)
TOTAL=${#FOLDERS[@]}
echo "⚡ $TOTAL folders — $CHUNK per push, max speed"

git add "$BASE_DIR"/*.* 2>/dev/null && git commit -m "root files" 2>/dev/null || true

PUSHES=0
for (( start=0; start<TOTAL; start+=CHUNK )); do
    end=$((start + CHUNK))
    (( end > TOTAL )) && end=$TOTAL
    slice=("${FOLDERS[@]:start:CHUNK}")

    echo ""
    echo "[$((start+1))..$end / $TOTAL] Adding ${#slice[@]} folders..."

    git add -- "${slice[@]}"

    FIRST=$(basename "${slice[0]}")
    LAST=$(basename "${slice[-1]}")
    git commit -m "Add $FIRST..$LAST ($((end-start)) games)" || { echo "  skip (nothing new)"; continue; }

    PUSHES=$((PUSHES + 1))
    echo ">>> Push #$PUSHES..."
    git push origin "$BRANCH"
done

git config --unset gc.auto
git config --unset core.compression
git config --unset pack.threads
git config --unset http.postBuffer
git config --unset pack.deltaCacheSize

echo ""
echo "Done"
