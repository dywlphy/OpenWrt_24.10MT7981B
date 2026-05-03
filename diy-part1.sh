#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 清理可能存在的旧源和空行，确保文件末尾有正确换行
sed -i '/^$/d' feeds.conf.default
sed -i '/printing-packages/d' feeds.conf.default
sed -i '/cupspackages/d' feeds.conf.default
echo "" >> feeds.conf.default

# 添加包含 CUPS 等打印包的第三方源（使用最新稳定源，版本 CUPS 2.4.12）
# echo 'src-git printing-packages https://gitee.com/master0123/openwrt-printing-packages.git;master' >> feeds.conf.default

# 添加包含 SSR-Plus 科学上网插件的源（如果不存在才添加）
if ! grep -q "helloworld" feeds.conf.default; then
    echo 'src-git helloworld https://github.com/fw876/helloworld' >> feeds.conf.default
fi

# 添加包含 CUPS 等打印包的第三方源
# echo 'src-git cupspackages https://github.com/Gr4ffy/lede-cups.git' >> feeds.conf.default
