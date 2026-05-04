#!/bin/bash

# ==========================================
# 终极防翻车：清理旧源 + 按优先级添加新源
# ==========================================

# 1. 暴力清理所有可能冲突的旧源
sed -i '/^$/d' feeds.conf.default
sed -i '/printing/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
sed -i '/kenzo/d' feeds.conf.default
sed -i '/master0123/d' feeds.conf.default
echo "" >> feeds.conf.default

# 2. 按「依赖优先级」顺序添加源 (🔴 顺序很重要)
#    第一层：small (SSR-Plus 的底层依赖库，如 Xray)
echo 'src-git small https://github.com/kenzok8/small' >> feeds.conf.default
#    第二层：你指定的 master-0123 (最新 CUPS)
echo 'src-git printing-packages https://gitee.com/master0123/openwrt-printing-packages.git;master' >> feeds.conf.default
#    第三层：fw876 (SSR-Plus 主界面)
echo 'src-git helloworld https://github.com/fw876/helloworld' >> feeds.conf.default

echo "✅ diy-part1.sh 执行完成，Feeds 源已按防冲突顺序配置！"
