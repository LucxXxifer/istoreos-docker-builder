# Failure Patterns

Use this reference after the skill has triggered and the symptom involves app downloads, vendor domains, or domains that resolve but stall.

## Google Play

Symptoms:
- Download stays at waiting.
- Percent appears but traffic does not continue.
- API domains work, but APK/CDN domains route differently.

Domains to inspect as separate control-plane and download-plane buckets:

| Bucket | Domains |
| --- | --- |
| Play/API | `play.googleapis.com`, `android.clients.google.com`, `clientservices.googleapis.com`, `services.googleapis.cn`, `mtalk.google.com` |
| APK/CDN | `xn--ngstr-lra8j.com`, `rr*.xn--ngstr-lra8j.com`, `gvt1.com`, `gvt2.com`, `gvt3.com`, `cache.pack.google.com`, `dl.google.com` |
| Measurement/noise | `app-measurement.com`, `firebaseinstallations.googleapis.com`, `firebaselogging.googleapis.com` |

Working rule of thumb: Play API and APK/CDN domains often need the same practical outlet. If API goes proxy and CDN goes DIRECT, downloads may show a percent and stall. If the user switches Play account regions, route these rules to an existing stable manual selector rather than a hard-coded country group.

For APK/CDN domains, `gvt1.com`, `gvt2.com`, `gvt3.com`, `redirector.gvt1.com`, and `dl.google.com` are known Google Play CDN delivery surfaces. Verify current logs before adding domain rules; these domains are not automatically the root cause. If a current AdGuard/query log proves one of these is blocked or rewritten to a sink answer, prefer a narrow allowlist for the proven domain over a broad Google unblock.

HTTPS smoke tests against these API/CDN roots may return `404` because the root path is not an application endpoint. Treat `404` as reachability evidence when DNS resolved, TCP connected, and TLS completed; keep investigating only when the result is timeout, connection refused/reset, TLS failure, captive portal, unexpected block page, or repeated `5xx`.

Do not assume `app-measurement.com` is the root cause. It can be blocked without breaking every install, so use current logs and a reproduction before changing it.

## Apple App Store, iCloud, And Updates

Symptoms:
- App Store opens but downloads fail or wait.
- iCloud login works but content sync/download fails.
- System update check succeeds but payload download stalls.

Domains to inspect:

| Bucket | Domains |
| --- | --- |
| Store/API | `itunes.apple.com`, `apps.apple.com`, `buy.itunes.apple.com`, `pancake.apple.com` |
| App payload/CDN | `iosapps.itunes.apple.com`, `osxapps.itunes.apple.com`, `mzstatic.com`, `aaplimg.com`, `cdn-apple.com` |
| iCloud | `icloud.com`, `icloud-content.com`, `setup.icloud.com`, `gateway.icloud.com` |
| Updates | `mesu.apple.com`, `swscan.apple.com`, `swcdn.apple.com`, `swdist.apple.com`, `xp.apple.com` |
| DNS/infra | `apple.com`, `apple-dns.net`, `akadns.net`, `akamaiedge.net` |

Apple flows may mix geo-sensitive store APIs with CDN domains. Compare rule hits and connection outlets before forcing all Apple domains through one route.

## Xiaomi, MIUI, And Mi Cloud

Symptoms:
- Xiaomi account login, cloud sync, updates, or push service behaves differently from normal web browsing.
- Some MIUI or Mi Home requests resolve to CN IPs and stall from the current path.

Domains to inspect:

| Bucket | Domains |
| --- | --- |
| Account/API | `account.xiaomi.com`, `api.account.xiaomi.com`, `api.io.mi.com`, `api.micloud.xiaomi.net` |
| MIUI/update | `miui.com`, `update.miui.com`, `bigota.d.miui.com`, `hugeota.d.miui.com`, `globalapi.ad.xiaomi.com` |
| Mi Cloud | `micloud.xiaomi.net`, `i.mi.com`, `find.api.micloud.xiaomi.net`, `galleryapi.micloud.xiaomi.net` |
| Push/msg | `resolver.msg.xiaomi.net`, `msg.xiaomi.net`, `app.chat.xiaomi.net` |
| Download/static | `mi.com`, `xiaomi.com`, `mifile.cn`, `cdn.cnbj1.fds.api.mi-img.com`, `cdn.awsde0.fds.api.mi-img.com` |
| Telemetry/noise | `tracking.miui.com`, `data.mistat.xiaomi.com`, `sdkconfig.ad.xiaomi.com`, `log.mi.com` |

Treat telemetry blocks as separate from account/update payload failures. Do not globally unblock telemetry as a first move.

## Internal Hosts And Tailnet Names

Symptoms:
- LAN hostnames fail while public DNS works.
- `.lan`, `.home.arpa`, or MagicDNS names return public DNS errors.
- Tailnet `100.64.0.0/10` traffic is proxied or captured.

Check:
- Client DNS server and search domain.
- dnsmasq local domain and host records.
- AdGuard rewrites/upstream for private suffixes.
- Both short hostname form and LAN FQDN form, for example `<local_hostname>` and `<local_hostname>.<lan_domain>`.
- Clash/Mihomo fake-ip filter and bypass rules for private suffixes.
- Tailscale MagicDNS status and whether `100.64.0.0/10` is in DIRECT/bypass.

## Reading The Evidence

Prefer this order:
1. Confirm whether the resolver answer differs by layer.
2. Confirm whether current query logs are live.
3. Confirm rule hit and outlet for the exact failing domain while reproducing.
4. Compare API/control-plane and CDN/download-plane outlet consistency.
5. Only then propose the smallest reversible rule, upstream, or blocklist change.
