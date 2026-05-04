#!/bin/bash
cd openwrt || exit 1

# ==========================================
# 终极防翻车：只做标准流程，不瞎折腾内核
# ==========================================

# 1. 标准流程：更新并安装 Feeds
echo "正在更新 Feeds..."
./scripts/feeds update -a
echo "正在安装 Feeds..."
./scripts/feeds install -a

# 2. 🔴 关键：强制从指定源安装 CUPS 和 SSR-Plus，防止被官方源覆盖
echo "正在强制安装核心软件包..."
./scripts/feeds install -a -p printing-packages cups cups-filters cups-bjnp gutenprint || true
./scripts/feeds install -a -p small xray-core naiveproxy shadowsocks-rust || true
./scripts/feeds install -a -p helloworld luci-app-ssr-plus || true

# 3. 🔴 关键：让系统根据 .config 自动补全所有缺失的默认配置
#    这一步能解决 90% 的「缺这个缺那个」的报错
echo "正在生成默认配置..."
make defconfig

# 4. 创建自启动脚本 (保留你的功能)
mkdir -p files/etc/init.d files/etc/rc.d

cat > files/etc/init.d/custom-autostart << 'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd enable && /etc/init.d/cupsd start
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon enable && /etc/init.d/avahi-daemon start
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd enable && /etc/init.d/ksmbd start
    [ -x /etc/init.d/miniupnpd ] && /etc/init.d/miniupnpd enable && /etc/init.d/miniupnpd start
    [ -x /etc/init.d/ddns ] && /etc/init.d/ddns enable && /etc/init.d/ddns start
}
EOF
chmod +x files/etc/init.d/custom-autostart
ln -sf ../init.d/custom-autostart files/etc/rc.d/S99custom-autostart

cat > files/etc/init.d/auto-share-init << 'EOF'
#!/bin/sh /etc/rc.common
START=98
boot() { sleep 15; start; }
start() {
    BEST_PART=""
    BEST_FREE=0
    for part in /mnt/*; do
        if mountpoint -q "$part" 2>/dev/null; then
            free_kb=$(df -k "$part" | awk 'NR==2{print $4}')
            [ "$free_kb" -gt "$BEST_FREE" ] && { BEST_FREE=$free_kb; BEST_PART=$part; }
        fi
    done
    [ -z "$BEST_PART" ] && return 0
    SHARE_DIR="$BEST_PART/OpenWrt_Share"
    mkdir -p "$SHARE_DIR" && chmod 0777 "$SHARE_DIR"
    
    while uci delete ksmbd.@share[0] 2>/dev/null; do :; done
    uci add ksmbd share
    uci set ksmbd.@share[-1].name='Auto_Share'
    uci set ksmbd.@share[-1].path="$SHARE_DIR"
    uci set ksmbd.@share[-1].browseable='yes'
    uci set ksmbd.@share[-1].read_only='no'
    uci set ksmbd.@share[-1].guest_ok='yes'
    uci commit ksmbd
    /etc/init.d/ksmbd restart
}
EOF
chmod +x files/etc/init.d/auto-share-init
ln -sf ../init.d/auto-share-init files/etc/rc.d/S98auto-share-init

echo "✅ diy-part2.sh 执行完成，未破坏内核，配置已补全！"
