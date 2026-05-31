#!/bin/bash
#
# diy-part2.sh - 自定义配置
# OpenWrt 24.10 for XR30 (MT7981B)
#

echo "=========================================="
echo "diy-part2.sh - 自定义配置"
echo "=========================================="

# 设置主机名（先还原再替换，避免重复拼接）
echo "[1/8] 设置主机名..."
CONFIG_FILE="package/base-files/files/bin/config_generate"
if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/ImmortalWrt/OpenWrt/g' "$CONFIG_FILE"
    sed -i 's/OpenWrt-24\.10-[0-9.]*/OpenWrt/g' "$CONFIG_FILE"
    sed -i 's/OpenWrt-24\.10/OpenWrt/g' "$CONFIG_FILE"
    sed -i 's/OpenWrt/OpenWrt-24.10/g' "$CONFIG_FILE"
else
    echo " 警告：$CONFIG_FILE 不存在，跳过主机名设置"
fi
echo " 主机名: OpenWrt-24.10"

# 设置时区
echo "[2/8] 设置时区..."
if [ -f "$CONFIG_FILE" ]; then
    sed -i "s/'UTC'/'CST-8'/g" "$CONFIG_FILE"
    sed -i '/set system.@system[-1].zonename/d' "$CONFIG_FILE"
    sed -i "/'CST-8'/a \\\t\\\tset system.@system[-1].zonename='Asia/Shanghai'" "$CONFIG_FILE"
else
    echo " 警告：$CONFIG_FILE 不存在，跳过时区设置"
fi
echo " 时区: Asia/Shanghai (CST-8)"

# 设置默认主题（bootstrap是默认主题，无需修改）
echo "[3/8] 设置默认主题..."
echo " 主题: Bootstrap（默认）"

# 创建uci-defaults脚本
echo "[4/8] 创建启动脚本..."
mkdir -p package/base-files/files/etc/uci-defaults

# opkg镜像源 + 开启流量卸载（flow offload）
cat > package/base-files/files/etc/uci-defaults/96-opkg-mirror << 'EOF'
#!/bin/sh
# 使用官方源（snapshot版本只能用官方源）
if [ -f /etc/opkg/distfeeds.conf ]; then
    # 恢复官方源
    sed -i 's|https://mirrors.aliyun.com/openwrt|https://downloads.openwrt.org|g' /etc/opkg/distfeeds.conf
    sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/openwrt|https://downloads.openwrt.org|g' /etc/opkg/distfeeds.conf
fi
# 开启硬件流量卸载
uci set firewall.@defaults[0].flow_offloading='1'
uci commit firewall
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/96-opkg-mirror

# timecontrol菜单路径修复 + rpcd重启（解决ubus code 6权限错误）
cat > package/base-files/files/etc/uci-defaults/97-timecontrol-menu << 'EOF'
#!/bin/sh
TC_MENU="/usr/share/luci/menu.d/luci-app-timecontrol.json"
if [ -f "$TC_MENU" ]; then
    sed -i 's|"admin/control/|"admin/network/|g' "$TC_MENU"
fi
/etc/init.d/rpcd restart
sleep 1
rm -f /tmp/luci-indexcache /tmp/luci-* 2>/dev/null
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/97-timecontrol-menu

# 修复 LuCI 权限和服务启动问题 + 预热缓存（解决首次登录转圈）
cat > package/base-files/files/etc/uci-defaults/98-luci-fix << 'EOF'
#!/bin/sh
chmod 755 /www/cgi-bin/luci
if [ -f /etc/config/uhttpd ]; then
    sed -i 's/option rfc1918_filter 1/option rfc1918_filter 0/g' /etc/config/uhttpd
fi
/etc/init.d/uhttpd enable
/etc/init.d/rpcd enable
# 等待 rpcd 完全启动
sleep 2
# 预热 LuCI 缓存，避免首次登录转圈（多种方式兼容）
# 方法1: 使用 build_index.lua（OpenWrt 24.10）
if [ -f /usr/share/luci/build_index.lua ]; then
    lua /usr/share/luci/build_index.lua 2>/dev/null || true
fi
# 方法2: 使用 luci-index-cache（旧版本）
if [ -x /usr/libexec/luci-index-cache ]; then
    /usr/libexec/luci-index-cache 2>/dev/null || true
fi
# 方法3: 直接访问 LuCI 触发缓存生成
curl -s http://127.0.0.1/cgi-bin/luci > /dev/null 2>&1 || true
# 标记缓存有效
touch /tmp/.luci-cache-valid 2>/dev/null || true
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-luci-fix

# 预设root密码（首次登录后请立即修改）
cat > package/base-files/files/etc/uci-defaults/99-set-password << 'EOF'
#!/bin/sh
echo -e "admin\nadmin" | passwd root
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-set-password

# 禁用不需要默认启动的服务（按需手动开启）
cat > package/base-files/files/etc/uci-defaults/100-disable-services << 'EOF'
#!/bin/sh
# 代理相关（与 OpenClash 功能重叠或冲突）
/etc/init.d/https-dns-proxy disable  2>/dev/null
/etc/init.d/nikki disable           2>/dev/null
/etc/init.d/openclash disable       2>/dev/null

# VPN 相关（按需启用）
/etc/init.d/tailscale disable       2>/dev/null
/etc/init.d/tailscale-settings disable  2>/dev/null
/etc/init.d/pbr disable             2>/dev/null

# 网络工具（按需启用）
/etc/init.d/miniupnpd disable       2>/dev/null
/etc/init.d/socat disable           2>/dev/null
/etc/init.d/sqm disable             2>/dev/null
/etc/init.d/watchcat disable        2>/dev/null
/etc/init.d/etherwake disable       2>/dev/null

# 文件共享（按需启用）
/etc/init.d/ksmbd disable           2>/dev/null
/etc/init.d/wsdd2 disable           2>/dev/null

# SSL证书（按需启用）
/etc/init.d/acme disable            2>/dev/null

# 监控统计（按需启用，占用资源）
/etc/init.d/collectd disable        2>/dev/null
/etc/init.d/luci_statistics disable 2>/dev/null
/etc/init.d/nlbwmon disable         2>/dev/null

# 时间同步（已有 sysntpd）
/etc/init.d/chronyd disable         2>/dev/null

# 其他（已在前面禁用）
/etc/init.d/ddns disable            2>/dev/null
/etc/init.d/adblock disable         2>/dev/null
/etc/init.d/frpc disable            2>/dev/null
/etc/init.d/frps disable            2>/dev/null
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/100-disable-services

echo " uci-defaults已创建"

# 自定义banner
echo "[5/8] 自定义banner..."
cat > package/base-files/files/etc/banner << 'EOF'
  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt 24.10 XR30 Cloud Build
 -----------------------------------------------------
EOF

# 修复 missing-macros 缺少 bin 目录的问题（tmpfs重启后必现）
echo "[6/8] 修复 missing-macros..."
mkdir -p tools/missing-macros/src/bin
touch tools/missing-macros/src/bin/.placeholder

# 拉取 OpenClash（git_sparse_clone 是 Makefile 函数，只能用普通 git）
echo "[7/8] 拉取 OpenClash..."
if [ ! -d "package/luci-app-openclash" ]; then
    git clone --depth 1 --filter=blob:none --sparse https://github.com/kenzok8/small-package.git openclash-tmp
    cd openclash-tmp
    git sparse-checkout set luci-app-openclash
    cd ..
    mv openclash-tmp/luci-app-openclash package/
    rm -rf openclash-tmp
    echo " OpenClash 已拉取"
else
    echo " OpenClash 已存在，跳过"
fi

# 预下载 OpenClash 核心（解决国内无法下载问题）
echo "[8/8] 预下载 OpenClash 核心..."
CORE_FILE="clash-linux-armv8.tar.gz"
CORE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-armv8.tar.gz"
# 核心放到 base-files 才能打包进固件
CORE_DEST="package/base-files/files/etc/openclash/core"
if [ -d "package/luci-app-openclash" ]; then
    mkdir -p $CORE_DEST
    # 先检查 dl 目录是否已有核心文件
    if [ -f "dl/$CORE_FILE" ] && [ -s "dl/$CORE_FILE" ]; then
        echo " 从 dl 目录复用核心"
        cp "dl/$CORE_FILE" /tmp/
    else
        # dl 目录没有，从网络下载
        echo " 从网络下载核心..."
        curl -sL -o /tmp/$CORE_FILE "$CORE_URL"
        # 下载成功后保存到 dl 目录
        if [ -f "/tmp/$CORE_FILE" ] && [ -s "/tmp/$CORE_FILE" ]; then
            cp /tmp/$CORE_FILE dl/
            echo " 核心已缓存到 dl 目录"
        fi
    fi
    # 解压安装到 base-files
    if [ -f "/tmp/$CORE_FILE" ] && [ -s "/tmp/$CORE_FILE" ]; then
        tar -xzf /tmp/$CORE_FILE -C $CORE_DEST/
        mv $CORE_DEST/clash* $CORE_DEST/clash_meta 2>/dev/null || true
        chmod 755 $CORE_DEST/clash_meta 2>/dev/null || true
        echo " OpenClash 核心已预置到 base-files"
        rm -f /tmp/$CORE_FILE
    else
        echo " 警告：核心下载失败，需手动下载"
    fi
else
    echo " 警告：OpenClash 包不存在，跳过核心下载"
fi

echo "=========================================="
echo "diy-part2.sh 完成"
echo "=========================================="
