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

search_dirs=()
setup_dir="$TARGET/patches/setup"
if [ -d "$setup_dir" ]; then
    search_dirs+=("$setup_dir")
fi
bugs_dir="$TARGET/patches/bugs"
if [ ! -d "$bugs_dir" ]; then
    echo >&2 "[!] There is no $bugs_dir directory"
    exit 1
fi
search_dirs+=("$bugs_dir")

is_setup=1
has_setup_patches=0
setup_tag=magma-setup

# TODO filter patches by target config.yaml
while read -r patch; do
    kind=$(basename "$(dirname "$patch")")
    if [ "$kind" = setup ]; then
        has_setup_patches=1
    fi
    if [ "$kind" = bugs ] && [ $is_setup -eq 1 ]; then
        # this is the first bug patch, setup is finished
        is_setup=0
        tag=$setup_tag
        if [ $has_setup_patches -eq 1 ]; then
            echo "[+] Setup done, tagging as $tag"
            git add .
            git commit -m $tag
        else
            echo "[-] No setup patches, tagging as $tag"
        fi
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
done < <(find "${search_dirs[@]}" -name "*.patch")

echo "[+] Storing total diff of patches into $OUT/bugs.diff"
git diff $setup_tag..HEAD >"$OUT/bugs.diff"
