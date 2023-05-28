# shellcheck shell=bash disable=SC2034

# From https://github.com/google/fuzzbench/blob/9b9fd20fc59f3f3cda1c5442f967562634dbebb6/common/sanitizer.py

declare -A common_sanitizer_options
common_sanitizer_options[handle_abort]=2
common_sanitizer_options[handle_sigbus]=2
common_sanitizer_options[handle_sigfpe]=2
common_sanitizer_options[handle_sigill]=2
common_sanitizer_options[symbolize]=1
common_sanitizer_options[symbolize_inline_frames]=0

declare -A address_sanitizer_options
address_sanitizer_options[alloc_dealloc_mismatch]=0
address_sanitizer_options[allocator_may_return_null]=1
address_sanitizer_options[allocator_release_to_os_interval_ms]=500
address_sanitizer_options[allow_user_segv_handler]=0
address_sanitizer_options[check_malloc_usable_size]=0
address_sanitizer_options[detect_odr_violation]=0
address_sanitizer_options[detect_leaks]=1
address_sanitizer_options[detect_stack_use_after_return]=1
address_sanitizer_options[fast_unwind_on_fatal]=1
address_sanitizer_options[max_uar_stack_size_log]=16
address_sanitizer_options[quarantine_size_mb]=64
address_sanitizer_options[strict_memcmp]=1

declare -A ub_sanitizer_options
ub_sanitizer_options[allocator_release_to_os_interval_ms]=500
ub_sanitizer_options[print_stacktrace]=1

join_sanitizer_options() {
    local sanitizer="$1"
    local sanitizer_options_var="${sanitizer}_sanitizer_options"
    local sanitizer_options_keys
    IFS=' ' read -r -a sanitizer_options_keys <<<"$(eval echo "\${!${sanitizer_options_var}[@]}")"
    local sanitizer_options_str="" idx=0 val
    for option in "${sanitizer_options_keys[@]}"; do
        val="$(eval echo "\${${sanitizer_options_var}[$option]}")"
        if [ $idx -gt 0 ]; then
            sanitizer_options_str="$sanitizer_options_str:"
        fi
        sanitizer_options_str="$sanitizer_options_str$option=$val"
        ((idx++))
    done
    echo "$sanitizer_options_str"
}

clone_aarray() {
    local -n array="$1"
    local -n clone="$2"
    for key in "${!array[@]}"; do
        clone[$key]="${array[$key]}"
    done
}

set_sanitizer_options() {
    local is_fuzzing="$1"
    local -A cpy_common_sanitizer_options
    clone_aarray common_sanitizer_options cpy_common_sanitizer_options
    local -A cpy_ub_sanitizer_options
    clone_aarray ub_sanitizer_options cpy_ub_sanitizer_options

    if [[ $is_fuzzing == 1 ]]; then
        cpy_common_sanitizer_options[symbolize]=0
        cpy_common_sanitizer_options[abort_on_error]=1
        cpy_ub_sanitizer_options[print_stacktrace]=0
    fi

    local common_options_str
    common_options_str="$(join_sanitizer_options cpy_common)"
    ASAN_OPTIONS="$common_options_str:$(join_sanitizer_options address)"
    UBSAN_OPTIONS="$common_options_str:$(join_sanitizer_options cpy_ub)"
    export ASAN_OPTIONS UBSAN_OPTIONS
}
