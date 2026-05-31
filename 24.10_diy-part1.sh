#!/bin/bash

echo "=========================================="
echo "diy-part1.sh - feeds配置"
echo "=========================================="

# 1. 写入 feeds.conf
cat > feeds.conf << 'EOF'
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
src-git routing https://github.com/openwrt/routing.git;openwrt-24.10
src-git telephony https://github.com/openwrt/telephony.git;openwrt-24.10
src-git timecontrol https://github.com/sirpdboy/luci-app-timecontrol.git
src-git frp https://github.com/kuoruan/luci-app-frpc.git
src-git tailscale https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community.git
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
EOF

echo "feeds配置完成："
cat feeds.conf
echo ""
echo "=========================================="
