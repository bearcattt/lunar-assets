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
git config advice.addIgnoredFile false

git config --local core.fsync none 2>/dev/null || true

# Get ALL files Git knows about that are not ignored:
# - staged files
# - unstaged new files
# - modified files
mapfile -t ITEMS < <(
    {
        git diff --cached --name-only
        git diff --name-only
        git ls-files --others --exclude-standard
    } | sort -u
)

TOTAL=${#ITEMS[@]}
echo "Found $TOTAL files"

if [ "$TOTAL" -eq 0 ]; then
    echo "Nothing to push."
    exit 0
fi

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