# shellcheck shell=bash disable=SC2034

store_target_lines() {
    if [ ! -f "$MAGMA_BUG_FILE" ]; then
        printf >&2 "MAGMA_BUG_FILE=%q is not a file\n" "$MAGMA_BUG_FILE"
        return 1
    fi

    local file=${1:-"$OUT/directed_targets.txt"}
    "$MAGMA"/showlinenum.awk path=1 show_header=0 <"$MAGMA_BUG_FILE" \
        | gawk -F':' -v repo_path="$TARGET/repo/" \
            'BEGIN { cmd_base = "readlink -f " repo_path }
            $1 ~ /\.(c|cc|cpp|h|hpp)$/ && $3 ~ /^\+/ {
                cmd = cmd_base $1; cmd | getline path;
                print path ":" $2
            }' >"$file"
    if [ "$(wc -l <"$file")" -lt 1 ]; then
        printf >&2 "No targets found in %q\n" "$MAGMA_BUG_FILE"
        return 1
    fi
}

check_env_magma_bug() {
    if [ -z "$MAGMA_BUG" ]; then
        printf >&2 "MAGMA_BUG is not set\n"
        return 1
    fi
}

store_magma_log_lines() {
    check_env_magma_bug || return 1

    local file=${1:-"$OUT/directed_targets.txt"}
    grep -rIn 'MAGMA_LOG("'"$MAGMA_BUG" "$TARGET/repo" \
        | sed -E 's/^(.+:[0-9]+):.*$/\1/' \
        | sort -u >"$file"
}

make_magma_log_lines_unique() {
    check_env_magma_bug || return 1

    local target_name=$1
    local infile=${2:-"$OUT/directed_targets.txt"}
    (
        case ${1} in
        libtiff)
            case ${MAGMA_BUG} in
            TIF012)
                exec grep -F 'tif_dir.c:313' "$infile"
                ;;
            esac
            ;;
        esac
        cat "$infile"
    )
}
