# Passwall2 Auto-Setup for OpenWrt

One-command Passwall2 setup for OpenWrt routers in Russia. Optimized for routers with 256MB+ RAM.

## What it does

- Installs Passwall2 with xray-core
- Removes conflicting software (zapret, podkop, sing-box)
- Configures split routing: blocked domains → VLESS proxy, everything else → direct
- Sets up subscription auto-update (every 12h)
- Applies memory optimizations for 256MB routers (no geosite/geoip files)
- Cron restart every 6h to prevent xray memory leak OOM crashes

## Proxied services

YouTube, Discord, Instagram, Facebook, Meta/Oculus Quest, WhatsApp, Telegram, Twitter/X, TikTok, Cloudflare CDN, GitHub, Claude/Anthropic, AnyDesk, VATSIM/vPilot, 9GAG, IPTV (tvizi), rutracker, and more.

## Quick install

```bash
wget -O /tmp/install.sh https://raw.githubusercontent.com/wormy09/wormyopenwrtsetup/main/install.sh
sh /tmp/install.sh
```

The script will:
1. Ask for your VLESS subscription URL
2. Install Passwall2 and dependencies
3. Fetch your nodes from the subscription
4. Show a numbered list of available servers
5. Let you pick which one to use for proxying blocked sites
6. Configure everything automatically

No hardcoded credentials — safe to share publicly.

## Requirements

- OpenWrt 23.05+ or 24.10+
- Supports both **opkg** and **apk** package managers (auto-detected)
- A working VLESS subscription URL

## After install

1. Log out of LuCI and log back in
2. Check **Services → PassWall2** — Core should show RUNNING
3. Test: youtube.com (proxied), ya.ru (direct)

## Adding new blocked domains

```
Services → PassWall2 → Rule Manage → Russia_Block → Edit → add domain:example.com
```

Then restart Passwall2.

## Troubleshooting

### No internet after install
```bash
rm -rf /tmp/bak_v2ray
/etc/init.d/passwall2 restart
```

### OOM crashes
```bash
# Check
logread | grep -i oom | tail -5

# Fix — remove any geo files
rm -f /usr/share/xray/geosite.dat /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geosite.dat /usr/share/v2ray/geoip.dat
rm -rf /tmp/bak_v2ray
/etc/init.d/passwall2 restart
```

## Memory notes (256MB routers)

| Approach | RAM usage | Stable? |
|----------|-----------|---------|
| Manual domain list | ~5 MB | ✅ Yes |
| geosite-ru-only.dat | ~80 MB | ❌ OOM after hours |
| geosite.dat (full) | ~1.3 GB | ❌ Instant crash |

**This script uses manual domain lists — the only stable approach for 256MB routers.**

## Known limitations

- **Telegram media on iPhone** — text messages work, but photos/videos don't download. This is an iOS TPROXY limitation. Android and web Telegram work fine. Workaround: use VPN app on iPhone for Telegram media, or use Telegram web version.
- **xray memory leak** — xray gradually consumes more memory. The 6-hour cron restart prevents OOM crashes on 256MB routers. Not an issue on 512MB+ routers.

## License

MIT
