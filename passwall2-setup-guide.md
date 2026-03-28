# Passwall2 Setup Guide — OpenWrt 24.10 (MediaTek mt7622 / aarch64)

Optimized for routers with ~256MB RAM. Avoids OOM crashes and common pitfalls.

---

## Prerequisites

- OpenWrt 24.10.x with opkg package manager
- SSH access to the router
- A working VLESS server (subscription URL or manual config)
- A Mac/PC on the same network for file transfers

---

## Step 1 — Remove conflicting software

If zapret, podkop, sing-box, or DNS-over-HTTPS are installed, remove them first:

```bash
# Stop and remove zapret (if installed)
/etc/init.d/zapret stop 2>/dev/null
rm -f /etc/init.d/zapret
rm -f /etc/hotplug.d/iface/90-zapret
rm -rf /opt/zapret

# Remove podkop + sing-box (if installed)
opkg remove --force-removal-of-dependent-packages sing-box podkop luci-app-podkop luci-i18n-podkop-ru 2>/dev/null
rm -f /etc/config/podkop /etc/config/sing-box
rm -rf /etc/sing-box

# Remove any stale DNS forwarders (from DNS-over-HTTPS setups)
# Check what's there first:
uci show dhcp | grep server
# Remove any 127.0.0.1#5053 or 127.0.0.1#5054 entries:
uci del_list dhcp.@dnsmasq[0].server='127.0.0.1#5053' 2>/dev/null
uci del_list dhcp.@dnsmasq[0].server='127.0.0.1#5054' 2>/dev/null
uci commit dhcp
```

---

## Step 2 — Disable flow offloading

Go to **Network → Firewall → General** in LuCI, and make sure both:
- Software flow offloading → **OFF**
- Hardware flow offloading → **OFF**

Or via SSH:

```bash
uci set firewall.@defaults[0].flow_offloading=0
uci set firewall.@defaults[0].flow_offloading_hw=0
uci commit firewall
```

---

## Step 3 — Install Passwall2

```bash
# Import signing key
wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add passwall.pub

# Add package feeds
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

for feed in passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

# Install prerequisites
opkg update
opkg remove dnsmasq
opkg install dnsmasq-full
opkg install kmod-nft-socket kmod-nft-tproxy kmod-nft-nat

# Install Passwall2
opkg install luci-app-passwall2
```

Log out of LuCI and log back in. **Services → PassWall2** should appear.

---

## Step 4 — Remove default geo files

**IMPORTANT:** Do NOT use geosite.dat or geoip.dat on 256MB routers — even the lightweight versions cause OOM crashes. We use manual domain and IP lists instead.

```bash
rm -f /usr/share/xray/geosite.dat
rm -f /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geosite.dat
rm -f /usr/share/v2ray/geoip.dat
```

---

## Step 5 — Add your VLESS nodes

1. Go to **Services → PassWall2 → Node Subscribe**
2. Click **Add**, paste your subscription URL
3. **Save & Apply**, then click **Update**
4. Go to **Node List** and verify servers appeared

**Important:** Do not use apostrophes or special characters in node names — they break UCI configs. Use only letters, numbers, hyphens, underscores.

---

## Step 6 — Create shunt rules

Go to **Rule Manage**, find the **Russia_Block** rule and click **Edit**.

### Domain field

Paste the full domain list from the provided `domains.txt` file. The list covers: YouTube, Google, Discord, Instagram, Facebook, Meta/Oculus Quest, WhatsApp, Telegram, Twitter/X, TikTok, Cloudflare CDN, Twitch emote services, Claude/Anthropic, GitHub, IPTV (tvizi), 9GAG, and torrents.

See the attached `domains.txt` for the complete list.

### IP field

Paste the following (Telegram IP ranges — needed because Telegram connects via IP, not DNS):

```
149.154.160.0/20
91.108.4.0/22
91.108.8.0/22
91.108.12.0/22
91.108.16.0/22
91.108.20.0/22
91.108.56.0/22
95.161.64.0/20
```

**Save.**

---

## Step 7 — Create the Xray-Shunt node

1. Go to **Node List → Add**
2. Set **Type** = Xray, **Protocol** = Shunt
3. Give it a name (e.g., `shunt-main`)
4. Scroll down to the rule assignments:
   - **Russia_Block** → select your VLESS server
   - **Default** → Direct Connection
   - Leave China, Iran, Russia as "Close (Not use)"
5. **Save & Apply**

---

## Step 8 — Set the Shunt as main node

Go to **Basic Settings (Main tab)**:

1. Check **Main switch** is ON
2. Set **Node** to your **Xray-Shunt** node (not the VLESS node directly)
3. **Save & Apply**

**Verify via SSH:**

```bash
# The tcp_node should point to your shunt node's ID
uci get passwall2.@global[0].tcp_node
```

---

## Step 9 — Configure DNS

Go to the **DNS** tab:

| Setting | Value |
|---------|-------|
| Remote DNS Protocol | TCP |
| Remote DNS | 1.1.1.1 (CloudFlare) or 8.8.8.8 |
| Remote DNS Outbound | Remote |
| Remote Query Strategy | UseIPv4 |
| DNS Redirect | ✓ (checked) |

**Save & Apply.**

---

## Step 10 — Restart and verify

```bash
/etc/init.d/passwall2 restart
```

Wait 10 seconds, then check:

```bash
# Check xray is running
ps | grep xray

# Check for errors (OOM = problem)
logread | grep -i oom | tail -5

# Check passwall2 log
cat /tmp/etc/passwall2/acl/default/*.log 2>/dev/null
```

The Passwall2 main page should show **Core: RUNNING**.

Test from a device on the network:
- `ya.ru` — should load (direct connection, Russian IP)
- `youtube.com` — should load (proxied through VLESS)
- `claude.com` — should load (proxied)
- Telegram app — should connect

---

## Step 11 — Set up daily maintenance cron

Xray can leak memory over time, and Passwall2 may recreate backup files that eat RAM. Set up a daily restart and cleanup:

```bash
echo '0 5 * * * rm -rf /tmp/bak_v2ray 2>/dev/null; /etc/init.d/passwall2 restart' > /etc/crontabs/root
/etc/init.d/cron restart
```

When a new site gets blocked, just add `domain:example.com` to the Russia_Block domain list and restart Passwall2.

---

## Step 12 — Disable Passwall2 auto-update for geo files

Go to **Services → PassWall2 → App Update** (or Maintain tab).

Turn OFF any auto-update for:
- geosite
- geoip

Also disable subscription auto-update and xray logging (saves RAM):

```bash
uci set passwall2.@subscribe_list[0].auto_update='0'
uci set passwall2.@global_rules[0].auto_update='0'
uci set passwall2.@global[0].loglevel='none'
uci commit passwall2
```

**CRITICAL:** Remove the geo backup directory — Passwall2 creates `/tmp/bak_v2ray` which can eat 80MB+ of RAM and cause OOM crashes:

```bash
rm -rf /tmp/bak_v2ray
```

Set up a daily cron job to clean this and restart Passwall2 (prevents memory leaks):

```bash
echo '0 5 * * * rm -rf /tmp/bak_v2ray 2>/dev/null; /etc/init.d/passwall2 restart' > /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Troubleshooting

### No internet at all after enabling Passwall2

Xray probably crashed (OOM). Check:

```bash
ps | grep xray
logread | grep -i oom | tail -5
```

**MOST COMMON CAUSE:** Passwall2 creates a `/tmp/bak_v2ray` directory that eats 80MB+ of RAM. Delete it:

```bash
rm -rf /tmp/bak_v2ray
free -m
/etc/init.d/passwall2 restart
```

If OOM persists, check for leftover geoip/geosite files:

```bash
rm -f /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geoip.dat
/etc/init.d/passwall2 restart
```

### "code not found in geosite.dat: RU-BLOCKED"

You have a geosite.dat file that shouldn't be there. Remove it:

```bash
rm -f /usr/share/xray/geosite.dat
rm -f /usr/share/v2ray/geosite.dat
/etc/init.d/passwall2 restart
```

Make sure the Russia_Block domain list does NOT contain `geosite:` entries — use only `domain:` entries.

### geosite.dat is a symlink

Remove it:

```bash
rm -f /usr/share/xray/geosite.dat
rm -f /usr/share/v2ray/geosite.dat
/etc/init.d/passwall2 restart
```

### DNS times out on 127.0.0.1

Check if xray is running (`ps | grep xray`). If not, see OOM section above. Also check for stale DNS forwarders:

```bash
uci show dhcp | grep server
# Remove any 127.0.0.1#5053 or 127.0.0.1#5054 entries
```

### A specific site doesn't work

Add it to Russia_Block domain list:

```
domain:example.com
```

Save & Apply, restart Passwall2.

### IPTV streams don't play

Check what domains the playlist uses:

```bash
curl -sL -A "VLC/3.0" "YOUR_PLAYLIST_URL" | grep -oE 'https?://[^/]+' | sort -u
```

Add those domains to Russia_Block.

### Node name causes errors

Don't use apostrophes or special characters. Use only: `a-z A-Z 0-9 - _`

---

## Memory-critical notes for 256MB routers

| File | Size | RAM usage | Safe? |
|------|------|-----------|-------|
| Manual domain list | 0 KB on disk | ~5 MB | ✅ Yes — RECOMMENDED |
| Manual IP ranges | 0 KB on disk | Negligible | ✅ Yes — RECOMMENDED |
| geosite-ru-only.dat | 5.3 MB | ~80 MB+ | ❌ OOM after hours |
| geosite.dat (full) | 62 MB | ~1.3 GB | ❌ Instant OOM crash |
| geoip-ru-only.dat | 1.2 MB | ~80 MB combined | ❌ OOM crash |
| geoip.dat (full) | 21 MB | — | ❌ OOM crash |

**Rule: Use manual domain lists + manual Telegram IPs. Never load any .dat files on 256MB routers.**

---

## Disk space notes

| Package | Size | Needed? |
|---------|------|---------|
| xray-core | 28 MB | ✅ Required |
| sing-box | 39 MB | ❌ Remove if not using |
| geoview | 7 MB | Optional |
| podkop | 0.1 MB | ❌ Remove if not using |

Free space with:

```bash
opkg remove --force-removal-of-dependent-packages sing-box podkop luci-app-podkop luci-i18n-podkop-ru 2>/dev/null
rm -f /etc/config/podkop /etc/config/sing-box
rm -rf /etc/sing-box
```
