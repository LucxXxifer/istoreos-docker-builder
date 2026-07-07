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

選擇匹配的 target 目錄，例如 fnOS/OECT arm64 產線使用 `armsr/`，並先用官方 `sha256sums` 校驗 archive，再觸發 workflow。

## 網路基線

- iStoreOS container IP：`192.168.31.3`
- LAN gateway：`192.168.31.1`
- LAN subnet：`192.168.31.0/24`
- DHCP server：關閉
- LAN masquerade：`192.168.31.0/24 -> !192.168.31.0/24`

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
