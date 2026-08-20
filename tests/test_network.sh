#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/src/network.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
attempts=$test_dir/attempts

_wget() {
    local output= url= arg
    while [[ $# -gt 0 ]]; do
        arg=$1
        shift
        case $arg in
        -O)
            output=$1
            shift
            ;;
        http://* | https://*)
            url=$arg
            ;;
        esac
    done
    printf '%s\n' "$url" >>"$attempts"
    [[ $url == https://ghfast.top/* ]] || return 1
    printf 'fixture-data\n' >"$output"
}

XRAY_GITHUB_PROXY=auto github_download \
    https://github.com/example/project/releases/download/v1/file.zip \
    "$test_dir/file.zip" fixture

grep -q '^https://gh-proxy.com/' "$attempts"
grep -q '^https://ghfast.top/' "$attempts"
[[ $(cat "$test_dir/file.zip") == fixture-data ]]

printf '%s  file.zip\n' "$(sha256sum "$test_dir/file.zip" | awk '{print $1}')" \
    >"$test_dir/file.zip.sha256"
verify_sha256 "$test_dir/file.zip" "$test_dir/file.zip.sha256" file.zip

printf 'SHA2-256= %s\n' "$(sha256sum "$test_dir/file.zip" | awk '{print $1}')" \
    >"$test_dir/file.zip.dgst"
verify_sha256 "$test_dir/file.zip" "$test_dir/file.zip.dgst" file.zip

echo 'network helper tests passed'
