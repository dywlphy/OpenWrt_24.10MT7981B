#!/bin/bash

# ==========================================
# 依赖安装 + 自启动脚本 + 自动共享
# ==========================================

# ---------- 1. 更新 feeds ----------
./scripts/feeds update -a

# 物理移除冲突包
echo "移除冲突包 odhcpd-ipv6only..."
rm -rf package/network/services/odhcpd-ipv6only
find feeds -path "*/odhcpd-ipv6only*" -exec rm -rf {} \; 2>/dev/null
echo "✅ 冲突包已移除"

# ---------- 2. 按需安装 feeds 包 ----------
echo "按需安装 feeds 包..."

./scripts/feeds install luci
./scripts/feeds install luci-i18n-base-zh-cn
./scripts/feeds install luci-proto-ipv6
./scripts/feeds install miniupnpd
./scripts/feeds install luci-app-upnp
./scripts/feeds install ddns-scripts
./scripts/feeds install luci-app-ddns
./scripts/feeds install luci-app-ssr-plus
./scripts/feeds install shadowsocksr-libev
./scripts/feeds install ksmbd-server
./scripts/feeds install luci-app-ksmbd
./scripts/feeds install cups
./scripts/feeds install cups-filters
./scripts/feeds install cups-bjnp
./scripts/feeds install gutenprint
./scripts/feeds install foomatic-db
./scripts/feeds install foomatic-db-engine
./scripts/feeds install avahi-daemon
./scripts/feeds install avahi-utils
./scripts/feeds install dbus
./scripts/feeds install libusb-1.0

echo "✅ feeds 包安装完成"

# ---------- 3. 克隆打印包（增加重试） ----------
echo "克隆打印包..."
rm -rf package/printing-packages
git clone --depth=1 https://github.com/master-0123/openwrt-printing-packages package/printing-packages || \
git clone --depth=1 https://github.com/master-0123/openwrt-printing-packages package/printing-packages
sed -i 's/+libmesa//g' package/printing-packages/cairo/Makefile 2>/dev/null
echo "✅ 打印包克隆完成"

# ---------- 4. 兜底禁用循环依赖（先删后加，确保生效） ----------
sed -i '/CONFIG_PACKAGE_luci-app-fchomo/d' .config
sed -i '/CONFIG_PACKAGE_nikki/d' .config
sed -i '/CONFIG_PACKAGE_mihomo/d' .config
echo "CONFIG_PACKAGE_luci-app-fchomo=n" >> .config
echo "CONFIG_PACKAGE_nikki=n" >> .config
echo "CONFIG_PACKAGE_mihomo=n" >> .config

# ---------- 5. 创建自启动目录 ----------
mkdir -p files/etc/init.d files/etc/rc.d

# ---------- 6. 服务自启动脚本 ----------
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

# ---------- 7. 自动共享脚本 ----------
cat > files/etc/init.d/auto-share-init << 'EOF'
#!/bin/sh /etc/rc.common
START=98
boot() { sleep 15; start; }

start() {
    echo "开始自动探测可用存储空间..."

    root_dev="$(df -k / | awk 'NR==2{print $1}')"
    BEST_PART=""
    BEST_FREE=0
    TOTAL_KB=0
    IS_SYSTEM_PART=0

    for part in /mnt/*; do
        if mountpoint -q "$part" 2>/dev/null; then
            dev=$(df -k "$part" | awk 'NR==2{print $1}')
            total_kb=$(df -k "$part" | awk 'NR==2{print $2}')
            free_kb=$(df -k "$part" | awk 'NR==2{print $4}')
            if [ "$dev" != "$root_dev" ] && [ "$free_kb" -gt "$BEST_FREE" ]; then
                BEST_FREE=$free_kb
                TOTAL_KB=$total_kb
                BEST_PART=$part
                IS_SYSTEM_PART=0
            fi
        fi
    done

    if [ -z "$BEST_PART" ]; then
        for part in /overlay /; do
            if mountpoint -q "$part" 2>/dev/null; then
                free_kb=$(df -k "$part" | awk 'NR==2{print $4}')
                if [ "$free_kb" -gt "$BEST_FREE" ]; then
                    BEST_FREE=$free_kb
                    TOTAL_KB=$(df -k "$part" | awk 'NR==2{print $2}')
                    BEST_PART=$part
                    IS_SYSTEM_PART=1
                fi
            fi
        done
    fi

    if [ -z "$BEST_PART" ]; then
        echo "未找到可用存储分区，跳过共享配置。"
        return 0
    fi

    SHARE_DIR="$BEST_PART/OpenWrt_Share"
    mkdir -p "$SHARE_DIR"
    chmod 0777 "$SHARE_DIR"

    free_kb=$(df -k "$BEST_PART" | awk 'NR==2{print $4}')
    use_kb=$((free_kb * 60 / 100))
    echo "$use_kb" > "$SHARE_DIR/.size_limit_kb"

    while uci delete ksmbd.@share[0] 2>/dev/null; do :; done
    uci add ksmbd share
    uci set ksmbd.@share[-1].name='Auto_Share'
    uci set ksmbd.@share[-1].path="$SHARE_DIR"
    uci set ksmbd.@share[-1].browseable='yes'
    uci set ksmbd.@share[-1].read_only='no'
    uci set ksmbd.@share[-1].guest_ok='yes'
    uci set ksmbd.@share[-1].force_directory_mode='0777'
    uci set ksmbd.@share[-1].force_create_mode='0666'
    uci commit ksmbd
    /etc/init.d/ksmbd restart

    TOTAL_MB=$((TOTAL_KB / 1024))
    SHARE_MB=$((use_kb / 1024))
    echo "自动共享配置完成！" > "$SHARE_DIR/README.txt"
    echo "分区：$BEST_PART (总容量约 ${TOTAL_MB}MB)" >> "$SHARE_DIR/README.txt"
    if [ "$IS_SYSTEM_PART" -eq 0 ]; then
        echo "类型：外部存储" >> "$SHARE_DIR/README.txt"
    else
        echo "类型：系统分区（未检测到外部存储，降级使用）" >> "$SHARE_DIR/README.txt"
    fi
    echo "共享空间上限(60%剩余空间)：${SHARE_MB}MB" >> "$SHARE_DIR/README.txt"
    echo "此目录为自动共享目录，可自由读写。" >> "$SHARE_DIR/README.txt"

    echo "自动共享初始化完成：$SHARE_DIR (总容量: ${TOTAL_MB}MB, 共享上限: ${SHARE_MB}MB)"
}

stop() {
    echo "auto-share-init stopped."
}
EOF
chmod +x files/etc/init.d/auto-share-init
ln -sf ../init.d/auto-share-init files/etc/rc.d/S98auto-share-init

# ---------- 修复 default-settings 强制依赖 luci-compat ----------
DEFAULT_SETTINGS_MAKEFILE="package/lean/default-settings/Makefile"
if [ -f "$DEFAULT_SETTINGS_MAKEFILE" ]; then
  sed -i 's/+luci-compat//g' "$DEFAULT_SETTINGS_MAKEFILE"
  echo "✅ 已移除 default-settings 对 luci-compat 的依赖"
fi

echo "✅ diy-part2.sh 执行完成"
