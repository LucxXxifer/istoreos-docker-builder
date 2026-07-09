# OECT fnOS iStoreOS Docker Builder

這是 OECT/fnOS Docker iStoreOS 旁路由的自用產線 fork。

上游授權與 attribution 保留在 `LICENSE` 和 git history 中；本 fork 不冒充上游官方項目。

## 目前上產範圍

默認先跑：

- `.github/workflows/oect-dry-run-release.yml`

它會發布：

- `manifest.json`
- `SHA256SUMS`
- `SAFETY.md`
- `oect-istoreos-seed-files.tar.gz`
- `oect-fnos-arm64-target.tar.gz`

這是 scaffold release，用來驗證 seed files、target files、checksum 和安全 gate。它不代表真 fnOS/OECT 部署已經通過。

## 手動 rootfs 編譯

手動 workflow：

- `.github/workflows/oect-build-rootfs.yml`

它需要官方 iStoreOS ImageBuilder URL 和精確 sha256。不要用未驗證或會漂移的 URL。

官方 ImageBuilder 入口：

- `https://fw.koolcenter.com/iStoreOS/ib/`

target 備註：

- 本 repo 目前沿用上游 Docker rootfs 產線：`armsr/armv8`，對應官方 `armsr/` ImageBuilder。
- OECT 硬件本身是 RK3566 / Rockchip。如果要做裸機或 RK 專用 iStoreOS 固件包，應使用官方 `rk3xxx/` ImageBuilder，也就是 `rockchip-armv8`。
- 不要把 Docker rootfs target 當成已經構建了 RK 裸機固件包。觸發 workflow 前，必須先用官方 `sha256sums` 校驗選中的 archive。

## 網路基線

- iStoreOS container IP：`192.168.31.3`
- LAN gateway：`192.168.31.1`
- LAN subnet：`192.168.31.0/24`
- DHCP server：關閉
- LAN masquerade：`192.168.31.0/24 -> !192.168.31.0/24`

通用 macvlan compose 範例見：

- `examples/compose.macvlan.yml`

Compose 變量速查：

| 變量 | 含義 |
| --- | --- |
| `ISTORE_IMAGE` | 要運行的 iStoreOS/OpenWrt image tag |
| `ISTORE_CONTAINER` | container 名稱，通常是 live router 名稱 |
| `ISTORE_IP` | 預留給 iStoreOS 的 container LAN IP |
| `ISTORE_MAC` | 證明發生 MAC drift 後，從現場探測並固定的 container macvlan endpoint MAC |
| `LAN_PARENT` | 作為 macvlan parent 的 host LAN interface |
| `LAN_SUBNET` | macvlan network 所在 LAN subnet |
| `LAN_GATEWAY` | container 使用的 LAN gateway |

## 安全邊界

公開 release 不得包含：

- Tailscale identity、auth key、`tailscaled.state`
- ShellCrash 訂閱、profile、CrashCore runtime
- Lucky 證書、token、domain、私有反代規則
- root password hash
- SSH private key

私有運行狀態應放在本地 private reapply pack，不進公開 image 或 GitHub Release。

## Promote 規則

產物要先在 A/B IP，例如 `192.168.31.4` 測試，通過後才能替換 `.3`。GitHub Actions PASS 不等於真 fnOS macvlan、LAN client、OECT reboot、可選 host BBR gate 全部通過。

上線前還必須通過 macvlan ARP/MAC gate：

- `runbooks/docker-macvlan-arp.md`

最低要求：

- container 在 `docker restart` 和 `docker compose up -d --force-recreate` 後仍保持同一個 IP 和已固定 MAC；
- host-side macvlan shim 使用未被佔用的 helper IP，不能佔用其他 LAN 設備的服務 IP；
- host IP、shim IP、container IP、其他 LAN 設備 IP 在 ARP 重新學習後都映射到正確 MAC；
- shim source policy rule 必須使用目標主機實際存在的 LAN route table 和空閒 priority，不能照抄其他機器；
- 最終 IP-to-MAC map 必須能通過 interface rebuild 和 host reboot。
