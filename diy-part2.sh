#!/bin/bash
#=================================================
# 自定义脚本：在编译前运行 (Part 2)
# 适配最终全功能固件：路由基础 + CUPS(Gutenprint) + ksmbd + SSR-Plus
# 新增：自动探测硬盘剩余空间，提示60%作为共享上限
#=================================================

# 0. 确认当前位于 openwrt 目录
echo "当前目录: $(pwd)"
if [ ! -f "feeds.conf.default" ] && [ ! -f "Makefile" ]; then
    echo "警告：当前似乎不在 openwrt 源码根目录！"
fi

# 1. 更新软件源
./scripts/feeds update -a
./scripts/feeds install -a

# 彻底移除导致编译失败的硬件监控驱动源码
echo "正在移除冲突的硬件监控驱动..."
rm -rf package/kernel/linux/modules/hwmon.mk
find package/kernel/linux/modules/ -type f -name "*hwmon*" -exec rm -f {} \;
echo "硬件监控驱动已移除。"

# 1.5 使用方法2直接克隆打印软件包源码
# ========== 正确集成新打印源 (方法3) ==========
echo "正在使用官方 feeds 方式集成最新打印软件包..."

# 1. 添加本地源指向到 feeds 配置文件
echo "src-link printing_packages $(pwd)/package/printing-packages" >> feeds.conf.default

# 2. 克隆最新打印源码
rm -rf package/printing-packages
git clone --depth=1 https://github.com/master-0123/openwrt-printing-packages package/printing-packages

# 3. 刷新 feeds 并安装这些新包
./scripts/feeds update printing_packages
./scripts/feeds install -a -p printing_packages

# 2. 安装所有核心软件包
# 路由器基础 (IPv6, UPnP, DDNS, SSH)
./scripts/feeds install dnsmasq-full || true
./scripts/feeds install ip6tables || true
./scripts/feeds install odhcp6c || true
./scripts/feeds install odhcpd || true
./scripts/feeds install luci-proto-ipv6 || true
./scripts/feeds install miniupnpd || true
./scripts/feeds install luci-app-upnp || true
./scripts/feeds install ddns-scripts || true
./scripts/feeds install luci-app-ddns || true
./scripts/feeds install openssh-sftp-server || true

# CUPS 打印服务 (含Gutenprint全驱动)
./scripts/feeds install cups || true
./scripts/feeds install cups-filters || true
./scripts/feeds install cups-bjnp || true
./scripts/feeds install libusb-1.0 || true
./scripts/feeds install foomatic-db || true
./scripts/feeds install foomatic-db-engine || true
./scripts/feeds install gutenprint || true

# Avahi 自动发现
./scripts/feeds install avahi-daemon || true
./scripts/feeds install avahi-utils || true
./scripts/feeds install dbus || true

# ksmbd 文件共享（轻量替代）
./scripts/feeds install luci-app-ksmbd || true
./scripts/feeds install ksmbd-server || true

# 科学上网（仅SSR-Plus）
./scripts/feeds install luci-app-ssr-plus || true

# 3. 覆盖自定义配置文件
# 工作流已将仓库内的 files 目录移动到 openwrt/files，我们只需确认并补充
if [ ! -d "./files" ]; then
    mkdir -p ./files
fi
echo "自定义配置文件目录 ./files 已就绪"

# 4. 创建自启动配置，确保服务开机运行
mkdir -p ./files/etc/rc.d
mkdir -p ./files/etc/init.d

cat > ./files/etc/init.d/cups-autostart << 'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() {
    start
}
start() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd start
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon start
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd start
    [ -x /etc/init.d/miniupnpd ] && /etc/init.d/miniupnpd start
    [ -x /etc/init.d/ddns ] && /etc/init.d/ddns start
}
stop() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd stop
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon stop
    [ -x /etc/init.d/ksmbd ] && /etc/init.d/ksmbd stop
    [ -x /etc/init.d/miniupnpd ] && /etc/init.d/miniupnpd stop
    [ -x /etc/init.d/ddns ] && /etc/init.d/ddns stop
}
EOF

chmod +x ./files/etc/init.d/cups-autostart
ln -sf ../init.d/cups-autostart ./files/etc/rc.d/S99cups-autostart

# 5. 创建自动探测并配置共享的初始化脚本
cat > ./files/etc/init.d/auto-share-init << 'EOF'
#!/bin/sh /etc/rc.common
START=98

boot() {
    sleep 10   # 等待硬盘挂载完成
    start
}

start() {
    echo "开始自动探测可用存储空间..."

    # 查找最大的可用分区（排除系统分区）
    BEST_PART=""
    BEST_FREE=0
    TOTAL_KB=0

    for part in $(ls -d /mnt/* 2>/dev/null); do
        if mountpoint -q "$part" 2>/dev/null; then
            # 获取该分区总空间和可用空间（单位：KB）
            total_kb=$(df -k "$part" | tail -1 | awk '{print $2}')
            free_kb=$(df -k "$part" | tail -1 | awk '{print $4}')
            if [ "$free_kb" -gt "$BEST_FREE" ]; then
                BEST_FREE=$free_kb
                TOTAL_KB=$total_kb
                BEST_PART=$part
            fi
        fi
    done

    if [ -z "$BEST_PART" ]; then
        echo "未找到可用存储分区，跳过共享配置。"
        return 0
    fi

    SHARE_DIR="${BEST_PART}/OpenWrt_Share"

    # 创建共享目录
    mkdir -p "$SHARE_DIR"
    chmod 0777 "$SHARE_DIR"

    # 更新 ksmbd 配置
    uci set ksmbd.@ksmbd[0]=ksmbd 2>/dev/null || uci add ksmbd ksmbd
    uci set ksmbd.@ksmbd[0].enabled='1'
    uci set ksmbd.@ksmbd[0].interface='lan'
    
    # 删除旧共享配置，添加新的
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

    # 重启 ksmbd 服务应用新配置
    /etc/init.d/ksmbd restart

    # 计算并写入共享空间说明（提示60%为建议上限）
    TOTAL_MB=$((TOTAL_KB / 1024))
    SHARE_MB=$((BEST_FREE * 60 / 100 / 1024))
    echo "自动共享配置完成！" > "$SHARE_DIR/README.txt"
    echo "分区：$BEST_PART (总容量约 ${TOTAL_MB}MB)" >> "$SHARE_DIR/README.txt"
    echo "建议共享用量(60%)：${SHARE_MB}MB" >> "$SHARE_DIR/README.txt"
    echo "此目录为自动共享目录，可自由读写。" >> "$SHARE_DIR/README.txt"
    echo "注意：请不要存放超过${SHARE_MB}MB的文件，以免分区空间不足。" >> "$SHARE_DIR/README.txt"

    echo "自动共享初始化完成：$SHARE_DIR (总容量: ${TOTAL_MB}MB, 建议共享用量: ${SHARE_MB}MB)"
}

stop() {
    echo "auto-share-init stopped."
}
EOF

chmod +x ./files/etc/init.d/auto-share-init
ln -sf ../init.d/auto-share-init ./files/etc/rc.d/S98auto-share-init

echo "所有服务和自启动配置已准备就绪。"
