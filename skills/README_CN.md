# 操作 Skills

[English](README.md)

這個目錄保存支援本 repo live iStoreOS/OpenWrt 操作的可復用 agent skills。Skills 是診斷文檔加輔助腳本，不是 build artifact，也不會默認安裝進 Docker image。

## Gateway DNS Proxy Troubleshoot

- Skill：`skills/gateway-dns-proxy-troubleshoot/SKILL.md`
- 主要 macvlan reference：`skills/gateway-dns-proxy-troubleshoot/references/docker-macvlan-arp.md`
- Repo runbook：`runbooks/docker-macvlan-arp.md`

當 OpenWrt/iStoreOS gateway 出現 DNS、域名分流、app 下載、AdGuard Home、dnsmasq、ShellCrash、OpenClash、Mihomo、Tailscale MagicDNS、Docker/macvlan LAN 故障時使用這個 skill。典型症狀包括：域名能解析但流量卡住、Google Play 或其他 app 下載停住、本地域名在 DNS 接管後失效、AdGuard query log 看起來不更新、proxy DNS loop、DNS hijack 繞過預期前置 resolver，或 Docker/macvlan 主機 ARP 正確但 ICMP/TCP 不通。

必須遵守的使用流程：

1. 先進入只讀診斷模式。
2. 操作前先打開 `skills/gateway-dns-proxy-troubleshoot/SKILL.md`，再按症狀打開最小相關 reference。
3. 從 live evidence 發現當前目標的 IP、MAC、端口、listener、firewall redirect 目標、upstream DNS、interface、route table、rule priority、client path 和 container state。
4. 未知或不存在的變量要明確填寫；不存在的組件用 `N/A`，例如沒有 host-side shim。
5. 不要照抄之前案例的值。先使用 `<gateway_ip>`、`<front_resolver>`、`<proxy_dns_port>`、`<upstream_dns>`、`<local_hostname>`、`<lan_domain>` 等角色佔位，等 live evidence 證明後再填實際值。
6. 先證明故障層，再提出修復。只有 listener 存在不夠，還要按場景配對 DNS answer、current query log、firewall redirect 目標、route/rule/outlet evidence 或 LAN reachability probe。
7. 只有在故障層已被證明後，才提出一個最小修復。
8. 經批准後，先備份，只改一個變量，窄範圍 reload，並用同一條 reproduction path 驗證。
9. 對 DNS/proxy 持久化配置，若已批准 restart 或 reboot gate，必須在重啟後重新檢查 runtime config 和 persistent config。

Reference 選擇：

| 症狀 | 先看 |
| --- | --- |
| OpenWrt/iStoreOS listener、DNS topology、ShellCrash/OpenClash、Tailscale、本地域名 | `references/openwrt-istoreos.md` |
| Google Play、Apple、Xiaomi、app 下載、API/CDN 分離、HTTPS smoke test | `references/failure-patterns.md` |
| Docker/macvlan ARP、MAC drift、host-side shim、promotion gate | `references/docker-macvlan-arp.md` 和 `../runbooks/docker-macvlan-arp.md` |
| 任何 live change proposal | `references/safe-remediation.md` |

可用的只讀收集工具：

```sh
sh skills/gateway-dns-proxy-troubleshoot/scripts/collect_gateway_dns_evidence.sh
python3 skills/gateway-dns-proxy-troubleshoot/scripts/dns_compare.py --help
python3 skills/gateway-dns-proxy-troubleshoot/scripts/watch_mihomo_connections.py --help
```

Docker macvlan ARP/MAC promotion gate 要先看 repo runbook：

```text
runbooks/docker-macvlan-arp.md
```

不要發布本地私有 runtime state、個人 MAC 地址、proxy subscription、Tailscale identity、certificate、token、password 或 SSH key。

重要判讀：

- API/CDN root 的 HTTPS smoke test 返回 `404` 時，仍可能代表 DNS、TCP、TLS 都可達。
- `gvt1.com`、`gvt2.com`、`gvt3.com`、`redirector.gvt1.com`、`dl.google.com` 是 Google Play 常見 CDN delivery surfaces，但必須由 current logs 證明 block 或 sink rewrite 後，才能加規則。
- DNS hijack 要檢查目標角色和端口。即使 listener 都在，redirect 仍可能繞過 AdGuard。
- ShellCrash/OpenClash generated runtime config 可能在 restart 後和 persistent config 不一致。未通過 restart gate 前，不要宣稱 DNS 修復已持久化。
