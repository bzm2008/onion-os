#!/bin/bash
set -e

cd /tmp

# 安装 QQ
echo "下载 QQ..."
if wget -q --show-progress -O qq.deb "https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.12_amd64_01.deb"; then
    echo "安装 QQ..."
    apt install -y ./qq.deb || apt install -y -f
    rm -f qq.deb
    echo "QQ 安装成功"
else
    echo "[WARN] QQ 下载失败"
fi

# 安装 Listen1
echo "下载 Listen1..."
if wget -q --show-progress -O listen1.deb "https://github.com/listen1/listen1_desktop/releases/download/v2.31.0/listen1_2.31.0_linux_amd64.deb"; then
    echo "安装 Listen1..."
    apt install -y ./listen1.deb || apt install -y -f
    rm -f listen1.deb
    echo "Listen1 安装成功"
else
    echo "[WARN] Listen1 下载失败"
fi

# 创建桌面快捷方式
if [[ -f /usr/share/applications/qq.desktop ]]; then
    mkdir -p /home/onion/Desktop
    cp /usr/share/applications/qq.desktop /home/onion/Desktop/
    chown onion:onion /home/onion/Desktop/qq.desktop
    chmod +x /home/onion/Desktop/qq.desktop
fi

if [[ -f /usr/share/applications/listen1.desktop ]]; then
    mkdir -p /home/onion/Desktop
    cp /usr/share/applications/listen1.desktop /home/onion/Desktop/
    chown onion:onion /home/onion/Desktop/listen1.desktop
    chmod +x /home/onion/Desktop/listen1.desktop
fi

echo "安装完成！"
