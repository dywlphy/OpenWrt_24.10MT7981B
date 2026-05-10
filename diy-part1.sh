#!/bin/bash
echo "===== 配置 feeds 源 ====="
> feeds.conf
# 官方源
echo "src-git packages https://github.com/openwrt/packages.git;openwrt-24.10" >> feeds.conf
echo "src-git luci https://github.com/openwrt/luci.git;openwrt-24.10" >> feeds.conf
# 第三方源（只加必要的）- 使用自己的 fork
echo "src-git smpackage https://github.com/dywlphy/small-package" >> feeds.conf
echo "src-git cups https://github.com/op4packages/openwrt-cups.git" >> feeds.conf
echo "src-git brlaser https://github.com/pdewacht/brlaser.git" >> feeds.conf
echo "✅ feeds.conf 配置完成（5个源）"
