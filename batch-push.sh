#!/usr/bin/env bash
set -euo pipefail

BRANCH="main"
CHUNK=250

git config gc.auto 0
git config core.compression 0
git config pack.threads 0
git config protocol.version 2
git config commit.gpgSign false
git config core.preloadindex true
git config core.fscache true
git config http.postBuffer 524288000

git config --local core.fsync none 2>/dev/null || true
git config advice.addIgnoredFile false

mapfile -t ITEMS < <(
    find . -mindepth 1 -maxdepth 1 \
        ! -name ".git" \
        | while read -r f; do
            git check-ignore -q "$f" || printf '%s\n' "$f"
        done \
        | sort
)

TOTAL=${#ITEMS[@]}
echo "Found $TOTAL items"

PUSH=1

for ((i=0; i<TOTAL; i+=CHUNK)); do
    slice=("${ITEMS[@]:i:CHUNK}")

    git add -- "${slice[@]}"

    if git diff --cached --quiet; then
        continue
    fi

    git commit -qm "Chunk $PUSH"

    echo "Push $PUSH"

    git push --no-verify origin "$BRANCH"

    PUSH=$((PUSH+1))
done

echo "Done."