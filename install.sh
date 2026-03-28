#!/bin/sh
# ============================================
# Passwall2 Auto-Setup for OpenWrt 24.10
# Optimized for 256MB RAM routers (MediaTek mt7622)
# ============================================
# Usage: wget -O- https://raw.githubusercontent.com/USER/REPO/main/install.sh | sh
# Or:    sh install.sh
# ============================================

set -e

# --- Configuration ---
SUB_URL="https://sub.wormyvpn.com/XesMAGuYyrYTRDuV"
SUB_REMARK="wormys vless"
PREFERRED_NODE_KEYWORD="DE-FRA"  # keyword to match preferred node for shunt

echo "=========================================="
echo " Passwall2 Auto-Setup"
echo "=========================================="

# --- Step 1: Remove conflicting software ---
echo "[1/9] Removing conflicting software..."
/etc/init.d/zapret stop 2>/dev/null || true
rm -f /etc/init.d/zapret
rm -f /etc/hotplug.d/iface/90-zapret
rm -rf /opt/zapret

opkg remove --force-removal-of-dependent-packages \
  sing-box podkop luci-app-podkop luci-i18n-podkop-ru 2>/dev/null || true
rm -f /etc/config/podkop /etc/config/sing-box
rm -rf /etc/sing-box

# Remove stale DNS forwarders (from DNS-over-HTTPS setups)
uci del_list dhcp.@dnsmasq[0].server='127.0.0.1#5053' 2>/dev/null || true
uci del_list dhcp.@dnsmasq[0].server='127.0.0.1#5054' 2>/dev/null || true
uci commit dhcp 2>/dev/null || true

echo "[1/9] Done."

# --- Step 2: Disable flow offloading ---
echo "[2/9] Disabling flow offloading..."
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall
echo "[2/9] Done."

# --- Step 3: Install Passwall2 ---
echo "[3/9] Installing Passwall2..."
wget -O passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add passwall.pub
rm -f passwall.pub

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

# Check if feeds already added
if ! grep -q "passwall_packages" /etc/opkg/customfeeds.conf 2>/dev/null; then
  for feed in passwall_packages passwall2; do
    echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
  done
fi

opkg update

# Install dnsmasq-full (replace dnsmasq)
if opkg list-installed | grep -q "^dnsmasq "; then
  opkg remove dnsmasq
fi
opkg install dnsmasq-full 2>/dev/null || true

# Install firewall modules
opkg install kmod-nft-socket kmod-nft-tproxy kmod-nft-nat 2>/dev/null || true

# Install Passwall2
opkg install luci-app-passwall2

echo "[3/9] Done."

# --- Step 4: Remove geo files ---
echo "[4/9] Removing geo files (prevents OOM on 256MB routers)..."
rm -f /usr/share/xray/geosite.dat
rm -f /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geosite.dat
rm -f /usr/share/v2ray/geoip.dat
rm -rf /tmp/bak_v2ray
echo "[4/9] Done."

# --- Step 5: Apply Passwall2 configuration ---
echo "[5/9] Applying Passwall2 configuration..."

# Domain list for Russia_Block rule
DOMAIN_LIST='domain:youtube.com
domain:youtu.be
domain:youtube-nocookie.com
domain:youtube-studio.com
domain:youtubeapi.com
domain:youtubechildren.com
domain:youtubecommunity.com
domain:youtubecreators.com
domain:youtubeeducation.com
domain:youtubekids.com
domain:youtube.be
domain:youtube.ca
domain:youtube.co
domain:youtube.co.in
domain:youtube.co.uk
domain:youtube.com.au
domain:youtube.com.br
domain:youtube.com.mx
domain:youtube.com.tr
domain:youtube.com.ua
domain:youtube.de
domain:youtube.es
domain:youtube.fr
domain:youtube.jp
domain:youtube.nl
domain:youtube.pl
domain:youtube.pt
domain:youtube.ru
domain:yt.be
domain:googlevideo.com
domain:ytimg.com
domain:ggpht.com
domain:nhacmp3youtube.com
domain:googleusercontent.com
domain:gstatic.com
domain:gvt1.com
domain:1e100.net
domain:play.google.com
domain:discord.com
domain:discord.gg
domain:discord.app
domain:discord.co
domain:discord.design
domain:discord.dev
domain:discord.gift
domain:discord.gifts
domain:discord.media
domain:discord.new
domain:discord.store
domain:discord.tools
domain:discordapp.com
domain:discordapp.io
domain:discordapp.net
domain:discordcdn.com
domain:discordmerch.com
domain:discordpartygames.com
domain:discordsays.com
domain:discordsez.com
domain:discordstatus.com
domain:discordactivities.com
domain:discord-activities.com
domain:dis.gd
domain:bigbeans.solutions
domain:airhornbot.com
domain:airhorn.solutions
domain:watchanimeattheoffice.com
domain:instagram.com
domain:instagram-brand.com
domain:instagram-engineering.com
domain:instagram-press.com
domain:instagram-press.net
domain:cdninstagram.com
domain:igcdn.com
domain:ig.me
domain:igtv.com
domain:instagramcn.com
domain:instagrampartners.com
domain:bookstagram.com
domain:carstagram.com
domain:facebook.com
domain:facebook.net
domain:facebook.org
domain:fb.com
domain:fb.me
domain:fb.gg
domain:fb.watch
domain:fbcdn.com
domain:fbcdn.net
domain:fbsbx.com
domain:fbsbx.net
domain:fburl.com
domain:fbwat.ch
domain:fbpigeon.com
domain:facebookmail.com
domain:facebookcorewwwi.onion
domain:fbworkmail.com
domain:fbrpms.com
domain:fbidb.io
domain:meta.com
domain:meta.net
domain:meta.ai
domain:atmeta.com
domain:aboutfacebook.com
domain:facebookbrand.com
domain:facebookbrand.net
domain:facebookpay.com
domain:facebooklive.com
domain:facebooksafety.com
domain:facebookstories.com
domain:facebookportal.com
domain:facebookwork.com
domain:workplace.com
domain:workplaceusecases.com
domain:threads.net
domain:accountkit.com
domain:crowdtangle.com
domain:expresswifi.com
domain:internet.org
domain:freebasics.com
domain:freebasics.net
domain:terragraph.com
domain:liverail.com
domain:liverail.tv
domain:thefacebook.com
domain:thefacebook.net
domain:thefind.com
domain:markzuckerberg.com
domain:akamaihd.net
domain:f8.com
domain:fbf8.com
domain:parse.com
domain:flow.dev
domain:flow.org
domain:flowtype.org
domain:hacklang.org
domain:hhvm.com
domain:reactjs.org
domain:react.com
domain:reactjs.com
domain:recoiljs.org
domain:frescolib.org
domain:componentkit.org
domain:draftjs.org
domain:buck.build
domain:buckbuild.com
domain:fasttext.cc
domain:fblitho.com
domain:fbredex.com
domain:fbinfer.com
domain:fbrell.com
domain:yogalayout.com
domain:mcrouter.net
domain:mcrouter.org
domain:makeitopen.com
domain:messengerdevelopers.com
domain:ogp.me
domain:opengraphprotocol.com
domain:opengraphprotocol.org
domain:pyrobot.org
domain:rocksdb.com
domain:rocksdb.net
domain:rocksdb.org
domain:botorch.org
domain:atscaleconference.com
domain:facebookconnect.com
domain:facebookappcenter.info
domain:facebookappcenter.net
domain:facebookappcenter.org
domain:facebookdevelopergarage.com
domain:faciometrics.com
domain:oculus.com
domain:oculuscdn.com
domain:oculusbrand.com
domain:oculusvr.com
domain:oculusrift.com
domain:oculusconnect.com
domain:oculusforbusiness.com
domain:oculus2014.com
domain:oculus3d.com
domain:oculusblog.com
domain:buyoculus.com
domain:binoculus.com
domain:ocul.us
domain:powersunitedvr.com
domain:whatsapp.com
domain:whatsapp.net
domain:wa.me
domain:telegram.org
domain:t.me
domain:telegram.me
domain:telesco.pe
domain:tdesktop.com
domain:telegra.ph
domain:web.telegram.org
domain:desktop.telegram.org
domain:updates.telegram.org
domain:core.telegram.org
domain:api.telegram.org
domain:td.telegram.org
domain:telegram.dog
domain:tg.dev
domain:twitter.com
domain:x.com
domain:twimg.com
domain:t.co
domain:tiktok.com
domain:tiktokcdn.com
domain:tiktokcdn-us.com
domain:tiktokv.com
domain:tiktokv.us
domain:tiktokw.us
domain:tiktokd.net
domain:tiktokd.org
domain:tik-tokapi.com
domain:musical.ly
domain:muscdn.com
domain:byteoversea.com
domain:ttwstatic.com
domain:p16-tiktokcdn-com.akamaized.net
domain:cloudflare.com
domain:cloudflare.net
domain:cloudflare-dns.com
domain:cloudflare-gateway.com
domain:cloudflare-quic.com
domain:cloudflare-ipfs.com
domain:cloudflare-stream.com
domain:cloudflare-tv.com
domain:cloudflare-access.com
domain:cloudflare-apps.com
domain:cloudflare-bolt.com
domain:cloudflare-client.com
domain:cloudflare-insights.com
domain:cloudflare-ok.com
domain:cloudflare-partners.com
domain:cloudflare-portal.com
domain:cloudflare-preview.com
domain:cloudflare-resolve.com
domain:cloudflare-ssl.com
domain:cloudflare-status.com
domain:cloudflare-storage.com
domain:cloudflare-test.com
domain:cloudflare-warp.com
domain:cloudflare-esni.com
domain:cloudflare-ech.com
domain:cloudflare-cn.com
domain:cloudflareanycast.net
domain:cloudflareglobal.net
domain:cloudflareinsights-cn.com
domain:cloudflareperf.com
domain:cloudflareprod.com
domain:cloudflarestaging.com
domain:cloudflarechina.cn
domain:cloudfront.net
domain:argotunnel.com
domain:cf-ipfs.com
domain:cf-ns.com
domain:cf-ns.net
domain:cf-ns.site
domain:cf-ns.tech
domain:cfl.re
domain:cftest5.cn
domain:cftest6.cn
domain:cftest7.com
domain:cftest8.com
domain:every1dns.net
domain:isbgpsafeyet.com
domain:one.one.one
domain:pacloudflare.com
domain:pages.dev
domain:trycloudflare.com
domain:videodelivery.net
domain:warp.plus
domain:workers.dev
domain:10tv.app
domain:7tv.app
domain:7tv.gg
domain:7tv.io
domain:betterttv.net
domain:frankerfacez.com
domain:ffzap.com
domain:claude.ai
domain:claude.com
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
domain:9cache.com
domain:pornolab.net
domain:rutracker.org'

# IP list for Russia_Block rule (Telegram ranges)
IP_LIST='149.154.160.0/20
91.108.4.0/22
91.108.8.0/22
91.108.12.0/22
91.108.16.0/22
91.108.20.0/22
91.108.56.0/22
95.161.64.0/20'

# Write Russia_Block shunt rule
uci set passwall2.Russia_Block=shunt_rules
uci set passwall2.Russia_Block.remarks='Russia_Block'
uci set passwall2.Russia_Block.network='tcp,udp'
uci set passwall2.Russia_Block.domain_list="$DOMAIN_LIST"
uci set passwall2.Russia_Block.ip_list="$IP_LIST"

# Disable unused shunt rules (China, Iran, Russia reference geo files we don't have)
uci set passwall2.China=shunt_rules
uci set passwall2.China.remarks='China'
uci set passwall2.China.network='tcp,udp'
uci set passwall2.China.domain_list=''
uci set passwall2.China.ip_list=''

uci set passwall2.Iran=shunt_rules
uci set passwall2.Iran.remarks='Iran'
uci set passwall2.Iran.network='tcp,udp'
uci set passwall2.Iran.domain_list=''
uci set passwall2.Iran.ip_list=''

# Global settings
uci set passwall2.@global[0].enabled='1'
uci set passwall2.@global[0].localhost_proxy='1'
uci set passwall2.@global[0].client_proxy='1'
uci set passwall2.@global[0].socks_enabled='0'
uci set passwall2.@global[0].acl_enable='0'
uci set passwall2.@global[0].loglevel='none'
uci set passwall2.@global[0].log_node='0'

# DNS settings
uci set passwall2.@global[0].direct_dns_protocol='auto'
uci set passwall2.@global[0].direct_dns_query_strategy='UseIP'
uci set passwall2.@global[0].remote_dns_protocol='tcp'
uci set passwall2.@global[0].remote_dns='8.8.8.8'
uci set passwall2.@global[0].remote_dns_query_strategy='UseIPv4'
uci set passwall2.@global[0].remote_dns_detour='remote'
uci set passwall2.@global[0].dns_redirect='1'
uci set passwall2.@global[0].dns_hosts='dns.google.com 8.8.8.8'

# Forwarding settings
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].tcp_proxy_way='redirect'
uci set passwall2.@global_forwarding[0].ipv6_tproxy='0'

# Disable ALL auto-updates for geo files
uci set passwall2.@global_rules[0].auto_update='0'
uci set passwall2.@global_rules[0].geosite_update='0'
uci set passwall2.@global_rules[0].geoip_update='0'

# Commit base config
uci commit passwall2

echo "[5/9] Done."

# --- Step 6: Set up subscription ---
echo "[6/9] Setting up subscription..."

# Delete existing subscriptions
while uci delete passwall2.@subscribe_list[0] 2>/dev/null; do :; done

# Add subscription
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

echo "[6/9] Done."

# --- Step 7: Trigger subscription update and configure shunt ---
echo "[7/9] Updating subscription and configuring shunt node..."

# Restart to trigger subscription update (boot_update=1)
/etc/init.d/passwall2 stop 2>/dev/null || true
sleep 2
/etc/init.d/passwall2 start
sleep 10

# Find the preferred node ID (match by keyword in remarks)
PREFERRED_NODE=""
for node_id in $(uci show passwall2 | grep "\.remarks=" | grep "$PREFERRED_NODE_KEYWORD" | head -1 | cut -d. -f2); do
  # Make sure it's actually a VLESS node, not a shunt
  proto=$(uci get passwall2.$node_id.protocol 2>/dev/null)
  if [ "$proto" = "vless" ]; then
    PREFERRED_NODE="$node_id"
    break
  fi
done

if [ -z "$PREFERRED_NODE" ]; then
  echo "WARNING: Could not find node matching '$PREFERRED_NODE_KEYWORD'"
  echo "Available nodes:"
  uci show passwall2 | grep "\.remarks=" | grep -v "shunt_rules"
  echo ""
  echo "After install, manually:"
  echo "  1. Go to Node List, note the ID of your preferred node"
  echo "  2. Create an Xray-Shunt node with Russia_Block pointing to it"
  echo "  3. Set tcp_node to the shunt node"
  echo ""
  echo "Or re-run this script after subscription updates."
else
  echo "Found preferred node: $PREFERRED_NODE ($(uci get passwall2.$PREFERRED_NODE.remarks))"

  # Create shunt node
  uci set passwall2.myshunt=nodes
  uci set passwall2.myshunt.type='Xray'
  uci set passwall2.myshunt.protocol='_shunt'
  uci set passwall2.myshunt.remarks='auto-shunt'
  uci set passwall2.myshunt.domainStrategy='AsIs'
  uci set passwall2.myshunt.domainMatcher='hybrid'
  uci set passwall2.myshunt.write_ipset_direct='1'
  uci set passwall2.myshunt.enable_geoview_ip='1'
  uci set passwall2.myshunt.Russia_Block="$PREFERRED_NODE"
  uci set passwall2.myshunt.default_node='_direct'

  # Set shunt as main node
  uci set passwall2.@global[0].tcp_node='myshunt'
  uci set passwall2.@global[0].node='myshunt'

  uci commit passwall2
  echo "Shunt configured: Russia_Block -> $PREFERRED_NODE, Default -> direct"
fi

echo "[7/9] Done."

# --- Step 8: Clean up and free memory ---
echo "[8/9] Cleaning up..."
rm -rf /tmp/bak_v2ray
rm -f /usr/share/xray/geosite.dat
rm -f /usr/share/xray/geoip.dat
rm -f /usr/share/v2ray/geosite.dat
rm -f /usr/share/v2ray/geoip.dat
echo "[8/9] Done."

# --- Step 9: Set up cron and restart ---
echo "[9/9] Setting up cron and final restart..."

echo '0 5 * * * rm -rf /tmp/bak_v2ray 2>/dev/null; /etc/init.d/passwall2 restart' > /etc/crontabs/root
/etc/init.d/cron restart

/etc/init.d/passwall2 restart
sleep 5

echo "[9/9] Done."

# --- Final check ---
echo ""
echo "=========================================="
echo " Setup complete!"
echo "=========================================="

if pidof xray > /dev/null 2>&1; then
  echo " ✓ Xray is running"
else
  echo " ✗ Xray is NOT running — check logs:"
  echo "   cat /tmp/etc/passwall2/acl/default/*.log"
fi

echo ""
echo " Memory: $(awk '/MemAvailable/ {print int($2/1024) "MB available"}' /proc/meminfo)"
echo " Disk:   $(df -h /overlay | tail -1 | awk '{print $4 " free"}')"
echo ""
echo " Test from a device on the network:"
echo "   - ya.ru        (should load — direct)"
echo "   - youtube.com  (should load — proxied)"
echo "   - claude.com   (should load — proxied)"
echo ""
echo " If a node wasn't found automatically, configure manually:"
echo "   Services → PassWall2 → Node List → create Xray-Shunt"
echo ""
echo " To add new blocked domains:"
echo "   Rule Manage → Russia_Block → add domain:example.com"
echo "=========================================="
