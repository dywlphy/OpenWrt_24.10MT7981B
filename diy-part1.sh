#!/bin/bash

# ==========================================
# 简化版：只留 SSR-Plus 依赖源，打印源用方法2手动 clone
# ==========================================

# 恢复 Lean 官方默认源
git checkout -- feeds.conf.default

# 清理并添加 SSR-Plus 必需的源
sed -i '/small/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default

# 只添加这两个源，打印源不用加了
echo "" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
echo "src-git helloworld https://github.com/fw876/helloworld" >> feeds.conf.default

# 打印确认
echo "✅ feeds.conf.default 已简化，内容如下："
cat feeds.conf.default
