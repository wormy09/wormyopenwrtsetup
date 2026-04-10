#!/bin/sh
# ============================================
# Passwall2 Auto-Setup for OpenWrt
# Optimized for 256MB+ RAM routers
# ============================================
# Usage:
#   wget -O /tmp/install.sh https://raw.githubusercontent.com/wormy09/wormyopenwrtsetup/main/install.sh
#   sh /tmp/install.sh
# ============================================

set -e

# --- Detect package manager ---
if command -v apk > /dev/null 2>&1 && apk --version > /dev/null 2>&1; then
  PKG_MGR="apk"
elif command -v opkg > /dev/null 2>&1; then
  PKG_MGR="opkg"
else
  echo "ERROR: No supported package manager found (need opkg or apk)"
  exit 1
fi

pkg_remove() {
  if [ "$PKG_MGR" = "apk" ]; then
    apk del "$@" 2>/dev/null || true
  else
    opkg remove --force-removal-of-dependent-packages "$@" 2>/dev/null || true
  fi
}

echo ""
echo "=========================================="
echo "  Passwall2 Auto-Setup for OpenWrt"
echo "=========================================="
echo "  Package manager: $PKG_MGR"
echo "=========================================="
echo ""

# --- Ask for subscription URL ---
printf "Enter your VLESS subscription URL: "
read SUB_URL

if [ -z "$SUB_URL" ]; then
  echo "ERROR: Subscription URL is required."
  exit 1
fi

printf "Enter a name for this subscription (default: my-vless): "
read SUB_REMARK
SUB_REMARK="${SUB_REMARK:-my-vless}"

# --- Step 1: Remove conflicting software ---
echo ""
echo "[1/8] Removing conflicting software..."
/etc/init.d/zapret stop 2>/dev/null || true
rm -f /etc/init.d/zapret
rm -f /etc/hotplug.d/iface/90-zapret
rm -rf /opt/zapret

pkg_remove sing-box podkop luci-app-podkop luci-i18n-podkop-ru \
  https-dns-proxy luci-app-https-dns-proxy v2ray-core

rm -f /etc/config/podkop /etc/config/sing-box
rm -rf /etc/sing-box

for port in 5053 5054 5055 5153 5253; do
  uci del_list dhcp.@dnsmasq[0].server="127.0.0.1#$port" 2>/dev/null || true
done
uci commit dhcp 2>/dev/null || true

echo "[1/8] Done."

# --- Step 2: Disable flow offloading ---
echo "[2/8] Disabling flow offloading..."
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall

echo "[2/8] Done."

# --- Step 3: Install Passwall2 ---
echo "[3/8] Installing Passwall2..."

# Skip if already installed
if [ "$PKG_MGR" = "apk" ] && apk list --installed 2>/dev/null | grep -q "luci-app-passwall2"; then
  echo "  Passwall2 already installed, skipping."
elif [ "$PKG_MGR" = "opkg" ] && opkg list-installed 2>/dev/null | grep -q "luci-app-passwall2"; then
  echo "  Passwall2 already installed, skipping."
else

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

if [ "$PKG_MGR" = "apk" ]; then
  wget -O /etc/apk/keys/passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub 2>/dev/null || true

  if ! grep -q "passwall_packages" /etc/apk/repositories.d/passwall.list 2>/dev/null; then
    for feed in passwall_packages passwall2; do
      echo "https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/apk/repositories.d/passwall.list
    done
  fi

  apk update
  apk add dnsmasq-full 2>/dev/null || true
  apk add kmod-nft-socket kmod-nft-tproxy kmod-nft-nat 2>/dev/null || true
  apk add luci-app-passwall2
else
  wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
  opkg-key add passwall.pub
  rm -f passwall.pub

  if ! grep -q "passwall_packages" /etc/opkg/customfeeds.conf 2>/dev/null; then
    for feed in passwall_packages passwall2; do
      echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
    done
  fi

  opkg update

  if opkg list-installed | grep -q "^dnsmasq "; then
    opkg remove dnsmasq
  fi
  opkg install dnsmasq-full 2>/dev/null || true
  opkg install kmod-nft-socket kmod-nft-tproxy kmod-nft-nat 2>/dev/null || true
  opkg install luci-app-passwall2
fi
fi

echo "[3/8] Done."

# --- Step 4: Remove geo files & apply config ---
echo "[4/8] Removing geo files and applying configuration..."
rm -f /usr/share/xray/geosite.dat /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geosite.dat /usr/share/v2ray/geoip.dat
rm -rf /tmp/bak_v2ray

# Domain list (optimized — domain:x.com matches ALL *.x.com subdomains)
DOMAIN_LIST='domain:youtube.com
domain:youtu.be
domain:youtube-nocookie.com
domain:youtube.ru
domain:yt.be
domain:googlevideo.com
domain:ytimg.com
domain:ggpht.com
domain:googleusercontent.com
domain:gstatic.com
domain:gvt1.com
domain:1e100.net
domain:play.google.com
domain:googleapis.com
domain:withgoogle.com
domain:discord.com
domain:discord.gg
domain:discordapp.com
domain:discordapp.net
domain:discordcdn.com
domain:discordstatus.com
domain:dis.gd
domain:instagram.com
domain:cdninstagram.com
domain:ig.me
domain:facebook.com
domain:facebook.net
domain:fb.com
domain:fb.me
domain:fb.gg
domain:fb.watch
domain:fbcdn.com
domain:fbcdn.net
domain:fbsbx.com
domain:facebookmail.com
domain:meta.com
domain:meta.ai
domain:threads.net
domain:akamaihd.net
domain:oculus.com
domain:oculuscdn.com
domain:ocul.us
domain:whatsapp.com
domain:whatsapp.net
domain:wa.me
domain:telegram.org
domain:t.me
domain:telegram.me
domain:telegra.ph
domain:tdesktop.com
domain:telegram.dog
domain:tg.dev
domain:telesco.pe
domain:twitter.com
domain:x.com
domain:twimg.com
domain:t.co
domain:tiktok.com
domain:tiktokcdn.com
domain:musical.ly
domain:cloudflare.com
domain:cloudflare.net
domain:cloudflare-dns.com
domain:cloudflare-gateway.com
domain:cloudflare-warp.com
domain:cloudfront.net
domain:one.one.one
domain:pages.dev
domain:workers.dev
domain:warp.plus
domain:videodelivery.net
domain:7tv.app
domain:7tv.gg
domain:7tv.io
domain:betterttv.net
domain:frankerfacez.com
domain:claude.ai
domain:anthropic.com
domain:claudeusercontent.com
domain:github.com
domain:githubusercontent.com
domain:tvizi.net
domain:tvizi.online
domain:online24.pm
domain:ip-tv.dev
domain:iptv.pm
domain:see24.eu
domain:9gag.com
domain:pornolab.net
domain:rutracker.org
domain:anydesk.com'

IP_LIST='149.154.160.0/20
91.108.4.0/22
91.108.8.0/22
91.108.12.0/22
91.108.16.0/22
91.108.20.0/22
91.108.56.0/22
95.161.64.0/20
157.240.0.0/16
31.13.24.0/21
31.13.64.0/18
102.132.96.0/20
129.134.0.0/16
185.60.216.0/22
142.250.0.0/15
172.217.0.0/16
216.58.192.0/19
172.253.0.0/16
74.125.0.0/16
64.233.160.0/19
108.177.0.0/17
173.194.0.0/16
209.85.128.0/17
192.178.0.0/15
62.96.74.120/29
213.61.91.48/29
217.110.18.136/29
217.110.194.192/29'

# Apply shunt rules
uci set passwall2.Russia_Block=shunt_rules
uci set passwall2.Russia_Block.remarks='Russia_Block'
uci set passwall2.Russia_Block.network='tcp,udp'
uci set passwall2.Russia_Block.domain_list="$DOMAIN_LIST"
uci set passwall2.Russia_Block.ip_list="$IP_LIST"

# Clear unused rules
for rule in China Iran; do
  uci set passwall2.$rule=shunt_rules
  uci set passwall2.$rule.remarks="$rule"
  uci set passwall2.$rule.network='tcp,udp'
  uci set passwall2.$rule.domain_list=''
  uci set passwall2.$rule.ip_list=''
done

# Global settings
uci set passwall2.@global[0].enabled='1'
uci set passwall2.@global[0].localhost_proxy='1'
uci set passwall2.@global[0].client_proxy='1'
uci set passwall2.@global[0].socks_enabled='0'
uci set passwall2.@global[0].acl_enable='0'
uci set passwall2.@global[0].loglevel='none'
uci set passwall2.@global[0].log_node='0'

# DNS
uci set passwall2.@global[0].direct_dns_protocol='auto'
uci set passwall2.@global[0].direct_dns_query_strategy='UseIP'
uci set passwall2.@global[0].remote_dns_protocol='tcp'
uci set passwall2.@global[0].remote_dns='8.8.8.8'
uci set passwall2.@global[0].remote_dns_query_strategy='UseIPv4'
uci set passwall2.@global[0].remote_dns_detour='remote'
uci set passwall2.@global[0].dns_redirect='1'
uci set passwall2.@global[0].dns_hosts='dns.google.com 8.8.8.8'

# Forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].tcp_proxy_way='redirect'
uci set passwall2.@global_forwarding[0].ipv6_tproxy='0'

# Disable geo auto-updates
uci set passwall2.@global_rules[0].auto_update='0'
uci set passwall2.@global_rules[0].geosite_update='0'
uci set passwall2.@global_rules[0].geoip_update='0'

uci commit passwall2
echo "[4/8] Done."

# --- Step 5: Fetch subscription and let user choose ---
echo "[5/8] Fetching nodes from subscription..."

# Stop passwall2 to ensure clean DNS
/etc/init.d/passwall2 stop 2>/dev/null || true
sleep 2

# Fetch and decode subscription directly (bypass passwall2's unreliable fetcher)
SUB_RAW=$(curl -sL -A "v2rayN/9.99" "$SUB_URL" | base64 -d 2>/dev/null)

if [ -z "$SUB_RAW" ]; then
  echo "ERROR: Could not fetch subscription. Check URL and network."
  exit 1
fi

# Parse vless:// links and create nodes
NODE_IDS=""
NODE_COUNT=0
NODE_NAMES=""

echo "$SUB_RAW" | while IFS= read -r line; do echo "$line"; done | grep "^vless://" | while IFS= read -r vless_url; do
  NODE_COUNT=$((NODE_COUNT + 1))

  # Extract fragment (remarks) — everything after #
  raw_remarks=$(echo "$vless_url" | sed 's/.*#//')
  remarks=$(printf '%b' "$(echo "$raw_remarks" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')")
  # Sanitize remarks for UCI (no apostrophes or special chars)
  remarks=$(echo "$remarks" | tr "'" "-" | tr '"' '-')

  # Extract uuid@address:port
  core=$(echo "$vless_url" | sed 's|vless://||' | sed 's|?.*||')
  uuid=$(echo "$core" | sed 's|@.*||')
  addr_port=$(echo "$core" | sed 's|.*@||')
  address=$(echo "$addr_port" | sed 's|:.*||')
  port=$(echo "$addr_port" | sed 's|.*:||')

  # Extract query parameters
  params=$(echo "$vless_url" | sed 's|.*?||' | sed 's|#.*||')

  get_param() {
    echo "$params" | tr '&' '\n' | grep "^$1=" | head -1 | sed "s|^$1=||" | sed 's/%2F/\//g'
  }

  encryption=$(get_param encryption)
  transport=$(get_param type)
  security=$(get_param security)
  sni=$(get_param sni)
  fp=$(get_param fp)
  pbk=$(get_param pbk)
  sid=$(get_param sid)
  flow=$(get_param flow)
  path=$(get_param path)
  host=$(get_param host)
  mode=$(get_param mode)

  # Generate unique node ID
  node_id="node_$(echo "$address$port" | md5sum 2>/dev/null | cut -c1-8 || echo "${NODE_COUNT}")"

  # Create node via UCI
  uci set passwall2.$node_id=nodes
  uci set passwall2.$node_id.type='Xray'
  uci set passwall2.$node_id.protocol='vless'
  uci set passwall2.$node_id.remarks="$remarks"
  uci set passwall2.$node_id.address="$address"
  uci set passwall2.$node_id.port="$port"
  uci set passwall2.$node_id.uuid="$uuid"
  uci set passwall2.$node_id.encryption="${encryption:-none}"
  uci set passwall2.$node_id.tls='1'
  uci set passwall2.$node_id.tls_allowInsecure='1'
  uci set passwall2.$node_id.timeout='60'
  uci set passwall2.$node_id.add_mode='2'
  uci set passwall2.$node_id.group="$SUB_REMARK"

  # Transport
  case "$transport" in
    xhttp)
      uci set passwall2.$node_id.transport='xhttp'
      [ -n "$path" ] && uci set passwall2.$node_id.xhttp_path="$path"
      [ -n "$host" ] && uci set passwall2.$node_id.xhttp_host="$host"
      [ -n "$mode" ] && uci set passwall2.$node_id.xhttp_mode="$mode"
      ;;
    tcp|"")
      uci set passwall2.$node_id.transport='raw'
      uci set passwall2.$node_id.tcp_guise='none'
      ;;
    ws)
      uci set passwall2.$node_id.transport='ws'
      [ -n "$path" ] && uci set passwall2.$node_id.ws_path="$path"
      [ -n "$host" ] && uci set passwall2.$node_id.ws_host="$host"
      ;;
    grpc)
      uci set passwall2.$node_id.transport='grpc'
      ;;
  esac

  # Security (Reality)
  if [ "$security" = "reality" ]; then
    uci set passwall2.$node_id.reality='1'
    [ -n "$pbk" ] && uci set passwall2.$node_id.reality_publicKey="$pbk"
    [ -n "$sid" ] && uci set passwall2.$node_id.reality_shortId="$sid"
    [ -n "$sni" ] && uci set passwall2.$node_id.tls_serverName="$sni"
    uci set passwall2.$node_id.utls='1'
    [ -n "$fp" ] && uci set passwall2.$node_id.fingerprint="$fp"
  fi

  # Flow (for XTLS Vision)
  [ -n "$flow" ] && uci set passwall2.$node_id.flow="$flow"

  echo "  $NODE_COUNT) $remarks  [$address:$port]"
done

# Re-read nodes since the while loop ran in a subshell
uci commit passwall2

# Collect node IDs for selection
NODE_IDS=""
NODE_COUNT=0

for line in $(uci show passwall2 | grep "\.protocol='vless'" ); do
  node_id=$(echo "$line" | cut -d. -f2)
  remarks=$(uci get passwall2.$node_id.remarks 2>/dev/null)
  addr=$(uci get passwall2.$node_id.address 2>/dev/null)

  case "$remarks" in
    Example|example|rulenode|auto-shunt) continue ;;
  esac
  [ -z "$addr" ] && continue

  NODE_COUNT=$((NODE_COUNT + 1))
  NODE_IDS="$NODE_IDS $node_id"
done

if [ "$NODE_COUNT" -eq 0 ]; then
  echo ""
  echo "ERROR: No nodes found. Check your subscription URL."
  echo "You can configure manually in LuCI: Services -> PassWall2"
  exit 1
fi

echo ""
printf "Select node for proxying blocked sites (1-$NODE_COUNT): "
read NODE_CHOICE

if ! echo "$NODE_CHOICE" | grep -qE '^[0-9]+$' || [ "$NODE_CHOICE" -lt 1 ] || [ "$NODE_CHOICE" -gt "$NODE_COUNT" ]; then
  echo "Invalid choice. Defaulting to 1."
  NODE_CHOICE=1
fi

SELECTED_NODE=$(echo $NODE_IDS | awk "{print \$$NODE_CHOICE}")
SELECTED_NAME=$(uci get passwall2.$SELECTED_NODE.remarks 2>/dev/null)

echo ""
echo "  Selected: $SELECTED_NAME"
echo "[5/8] Done."

# --- Step 6: Set up subscription for auto-updates ---
echo "[6/8] Setting up subscription auto-update..."

while uci delete passwall2.@subscribe_list[0] 2>/dev/null; do :; done

uci add passwall2 subscribe_list
uci set passwall2.@subscribe_list[0].remark="$SUB_REMARK"
uci set passwall2.@subscribe_list[0].url="$SUB_URL"
uci set passwall2.@subscribe_list[0].allowInsecure='1'
uci set passwall2.@subscribe_list[0].filter_keyword_mode='5'
uci set passwall2.@subscribe_list[0].ss_type='global'
uci set passwall2.@subscribe_list[0].trojan_type='global'
uci set passwall2.@subscribe_list[0].vmess_type='global'
uci set passwall2.@subscribe_list[0].vless_type='global'
uci set passwall2.@subscribe_list[0].hysteria2_type='global'
uci set passwall2.@subscribe_list[0].domain_strategy='global'
uci set passwall2.@subscribe_list[0].boot_update='1'
uci set passwall2.@subscribe_list[0].auto_update='1'
uci set passwall2.@subscribe_list[0].user_agent='v2rayN/9.99'
uci set passwall2.@subscribe_list[0].week_update='8'
uci set passwall2.@subscribe_list[0].interval_update='12'

uci commit passwall2
echo "[6/8] Done."

# --- Step 7: Create shunt and enable ---
echo "[7/8] Creating shunt node..."

uci set passwall2.myshunt=nodes
uci set passwall2.myshunt.type='Xray'
uci set passwall2.myshunt.protocol='_shunt'
uci set passwall2.myshunt.remarks='auto-shunt'
uci set passwall2.myshunt.domainStrategy='AsIs'
uci set passwall2.myshunt.domainMatcher='hybrid'
uci set passwall2.myshunt.write_ipset_direct='1'
uci set passwall2.myshunt.enable_geoview_ip='1'
uci set passwall2.myshunt.Russia_Block="$SELECTED_NODE"
uci set passwall2.myshunt.default_node='_direct'

uci set passwall2.@global[0].tcp_node='myshunt'
uci set passwall2.@global[0].node='myshunt'

# Re-enable passwall2 and DNS redirect (was disabled for subscription fetch)
uci set passwall2.@global[0].enabled='1'
uci set passwall2.@global[0].dns_redirect='1'

uci commit passwall2

echo "  Shunt: Russia_Block -> $SELECTED_NAME"
echo "  Default -> direct connection"
echo "[7/8] Done."

# --- Step 8: Cron, cleanup, restart ---
echo "[8/8] Final cleanup and restart..."

rm -rf /tmp/bak_v2ray
rm -f /usr/share/xray/geosite.dat /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geosite.dat /usr/share/v2ray/geoip.dat

mkdir -p /etc/cron.d
echo '0 */6 * * * root rm -rf /tmp/bak_v2ray 2>/dev/null; /etc/init.d/passwall2 restart' > /etc/cron.d/passwall2_restart
chmod 644 /etc/cron.d/passwall2_restart
/etc/init.d/cron restart

/etc/init.d/passwall2 restart
sleep 5

echo "[8/8] Done."

# --- Final status ---
echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="

if pidof xray > /dev/null 2>&1; then
  echo "  Status:  Xray is RUNNING"
else
  echo "  Status:  Xray is NOT running"
  echo "  Debug:   cat /tmp/etc/passwall2/acl/default/*.log"
fi

echo "  Memory:  $(awk '/MemAvailable/ {print int($2/1024) "MB available"}' /proc/meminfo)"
echo "  Disk:    $(df -h /overlay | tail -1 | awk '{print $4 " free"}')"
echo ""
echo "  Test from a device on the network:"
echo "    ya.ru        -> should load (direct)"
echo "    youtube.com  -> should load (proxied)"
echo "    claude.com   -> should load (proxied)"
echo ""
echo "  Add blocked domains:"
echo "    Services -> PassWall2 -> Rule Manage -> Russia_Block"
echo "=========================================="
