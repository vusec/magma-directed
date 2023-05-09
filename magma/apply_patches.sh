#!/bin/bash
set -e

##
# Pre-requirements:
# - env TARGET: path to target work dir
##

cd "$TARGET/repo"

git config user.name &>/dev/null || git config --global user.name magma
git config user.email &>/dev/null || git config --global user.email '<>'

if [ ! -d .git ]; then
    git init
    git add .
    git commit -m init
fi

tag=magma-init
echo "[+] Tagging initial git state with $tag"
git tag $tag

is_setup=1
setup_tag=magma-setup

# TODO filter patches by target config.yaml
while read -r patch; do
    kind=$(basename "$(dirname "$patch")")
    if [ "$kind" = bugs ] && [ $is_setup -eq 1 ]; then
        # this is the first bug patch, setup is finished
        is_setup=0
        tag=$setup_tag
        echo "[+] Setup done, tagging as $tag"
        git add .
        git commit -m $tag
        git tag $tag
    fi

    echo "[+] Applying $patch"
    name=${patch##*/}
    name=${name%.patch}
    sed "s/%MAGMA_BUG%/$name/g" "$patch" | patch -p1 --no-backup-if-mismatch

    if [ "$kind" = bugs ]; then
        oldtag=$tag
        tag="magma-bug-$name"
        echo "[+] Tagging $tag"
        git add .
        git commit -m "$tag"
        git tag "$tag"
        echo "[+] Storing $OUT/bug_$name.diff"
        git diff "$oldtag..$tag" >"$OUT/bug_$name.diff"
    fi
done < <(find "$TARGET/patches/setup" "$TARGET/patches/bugs" -name "*.patch")

echo "[+] Storing total diff of patches into $OUT/bugs.diff"
git diff $setup_tag..HEAD >"$OUT/bugs.diff"
