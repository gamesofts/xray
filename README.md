# 介绍

最好用的 Xray 一键安装脚本 & 管理脚本

> 本分支是面向中国大陆服务器（包括阿里云 ECS）的兼容版，基于
> [233boy/Xray](https://github.com/233boy/Xray) 修改并保留原作者署名。

## 中国大陆安装

```bash
bash <(wget -qO- "https://gh-proxy.com/https://raw.githubusercontent.com/gamesofts/Xray/main/install.sh")
```

脚本默认按 `gh-proxy.com -> ghfast.top -> ghproxy.net -> GitHub 官方` 的顺序尝试，
并对 Xray、脚本、规则库和 Caddy 的发布文件进行 SHA-256 校验。也可以指定自己的
GitHub 反向代理（推荐长期使用自建代理）：

```bash
export XRAY_GITHUB_PROXY="https://你的代理域名/"
bash install.sh
```

安装时指定的代理会写入 `/etc/xray/network.env`，以后执行 `xray update` 时会继续使用。

只使用 GitHub 官方地址：

```bash
XRAY_GITHUB_PROXY=direct bash install.sh
```

本版还将公网 IP 探测切换为 `ipw.cn`，域名解析检查切换为阿里云公共 DNS，
并将脚本内 DNS 菜单的默认选项改为 AliDNS / DNSPod。公共 GitHub 加速服务是
第三方服务，可能限速或失效；校验可以发现文件损坏或内容不一致，但不能替代对
第三方代理的信任评估，因此生产环境建议使用你控制的反向代理或预下载后通过
`--core-file` 本地安装。

# 特点

- 快速安装
- 无敌好用
- 零学习成本
- 自动化 TLS
- 简化所有流程
- 屏蔽 BT
- 屏蔽中国 IP
- 使用 API 操作
- 兼容 Xray 命令
- 强大的快捷参数
- 支持所有常用协议
- 一键添加 VLESS-REALITY (默认)
- 一键添加 Shadowsocks 2022
- 一键添加 VMess-(TCP/mKCP)
- 一键添加 VMess-(WS/gRPC)-TLS
- 一键添加 VLESS-(WS/gRPC/XHTTP)-TLS
- 一键添加 Trojan-(WS/gRPC)-TLS
- 一键添加 VMess-(TCP/mKCP) 动态端口
- 一键启用 BBR
- 一键更改伪装网站
- 一键更改 (端口/UUID/密码/域名/路径/加密方式/SNI/动态端口/等...)
- 还有更多...

# 设计理念

设计理念为：**高效率，超快速，极易用**

脚本基于作者的自身使用需求，以 **多配置同时运行** 为核心设计

并且专门优化了，添加、更改、查看、删除、这四项常用功能

你只需要一条命令即可完成 添加、更改、查看、删除、等操作

例如，添加一个配置仅需不到 1 秒！瞬间完成添加！其他操作亦是如此！

脚本的参数非常高效率并且超级易用，请掌握参数的使用

# 文档

安装及使用：https://233boy.com/xray/xray-script/

# 帮助

使用：`xray help`

```
Xray script v1.21 by 233boy
Usage: xray [options]... [args]...

基本:
   v, version                                      显示当前版本
   ip                                              返回当前主机的 IP
   pbk                                             同等于 xray x25519
   get-port                                        返回一个可用的端口
   ss2022                                          返回一个可用于 Shadowsocks 2022 的密码

一般:
   a, add [protocol] [args... | auto]              添加配置
   c, change [name] [option] [args... | auto]      更改配置
   d, del [name]                                   删除配置**
   i, info [name]                                  查看配置
   qr [name]                                       二维码信息
   url [name]                                      URL 信息
   log                                             查看日志
   logerr                                          查看错误日志

更改:
   dp, dynamicport [name] [start | auto] [end]     更改动态端口
   full [name] [...]                               更改多个参数
   id [name] [uuid | auto]                         更改 UUID
   host [name] [domain]                            更改域名
   port [name] [port | auto]                       更改端口
   path [name] [path | auto]                       更改路径
   passwd [name] [password | auto]                 更改密码
   key [name] [Private key | atuo] [Public key]    更改密钥
   type [name] [type | auto]                       更改伪装类型
   method [name] [method | auto]                   更改加密方式
   sni [name] [ ip | domain]                       更改 serverName
   seed [name] [seed | auto]                       更改 mKCP seed
   new [name] [...]                                更改协议
   web [name] [domain]                             更改伪装网站

进阶:
   dns [...]                                       设置 DNS
   dd, ddel [name...]                              删除多个配置**
   fix [name]                                      修复一个配置
   fix-all                                         修复全部配置
   fix-caddyfile                                   修复 Caddyfile
   fix-config.json                                 修复 config.json

管理:
   un, uninstall                                   卸载
   u, update [core | sh | dat | caddy] [ver]       更新
   U, update.sh                                    更新脚本
   s, status                                       运行状态
   start, stop, restart [caddy]                    启动, 停止, 重启
   t, test                                         测试运行
   reinstall                                       重装脚本

测试:
   client [name]                                   显示用于客户端 JSON, 仅供参考
   debug [name]                                    显示一些 debug 信息, 仅供参考
   gen [...]                                       同等于 add, 但只显示 JSON 内容, 不创建文件, 测试使用
   genc [name]                                     显示用于客户端部分 JSON, 仅供参考
   no-auto-tls [...]                               同等于 add, 但禁止自动配置 TLS, 可用于 *TLS 相关协议
   xapi [...]                                      同等于 xray api, 但 API 后端使用当前运行的 Xray 服务

其他:
   bbr                                             启用 BBR, 如果支持
   bin [...]                                       运行 Xray 命令, 例如: xray bin help
   api, x25519, tls, run, uuid  [...]              兼容 Xray 命令
   h, help                                         显示此帮助界面

谨慎使用 del, ddel, 此选项会直接删除配置; 无需确认
反馈问题) https://github.com/233boy/xray/issues
文档(doc) https://233boy.com/xray/xray-script/
```
