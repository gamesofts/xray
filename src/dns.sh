is_dns_list=(
    223.5.5.5
    119.29.29.29
    https://dns.alidns.com/dns-query
    https://doh.pub/dns-query
    1.1.1.1
    8.8.8.8
    set
    none
)
dns_set() {
    if [[ $1 ]]; then
        case ${1,,} in
        223 | ali | alidns)
            is_dns_use=${is_dns_list[0]}
            ;;
        119 | dnspod | tencent)
            is_dns_use=${is_dns_list[1]}
            ;;
        alidoh)
            is_dns_use=${is_dns_list[2]}
            ;;
        dohpub)
            is_dns_use=${is_dns_list[3]}
            ;;
        11 | 1111 | cloudflare)
            is_dns_use=${is_dns_list[4]}
            ;;
        88 | 8888 | google)
            is_dns_use=${is_dns_list[5]}
            ;;
        set)
            if [[ $2 ]]; then
                is_dns_use=${2,,}
            else
                ask string is_dns_use "请输入 DNS: "
            fi
            ;;
        none)
            is_dns_use=none
            ;;
        *)
            err "无法识别 DNS 参数: $@"
            ;;
        esac
    else
        is_tmp_list=(${is_dns_list[@]})
        ask list is_dns_use null "\n请选择 DNS:\n"
        if [[ $is_dns_use == "set" ]]; then
            ask string is_dns_use "请输入 DNS: "
        fi
    fi
    if [[ $is_dns_use == "none" ]]; then
        cat <<<$(jq '.dns={}' $is_config_json) >$is_config_json
    else
        cat <<<$(jq '.dns.servers=["'${is_dns_use/https/https+local}'"]' $is_config_json) >$is_config_json
    fi
    manage restart &
    msg "\n已更新 DNS 为: $(_green $is_dns_use)\n"
}
