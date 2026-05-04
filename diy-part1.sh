#!/bin/bash

# ==========================================
# 终极防语法错误版：直接重写 feeds.conf.default
# ==========================================

# 🔴 关键：直接用 cat 生成一个全新的文件，覆盖旧的，不留任何残留
cat > feeds.conf.default << 'EOF'
src-git small https://github.com/kenzok8/small
src-git printing-packages https://gitee.com/master0123/openwrt-printing-packages.git;master
src-git helloworld https://github.com/fw876/helloworld
src-git packages https://github.com/coolsnowwolf/packages
src-git luci https://github.com/coolsnowwolf/luci
src-git routing https://github.com/coolsnowwolf/routing
src-git telephony https://git.openwrt.org/feed/telephony.git
EOF

# 可选：查看生成的文件确认无误（会在 Actions 日志里打印出来）
echo "✅ 生成的 feeds.conf.default 内容如下："
cat feeds.conf.default

echo "✅ diy-part1.sh 执行完成，Feeds 源已安全配置！"
