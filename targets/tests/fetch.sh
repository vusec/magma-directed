#!/bin/bash
set -ex
# Needed because magma/apply_patches.sh requires code to be in $TARGET/repo
cp -r "$TARGET/src" "$TARGET/repo"
