#!/bin/bash

# ==========================================
# 云编译专用：彻底移除small源 只保留helloworld
# 根治 fchomo/nikki 循环依赖 保留SSR-Plus可用
# ==========================================

# 恢复Lean官方默认feeds配置
git checkout -- feeds.conf.default

# 清理原有旧的small、helloworld行
sed -i '/small/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default

# 只添加 helloworld 源，坚决不加冲突的small源
echo "" >> feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default

# 打印确认
echo "✅ feeds配置完成：已禁用small源，仅保留helloworld"
cat feeds.conf.default
