#!/bin/bash
#=================================================
# 自定义脚本：在编译前运行
# 功能：安装软件包、固化配置文件、设置自启动
#=================================================

# 0. 确认当前位于 openwrt 目录
echo "当前目录: $(pwd)"
if [ ! -f "feeds.conf.default" ] && [ ! -f "Makefile" ]; then
    echo "警告：当前似乎不在 openwrt 源码根目录！"
fi

# 1. 更新软件源
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 安装所有需要的软件包
# 使用 || echo 确保即使找不到包，脚本也不会中断
./scripts/feeds install cups 2>/dev/null || echo "cups 未在官方源找到，将尝试第三方源"
./scripts/feeds install cups-filters 2>/dev/null || echo "cups-filters 未在官方源找到"
./scripts/feeds install cups-bjnp 2>/dev/null || echo "cups-bjnp 未在官方源找到"
./scripts/feeds install gutenprint 2>/dev/null || echo "gutenprint 未在官方源找到，固件体积会较小"
./scripts/feeds install foomatic-db 2>/dev/null || echo "foomatic-db 未在官方源找到"
./scripts/feeds install foomatic-db-engine 2>/dev/null || echo "foomatic-db-engine 未在官方源找到"
./scripts/feeds install avahi-daemon 2>/dev/null || echo "avahi-daemon 未在官方源找到"
./scripts/feeds install avahi-utils 2>/dev/null || echo "avahi-utils 未在官方源找到"
./scripts/feeds install luci-app-samba4 2>/dev/null || echo "luci-app-samba4 未在官方源找到"
./scripts/feeds install samba4-server 2>/dev/null || echo "samba4-server 未在官方源找到"
./scripts/feeds install samba4-hotplug 2>/dev/null || echo "samba4-hotplug 未在官方源找到"
./scripts/feeds install luci-i18n-base-zh-cn 2>/dev/null || echo "luci-i18n-base-zh-cn 未在官方源找到"
./scripts/feeds install kmod-usb-printer 2>/dev/null || echo "kmod-usb-printer 未在官方源找到"
./scripts/feeds install kmod-fs-ext4 2>/dev/null || echo "kmod-fs-ext4 未在官方源找到"
./scripts/feeds install kmod-fs-ntfs 2>/dev/null || echo "kmod-fs-ntfs 未在官方源找到"
./scripts/feeds install block-mount 2>/dev/null || echo "block-mount 未在官方源找到"

# 3. 覆盖自定义配置文件
# 工作流已将仓库内的 files 目录移动到 openwrt/files，我们只需确认并补充
if [ ! -d "./files" ]; then
    mkdir -p ./files
fi
echo "自定义配置文件目录 ./files 已就绪"

# 4. 在预置文件目录中创建自启动配置
mkdir -p ./files/etc/rc.d
mkdir -p ./files/etc/init.d

# 创建统一的自启动脚本
cat > ./files/etc/init.d/cups-autostart << 'EOF'
#!/bin/sh /etc/rc.common
START=99
boot() {
    start
}
start() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd start
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon start
    [ -x /etc/init.d/samba4 ] && /etc/init.d/samba4 start
}
stop() {
    [ -x /etc/init.d/cupsd ] && /etc/init.d/cupsd stop
    [ -x /etc/init.d/avahi-daemon ] && /etc/init.d/avahi-daemon stop
    [ -x /etc/init.d/samba4 ] && /etc/init.d/samba4 stop
}
EOF

chmod +x ./files/etc/init.d/cups-autostart
# 创建软链接，指向我们刚创建的脚本
ln -sf ../init.d/cups-autostart ./files/etc/rc.d/S99cups-autostart

echo "自启动脚本 cups-autostart 已创建并设置开机启动"

# 5. 确认 .config 文件
if [ -f ".config" ]; then
    echo ".config 文件已在编译目录中"
else
    echo "警告：当前目录下未找到 .config 文件！编译可能失败。"
fi

echo "diy-part2.sh 执行完毕"
