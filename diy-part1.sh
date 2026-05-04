#!/bin/bash

# ==========================================
# 终极暴力覆盖法：直接生成 100% 语法正确的文件
# ==========================================

# 🔴 核心：直接生成一个全新的文件，包含 Lean 官方默认源 + 我们的第三方源
# 注意：这里的前4行是 Lean 大 lede 源码的标准默认源，绝对不会错
cat > feeds.conf.default << 'EOF'
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci
src-git routing https://github.com/coolsnowwolf/routing
src-git telephony https://git.openwrt.org/feed/telephony.git

# 自定义第三方源
src-git small https://github.com/kenzok8/small
src-git printing-packages https://gitee.com/master0123/openwrt-printing-packages.git;master
src-git helloworld https://github.com/fw876/helloworld
EOF

# 打印出来确认（会在 Actions 日志里显示）
echo "✅ 生成的 feeds.conf.default 内容如下（请检查）："
echo "--------------------------------------------------"
cat feeds.conf.default
echo "--------------------------------------------------"
echo "✅ diy-part1.sh 执行完成！"
