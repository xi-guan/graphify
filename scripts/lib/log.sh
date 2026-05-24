#!/usr/bin/env bash
# log helpers — source from justfile recipes

_G='\033[0;32m'
_Y='\033[1;33m'
_R='\033[0;31m'
_NC='\033[0m'

log_info()  { printf "${_G}→${_NC} %s\n" "$*"; }
log_warn()  { printf "${_Y}⚠${_NC} %s\n" "$*" >&2; }
log_error() { printf "${_R}✗${_NC} %s\n" "$*" >&2; }
log_done()  { printf "${_G}✓${_NC} %s\n" "$*"; }

# run_quiet: suppress output on success, dump full log on failure
_BUILD_LOG=$(mktemp)
trap 'rm -f "$_BUILD_LOG"' EXIT

run_quiet() {
    local label="$1"; shift
    log_info "$label"
    if "$@" > "$_BUILD_LOG" 2>&1; then
        return 0
    else
        local rc=$?
        log_error "$label failed. log:"
        cat "$_BUILD_LOG" >&2
        exit $rc
    fi
}
