#!/bin/bash
set -e

##
# Pre-requirements:
# - env TARGET: path to target work dir
# + env APPLY_ALL: if set, apply all patches (default: unset)
##

cd "$TARGET/repo"

# configure git to create commits
git config user.name &>/dev/null || git config --global user.name magma
git config user.email &>/dev/null || git config --global user.email '<>'

# initialize git repo if needed
if [ ! -d .git ]; then
    git init
    git add .
    git commit -m init
fi

tag=magma-init
echo "[+] Tagging initial git state with $tag"
git tag $tag

find_patches() { find "$1" -name "*.patch" -print0 | sort -z; }
patch_name() { local name=${1##*/}; echo "${name%.patch}"; }

# apply setup patches
has_setup_patches=0
setup_tag=magma-setup
setup_dir="$TARGET/patches/setup"
if [ -d "$setup_dir" ]; then
    while read -r -d '' patch; do
        has_setup_patches=1
        echo "[+] Applying setup $patch"
        patch -p1 --no-backup-if-mismatch <"$patch"
    done < <(find_patches "$setup_dir")
fi

if [ $has_setup_patches -eq 1 ]; then
    echo "[+] Setup done, tagging as $setup_tag"
    git add .
    git commit -m $setup_tag
else
    echo "[-] No setup patches, tagging as $setup_tag"
fi

git tag $setup_tag

# apply bug patches
bugs_dir="$TARGET/patches/bugs"
if [ ! -d "$bugs_dir" ]; then
    echo >&2 "[!] There is no $bugs_dir directory"
    exit 1
fi

if [ -n "$MAGMA_BUG" ] && [ ! -f "$bugs_dir/$MAGMA_BUG.patch" ]; then
    echo >&2 "[!] There is no $bugs_dir/$MAGMA_BUG.patch file"
    exit 1
fi

# sort patches by name and place the target patch at the end
bugs=()
while read -r -d '' patch; do
    if [ -z "$MAGMA_BUG" ]; then
        bugs+=("$patch")
    elif [ -n "$APPLY_ALL" ] && [ "$(patch_name "$patch")" != "$MAGMA_BUG" ]; then
        bugs+=("$patch")
    fi
done < <(find_patches "$bugs_dir")

if [ -n "$MAGMA_BUG" ]; then
    bugs+=("$bugs_dir/$MAGMA_BUG.patch")
fi

for patch in "${bugs[@]}"; do
    echo "[+] Applying bug $patch"
    name=$(patch_name "$patch")
    sed "s/%MAGMA_BUG%/$name/g" "$patch" | patch -p1 --no-backup-if-mismatch
    tag="magma-bug-$name"
    echo "[+] Tagging $tag"
    git add .
    git commit -m "$tag"
    git tag "$tag"
    if [ -n "$MAGMA_BUG" ] && [ "$name" = "$MAGMA_BUG" ]; then
        echo "[+] Storing $OUT/bug_$name.diff"
        git diff "$tag^..$tag" >"$OUT/bug_$name.diff"
    fi
done

echo "[+] Storing total diff of patches into $OUT/bugs.diff"
git diff $setup_tag..HEAD >"$OUT/bugs.diff"
