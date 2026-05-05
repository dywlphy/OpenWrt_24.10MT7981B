#!/bin/bash

# ==========================================
# feeds 源配置：只保留 packages/luci/routing/helloworld
# ==========================================

# 恢复默认 feeds 配置
git checkout -- feeds.conf.default

# 删除不需要的源：small、helloworld、telephony
sed -i '/small/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default
sed -i '/telephony/d' feeds.conf.default

# 添加 helloworld 源
echo "" >> feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default

echo "✅ feeds配置完成：packages luci routing helloworld"
cat feeds.conf.default
