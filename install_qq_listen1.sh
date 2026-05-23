#!/bin/bash
set -e

cd /home/user/onion-os

# 设置环境变量
export ONION_USER="onion"
export DEBIAN_FRONTEND=noninteractive

# 执行模块 05
echo "开始安装 QQ 和 Listen1..."
chroot chroot /usr/bin/env \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    HOME="/root" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin" \
    TERM="linux" \
    ONION_USER="onion" \
    bash /tmp/onion-build/modules/05_security_tools.sh

echo "QQ 和 Listen1 安装完成！"
