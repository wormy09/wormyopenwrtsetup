# Passwall2 Auto-Setup for OpenWrt

One-command Passwall2 setup for OpenWrt routers in Russia. Optimized for 256MB RAM devices (MediaTek mt7622 / aarch64).

## What it does

- Installs Passwall2 with xray-core
- Removes conflicting software (zapret, podkop, sing-box)
- Configures split routing: blocked domains → VLESS proxy, everything else → direct
- Sets up subscription auto-update (every 12h)
- Applies memory optimizations for 256MB routers (no geosite/geoip files)
- Daily cron cleanup to prevent OOM crashes

## Proxied services

YouTube, Discord, Instagram, Facebook, Meta/Oculus Quest, WhatsApp, Telegram, Twitter/X, TikTok, Cloudflare CDN, GitHub, Claude/Anthropic, 9GAG, IPTV (tvizi), rutracker, and more.

## Quick install

```bash
wget -O /tmp/install.sh https://raw.githubusercontent.com/wormy09/wormyopenwrtsetup/main/install.sh
sh /tmp/install.sh
```

### Custom subscription URL

```bash
wget -O /tmp/install.sh https://raw.githubusercontent.com/wormy09/wormyopenwrtsetup/main/install.sh
sh /tmp/install.sh "https://your-sub-url.com/xyz" "US-NJ" "my vless"
```

Arguments:
1. Subscription URL (default: built-in)
2. Preferred node keyword to match (default: `DE-FRA`)
3. Subscription display name (default: `wormys vless`)

## Requirements

- OpenWrt 23.05+ or 24.10+
- Supports both **opkg** and **apk** package managers (auto-detected)
- A working VLESS subscription URL

## Configuration

Pass arguments to the script to customize:

```bash
sh /tmp/install.sh "SUB_URL" "NODE_KEYWORD" "DISPLAY_NAME"
```

| Argument | Default | Description |
|----------|---------|-------------|
| 1st | built-in URL | Your VLESS subscription URL |
| 2nd | `DE-FRA` | Keyword to match preferred server |
| 3rd | `wormys vless` | Display name for subscription |

No arguments = uses built-in defaults.

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

### Node not found automatically
If the script can't match your preferred node, configure manually:
1. Go to **Node List**, note which server you want
2. Create an **Xray-Shunt** node: Russia_Block → your server, Default → Direct Connection
3. Set **TCP Node** to the shunt node

## Memory notes (256MB routers)

| Approach | RAM usage | Stable? |
|----------|-----------|---------|
| Manual domain list | ~5 MB | ✅ Yes |
| geosite-ru-only.dat | ~80 MB | ❌ OOM after hours |
| geosite.dat (full) | ~1.3 GB | ❌ Instant crash |

**This script uses manual domain lists — the only stable approach for 256MB routers.**

## License

MIT
