#!/bin/bash
#=================================================
# 自定义脚本：在编译前运行
# 功能：添加软件源、更新、安装包、覆盖自定义文件
#=================================================

# 1. 添加CUPS等第三方软件源（如果官方源没有）
# 25.12稳定版可能已包含部分包，视情况添加
# echo 'src-git cups https://github.com/Gr4ffy/lede-cups.git' >> feeds.conf

# 2. 更新软件源
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 安装你需要的所有软件包 (这些是“立即可用”的核心)
# 用 ./scripts/feeds install 的方式更稳妥，确保依赖全搞定
./scripts/feeds install cups
./scripts/feeds install cups-filters
./scripts/feeds install gutenprint           # 海量打印机驱动
./scripts/feeds install foomatic-db          # 驱动数据库
./scripts/feeds install avahi-daemon         # 让设备能被自动发现
./scripts/feeds install luci-app-samba4      # Samba网络共享
./scripts/feeds install samba4-hotplug       # USB存储自动共享
./scripts/feeds install luci-i18n-base-zh-cn # 中文界面
# 根据需要添加更多...

# 4. (可选) 如果你的打印机是USB的，确保内核模块被选中
# 通常 cups 依赖会自动带上 kmod-usb-printer，但可以显式确认一下
# ./scripts/feeds install kmod-usb-printer

# 5. (重要) 覆盖你本地自定义的文件，实现“立即可用”配置
# 假设你已经在仓库里创建了 files 文件夹并放好了配置
# cp -rf files/* ./  # 这会把 files 目录下的内容覆盖到编译根目录
