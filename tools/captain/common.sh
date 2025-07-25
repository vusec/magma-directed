# shellcheck shell=bash

export TARBALL_BASENAME="ball"

echo_time() {
    date "+[%F %R] $*"
}
export -f echo_time

contains_element() {
    local e match="$1"
    shift
    for e; do [[ $e == "$match" ]] && return 0; done
    return 1
}
export -f contains_element

magma_image_name() {
    # shellcheck disable=SC2153
    local img="magma/$FUZZER/$TARGET"
    if [ -n "$BUG" ]; then
        img="$img/$BUG"
    fi
    # image repository names have to be lowercase
    awk '{print tolower($0)}' <<<"$img"
}
export -f magma_image_name

magma_analysis_image_name() { awk '{print tolower($0)}' <<<"magma/$ANALYSIS/$TARGET"; }
export -f magma_analysis_image_name

magma_patch_for_bug() { printf '%s/targets/%s/patches/bugs/%s.patch' "$MAGMA" "$TARGET" "$BUG"; }
export -f magma_patch_for_bug

meta_var() {
    join_by() {
        local IFS="$1"
        shift
        echo "$*"
    }

    local pattern name value
    pattern=$(join_by _ "${@}")
    name="$(eval echo "${pattern}")"
    name="${name}[@]"
    value="${!name}"
    echo "${value[@]}"
}
export -f meta_var

get_var_or_default() {
    local value
    value=$(meta_var "${@}")
    if [ -z "$value" ] || [ ${#value[@]} -eq 0 ]; then
        set -- "DEFAULT" "${@:2}"
        value=$(meta_var "${@}")
        if [ -z "$value" ] || [ ${#value[@]} -eq 0 ]; then
            set -- "${@:2}"
            value=$(meta_var "${@}")
        fi
    fi
    echo "${value[@]}"
}
export -f get_var_or_default

setup_defaults_for_fuzzer() {
    # XXX: make variables that could interfere with other scripts/functions local
    local DIRECTED
    # shellcheck disable=SC1090
    source "$MAGMA/fuzzers/$1/configrc"
    declare -g "$1_DIRECTED"="$DIRECTED"
}

setup_defaults() {
    pushd "$MAGMA/fuzzers" &>/dev/null
    shopt -s nullglob
    ALL_FUZZERS=(*)
    shopt -u nullglob

    local IFUZZER
    for IFUZZER in "${ALL_FUZZERS[@]}"; do
        if [ ! -f "$MAGMA/fuzzers/$IFUZZER/configrc" ]; then
            continue
        fi
        setup_defaults_for_fuzzer "$IFUZZER"
    done
    popd &>/dev/null

    pushd "$MAGMA/targets" &>/dev/null
    if [ -z ${DEFAULT_TARGETS+x} ]; then
        shopt -s nullglob
        DEFAULT_TARGETS=(*)
        shopt -u nullglob
    fi

    local ITARGET IPROGRAM IBUG
    for ITARGET in "${DEFAULT_TARGETS[@]}"; do
        # shellcheck disable=SC1090
        source "$MAGMA/targets/$ITARGET/configrc"

        if [ -z "$(meta_var DEFAULT "$ITARGET" PROGRAMS)" ]; then
            # shellcheck disable=SC2153
            local PROGRAMS_str="${PROGRAMS[*]}"
            declare -g -a "DEFAULT_${ITARGET}_PROGRAMS"="($PROGRAMS_str)"
        fi

        local target_bugs
        pushd "$ITARGET/patches/bugs" &>/dev/null
        shopt -s nullglob
        target_bugs=(*)
        shopt -u nullglob
        popd &>/dev/null
        for IBUG in "${!target_bugs[@]}"; do
            target_bugs[$IBUG]="${target_bugs[$IBUG]%.patch}"
        done

        for IPROGRAM in "${PROGRAMS[@]}"; do
            if [ -z "$(meta_var DEFAULT "$ITARGET" "$IPROGRAM" BUGS)" ]; then
                local BUGS_str="${target_bugs[*]}"
                declare -g -a "DEFAULT_${ITARGET}_${IPROGRAM}_BUGS"="($BUGS_str)"
            fi
            local varname="${IPROGRAM}_ARGS"
            declare -g "DEFAULT_${ITARGET}_${IPROGRAM}_ARGS"="${!varname}"
        done
    done
    popd &>/dev/null
}

if [ -n "$MAGMA" ]; then
    setup_defaults
else
    echo 'The $MAGMA environment variable must be set before sourcing common.sh'
    exit 1
fi
