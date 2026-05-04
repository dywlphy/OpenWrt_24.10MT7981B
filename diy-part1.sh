#!/bin/bash

# ==========================================
# 严格按照 master-0123 官方 README 方法1
# 零注释，零错误
# ==========================================

cat > feeds.conf.default << 'EOF'
src-git printing-packages https://gitee.com/master0123/openwrt-printing-packages.git;master
src-git small https://github.com/kenzok8/small
src-git helloworld https://github.com/fw876/helloworld
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci
src-git routing https://github.com/coolsnowwolf/routing
src-git telephony https://git.openwrt.org/feed/telephony.git
EOF

# 打印确认
echo "✅ 最终 feeds.conf.default 内容："
cat feeds.conf.default
