#!/bin/bash

# ==========================================
# 最终安全版：无make defconfig 不覆盖自定义.config
# 保留打印包克隆 + 自启动 + ksmbd自动共享全部功能
# ==========================================

# 1. 标准更新feeds索引
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 手动克隆完整CUPS打印包（方法2独立编译，不依赖feeds）
echo "正在克隆 master-0123 打印包..."
rm -rf package/printing-packages
git clone --depth=1 https://github.com/master-0123/openwrt-printing-packages package/printing-packages
echo "✅ 打印包克隆完成"

# 3. 兜底强制禁用循环依赖插件，双层保险
sed -i 's/^CONFIG_PACKAGE_luci-app-fchomo=.*/CONFIG_PACKAGE_luci-app-fchomo=n/' .config
sed -i 's/^CONFIG_PACKAGE_nikki=.*/CONFIG_PACKAGE_nikki=n/' .config

# 4. 创建自启动目录结构
mkdir -p files/etc/init.d files/etc/rc.d

# 5. 自定义服务自启动脚本
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

# 6. 自动识别最大空闲分区 自动创建ksmbd共享脚本
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

echo "✅ diy-part2.sh 执行完成：无覆盖配置、所有功能已部署"
