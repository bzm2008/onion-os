#!/usr/bin/env bash
# ============================================================================
# Onion OS 模块 02: 应用软件安装
# ============================================================================
# 设计意图：
#   安装桌面环境核心组件、中文输入法、预装应用（WPS/微信/Firefox）、
#   应用商店（GNOME Software + Flatpak）以及中文字体。
#   所有安装均在 chroot 中以非交互模式完成。
#
# 输入：
#   环境变量: ONION_USER
#
# 输出：
#   安装完成的桌面环境与应用软件
#
# 关键步骤：
#   1. 安装 Xfce 4.18 桌面环境与 Compton 合成器
#   2. 安装 LightDM 显示管理器（自动登录）
#   3. 安装 Firefox ESR 浏览器
#   4. 安装 WPS Office（官方 deb）及字体依赖
#   5. 安装微信（deepin-wine 方案）
#   6. 安装 Fcitx5 中文输入法
#   7. 安装 GNOME Software + Flatpak（应用商店）
#   8. 安装中文字体
# ============================================================================

set -uo pipefail

# ======================== 桌面环境 ========================

install_xfce_desktop() {
    apt install -y --no-install-recommends \
        xserver-xorg \
        xserver-xorg-video-intel \
        xserver-xorg-video-amdgpu \
        xserver-xorg-video-ati \
        xserver-xorg-video-nouveau \
        xserver-xorg-input-libinput \
        xfce4 \
        xfce4-panel \
        xfce4-session \
        xfce4-settings \
        xfce4-terminal \
        xfce4-appfinder \
        xfce4-whiskermenu-plugin \
        xfce4-taskmanager \
        xfce4-notifyd \
        thunar \
        thunar-archive-plugin \
        thunar-media-tags-plugin \
        thunar-volman \
        tumbler \
        mousepad \
        ristretto \
        xdg-user-dirs \
        xdg-utils \
        desktop-base \
        xfce4-power-manager \
        xfce4-power-manager-plugins

    apt install -y --no-install-recommends \
        picom \
        plank \
        librsvg2-bin \
        librsvg2-common \
        imagemagick

    mkdir -p /etc/xdg/picom
    cat > /etc/xdg/picom/picom.conf << PICOMDEFAULT
backend = "glx";
vsync = true;
unredir-if-possible = true;

shadow = true;
shadow-radius = 8;
shadow-opacity = 0.5;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_GTK_FRAME_EXTENTS@:c",
    "name = 'xfce4-notifyd'",
    "window_type = 'dock'",
    "window_type = 'desktop'"
];

fading = true;
fade-in-step = 3.0e-2;
fade-out-step = 3.0e-2;
fade-delta = 4;

inactive-opacity = 0.92;
frame-opacity = 0.95;
inactive-opacity-override = false;

blur-background = true;
blur-background-frame = true;
blur-background-fixed = true;
blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "_GTK_FRAME_EXTENTS@:c"
];
blur-method = "dual_kawase";
blur-strength = 5;

wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.9; focus = true; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};

detect-client-leader = true;
detect-transient = true;
use-damage = true;
log-level = "warn";
xrender-sync-fence = true;
PICOMDEFAULT

    # 老旧GPU回退配置（当 GLX 不可用时自动降级到 xrender）
    mkdir -p /etc/xdg/picom-backup
    cat > /etc/xdg/picom/picom-fallback.conf << PICOMFALLBACK
backend = "xrender";
vsync = false;
unredir-if-possible = false;
shadow = false;
fading = true;
fade-in-step = 5.0e-2;
fade-out-step = 5.0e-2;
fade-delta = 4;
inactive-opacity = 0.95;
frame-opacity = 0.98;
inactive-opacity-override = false;
use-damage = true;
log-level = "warn";
detect-client-leader = true;
detect-transient = true;
PICOMFALLBACK

    # Picom 启动包装器（自动探测 GLX 可用性，回退 xrender）
    cat > /usr/local/bin/onion-picom << 'PICOMWRAP'
#!/usr/bin/env bash
CONF="${HOME}/.config/picom/picom.conf"
FALLBACK="/etc/xdg/picom/picom-fallback.conf"
PICOM_BIN=$(command -v picom 2>/dev/null || echo "picom")

HAS_GPU=0
if [ -e /dev/dri/card0 ] || [ -e /dev/dri/renderD128 ] || [ -e /dev/dri/card1 ]; then
    HAS_GPU=1
fi
if [ "$HAS_GPU" -eq 0 ] && command -v glxinfo &>/dev/null; then
    if glxinfo 2>/dev/null | grep -q "direct rendering: Yes"; then
        HAS_GPU=1
    fi
fi
if [ "$HAS_GPU" -eq 0 ]; then
    if ${PICOM_BIN} --config "${CONF}" --backend glx --no-fading-openclose 2>/dev/null &
        PICOM_PID=$!
        sleep 1
        kill "${PICOM_PID}" 2>/dev/null
        wait "${PICOM_PID}" 2>/dev/null
    then
        HAS_GPU=1
    fi
fi

if [ "$HAS_GPU" -eq 1 ]; then
    exec ${PICOM_BIN} --config "${CONF}" -b "$@"
else
    exec ${PICOM_BIN} --config "${FALLBACK}" -b "$@"
fi
PICOMWRAP
    chmod +x /usr/local/bin/onion-picom

    echo "lightdm lightdm/default-display-manager select lightdm" | debconf-set-selections
    apt install -y --no-install-recommends \
        lightdm \
        lightdm-gtk-greeter \
        plymouth \
        plymouth-themes

    mkdir -p /etc/plymouth
    echo -e "[Daemon]\nTheme=onion-os\nShowDelay=0" > /etc/plymouth/plymouthd.conf
    mkdir -p /usr/share/plymouth/themes/onion-os
    cat > /usr/share/plymouth/themes/onion-os/onion-os.plymouth << PLYMOUTHCONF
[Plymouth Theme]
Name=Onion OS
Description=Onion OS Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/onion-os
ScriptFile=/usr/share/plymouth/themes/onion-os/onion-os.script
PLYMOUTHCONF

    cat > /usr/share/plymouth/themes/onion-os/onion-os.script << 'PLYMOUTHSCRIPT'
wallpaper_image = Image("wallpaper.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
resized_wallpaper = wallpaper_image.Scale(screen_width, screen_height);
resized_wallpaper.SetOpacity(0.8);
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(screen_width / 2 - logo_image.GetWidth() / 2);
logo_sprite.SetY(screen_height / 2 - logo_image.GetHeight() / 2);
message_sprite = Sprite();
message_sprite.SetX(screen_width / 2);
message_sprite.SetY(screen_height / 2 + logo_image.GetHeight() / 2 + 20);

progress = 0;
fun refresh_callback()
    progress = progress + 0.01;
    if (progress > 1)
        progress = 1;
    opacity = 1 - progress;
    logo_sprite.SetOpacity(opacity);
    message_sprite.SetOpacity(opacity);
    resized_wallpaper.SetOpacity(0.8 * opacity);
end

Plymouth.SetRefreshFunction(refresh_callback);

fun quit_callback()
    if (Plymouth.GetMode() == "shutdown")
        return;
    message_sprite.SetText("欢迎使用 Onion OS");
end

Plymouth.SetQuitFunction(quit_callback);

fun message_callback(message)
    message_sprite.SetText(message);
end

Plymouth.SetMessageFunction(message_callback);
PLYMOUTHSCRIPT

    plymouth-set-default-theme onion-os 2>/dev/null || true

    systemctl enable lightdm 2>/dev/null || true

    install_vbox_guest_and_display
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf << AUTOLOGIN
[Seat:*]
autologin-user=${ONION_USER}
autologin-user-timeout=0
user-session=xfce
AUTOLOGIN

    cat > /etc/lightdm/lightdm-gtk-greeter.conf << GREETERCFG
[greeter]
theme-name = Onion-Glass
icon-theme-name = Papirus
font-name = WenQuanYi Micro Hei 11
background = /usr/share/backgrounds/onion-os/default.png
user-background = false
GREETERCFG
}

# ======================== VirtualBox / 虚拟机显示 ========================

install_vbox_guest_and_display() {
    apt install -y --no-install-recommends \
        xserver-xorg-video-vesa \
        xserver-xorg-video-fbdev \
        xserver-xorg-video-vmware \
        xserver-xorg-video-qxl \
        xserver-xorg-video-modesetting \
        || true

    if apt-cache show virtualbox-guest-utils virtualbox-guest-x11 >/dev/null 2>&1; then
        apt install -y --no-install-recommends \
            virtualbox-guest-utils \
            virtualbox-guest-x11 \
            || true
        systemctl enable vboxadd-service 2>/dev/null || true
    fi
}

# ======================== 中文字体 ========================

install_fonts() {
    apt install -y --no-install-recommends \
        fonts-wqy-microhei \
        fonts-wqy-zenhei \
        fonts-noto-cjk \
        fonts-noto-cjk-extra

    apt install -y --no-install-recommends fonts-liberation fonts-croscore || true

    fc-cache -f -v
}

# ======================== Firefox ESR ========================

install_firefox() {
    apt install -y --no-install-recommends \
        firefox-esr \
        firefox-esr-l10n-zh-cn

    sudo -u "${ONION_USER}" xdg-settings set default-web-browser firefox-esr.desktop 2>/dev/null || true
}

# ======================== WPS Office ========================

install_wps_office() {
    local wps_url="https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11723/wps-office_11.1.0.11723_amd64.deb"
    local wps_deb="/tmp/wps-office.deb"

    echo "下载 WPS Office..."
    if wget -q --show-progress -O "${wps_deb}" "${wps_url}" 2>/dev/null; then
        apt install -y "${wps_deb}" || apt install -y -f
        rm -f "${wps_deb}"
    else
        echo "[WARN] WPS Office 下载失败，跳过。用户可后续从应用商店安装。"
        rm -f "${wps_deb}"
        return 0
    fi

    apt install -y --no-install-recommends \
        libglu1-mesa \
        libxslt1.1 \
        libxml2

    if [[ -d /usr/share/fonts/wps-office ]]; then
        ln -sf /usr/share/fonts/truetype/wqy /usr/share/fonts/wps-office/wqy 2>/dev/null || true
    fi
}

# ======================== 微信 (deepin-wine) ========================

install_wechat() {
    dpkg --add-architecture i386
    apt update 2>/dev/null || true

    local dwine_repo="deb [trusted=yes] https://mirrors.huaweicloud.com/deepin stable main contrib non-free"

    echo "${dwine_repo}" > /etc/apt/sources.list.d/deepin-wine.list
    apt update 2>/dev/null || true

    apt install -y --no-install-recommends \
        deepin-wine5 \
        deepin-wine-helper \
        deepin-wine-plugin \
        deepin-libwine \
        deepin-libwine:i386 \
        deepin-fonts-wine \
        fonts-wqy-microhei:i386 2>/dev/null || true

    local wechat_url="https://mirrors.huaweicloud.com/deepin/pool/non-free/d/deepin.com.wechat/"
    local wechat_deb="/tmp/wechat.deb"

    echo "下载微信 (deepin-wine 版)..."
    local wechat_latest
    wechat_latest=$(curl -sL "${wechat_url}" 2>/dev/null | grep -oP 'href="[^"]*amd64\.deb"' | tail -1 | sed 's/href="//;s/"//')

    if [[ -n "${wechat_latest}" ]]; then
        wget -q --show-progress -O "${wechat_deb}" "${wechat_url}${wechat_latest}" 2>/dev/null || true
        if [[ -f "${wechat_deb}" && -s "${wechat_deb}" ]]; then
            dpkg -i "${wechat_deb}" || apt install -y -f
            rm -f "${wechat_deb}"
        else
            echo "[WARN] 微信 deb 下载失败，跳过。"
            rm -f "${wechat_deb}"
        fi
    else
        echo "[WARN] 无法获取微信下载链接，跳过。用户可后续手动安装。"
    fi

    rm -f /etc/apt/sources.list.d/deepin-wine.list
    apt update 2>/dev/null || true

    mkdir -p /home/${ONION_USER}/Desktop
    cat > /home/${ONION_USER}/Desktop/wechat.desktop << WECHATDESKTOP
[Desktop Entry]
Name=微信
Name[zh_CN]=微信
Comment=WeChat for Linux (deepin-wine)
Exec=env WINEPREFIX=~/.deepinwine/Deepin-WeChat deepin-wine5 "c:\\Program Files\\Tencent\\WeChat\\WeChat.exe"
Icon=deepin.com.wechat
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
StartupNotify=true
WECHATDESKTOP
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/Desktop/wechat.desktop"
    chmod +x "/home/${ONION_USER}/Desktop/wechat.desktop"

    # 同步到系统应用目录，供 Plank Dock / Whisker 菜单解析
    cp /home/${ONION_USER}/Desktop/wechat.desktop /usr/share/applications/deepin.com.wechat.desktop
}

# ======================== Fcitx5 中文输入法 ========================

install_fcitx5() {
    apt install -y --no-install-recommends \
        fcitx5 \
        fcitx5-chinese-addons \
        fcitx5-frontend-gtk3 \
        fcitx5-frontend-gtk4 \
        fcitx5-frontend-qt5 \
        fcitx5-config-qt \
        fcitx5-material-color

    sudo -u "${ONION_USER}" bash -c 'cat > ~/.xinputrc << XINPUTRC
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
fcitx5 -d --replace
XINPUTRC'

    sudo -u "${ONION_USER}" mkdir -p /home/${ONION_USER}/.config/fcitx5/profile
    sudo -u "${ONION_USER}" bash -c 'cat > /home/'${ONION_USER}'/.config/fcitx5/profile/default << FCITX5PROFILE
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
FCITX5PROFILE'
}

# ======================== 应用商店 (GNOME Software + Flatpak) ========================

install_app_store() {
    apt install -y --no-install-recommends \
        gnome-software \
        gnome-software-plugin-flatpak \
        gnome-software-plugin-snap \
        flatpak \
        xdg-desktop-portal \
        xdg-desktop-portal-gtk

    flatpak remote-add --if-not-exists flathub \
        "https://flathub.org/repo/flathub.flatpakrepo" 2>/dev/null || true

    # 添加 Flathub 南大镜像 beta 加速源（中国用户下载更快）
    flatpak remote-add --if-not-exists flathub-cn \
        "https://mirror.nju.edu.cn/flathub/flathub.flatpakrepo" 2>/dev/null || true

    flatpak update --appstream 2>/dev/null || true

    # 配置 Flatpak 系统级安装目录
    mkdir -p /etc/flatpak/installations.d
    cat > /etc/flatpak/installations.d/onion.conf << FLATPAKCONF
[Onion OS System]
Path=/var/lib/flatpak
DisplayName=Onion OS System Applications
StorageType=harddisk
FLATPAKCONF

    # GNOME Software GSettings 覆盖（静默更新、不弹upgrade横幅）
    mkdir -p /usr/share/glib-2.0/schemas
    cat > /usr/share/glib-2.0/schemas/onion-gnome-software.gschema.override << GSOVERRIDE
[org.gnome.software]
download-updates=false
download-updates-notify=false
first-run=false
check-timestamp=0
show-ratings=true
show-nonfree-prompt=false
show-upgrade-prerelease=false

[org.gnome.software.external-appstream]
enabled=false
GSOVERRIDE

    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true

    # 部署 Gnome Software 自动推荐安装脚本（首次启动后台安装推荐应用）
    cat > /usr/local/bin/onion-app-recommend << 'RECOMMEND'
#!/usr/bin/env bash
# Onion OS 推荐应用安装脚本 - 首次启动后台静默安装常用 Flatpaks

MARKER="${HOME}/.config/onion-os/app-recommend-done"
if [[ -f "${MARKER}" ]]; then
    exit 0
fi

mkdir -p "$(dirname "${MARKER}")"

NOTIFY_TITLE="Onion OS 推荐应用"
RECOMMENDED=(
    "org.videolan.VLC"
    "com.visualstudio.code"
    "com.obsproject.Studio"
    "org.gimp.GIMP"
    "org.libreoffice.LibreOffice"
    "org.onlyoffice.desktopeditors"
)

INSTALLED_ANY=false
for app in "${RECOMMENDED[@]}"; do
    if flatpak list 2>/dev/null | grep -q "${app}"; then
        continue
    fi
    if zenity --question \
        --title="${NOTIFY_TITLE}" \
        --text="检测到可选应用「${app}」尚未安装。\n\n是否现在安装？（可跳过，稍后从应用商店安装）" \
        --ok-label="安装" --cancel-label="跳过" \
        --width=420 2>/dev/null; then
        flatpak install -y --noninteractive flathub "${app}" 2>/dev/null && INSTALLED_ANY=true || true
    fi
done

if [[ "${INSTALLED_ANY}" == "true" ]]; then
    notify-send -i onion-app-store "${NOTIFY_TITLE}" "推荐应用安装完成！" 2>/dev/null || true
fi

echo "done" > "${MARKER}"
RECOMMEND

    chmod +x /usr/local/bin/onion-app-recommend

    # 创建应用商店桌面快捷方式
    mkdir -p /home/${ONION_USER}/Desktop
    cat > /home/${ONION_USER}/Desktop/gnome-software.desktop << GSDESKTOP
[Desktop Entry]
Name=应用商店
Name[zh_CN]=应用商店
Comment=安装和管理应用程序
Comment[zh_CN]=浏览、安装和管理海量免费与开源软件
Exec=gnome-software --mode=updates
Icon=onion-app-store
Terminal=false
Type=Application
Categories=System;PackageManager;
Keywords=software;store;app;install;flatpak;应用;商店;软件;安装;
StartupNotify=true
GSDESKTOP
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/Desktop/gnome-software.desktop"
    chmod +x "/home/${ONION_USER}/Desktop/gnome-software.desktop"

    # 同样更新 system 级 desktop（菜单用）
    cat > /usr/share/applications/gnome-software.desktop << GSSYSDESKTOP
[Desktop Entry]
Name=应用商店
Name[zh_CN]=应用商店
Comment=安装和管理应用程序
Comment[zh_CN]=浏览、安装和管理海量免费与开源软件
Exec=gnome-software --mode=updates
Icon=onion-app-store
Terminal=false
Type=Application
Categories=System;PackageManager;
Keywords=software;store;app;install;flatpak;应用;商店;软件;安装;
StartupNotify=true
GSSYSDESKTOP

    # 推荐应用首次启动项
    mkdir -p "/home/${ONION_USER}/.config/autostart"
    cat > "/home/${ONION_USER}/.config/autostart/onion-app-recommend.desktop" << APPRECAUTOSTART
[Desktop Entry]
Type=Application
Name=Onion App Recommendations
Comment=Recommended apps for Onion OS
Exec=/usr/local/bin/onion-app-recommend
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=15
APPRECAUTOSTART
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/autostart/onion-app-recommend.desktop"

    cat > /etc/systemd/system/onion-appstore-ready.service << 'SVCUNIT'
[Unit]
Description=Onion OS App Store Readiness
After=network-online.target NetworkManager.service
Wants=network-online.target
Before=gnome-software.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'while ! nm-online -t 5 -q; do sleep 2; done; flatpak update --appstream 2>/dev/null; exit 0'
TimeoutStartSec=90
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCUNIT

    systemctl enable onion-appstore-ready.service 2>/dev/null || true

    cat > "/home/${ONION_USER}/.config/autostart/onion-appstream-refresh.desktop" << APPASTREAM
[Desktop Entry]
Type=Application
Name=Onion AppStream Refresh
Exec=/bin/sh -c 'sleep 15 && flatpak update --appstream 2>/dev/null'
X-GNOME-Autostart-Phase=Applications
APPASTREAM
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/autostart/onion-appstream-refresh.desktop"
}

# ======================== 附加实用工具 ========================

install_utilities() {
    apt install -y --no-install-recommends \
        pavucontrol \
        pulseaudio \
        pulseaudio-module-bluetooth \
        alsa-utils \
        volumeicon-alsa \
        gnome-calculator \
        gnome-screenshot \
        evince \
        file-roller \
        engrampa \
        timeshift \
        baobab \
        zenity \
        yad \
        gvfs \
        gvfs-backends \
        udisks2 \
        udisks2-btrfs \
        polkitd \
        policykit-1-gnome \
        upower \
        dmidecode \
        x11-xserver-utils \
        arandr \
        autorandr \
        mesa-utils \
        inxi \
        brightnessctl \
        redshift
}

# ======================== 主流程 ========================

main() {
    echo "=====> [02_apps] 开始安装应用软件 <====="

    install_xfce_desktop
    install_fonts
    install_firefox
    install_wps_office
    install_wechat
    install_fcitx5
    install_app_store
    install_utilities

    echo "=====> [02_apps] 应用软件安装完成 <====="
}

main
