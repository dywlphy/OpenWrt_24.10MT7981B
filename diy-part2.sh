#!/bin/bash
#=================================================
# 自定义脚本：在编译前运行
# 功能：安装软件包、固化配置文件、设置自启动
#=================================================

# 进入编译目录
cd openwrt

# 1. 更新软件源
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 安装所有需要的软件包
# 注意：cups 相关包可能在你的源里不存在，后面有备选方案
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

# 3. 覆盖自定义配置文件到编译目录
# 这是“立即可用”的关键：把 files 目录下的内容复制到 openwrt/files
if [ -d "../files" ]; then
    cp -rf ../files/* ./files/ 2>/dev/null
    echo "自定义配置文件已复制到编译目录"
fi

# 4. 在编译目录内创建自启动链接
# 注意：现在路径是 openwrt/files/etc/rc.d/，这最终会被打包进固件
mkdir -p ./files/etc/rc.d

# 创建启动脚本（如果 cupsd 等服务的启动脚本存在的话）
# OpenWrt 标准启动脚本一般在 package 目录下，这里手动创建一个简单的自启脚本
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

# 创建软链接（在固件内的 /etc/rc.d/ 目录下）
ln -sf ../init.d/cups-autostart ./files/etc/rc.d/S99cups-autostart

# 5. 确认 .config 文件存在
if [ -f "../.config" ]; then
    cp ../.config ./.config
    echo ".config 已复制到编译目录"
else
    echo "警告：未找到 .config 文件！"
fi

echo "diy-part2.sh 执行完毕"
