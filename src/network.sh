#!/bin/bash

# Mainland-China friendly network helpers.  Set XRAY_GITHUB_PROXY to a custom
# prefix, a comma/space separated list, "auto" (default), or "direct".
github_proxy_candidates() {
    local configured=${XRAY_GITHUB_PROXY:-auto}
    local base
    if [[ $configured == direct || $configured == none ]]; then
        printf '%s\n' direct
        return
    fi
    if [[ $configured != auto ]]; then
        configured=${configured//,/ }
        for base in $configured; do
            [[ $base != */ ]] && base="$base/"
            printf '%s\n' "$base"
        done
    else
        printf '%s\n' \
            'https://gh-proxy.com/' \
            'https://ghfast.top/' \
            'https://ghproxy.net/'
    fi
    printf '%s\n' direct
}

github_download() {
    local original_url=$1
    local output=$2
    local display_name=${3:-file}
    local base candidate
    while IFS= read -r base; do
        [[ $base == direct ]] && candidate=$original_url || candidate="${base}${original_url}"
        rm -f "$output"
        echo "尝试下载 ${display_name}: ${candidate}" >&2
        if _wget -t 2 -T 30 -q "$candidate" -O "$output" && [[ -s $output ]]; then
            return 0
        fi
    done < <(github_proxy_candidates)
    rm -f "$output"
    return 1
}

github_read() {
    local url=$1
    local tmp
    tmp=$(mktemp) || return 1
    if github_download "$url" "$tmp" metadata; then
        cat "$tmp"
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

verify_sha256() {
    local file=$1
    local checksum_file=$2
    local asset_name=$3
    local expected actual
    expected=$(awk -v f="$asset_name" '$2 == f || $2 == "*" f {print $1; exit}' "$checksum_file")
    [[ $expected ]] || expected=$(grep -i -E 'SHA(2-)?-?256' "$checksum_file" | grep -E -o '[[:xdigit:]]{64}' | head -n1)
    [[ $expected =~ ^[[:xdigit:]]{64}$ ]] || return 1
    actual=$(sha256sum "$file" | awk '{print $1}')
    [[ ${actual,,} == ${expected,,} ]]
}

download_and_verify() {
    local url=$1
    local output=$2
    local display_name=$3
    local checksum_suffix=$4
    local checksum_url=${5:-${url}${checksum_suffix}}
    local checksum_file="${output}.checksum"
    local asset_name=${url##*/}
    github_download "$url" "$output" "$display_name" || return 1
    [[ ${XRAY_VERIFY_CHECKSUM:-1} == 0 ]] && return 0
    github_download "$checksum_url" "$checksum_file" "${display_name} checksum" || return 1
    verify_sha256 "$output" "$checksum_file" "$asset_name"
}

network_get_ip() {
    local public_ip
    public_ip=$(_wget -4 -T 10 -qO- https://4.ipw.cn 2>/dev/null | tr -d '[:space:]')
    [[ $public_ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] && ip=$public_ip
    if [[ -z $ip ]]; then
        public_ip=$(_wget -4 -T 10 -qO- https://ip.3322.net 2>/dev/null | tr -d '[:space:]')
        [[ $public_ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] && ip=$public_ip
    fi
    if [[ -z $ip ]]; then
        public_ip=$(_wget -6 -T 10 -qO- https://6.ipw.cn 2>/dev/null | tr -d '[:space:]')
        [[ $public_ip == *:* ]] && ip=$public_ip
    fi
    export ip
}

network_dns_lookup() {
    local name=$1
    local record_type=$2
    _wget -qO- --header='accept: application/dns-json' \
        "https://dns.alidns.com/resolve?name=${name}&type=${record_type}"
}
