#!/bin/bash

# ==========================================
# feeds 源配置：只保留 helloworld
# ==========================================

# 恢复默认 feeds 配置
git checkout -- feeds.conf.default

# 清理已有源
sed -i '/small/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default

# 只添加 helloworld 源
echo "" >> feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default

echo "✅ feeds配置完成：仅保留 helloworld 源"
cat feeds.conf.default
