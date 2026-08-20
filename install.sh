#!/bin/bash

author=233boy
cn_maintainer=gamesofts
# github=https://github.com/233boy/xray

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# root
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

# yum or apt-get or apk, ubuntu/debian/centos/alpine
cmd=$(type -P apt-get || type -P yum || type -P apk)
[[ ! $cmd ]] && err "此脚本仅支持 ${yellow}(Ubuntu or Debian or CentOS or Alpine)${none}."

# alpine linux
is_alpine=
[[ $cmd =~ apk ]] && is_alpine=1

# systemd or openrc
if [[ $is_alpine ]]; then
    [[ ! $(type -P rc-service) ]] && {
        err "此系统缺少 ${yellow}(rc-service)${none}, 请尝试执行:${yellow} ${cmd} add openrc ${none}来修复此错误."
    }
else
    [[ ! $(type -P systemctl) ]] && {
        err "此系统缺少 ${yellow}(systemctl)${none}, 请尝试执行:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none}来修复此错误."
    }
fi

# wget installed or none
is_wget=$(type -P wget)

# x64
case $(uname -m) in
amd64 | x86_64)
    is_jq_arch=amd64
    is_core_arch="64"
    ;;
*aarch64* | *armv8*)
    is_jq_arch=arm64
    is_core_arch="arm64-v8a"
    ;;
*)
    err "此脚本仅支持 64 位系统..."
    ;;
esac

is_core=xray
is_core_name=Xray
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=xtls/$is_core-core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=${XRAY_SCRIPT_REPO:-$cn_maintainer/$is_core}
is_pkg="wget unzip jq ca-certificates"
is_config_json=$is_core_dir/config.json
tmp_var_lists=(
    tmpcore
    tmpsh
    is_core_ok
    is_sh_ok
    is_pkg_ok
)

# tmp dir
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}

# set up var
for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

# load bash script.
load() {
    . $is_sh_dir/src/$1
}

# wget wrapper; keep certificate verification enabled.
_wget() {
    if [[ $proxy ]]; then
        export http_proxy=$proxy
        export https_proxy=$proxy
        export all_proxy=$proxy
    fi
    wget "$@"
}

# GitHub is frequently slow or unreachable from mainland China.  An explicit
# XRAY_GITHUB_PROXY value wins; "direct" disables mirror use.  The public
# mirrors are fallbacks only and every supported release asset is checksummed.
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
        msg warn "下载 ${display_name} > ${candidate}"
        if _wget -t 2 -T 30 -q "$candidate" -O "$output" && [[ -s $output ]]; then
            return 0
        fi
    done < <(github_proxy_candidates)
    rm -f "$output"
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
    local checksum_file="${output}.checksum"
    local asset_name=${url##*/}
    github_download "$url" "$output" "$display_name" || return 1
    [[ ${XRAY_VERIFY_CHECKSUM:-1} == 0 ]] && return 0
    github_download "${url}${checksum_suffix}" "$checksum_file" "${display_name} checksum" || return 1
    verify_sha256 "$output" "$checksum_file" "$asset_name"
}

# print a mesage
msg() {
    case $1 in
    warn)
        local color=$yellow
        ;;
    err)
        local color=$red
        ;;
    ok)
        local color=$green
        ;;
    esac

    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# show help msg
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径, e.g., -f /root/${is_core}-linux-64.zip"
    echo -e "  -l, --local-install             本地获取安装脚本, 使用当前目录"
    echo -e "  -p, --proxy <addr>              使用代理下载, e.g., -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本, e.g., -v v1.8.1"
    echo -e "  -h, --help                      显示此帮助界面\n"

    exit 0
}

# install dependent pkg
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "安装依赖包 >${pkg}"
        if [[ $is_alpine ]]; then
            $cmd add $pkg &>/dev/null
        else
            $cmd install -y $pkg &>/dev/null
        fi
        if [[ $? != 0 ]]; then
            [[ $cmd =~ yum ]] && yum install epel-release -y &>/dev/null
            if [[ $is_alpine ]]; then
                $cmd update &>/dev/null
                $cmd add $pkg &>/dev/null
            else
                $cmd update -y &>/dev/null
                $cmd install -y $pkg &>/dev/null
            fi
            [[ $? == 0 ]] && >$is_pkg_ok
        else
            >$is_pkg_ok
        fi
    else
        >$is_pkg_ok
    fi
}

# download file
download() {
    case $1 in
    core)
        link=https://github.com/${is_core_repo}/releases/latest/download/${is_core}-linux-${is_core_arch}.zip
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-linux-${is_core_arch}.zip"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        link=https://github.com/${is_sh_repo}/archive/refs/heads/main.zip
        name="$is_core_name 脚本"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        ;;
    esac

    if [[ $1 == sh ]]; then
        # GitHub's dynamically generated branch archive has no stable sidecar
        # checksum. Validate its required files and syntax after extraction.
        github_download "$link" "$tmpfile" "$name"
    else
        download_and_verify "$link" "$tmpfile" "$name" .dgst
    fi
    if [[ $? == 0 ]]; then
        mv -f $tmpfile $is_ok
    fi
}

# get server ip
get_ip() {
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

# check background tasks status
check_status() {
    # dependent pkg install fail
    [[ ! -f $is_pkg_ok ]] && {
        msg err "安装依赖包失败"
        msg err "请尝试手动安装依赖包: $cmd update -y; $cmd install -y $is_pkg"
        is_fail=1
    }

    # download file status
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            msg err "下载 ${is_core_name} 失败"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            msg err "下载 ${is_core_name} 脚本失败"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            [[ ! $local_install ]] && download sh &
            get_ip
            wait
            check_status
        }
    fi

    # found fail status, remove tmp dir and exit.
    [[ $is_fail ]] && {
        exit_and_del_tmpdir
    }
}

# parameters check
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 /root/$is_core-linux-64.zip]"
            } || [[ ! -f $2 ]] && {
                err "($2) 不是一个常规的文件."
            }
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f ${PWD}/src/core.sh || ! -f ${PWD}/$is_core.sh ]] && {
                err "当前目录 (${PWD}) 非完整的脚本目录."
            }
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 http://127.0.0.1:2333 or -p socks5://127.0.0.1:2333]"
            }
            proxy=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 v1.8.1]"
            }
            is_core_ver=v${2#v}
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        *)
            echo -e "\n${is_err} ($@) 为未知参数...\n"
            show_help
            ;;
        esac
    done
    [[ $is_core_ver && $is_core_file ]] && {
        err "无法同时自定义 ${is_core_name} 版本和 ${is_core_name} 文件."
    }
}

# exit and remove tmpdir
exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && {
        msg err "哦豁.."
        msg err "安装过程出现错误..."
        echo -e "反馈问题) https://github.com/${is_sh_repo}/issues"
        echo
        exit 1
    }
    exit
}

# main
main() {

    # check old version
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        err "检测到脚本已安装, 如需重装请使用${green} ${is_core} reinstall ${none}命令."
    }

    # check parameters
    [[ $# -gt 0 ]] && pass_args $@

    # show welcome msg
    clear
    echo
    echo "........... $is_core_name script by $author .........."
    echo

    # start installing...
    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "使用代理: ${yellow}$proxy${none}"
    # create tmpdir
    mkdir -p $tmpdir
    # if is_core_file, copy file
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg warn "${yellow}${is_core_name} 文件使用 > $is_core_file${none}"
    }
    # local dir install sh script
    [[ $local_install ]] && {
        >$is_sh_ok
        msg warn "${yellow}本地获取安装脚本 > $PWD ${none}"
    }

    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && {
        [[ $is_alpine ]] || msg warn "${yellow}\e[4m提醒!!! 无法设置自动同步时间, 可能会影响使用 VMess 协议.${none}"
    }
    # alpine 默认无 timedatectl, 尝试用 chronyd / ntpd 替代
    [[ $is_alpine ]] && {
        rc-service chronyd start &>/dev/null || rc-service ntpd start &>/dev/null || \
            msg warn "${yellow}\e[4m提醒!!! 无法设置自动同步时间, 可能会影响使用 VMess 协议.${none}"
    }

    # install dependent pkg
    # Install CA certificates before starting HTTPS downloads.
    install_pkg $is_pkg

    # if wget installed. download core, sh, jq, get ip
    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && download core &
        [[ ! $local_install ]] && download sh &
        get_ip
    }

    # waiting for background tasks is done
    wait

    # check background tasks status
    check_status

    # test $is_core_file
    if [[ $is_core_file ]]; then
        unzip -qo $is_core_ok -d $tmpdir/testzip &>/dev/null
        [[ $? != 0 ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
        for i in ${is_core} geoip.dat geosite.dat; do
            [[ ! -f $tmpdir/testzip/$i ]] && is_file_err=1 && break
        done
        [[ $is_file_err ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
    fi

    # get server ip.
    [[ ! $ip ]] && {
        msg err "获取服务器 IP 失败."
        exit_and_del_tmpdir
    }

    # create sh dir...
    mkdir -p $is_sh_dir

    # copy sh file or unzip sh zip file.
    if [[ $local_install ]]; then
        cp -rf $PWD/* $is_sh_dir
    else
        sh_extract_dir=$tmpdir/sh-extract
        mkdir -p "$sh_extract_dir"
        unzip -qo $is_sh_ok -d "$sh_extract_dir"
        sh_root=$(find "$sh_extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
        [[ ! -f "$sh_root/xray.sh" || ! -f "$sh_root/src/core.sh" || ! -f "$sh_root/src/network.sh" ]] && {
            msg err "脚本源码包结构校验失败."
            exit_and_del_tmpdir
        }
        bash -n "$sh_root/install.sh" "$sh_root/xray.sh" "$sh_root"/src/*.sh || {
            msg err "脚本源码包语法校验失败."
            exit_and_del_tmpdir
        }
        cp -rf "$sh_root"/. $is_sh_dir
    fi

    # create core bin dir
    mkdir -p $is_core_dir/bin
    # Persist a custom GitHub proxy for future `xray update` operations.
    if [[ ${XRAY_GITHUB_PROXY+x} ]]; then
        printf 'export XRAY_GITHUB_PROXY=%q\n' "$XRAY_GITHUB_PROXY" >$is_core_dir/network.env
        chmod 600 $is_core_dir/network.env
    fi
    # copy core file or unzip core zip file
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/* $is_core_dir/bin
    else
        unzip -qo $is_core_ok -d $is_core_dir/bin
    fi

    # add alias
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc

    # core command
    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin

    # chmod
    chmod +x $is_core_bin $is_sh_bin

    # create log dir
    mkdir -p $is_log_dir

    # show a tips msg
    msg ok "生成配置文件..."

    # create systemd service
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null

    # create condf dir
    mkdir -p $is_conf_dir

    load core.sh
    # create a tcp config
    add reality
    # remove tmp dir and exit.
    exit_and_del_tmpdir ok
}

# start.
main $@
