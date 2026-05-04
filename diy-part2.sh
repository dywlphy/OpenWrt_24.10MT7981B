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

# 6. 自动识别最大空闲非系统分区 + 占用剩余空间60%做共享（最佳融合版）
cat > files/etc/init.d/auto-share-init << 'EOF'
#!/bin/sh /etc/rc.common
START=98
boot() { sleep 15; start; }

start() {
    echo "开始自动探测可用存储空间..."

    # 先获取系统根分区的设备名，用于排除系统盘
    root_dev="$(df -k / | awk 'NR==2{print $1}')"
    BEST_PART=""
    BEST_FREE=0
    TOTAL_KB=0
    IS_SYSTEM_PART=0

    # 第一步：遍历所有 /mnt 下的挂载点，优先找【非系统盘】
    for part in /mnt/*; do
        if mountpoint -q "$part" 2>/dev/null; then
            dev=$(df -k "$part" | awk 'NR==2{print $1}')
            total_kb=$(df -k "$part" | awk 'NR==2{print $2}')
            free_kb=$(df -k "$part" | awk 'NR==2{print $4}')
            
            # 只选择【不是系统分区】的外接磁盘
            if [ "$dev" != "$root_dev" ] && [ "$free_kb" -gt "$BEST_FREE" ]; then
                BEST_FREE=$free_kb
                TOTAL_KB=$total_kb
                BEST_PART=$part
                IS_SYSTEM_PART=0
            fi
        fi
    done

    # 第二步：如果没找到外接盘 → 降级使用系统分区（/overlay 或 /）
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

    # 如果任何分区都找不到，退出
    if [ -z "$BEST_PART" ]; then
        echo "未找到可用存储分区，跳过共享配置。"
        return 0
    fi

    # 计算共享目录路径
    SHARE_DIR="$BEST_PART/OpenWrt_Share"
    mkdir -p "$SHARE_DIR"
    chmod 0777 "$SHARE_DIR"

    # 核心：只使用 60% 剩余空间（不写满盘）
    free_kb=$(df -k "$BEST_PART" | awk 'NR==2{print $4}')
    use_kb=$((free_kb * 60 / 100))

    # 创建一个控制文件，标记建议最大使用空间
    echo "$use_kb" > "$SHARE_DIR/.size_limit_kb"

    # 清空旧共享，添加新共享
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

    # 写入 README 说明文件
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
    echo "注意：实际可用空间以磁盘剩余空间为准，建议不超过上述上限。" >> "$SHARE_DIR/README.txt"

    echo "自动共享初始化完成：$SHARE_DIR (总容量: ${TOTAL_MB}MB, 共享上限: ${SHARE_MB}MB)"
}

stop() {
    echo "auto-share-init stopped."
}
EOF
chmod +x files/etc/init.d/auto-share-init
ln -sf ../init.d/auto-share-init files/etc/rc.d/S98auto-share-init

echo "✅ diy-part2.sh 执行完成：无覆盖配置、所有功能已部署"
