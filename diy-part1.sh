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

# 添加包含 CUPS 等打印包的第三方源
echo 'src-git cupspackages https://github.com/Gr4ffy/lede-cups.git' >> feeds.conf.default

# 添加包含 PassWall 科学上网插件的源
echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >> feeds.conf.default
