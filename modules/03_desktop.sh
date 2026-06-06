#!/usr/bin/env bash
# ============================================================================
# Onion OS 模块 03: 桌面定制与美化 (26.1.0 macOS Dock + 玻璃风重构版)
# ============================================================================
# 设计意图：
#   将 Xfce 深度定制为 Onion OS 独特风格 —— 丝滑动画、简洁面板、
#   自动 HiDPI 缩放、品牌化视觉、开箱即用的完整体验。
#
# 核心改进 (vs 26.0.6)：
#   1. 真·macOS Dock：底部 Plank 程序坞（悬停放大），顶部细菜单栏放托盘/时钟
#   2. 美化必达：配置同步进 /etc/skel，安装后的新用户也继承（见 07_finalize.sh）
#   3. Picom 改用主线 10.x 兼容写法，杜绝因解析失败导致美化无效
#   4. 登录自愈 onion-apply-appearance：逐显示器强制套用壁纸/主题/Dock
#   5. 自动分辨率检测 → 自适应 DPI/顶栏/Dock 图标/字体缩放
#   6. Onion 品牌化液态玻璃主题 (紫色系) + 多分辨率壁纸生成
# ============================================================================

set -uo pipefail

readonly ONION_PURPLE="#8E44AD"
readonly ONION_PURPLE_DARK="#6C3483"
readonly ONION_BG="#2D1B4E"
readonly ONION_ACCENT="#9B59B6"

# ======================== HiDPI 自动缩放 ========================

configure_hidpi_autoscale() {
    cat > /usr/local/bin/onion-scale << 'ONIONSCALE'
#!/usr/bin/env bash
# Onion OS 自动缩放 - 覆盖所有屏幕比例与分辨率
# 支持: 5:4 / 4:3 / 16:9 / 16:10 / 21:9 / 32:9 及纵向旋转

SCALE_CONFIG="${HOME}/.config/onion-os/scale-done"
if [[ -f "${SCALE_CONFIG}" ]]; then
    exit 0
fi
mkdir -p "$(dirname "${SCALE_CONFIG}")"

# 等待 Xorg 就绪
for i in $(seq 1 15); do
    if xrandr --current &>/dev/null; then break; fi
    sleep 1
done

RESOLUTION=$(xrandr --current 2>/dev/null | grep '*' | head -1 | awk '{print $1}')
WIDTH=$(echo "${RESOLUTION}" | cut -d'x' -f1 2>/dev/null || echo "1920")
HEIGHT=$(echo "${RESOLUTION}" | cut -d'x' -f2 2>/dev/null || echo "1080")

# 宽高比计算
if [[ -n "${HEIGHT}" && "${HEIGHT}" -gt 0 ]]; then
    ASPECT=$(awk "BEGIN {printf \"%.2f\", ${WIDTH}/${HEIGHT}}")
else
    ASPECT=1.78
fi

# DPI策略：像素密度 / 屏幕物理尺寸估算
# PANEL_SIZE = 顶部菜单栏高度；DOCK_ICON = Plank 底部 Dock 图标尺寸
if [[ "${WIDTH}" -ge 5120 ]]; then
    DPI=240;   PANEL_SIZE=40; DOCK_ICON=72; CURSOR_SIZE=44; FONT_SIZE=16
elif [[ "${WIDTH}" -ge 3840 ]]; then
    DPI=192;   PANEL_SIZE=36; DOCK_ICON=64; CURSOR_SIZE=36; FONT_SIZE=14
elif [[ "${WIDTH}" -ge 2560 ]]; then
    DPI=144;   PANEL_SIZE=32; DOCK_ICON=56; CURSOR_SIZE=30; FONT_SIZE=12
elif [[ "${WIDTH}" -ge 1920 ]]; then
    DPI=96;    PANEL_SIZE=30; DOCK_ICON=48; CURSOR_SIZE=24; FONT_SIZE=11
elif [[ "${WIDTH}" -ge 1680 ]]; then
    DPI=96;    PANEL_SIZE=28; DOCK_ICON=44; CURSOR_SIZE=22; FONT_SIZE=11
elif [[ "${WIDTH}" -ge 1440 ]]; then
    DPI=96;    PANEL_SIZE=28; DOCK_ICON=42; CURSOR_SIZE=22; FONT_SIZE=10
elif [[ "${WIDTH}" -ge 1366 ]]; then
    DPI=96;    PANEL_SIZE=26; DOCK_ICON=40; CURSOR_SIZE=22; FONT_SIZE=10
elif [[ "${WIDTH}" -ge 1280 ]]; then
    DPI=96;    PANEL_SIZE=26; DOCK_ICON=38; CURSOR_SIZE=20; FONT_SIZE=10
elif [[ "${WIDTH}" -ge 1024 ]]; then
    DPI=96;    PANEL_SIZE=24; DOCK_ICON=34; CURSOR_SIZE=18; FONT_SIZE=9
else
    DPI=96;    PANEL_SIZE=24; DOCK_ICON=30; CURSOR_SIZE=18; FONT_SIZE=9
fi

# 纵向模式修正（如平板旋转）— 用 awk 做数值比较，避免字符串字典序误判
if awk "BEGIN {exit !(${ASPECT} < 1.0)}"; then
    PANEL_SIZE=$((PANEL_SIZE + 2))
    FONT_SIZE=$((FONT_SIZE + 1))
fi

# 矮屏幕修正（小于 800px 高度）— 紧缩面板与 Dock
if [[ "${HEIGHT}" -lt 800 ]]; then
    PANEL_SIZE=$((PANEL_SIZE > 24 ? PANEL_SIZE - 2 : 22))
    DOCK_ICON=$((DOCK_ICON > 32 ? DOCK_ICON - 6 : 30))
    FONT_SIZE=$((FONT_SIZE > 9 ? FONT_SIZE - 1 : 9))
fi

# 应用设置
xfconf-query -c xsettings -p /Xft/DPI -s "${DPI}" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s "${CURSOR_SIZE}" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/FontName -s "WenQuanYi Micro Hei ${FONT_SIZE}" 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-0/size -s "${PANEL_SIZE}" 2>/dev/null || true

# Plank Dock 图标尺寸（写入 dconf；Plank 优先读 dconf 再回退 settings 文件）
if command -v dconf &>/dev/null; then
    dconf write /net/launchpad/plank/docks/dock1/icon-size "${DOCK_ICON}" 2>/dev/null || true
fi
# 同步更新 settings 文件，确保下次启动一致
PLANK_SETTINGS="${HOME}/.config/plank/dock1/settings"
if [[ -f "${PLANK_SETTINGS}" ]]; then
    sed -i "s/^IconSize=.*/IconSize=${DOCK_ICON}/" "${PLANK_SETTINGS}" 2>/dev/null || true
fi

# Whisfer Menu 高度安全约束（不能超出屏幕 75%）
MENU_HEIGHT=$((HEIGHT * 72 / 100))
if [[ "${MENU_HEIGHT}" -gt 540 ]]; then MENU_HEIGHT=540; fi
if [[ "${MENU_HEIGHT}" -lt 360 ]]; then MENU_HEIGHT=360; fi
xfconf-query -c xfce4-panel -p /plugins/plugin-1/menu-height -s "${MENU_HEIGHT}" 2>/dev/null || true

echo "done" > "${SCALE_CONFIG}"
ONIONSCALE

    chmod +x /usr/local/bin/onion-scale

    # 创建自启动项
    mkdir -p "/home/${ONION_USER}/.config/autostart"
    cat > "/home/${ONION_USER}/.config/autostart/onion-scale.desktop" << SCALEAUTOSTART
[Desktop Entry]
Type=Application
Name=Onion Display Scale
Comment=Auto-configure display scaling
Exec=/usr/local/bin/onion-scale
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
SCALEAUTOSTART
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/autostart/onion-scale.desktop"
}

# ======================== Onion OS 品牌图标生成 (SVG) ========================

generate_onion_icons() {
    local icon_base="/usr/share/icons/hicolor"
    mkdir -p "${icon_base}/32x32/apps" "${icon_base}/48x48/apps" \
             "${icon_base}/64x64/apps" "${icon_base}/128x128/apps" \
             "${icon_base}/scalable/apps"

    # 菜单图标 (32x32)
    cat > "${icon_base}/32x32/apps/onion-os-menu.svg" << 'MENUICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="onionGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="35%" r="50%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.6"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="32" height="32" rx="6" fill="url(#onionGrad)"/>
  <rect width="32" height="32" rx="6" fill="url(#glow)"/>
  <ellipse cx="16" cy="13" rx="7" ry="5" fill="none" stroke="#E8DAEF" stroke-width="1.5" opacity="0.9"/>
  <ellipse cx="16" cy="9" rx="5" ry="3.5" fill="none" stroke="#D7BDE2" stroke-width="1.2" opacity="0.8"/>
  <path d="M13 6 Q16 2 19 6 Q16 8 13 6Z" fill="#E8DAEF" opacity="0.7"/>
  <path d="M14 20 Q16 18 18 20 L18 24 Q16 25 14 24Z" fill="#D7BDE2" opacity="0.5"/>
  <circle cx="16" cy="13" r="2" fill="#E8DAEF" opacity="0.4"/>
</svg>
MENUICON

    # 48x48
    cp "${icon_base}/32x32/apps/onion-os-menu.svg" "${icon_base}/48x48/apps/onion-os-menu.svg"
    # 实际 48x48 版本
    cat > "${icon_base}/48x48/apps/onion-os-menu.svg" << 'MENUICON48'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="onionGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="35%" r="50%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.5"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="48" height="48" rx="8" fill="url(#onionGrad)"/>
  <rect width="48" height="48" rx="8" fill="url(#glow)"/>
  <ellipse cx="24" cy="19" rx="10" ry="7" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <ellipse cx="24" cy="13" rx="7" ry="5" fill="none" stroke="#D7BDE2" stroke-width="1.5" opacity="0.8"/>
  <ellipse cx="24" cy="8" rx="4.5" ry="3.2" fill="none" stroke="#BB8FCE" stroke-width="1.2" opacity="0.7"/>
  <path d="M19 9 Q24 3 29 9 Q24 11 19 9Z" fill="#E8DAEF" opacity="0.6"/>
  <circle cx="24" cy="19" r="3" fill="#E8DAEF" opacity="0.3"/>
</svg>
MENUICON48

    # 系统 Logo (128x128)
    cat > "${icon_base}/128x128/apps/onion-os-logo.svg" << 'LOGOICON'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="logoGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#2D1B4E"/>
      <stop offset="100%" style="stop-color:#1A0F2E"/>
    </linearGradient>
    <radialGradient id="logoGlow" cx="50%" cy="40%" r="50%">
      <stop offset="0%" style="stop-color:#9B59B6;stop-opacity:0.4"/>
      <stop offset="100%" style="stop-color:#6C3483;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="128" height="128" rx="24" fill="url(#logoGrad)"/>
  <rect width="128" height="128" rx="24" fill="url(#logoGlow)"/>
  <circle cx="64" cy="52" r="30" fill="none" stroke="#7D3C98" stroke-width="1.5" opacity="0.5"/>
  <circle cx="64" cy="52" r="22" fill="none" stroke="#8E44AD" stroke-width="1.5" opacity="0.6"/>
  <circle cx="64" cy="52" r="14" fill="none" stroke="#9B59B6" stroke-width="1.5" opacity="0.7"/>
  <path d="M64 18 Q72 44 64 52 Q56 44 64 18Z" fill="#9B59B6" opacity="0.5"/>
  <path d="M51 32 Q64 44 64 52 Q56 44 51 32Z" fill="#8E44AD" opacity="0.35"/>
  <path d="M77 32 Q64 44 64 52 Q72 44 77 32Z" fill="#8E44AD" opacity="0.35"/>
  <circle cx="64" cy="34" r="5" fill="#D7BDE2" opacity="0.4"/>
  <circle cx="64" cy="52" r="4" fill="#E8DAEF" opacity="0.25"/>
  <text x="64" y="98" text-anchor="middle" fill="#D7BDE2" font-family="sans-serif" font-size="11" font-weight="bold" opacity="0.8">ONION OS</text>
</svg>
LOGOICON

    # 文件管理器图标 (32x32) - 简洁文件夹，深紫渐变，玻璃透明效果
    cat > "${icon_base}/32x32/apps/files-icon.svg" << 'FILESICON32'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="filesGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="filesGlow" cx="50%" cy="30%" r="55%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.5"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="32" height="32" rx="7" fill="url(#filesGrad)"/>
  <rect width="32" height="32" rx="7" fill="url(#filesGlow)"/>
  <path d="M4 9 L4 25 Q4 27 6 27 L26 27 Q28 27 28 25 L28 11 Q28 9 26 9 L15 9 L13 6 L5 6 Q4 6 4 7Z" fill="none" stroke="#E8DAEF" stroke-width="1.5" opacity="0.9"/>
  <path d="M4 9 L15 9 L13 6 L5 6 Q4 6 4 7Z" fill="#D7BDE2" opacity="0.3"/>
  <rect x="6" y="11" width="20" height="14" rx="1.5" fill="#E8DAEF" opacity="0.12"/>
</svg>
FILESICON32

    # 文件管理器图标 (48x48)
    cat > "${icon_base}/48x48/apps/files-icon.svg" << 'FILESICON48'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="filesGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="filesGlow" cx="50%" cy="30%" r="55%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.45"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#filesGrad)"/>
  <rect width="48" height="48" rx="10" fill="url(#filesGlow)"/>
  <path d="M6 13 L6 37 Q6 40 9 40 L39 40 Q42 40 42 37 L42 17 Q42 14 39 14 L22 14 L19 9 L7 9 Q6 9 6 10Z" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <path d="M6 13 L22 13 L19 9 L7 9 Q6 9 6 10Z" fill="#D7BDE2" opacity="0.28"/>
  <rect x="9" y="16" width="30" height="21" rx="2" fill="#E8DAEF" opacity="0.10"/>
</svg>
FILESICON48

    # 浏览器图标 (32x32) - 地球/浏览器，紫色渐变，玻璃效果
    cat > "${icon_base}/32x32/apps/browser-icon.svg" << 'BROWSERICON32'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="browserGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="browserGlow" cx="50%" cy="35%" r="50%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.5"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="32" height="32" rx="7" fill="url(#browserGrad)"/>
  <rect width="32" height="32" rx="7" fill="url(#browserGlow)"/>
  <circle cx="16" cy="16" r="10" fill="none" stroke="#E8DAEF" stroke-width="1.5" opacity="0.85"/>
  <ellipse cx="16" cy="16" rx="10" ry="4" fill="none" stroke="#D7BDE2" stroke-width="1" opacity="0.6"/>
  <ellipse cx="16" cy="16" rx="4" ry="10" fill="none" stroke="#D7BDE2" stroke-width="1" opacity="0.6"/>
  <line x1="6" y1="16" x2="26" y2="16" stroke="#D7BDE2" stroke-width="0.8" opacity="0.5"/>
  <circle cx="16" cy="16" r="3" fill="#E8DAEF" opacity="0.25"/>
</svg>
BROWSERICON32

    # 浏览器图标 (48x48)
    cat > "${icon_base}/48x48/apps/browser-icon.svg" << 'BROWSERICON48'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="browserGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="browserGlow" cx="50%" cy="35%" r="50%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.45"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#browserGrad)"/>
  <rect width="48" height="48" rx="10" fill="url(#browserGlow)"/>
  <circle cx="24" cy="24" r="15" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.85"/>
  <ellipse cx="24" cy="24" rx="15" ry="6" fill="none" stroke="#D7BDE2" stroke-width="1.2" opacity="0.55"/>
  <ellipse cx="24" cy="24" rx="6" ry="15" fill="none" stroke="#D7BDE2" stroke-width="1.2" opacity="0.55"/>
  <line x1="9" y1="24" x2="39" y2="24" stroke="#D7BDE2" stroke-width="1" opacity="0.4"/>
  <circle cx="24" cy="24" r="4.5" fill="#E8DAEF" opacity="0.2"/>
</svg>
BROWSERICON48

    # 应用商店图标 (32x32) - 购物袋风格，紫色渐变，玻璃效果
    cat > "${icon_base}/32x32/apps/store-icon.svg" << 'STOREICON32'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="storeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="storeGlow" cx="50%" cy="30%" r="50%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.5"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="32" height="32" rx="7" fill="url(#storeGrad)"/>
  <rect width="32" height="32" rx="7" fill="url(#storeGlow)"/>
  <path d="M8 10 L8 25 Q8 27 10 27 L22 27 Q24 27 24 25 L24 10Z" fill="none" stroke="#E8DAEF" stroke-width="1.5" opacity="0.9"/>
  <path d="M11 10 Q11 5 16 5 Q21 5 21 10" fill="none" stroke="#E8DAEF" stroke-width="1.5" opacity="0.85"/>
  <line x1="8" y1="14" x2="24" y2="14" stroke="#D7BDE2" stroke-width="1" opacity="0.5"/>
  <circle cx="13" cy="20" r="1.5" fill="#E8DAEF" opacity="0.5"/>
  <circle cx="19" cy="20" r="1.5" fill="#E8DAEF" opacity="0.5"/>
</svg>
STOREICON32

    # 应用商店图标 (48x48) - 购物袋风格
    cat > "${icon_base}/48x48/apps/store-icon.svg" << 'STOREICON48'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="storeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
    <radialGradient id="storeGlow" cx="50%" cy="30%" r="50%">
      <stop offset="0%" style="stop-color:#D7BDE2;stop-opacity:0.45"/>
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0"/>
    </radialGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#storeGrad)"/>
  <rect width="48" height="48" rx="10" fill="url(#storeGlow)"/>
  <path d="M11 14 L11 38 Q11 41 14 41 L34 41 Q37 41 37 38 L37 14Z" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <path d="M16 14 Q16 7 24 7 Q32 7 32 14" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.85"/>
  <line x1="11" y1="21" x2="37" y2="21" stroke="#D7BDE2" stroke-width="1.2" opacity="0.45"/>
  <circle cx="19" cy="31" r="2.5" fill="#E8DAEF" opacity="0.45"/>
  <circle cx="29" cy="31" r="2.5" fill="#E8DAEF" opacity="0.45"/>
</svg>
STOREICON48

    # 应用商店图标 (48x48)
    cat > "${icon_base}/48x48/apps/onion-app-store.svg" << STOREICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="storeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#storeGrad)"/>
  <rect x="10" y="14" width="28" height="24" rx="3" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <line x1="10" y1="22" x2="38" y2="22" stroke="#E8DAEF" stroke-width="1.5" opacity="0.7"/>
  <circle cx="16" cy="33" r="2" fill="#E8DAEF" opacity="0.7"/>
  <circle cx="24" cy="33" r="2" fill="#E8DAEF" opacity="0.7"/>
  <circle cx="32" cy="33" r="2" fill="#E8DAEF" opacity="0.7"/>
  <circle cx="16" cy="27" r="1.5" fill="#D7BDE2" opacity="0.5"/>
  <circle cx="24" cy="27" r="1.5" fill="#D7BDE2" opacity="0.5"/>
  <path d="M18 14 L16 6 L20 6Z" fill="#E8DAEF" opacity="0.5"/>
  <path d="M30 14 L28 6 L32 6Z" fill="#E8DAEF" opacity="0.5"/>
  <line x1="20" y1="10" x2="28" y2="10" stroke="#E8DAEF" stroke-width="1.5" opacity="0.4"/>
</svg>
STOREICON

    # 安全管家图标
    cat > "${icon_base}/48x48/apps/onion-security.svg" << SECICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="secGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6C3483"/>
      <stop offset="100%" style="stop-color:#4A235A"/>
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#secGrad)"/>
  <path d="M24 4 L38 12 L38 26 Q38 36 24 44 Q10 36 10 26 L10 12Z" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <path d="M24 16 L20 22 L28 22 L24 30" fill="none" stroke="#D7BDE2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" opacity="0.8"/>
</svg>
SECICON

    # 缩放显示图标
    cat > "${icon_base}/48x48/apps/onion-display.svg" << DISPICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="dispGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#8E44AD"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#dispGrad)"/>
  <rect x="6" y="8" width="36" height="26" rx="3" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <rect x="10" y="12" width="28" height="18" rx="1" fill="#2D1B4E" opacity="0.5"/>
  <line x1="6" y1="36" x2="18" y2="44" stroke="#E8DAEF" stroke-width="2" opacity="0.7"/>
  <line x1="42" y1="36" x2="30" y2="44" stroke="#E8DAEF" stroke-width="2" opacity="0.7"/>
  <line x1="16" y1="40" x2="32" y2="40" stroke="#D7BDE2" stroke-width="1.5" opacity="0.5"/>
</svg>
DISPICON

    # 更新管理器图标
    cat > "${icon_base}/48x48/apps/onion-update-icon.svg" << UPDICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="updGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#9B59B6"/>
      <stop offset="100%" style="stop-color:#6C3483"/>
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10" fill="url(#updGrad)"/>
  <path d="M24 8 L24 16" stroke="#E8DAEF" stroke-width="2.5" stroke-linecap="round" opacity="0.9"/>
  <path d="M18 14 L24 6 L30 14" fill="none" stroke="#E8DAEF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" opacity="0.8"/>
  <circle cx="24" cy="28" r="12" fill="none" stroke="#D7BDE2" stroke-width="2" opacity="0.7"/>
  <path d="M24 22 L24 30 M20 28 L28 28" stroke="#E8DAEF" stroke-width="2" stroke-linecap="round" opacity="0.8"/>
</svg>
UPDICON

    # 系统设置图标
    cat > "${icon_base}/48x48/apps/onion-settings.svg" << SETICON
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <rect width="48" height="48" rx="10" fill="#6C3483"/>
  <circle cx="24" cy="24" r="5" fill="none" stroke="#E8DAEF" stroke-width="2" opacity="0.9"/>
  <path d="M24 4 L24 12 M24 36 L24 44 M4 24 L12 24 M36 24 L44 24" stroke="#E8DAEF" stroke-width="2" stroke-linecap="round" opacity="0.6"/>
  <path d="M10 10 L16 16 M32 32 L38 38 M38 10 L32 16 M10 38 L16 32" stroke="#D7BDE2" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
  <circle cx="24" cy="24" r="12" fill="none" stroke="#8E44AD" stroke-width="1" opacity="0.3"/>
</svg>
SETICON

    # Update gtk icon cache
    gtk-update-icon-cache "${icon_base}" 2>/dev/null || true
}

# ======================== 主题与图标 ========================

install_themes() {
    apt install -y --no-install-recommends \
        arc-theme \
        numix-gtk-theme \
        papirus-icon-theme \
        numix-icon-theme-circle

    # 生成 Onion 品牌化 GTK3 CSS 覆盖（紫色强调色）
    mkdir -p /usr/share/themes/Arc-Darker/gtk-3.0
    cat > /usr/share/themes/Arc-Darker/gtk-3.0/gtk-onion.css << ONIONGTKCSS
@define-color theme_selected_bg_color #8E44AD;
@define-color theme_selected_fg_color #ffffff;
@define-color theme_selected_bg_color_rgba rgba(142,68,173,0.85);

headerbar entry selection,
headerbar .selection,
toolbar .selection,
toolbar selection,
entry selection,
label selection,
.view:selected,
.nautilus-canvas-item:selected,
.tile:selected {
    background-color: #8E44AD;
    color: #ffffff;
}

button.suggested-action {
    background-image: linear-gradient(to bottom, #9B59B6, #7D3C98);
    border-color: #6C3483;
    color: #ffffff;
}
button.suggested-action:hover {
    background-image: linear-gradient(to bottom, #A569BD, #8E44AD);
}
ONIONGTKCSS

    mkdir -p "/home/${ONION_USER}/.config/gtk-3.0"
    cat > "/home/${ONION_USER}/.config/gtk-3.0/settings.ini" << 'GTKSETTINGS'

[Settings]
gtk-theme-name=Onion-Glass
gtk-icon-theme-name=Papirus
gtk-font-name=WenQuanYi Micro Hei 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_SMALL_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
GTKSETTINGS

    cat > "/home/${ONION_USER}/.gtkrc-2.0" << 'GTK2SETTINGS'
gtk-theme-name="Onion-Glass"
gtk-icon-theme-name="Papirus"
gtk-font-name="WenQuanYi Micro Hei 11"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
GTK2SETTINGS
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/gtk-3.0/settings.ini" "/home/${ONION_USER}/.gtkrc-2.0"

    # Onion-Glass GTK3 液态玻璃主题
    mkdir -p /usr/share/themes/Onion-Glass/gtk-3.0
    cat > /usr/share/themes/Onion-Glass/gtk-3.0/gtk.css << 'ONIONGLASSCSS'
@define-color theme_bg_color rgba(26, 10, 46, 0.85);
@define-color theme_fg_color #ffffff;
@define-color theme_selected_bg_color #8E44AD;
@define-color theme_selected_fg_color #ffffff;
@define-color borders rgba(142, 68, 173, 0.3);
@define-color theme_base_color rgba(26, 10, 46, 0.75);
@define-color theme_text_color #ffffff;
@define-color insensitive_bg_color rgba(26, 10, 46, 0.5);
@define-color insensitive_fg_color rgba(255, 255, 255, 0.4);
@define-color unfocused_bg_color rgba(26, 10, 46, 0.7);
@define-color unfocused_fg_color rgba(255, 255, 255, 0.7);

* {
  -GtkWidget-cursor-aspect-ratio: 0.05;
}

window {
  background-color: @theme_bg_color;
  border-radius: 12px;
}

window decoration {
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
  margin: 6px;
}

button {
  border-radius: 8px;
  padding: 6px 16px;
  border: 1px solid @borders;
  background-color: rgba(142, 68, 173, 0.2);
  color: @theme_fg_color;
  transition: all 200ms ease;
  min-height: 28px;
}

button:hover {
  background-color: rgba(142, 68, 173, 0.4);
  border-color: #9B59B6;
}

button:active {
  background-color: rgba(142, 68, 173, 0.6);
}

button:disabled {
  background-color: @insensitive_bg_color;
  color: @insensitive_fg_color;
}

entry {
  border-radius: 8px;
  padding: 6px 12px;
  border: 1px solid @borders;
  background-color: rgba(26, 10, 46, 0.5);
  color: @theme_fg_color;
  min-height: 28px;
}

entry:focus {
  border-color: #9B59B6;
}

notebook header {
  background-color: rgba(26, 10, 46, 0.6);
  border: none;
}

notebook tab {
  border-radius: 8px 8px 0 0;
  padding: 6px 16px;
  background-color: rgba(26, 10, 46, 0.4);
  color: @unfocused_fg_color;
  border: 1px solid transparent;
  border-bottom: none;
  min-height: 28px;
}

notebook tab:checked {
  background-color: rgba(142, 68, 173, 0.3);
  color: @theme_fg_color;
  border-color: @borders;
}

scrollbar slider {
  border-radius: 6px;
  background-color: rgba(142, 68, 173, 0.5);
  min-width: 8px;
  min-height: 24px;
}

scrollbar slider:hover {
  background-color: rgba(142, 68, 173, 0.7);
}

tooltip {
  border-radius: 8px;
  background-color: rgba(26, 10, 46, 0.95);
  color: @theme_fg_color;
  border: 1px solid @borders;
  padding: 6px 10px;
}

menu, .menu {
  background-color: rgba(26, 10, 46, 0.9);
  border: 1px solid @borders;
  border-radius: 10px;
  padding: 4px;
}

menuitem {
  border-radius: 6px;
  padding: 6px 12px;
  min-height: 24px;
  color: @theme_fg_color;
}

menuitem:hover {
  background-color: rgba(142, 68, 173, 0.3);
}

headerbar {
  background-color: rgba(26, 10, 46, 0.7);
  border: none;
  border-radius: 12px 12px 0 0;
  padding: 4px 8px;
  min-height: 36px;
}

toolbar {
  background-color: rgba(26, 10, 46, 0.6);
  border: none;
}

.separator {
  color: rgba(142, 68, 173, 0.2);
}

switch {
  border-radius: 16px;
  background-color: rgba(255, 255, 255, 0.15);
  border: 1px solid @borders;
}

switch:checked {
  background-color: #8E44AD;
  border-color: #9B59B6;
}

scale slider {
  border-radius: 50%;
  background-color: #8E44AD;
  border: 2px solid #9B59B6;
  min-width: 16px;
  min-height: 16px;
}

scale trough {
  border-radius: 4px;
  background-color: rgba(255, 255, 255, 0.1);
  min-height: 6px;
}

progressbar trough {
  border-radius: 6px;
  background-color: rgba(255, 255, 255, 0.1);
  min-height: 8px;
}

progressbar progress {
  border-radius: 6px;
  background-color: #8E44AD;
}

checkbutton check, radiobutton radio {
  border-radius: 4px;
  background-color: rgba(255, 255, 255, 0.1);
  border: 1px solid @borders;
  min-width: 18px;
  min-height: 18px;
}

checkbutton check:checked, radiobutton radio:checked {
  background-color: #8E44AD;
  border-color: #9B59B6;
}

.view, iconview {
  background-color: rgba(26, 10, 46, 0.5);
  color: @theme_fg_color;
  border-radius: 8px;
}

.view:selected, iconview:selected {
  background-color: rgba(142, 68, 173, 0.4);
  color: @theme_selected_fg_color;
}

treeview header button {
  background-color: rgba(26, 10, 46, 0.7);
  color: @theme_fg_color;
  border: none;
  border-bottom: 1px solid @borders;
  padding: 4px 8px;
  min-height: 24px;
}

spinbutton entry {
  border-radius: 8px 0 0 8px;
}

spinbutton button {
  border-radius: 0;
  padding: 4px 8px;
}

.xfce4-panel {
  background-color: rgba(26, 10, 46, 0.72);
  border: 1px solid rgba(142, 68, 173, 0.25);
  border-radius: 14px;
  margin: 6px 8px 4px 8px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.06);
  padding: 2px 6px;
}

.xfce4-panel button {
  border-radius: 10px;
  padding: 3px 6px;
  margin: 2px 4px;
  border: 1px solid transparent;
  background-color: transparent;
  transition: all 200ms ease;
  min-width: 36px;
  min-height: 36px;
}

.xfce4-panel button:hover {
  background-color: rgba(142, 68, 173, 0.35);
  border-color: rgba(155, 89, 182, 0.5);
  box-shadow: 0 0 12px rgba(142, 68, 173, 0.3);
}

.xfce4-panel button:checked {
  background-color: rgba(142, 68, 173, 0.5);
  border-color: rgba(155, 89, 182, 0.6);
  box-shadow: 0 0 8px rgba(142, 68, 173, 0.4);
}
ONIONGLASSCSS

    # 创建 index.theme 文件
    cat > /usr/share/themes/Onion-Glass/index.theme << 'THEMEINDEX'
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Onion Glass
Comment=Onion OS 26.1.0 Liquid Glass Theme
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=Onion-Glass
MetacityTheme=Onion-Glass
IconTheme=Papirus
CursorTheme=Adwaita
THEMEINDEX
}

# ======================== 壁纸生成 ========================

setup_wallpaper() {
    mkdir -p /usr/share/backgrounds/onion-os

    # 主壁纸 - 深紫渐变 + 洋葱图标
    cat > /usr/share/backgrounds/onion-os/default.svg << WALLPAPERSVG
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1A0F2E;stop-opacity:1" />
      <stop offset="35%" style="stop-color:#2D1B4E;stop-opacity:1" />
      <stop offset="65%" style="stop-color:#4A235A;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#1A0F2E;stop-opacity:1" />
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="40%" r="50%">
      <stop offset="0%" style="stop-color:#8E44AD;stop-opacity:0.15" />
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0" />
    </radialGradient>
    <filter id="softShadow">
      <feGaussianBlur in="SourceAlpha" stdDeviation="4"/>
      <feOffset dx="0" dy="2"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#glow)"/>

  <!-- 装饰性几何线条 -->
  <line x1="0" y1="0" x2="480" y2="1080" stroke="#6C3483" stroke-width="0.5" opacity="0.15"/>
  <line x1="1920" y1="0" x2="1440" y2="1080" stroke="#6C3483" stroke-width="0.5" opacity="0.15"/>
  <circle cx="960" cy="400" r="220" fill="none" stroke="#7D3C98" stroke-width="1" opacity="0.2"/>
  <circle cx="960" cy="400" r="160" fill="none" stroke="#8E44AD" stroke-width="1" opacity="0.25"/>
  <circle cx="960" cy="400" r="100" fill="none" stroke="#9B59B6" stroke-width="1" opacity="0.3"/>

  <!-- 洋葱图标 -->
  <path d="M960 180 Q1000 320 960 400 Q920 320 960 180Z" fill="#9B59B6" opacity="0.4"/>
  <path d="M900 240 Q960 350 960 400 Q920 350 900 240Z" fill="#8E44AD" opacity="0.3"/>
  <path d="M1020 240 Q960 350 960 400 Q1000 350 1020 240Z" fill="#8E44AD" opacity="0.3"/>
  <path d="M870 300 Q950 370 960 400 Q920 370 870 300Z" fill="#7D3C98" opacity="0.25"/>
  <path d="M1050 300 Q970 370 960 400 Q1000 370 1050 300Z" fill="#7D3C98" opacity="0.25"/>

  <!-- 品牌文字 -->
  <text x="960" y="660" text-anchor="middle" fill="#E8DAEF" font-family="sans-serif" font-size="72" font-weight="bold" letter-spacing="8">Onion OS</text>
  <text x="960" y="720" text-anchor="middle" fill="#D7BDE2" font-family="sans-serif" font-size="24">${ONION_OS_VERSION} Home Edition</text>
  <text x="960" y="760" text-anchor="middle" fill="#BB8FCE" font-family="sans-serif" font-size="16" letter-spacing="4">层层精简 · 层层用心</text>

  <!-- 底部装饰线 -->
  <line x1="760" y1="790" x2="1160" y2="790" stroke="#8E44AD" stroke-width="1" opacity="0.4"/>
</svg>
WALLPAPERSVG

    # 1366x768 壁纸变体 - 深紫渐变 + 洋葱图标 (尺寸适配)
    cat > /usr/share/backgrounds/onion-os/default-1366x768.svg << 'WALLPAPERSVG1366'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1366" height="768" viewBox="0 0 1366 768">
  <defs>
    <linearGradient id="bg1366" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1A0F2E;stop-opacity:1" />
      <stop offset="35%" style="stop-color:#2D1B4E;stop-opacity:1" />
      <stop offset="65%" style="stop-color:#4A235A;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#1A0F2E;stop-opacity:1" />
    </linearGradient>
    <radialGradient id="glow1366" cx="50%" cy="40%" r="50%">
      <stop offset="0%" style="stop-color:#8E44AD;stop-opacity:0.15" />
      <stop offset="100%" style="stop-color:#8E44AD;stop-opacity:0" />
    </radialGradient>
    <filter id="softShadow1366">
      <feGaussianBlur in="SourceAlpha" stdDeviation="3"/>
      <feOffset dx="0" dy="1"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect width="1366" height="768" fill="url(#bg1366)"/>
  <rect width="1366" height="768" fill="url(#glow1366)"/>

  <!-- 装饰性几何线条 -->
  <line x1="0" y1="0" x2="341" y2="768" stroke="#6C3483" stroke-width="0.5" opacity="0.15"/>
  <line x1="1366" y1="0" x2="1025" y2="768" stroke="#6C3483" stroke-width="0.5" opacity="0.15"/>
  <circle cx="683" cy="284" r="156" fill="none" stroke="#7D3C98" stroke-width="1" opacity="0.2"/>
  <circle cx="683" cy="284" r="114" fill="none" stroke="#8E44AD" stroke-width="1" opacity="0.25"/>
  <circle cx="683" cy="284" r="71" fill="none" stroke="#9B59B6" stroke-width="1" opacity="0.3"/>

  <!-- 洋葱图标 -->
  <path d="M683 128 Q711 227 683 284 Q655 227 683 128Z" fill="#9B59B6" opacity="0.4"/>
  <path d="M640 171 Q683 249 683 284 Q655 249 640 171Z" fill="#8E44AD" opacity="0.3"/>
  <path d="M726 171 Q683 249 683 284 Q711 249 726 171Z" fill="#8E44AD" opacity="0.3"/>
  <path d="M619 213 Q676 263 683 284 Q655 263 619 213Z" fill="#7D3C98" opacity="0.25"/>
  <path d="M747 213 Q690 263 683 284 Q711 263 747 213Z" fill="#7D3C98" opacity="0.25"/>

  <!-- 品牌文字 -->
  <text x="683" y="469" text-anchor="middle" fill="#E8DAEF" font-family="sans-serif" font-size="48" font-weight="bold" letter-spacing="5">Onion OS</text>
  <text x="683" y="512" text-anchor="middle" fill="#D7BDE2" font-family="sans-serif" font-size="16">${ONION_OS_VERSION} Home Edition</text>
  <text x="683" y="540" text-anchor="middle" fill="#BB8FCE" font-family="sans-serif" font-size="11" letter-spacing="3">层层精简 · 层层用心</text>

  <!-- 底部装饰线 -->
  <line x1="540" y1="562" x2="826" y2="562" stroke="#8E44AD" stroke-width="1" opacity="0.4"/>
</svg>
WALLPAPERSVG1366

    if command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 1366 -h 768 /usr/share/backgrounds/onion-os/default-1366x768.svg \
            > /usr/share/backgrounds/onion-os/default-1366x768.png 2>/dev/null || true
    elif command -v convert &>/dev/null; then
        convert -resize 1366x768 /usr/share/backgrounds/onion-os/default-1366x768.svg \
            /usr/share/backgrounds/onion-os/default-1366x768.png 2>/dev/null || true
    fi

    if [[ ! -f /usr/share/backgrounds/onion-os/default-1366x768.png ]]; then
        cp /usr/share/backgrounds/onion-os/default-1366x768.svg /usr/share/backgrounds/onion-os/default-1366x768.png
    fi

    if command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 1920 -h 1080 /usr/share/backgrounds/onion-os/default.svg \
            > /usr/share/backgrounds/onion-os/default.png
    elif command -v convert &>/dev/null; then
        convert -resize 1920x1080 /usr/share/backgrounds/onion-os/default.svg \
            /usr/share/backgrounds/onion-os/default.png 2>/dev/null || true
    fi

    if [[ ! -f /usr/share/backgrounds/onion-os/default.png ]]; then
        cp /usr/share/backgrounds/onion-os/default.svg /usr/share/backgrounds/onion-os/default.png
    fi

    # 额外壁纸变体
    # 变体2：简洁版（深色）
    cat > /usr/share/backgrounds/onion-os/dark.svg << WALLPAPERSVG2
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">
  <defs>
    <linearGradient id="bg2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#0E0620;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#1A0F2E;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg2)"/>
  <circle cx="960" cy="540" r="350" fill="none" stroke="#4A235A" stroke-width="0.5" opacity="0.3"/>
  <circle cx="960" cy="540" r="280" fill="none" stroke="#6C3483" stroke-width="0.5" opacity="0.25"/>
  <circle cx="960" cy="540" r="210" fill="none" stroke="#7D3C98" stroke-width="0.5" opacity="0.2"/>
  <circle cx="960" cy="540" r="140" fill="none" stroke="#8E44AD" stroke-width="0.5" opacity="0.15"/>
  <text x="960" y="530" text-anchor="middle" fill="#6C3483" font-family="sans-serif" font-size="48" font-weight="bold" opacity="0.6">ONION OS</text>
  <text x="960" y="570" text-anchor="middle" fill="#4A235A" font-family="sans-serif" font-size="18" opacity="0.5">${ONION_OS_VERSION} Home Edition</text>
</svg>
WALLPAPERSVG2

    if command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 1920 -h 1080 /usr/share/backgrounds/onion-os/dark.svg \
            > /usr/share/backgrounds/onion-os/dark.png
    fi

    # 设置默认壁纸（PNG，xfdesktop 不渲染 SVG backdrop）
    # 实际“逐显示器”应用交给 onion-apply-appearance 登录脚本，
    # 因为真实连接器名（如 monitorVGA-1/HDMI-1）在构建期未知。
    runuser -u "${ONION_USER}" -- xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/monitorscreen/workspace0/last-image \
        -n -t string -s /usr/share/backgrounds/onion-os/default.png 2>/dev/null || true

    # 同步壁纸到 Plymouth 启动动画目录
    mkdir -p /usr/share/plymouth/themes/onion-os
    cp /usr/share/backgrounds/onion-os/default.png /usr/share/plymouth/themes/onion-os/wallpaper.png 2>/dev/null || true
    if [[ ! -f /usr/share/plymouth/themes/onion-os/wallpaper.png ]]; then
        cp /usr/share/backgrounds/onion-os/default.svg /usr/share/plymouth/themes/onion-os/wallpaper.png 2>/dev/null || true
    fi
    if command -v rsvg-convert &>/dev/null; then
        rsvg-convert -w 1920 -h 1080 /usr/share/backgrounds/onion-os/default.svg \
            > /usr/share/plymouth/themes/onion-os/wallpaper.png 2>/dev/null || true
    fi
    # 生成 Plymouth 圆形 Logo
    if command -v convert &>/dev/null; then
        convert -size 128x128 xc:transparent \
            -fill '#8E44AD' -draw "circle 64,64 64,12" \
            /usr/share/plymouth/themes/onion-os/logo.png 2>/dev/null || true
    fi
    plymouth-set-default-theme onion-os 2>/dev/null || true
}

# ======================== Xfce 顶部菜单栏 (macOS 风格) ========================
# 设计：顶部一条细面板充当 macOS 菜单栏（左 Onion 菜单 + 右托盘/时钟），
#       底部由 Plank 提供可放大的真·Dock（见 configure_plank_dock）。
#       Xfce 面板本身无法做 dock 悬停放大动画，因此 Dock 交给 Plank。

configure_xfce_panel() {
    local xfconf_dir="/home/${ONION_USER}/.config/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p "${xfconf_dir}"

    local old_panel_dir="/home/${ONION_USER}/.config/xfce4/panel"
    rm -rf "${old_panel_dir}"
    mkdir -p "${old_panel_dir}"

    cat > "${xfconf_dir}/xfce4-panel.xml" << 'PANELXML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="0"/>
    <property name="panel-0" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="autohide-behavior" type="uint" value="0"/>
      <property name="length" type="uint" value="100"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="icon-size" type="uint" value="18"/>
      <property name="nrows" type="uint" value="1"/>
      <property name="mode" type="uint" value="0"/>
      <property name="background-style" type="uint" value="2"/>
      <property name="background-rgba" type="array">
        <value type="double" value="0.101961"/>
        <value type="double" value="0.039216"/>
        <value type="double" value="0.180392"/>
        <value type="double" value="0.680000"/>
      </property>
      <property name="enter-opacity" type="uint" value="100"/>
      <property name="leave-opacity" type="uint" value="88"/>
      <property name="disable-struts" type="bool" value="false"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="6"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <!-- plugin-1: Whisker Menu (Onion 品牌开始菜单) -->
    <property name="plugin-1" type="string" value="whiskermenu">
      <property name="button-icon" type="string" value="onion-os-menu"/>
      <property name="button-title" type="string" value="Onion OS"/>
      <property name="show-button-title" type="bool" value="true"/>
      <property name="menu-width" type="uint" value="440"/>
      <property name="menu-height" type="uint" value="520"/>
      <property name="menu-opacity" type="uint" value="92"/>
      <property name="position-categories-alternate" type="bool" value="false"/>
      <property name="view-mode" type="uint" value="1"/>
      <property name="show-generic-names" type="bool" value="true"/>
      <property name="show-tooltips" type="bool" value="true"/>
      <property name="launcher-show-description" type="bool" value="true"/>
    </property>

    <!-- plugin-2: 弹性分隔符（把右侧内容推到最右） -->
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
      <property name="expand" type="bool" value="true"/>
    </property>

    <!-- plugin-3: 电源管理插件 (电池/亮度) -->
    <property name="plugin-3" type="string" value="power-manager-plugin"/>

    <!-- plugin-4: 状态托盘 (网络/音量/通知; Xfce 4.18 systray 已内置 SNI 支持) -->
    <property name="plugin-4" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
      <property name="icon-size" type="uint" value="16"/>
      <property name="known-legacy-items" type="array">
        <value type="string" value="networkmanager applet"/>
        <value type="string" value="pulseaudio plugin"/>
      </property>
    </property>

    <!-- plugin-6: 时钟 -->
    <property name="plugin-6" type="string" value="clock">
      <property name="digital-layout" type="uint" value="3"/>
      <property name="digital-time-format" type="string" value="%H:%M"/>
      <property name="digital-date-format" type="string" value="%m月%d日"/>
      <property name="tooltip-format" type="string" value="%Y年%m月%d日 %A"/>
      <property name="mode" type="uint" value="2"/>
    </property>
  </property>
</channel>
PANELXML

    chown -R "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/xfce4"
}

# ======================== Plank macOS 风格 Dock ========================

configure_plank_dock() {
    local plank_dir="/home/${ONION_USER}/.config/plank/dock1"
    mkdir -p "${plank_dir}/launchers"

    # Dock 行为与外观：底部居中、悬停放大、半透明玻璃
    cat > "${plank_dir}/settings" << 'PLANKSETTINGS'
[PlankDockPreferences]
#当前 Dock 上的启动器（顺序即显示顺序）
DockItems=firefox-esr.dockitem;;thunar.dockitem;;gnome-software.dockitem;;wechat.dockitem;;garlic-claw.dockitem;;onion-update.dockitem;;xfce4-settings-manager.dockitem
#停靠位置: 0=左 1=右 2=上 3=下
Position=3
#对齐: 3=居中
Alignment=3
#图标大小（onion-scale 会按分辨率覆盖）
IconSize=48
#悬停放大开关
ZoomEnabled=true
#放大倍率 (1.0-2.0)；1.5 接近 macOS 手感
ZoomPercent=150
#隐藏模式: 0=不隐藏 1=智能隐藏 2=自动隐藏 3=躲避窗口 4=窗口铺满时隐藏
HideMode=4
#自动隐藏延迟
UnhideDelay=0
HideDelay=0
#主题（见下方 Onion.theme）
Theme=Onion
#显示在所有工作区
Monitor=
#锁定图标，防止误拖拽
LockItems=false
#压力解锁
PressureReveal=false
#显示正在运行程序的指示点
ShowDockItem=true
ItemsAlignment=3
#淡入淡出
FadeOpacity=1.0
PLANKSETTINGS

    # Dock 启动器（.dockitem 指向系统 .desktop）
    _plank_launcher() {
        local name="$1" target="$2"
        cat > "${plank_dir}/launchers/${name}.dockitem" << DOCKITEM
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/${target}
DOCKITEM
    }

    _plank_launcher "firefox-esr" "firefox-esr.desktop"
    _plank_launcher "thunar" "thunar.desktop"
    _plank_launcher "gnome-software" "gnome-software.desktop"
    _plank_launcher "wechat" "deepin.com.wechat.desktop"
    _plank_launcher "garlic-claw" "garlic-claw.desktop"
    _plank_launcher "onion-update" "onion-update.desktop"
    _plank_launcher "xfce4-settings-manager" "xfce-settings-manager.desktop"

    # Onion 玻璃风 Plank 主题
    local theme_dir="/usr/share/plank/themes/Onion"
    mkdir -p "${theme_dir}"
    cat > "${theme_dir}/dock.theme" << 'PLANKTHEME'
[PlankTheme]
TopRoundness=12
BottomRoundness=0
LineWidth=1
OuterStrokeColor=155;89;182;90
FillStartColor=26;10;46;200
FillEndColor=26;10;46;230
InnerStrokeColor=216;191;226;40

[PlankDockTheme]
HorizPadding=8
TopPadding=-6
BottomPadding=4
ItemPadding=4
IndicatorSize=5
IconShadowSize=2
UrgentBounceHeight=1.6666666666666667
LaunchBounceHeight=0.625
FadeOpacity=1.0
ClickTime=300
UrgentBounceTime=600
LaunchBounceTime=600
ActiveTime=300
SlideTime=300
FadeTime=250
HideTime=250
GlowSize=30
GlowTime=10000
GlowPulseTime=2000
UrgentHueShift=150
ItemMoveTime=450
CascadeHide=true
PLANKTHEME

    # Plank 自启动（picom 之后启动，确保 dock 透明模糊正常）
    local autostart_dir="/home/${ONION_USER}/.config/autostart"
    mkdir -p "${autostart_dir}"
    cat > "${autostart_dir}/plank.desktop" << 'PLANKAUTO'
[Desktop Entry]
Type=Application
Name=Plank Dock
Comment=Onion OS macOS 风格程序坞
Exec=sh -c "sleep 2 && plank"
Icon=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=2
PLANKAUTO

    chown -R "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/plank" \
        "${autostart_dir}/plank.desktop"
}

# ======================== Picom 用户级配置 ========================

configure_picom() {
    mkdir -p /home/${ONION_USER}/.config/picom
    cat > /home/${ONION_USER}/.config/picom/picom.conf << 'PICOMCFG'
# Onion OS 26.1.0 Picom 配置 - 液态玻璃效果 (mainline picom 10.x 兼容)
# 说明：Debian 12 仓库的 picom 为 10.2 主线版，不支持 jonaburg/FT-Labs
#       分支的 animations 块；强行写入会导致配置解析失败、合成器拒绝启动，
#       这正是历史版本“美化没生效”的元凶之一。这里只用主线支持的特性：
#       dual_kawase 模糊 + 圆角 + 柔光阴影 + 渐入渐出，配合 Plank 的 dock
#       缩放动画，实现 macOS 风格的丝滑观感。
backend = "glx";
vsync = true;
unredir-if-possible = true;
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
use-damage = true;
xrender-sync-fence = true;

# ---- 液态玻璃模糊 (dual_kawase 为主线 picom 支持) ----
blur-method = "dual_kawase";
blur-strength = 7;
blur-background = true;
blur-background-frame = true;
blur-background-fixed = true;
blur-background-exclude = [
  "class_g = 'firefox'",
  "class_g = 'Chromium'",
  "class_g = 'Code'",
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "_GTK_FRAME_EXTENTS@:c",
];

# ---- 阴影 ----
shadow = true;
shadow-radius = 16;
shadow-opacity = 0.30;
shadow-offset-x = -10;
shadow-offset-y = -10;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "class_g = 'Cairo-clock'",
  "window_type = 'dock'",
  "window_type = 'desktop'",
];

# ---- 圆角窗口 ----
corner-radius = 12;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "window_type = 'notification'",
];

# ---- 透明度 ----
inactive-opacity = 0.92;
active-opacity = 0.98;
frame-opacity = 0.90;
inactive-opacity-override = false;
opacity-rule = [
  "85:class_g = 'firefox'",
  "90:class_g = 'Thunar'",
  "90:class_g = 'Xfce4-terminal'",
];

# ---- 渐入渐出 ----
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = 5;

# ---- wintypes ----
wintypes:
{
  tooltip = { fade = true; shadow = true; opacity = 0.85; focus = true; blur = true; };
  dock = { shadow = false; blur = true; };
  dnd = { shadow = false; };
  dropdown_menu = { shadow = true; blur = true; };
  popup_menu = { shadow = true; blur = true; };
  utility = { shadow = true; blur = true; };
  notification = { shadow = true; blur = true; };
};

detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
detect-client-leader = true;
PICOMCFG

    # Fallback 配置 (老显卡 xrender, 无 blur, 无动画)
    mkdir -p /etc/xdg/picom
    cat > /etc/xdg/picom/picom-fallback.conf << 'PICOMFALLBACK'
backend = "xrender";
vsync = true;
unredir-if-possible = false;
use-damage = true;
shadow = true;
shadow-radius = 6;
shadow-opacity = 0.20;
shadow-offset-x = -4;
shadow-offset-y = -4;
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
inactive-opacity = 0.95;
active-opacity = 1.0;
PICOMFALLBACK

    chown -R "${ONION_USER}:${ONION_USER}" /home/${ONION_USER}/.config/picom
}

# ======================== 通知降噪 ========================

configure_notification_filter() {
    mkdir -p /home/${ONION_USER}/.config/xfce4
    cat > "/home/${ONION_USER}/.config/xfce4/xfce4-notifyd.xml" << 'NOTIFYCFG'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-notifyd">
  <property name="notify-location" type="uint" value="3"/>
  <property name="theme" type="string" value="Smoke"/>
  <property name="initial-opacity" type="double" value="0.85"/>
  <property name="expire-timeout" type="int" value="3"/>
  <property name="do-fadeout" type="bool" value="true"/>
  <property name="do-slideout" type="bool" value="true"/>
  <property name="log-only" type="bool" value="false"/>
  <property name="log-max-size" type="int" value="50"/>
  <property name="known-applications" type="array">
    <value type="string" value="network-manager-applet"/>
    <value type="string" value="xfce4-power-manager"/>
    <value type="string" value="pulseaudio"/>
    <value type="string" value="garlic-claw"/>
    <value type="string" value="xfce4-power-manager-settings"/>
  </property>
</channel>
NOTIFYCFG
}

# ======================== Thunar 右键菜单 ========================

configure_thunar_uca() {
    mkdir -p /home/${ONION_USER}/.config/Thunar
    cat > "/home/${ONION_USER}/.config/Thunar/uca.xml" << 'UCACFG'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
    <icon>terminal</icon>
    <name>在此打开终端</name>
    <unique-id>1</unique-id>
    <command>exo-open --working-directory %f --launch TerminalEmulator</command>
    <description>在当前目录打开终端</description>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>accessories-text-editor</icon>
    <name>以管理员身份编辑</name>
    <unique-id>2</unique-id>
    <command>pkexec mousepad %f</command>
    <description>使用管理员权限编辑此文件</description>
    <patterns>*</patterns>
    <text-files/>
</action>
<action>
    <icon>folder</icon>
    <name>以管理员身份打开</name>
    <unique-id>3</unique-id>
    <command>pkexec thunar %f</command>
    <description>使用管理员权限打开此文件夹</description>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>utilities-terminal</icon>
    <name>询问 Garlic Claw</name>
    <unique-id>4</unique-id>
    <command>xfce4-terminal --title="Garlic Claw" -e "garlic-claw ask \"请分析这个文件: %f\""</command>
    <description>使用 Garlic Claw AI 助手分析此文件</description>
    <patterns>*</patterns>
    <text-files/>
    <other-files/>
</action>
</actions>
UCACFG
}

# ======================== 桌面快捷方式 (极简) ========================

setup_desktop_shortcuts() {
    local desktop_dir="/home/${ONION_USER}/Desktop"
    mkdir -p "${desktop_dir}"

    # 仅保留 3 个核心快捷方式
    cat > "${desktop_dir}/thunar.desktop" << THUNARDESKTOP
[Desktop Entry]
Name=文件
Name[zh_CN]=文件管理器
Comment=浏览文件和文件夹
Exec=thunar
Icon=system-file-manager
Terminal=false
Type=Application
Categories=System;FileManager;
StartupNotify=true
THUNARDESKTOP

    cat > "${desktop_dir}/firefox.desktop" << FFDESKTOP
[Desktop Entry]
Name=浏览器
Name[zh_CN]=Firefox 浏览器
Comment=浏览互联网
Exec=firefox-esr
Icon=firefox-esr
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
FFDESKTOP

    cat > "${desktop_dir}/garlic-claw.desktop" << GCDESKTOP
[Desktop Entry]
Name=AI 助手
Name[zh_CN]=Garlic Claw
Comment=Onion OS AI 助手
Exec=xfce4-terminal --title="Garlic Claw" -e "garlic-claw"
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;AI;
StartupNotify=true
GCDESKTOP

    chown -R "${ONION_USER}:${ONION_USER}" "${desktop_dir}"
    chmod +x "${desktop_dir}"/*.desktop
}

# ======================== Xfce 会话自启动 ========================

configure_autostart() {
    local autostart_dir="/home/${ONION_USER}/.config/autostart"
    mkdir -p "${autostart_dir}"

    # Picom 合成器 (GLX自动探测，老旧GPU回退xrender)
    cat > "${autostart_dir}/picom.desktop" << PICOMAUTOSTART
[Desktop Entry]
Type=Application
Name=Picom Compositor
Comment=窗口合成器
Exec=/usr/local/bin/onion-picom
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
PICOMAUTOSTART

    # NetworkManager 小程序
    cat > "${autostart_dir}/nm-applet.desktop" << NMAUTOSTART
[Desktop Entry]
Type=Application
Name=Network Manager
Comment=网络管理
Exec=nm-applet
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
NMAUTOSTART

    # 音量控制
    cat > "${autostart_dir}/volumeicon.desktop" << VOLAUTOSTART
[Desktop Entry]
Type=Application
Name=Volume Control
Comment=音量控制
Exec=volumeicon
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
VOLAUTOSTART

    # 电源管理器（笔记本电池图标）
    cat > "${autostart_dir}/xfce4-power-manager.desktop" << POWERAUTOSTART
[Desktop Entry]
Type=Application
Name=Power Manager
Comment=电源管理
Exec=xfce4-power-manager
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
POWERAUTOSTART

    # 首次启动配置向导
    cat > "${autostart_dir}/onion-first-run.desktop" << FIRSTRUN
[Desktop Entry]
Type=Application
Name=Onion First Setup
Comment=首次启动配置
Exec=/usr/local/bin/onion-first-run.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
FIRSTRUN

    # Calamares Live 安装器
    cat > "${autostart_dir}/calamares-live.desktop" << CALAMARES
[Desktop Entry]
Type=Application
Name=Install Onion OS
Comment=系统安装程序
Exec=/usr/local/bin/onion-live-installer.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
CALAMARES

    chown -R "${ONION_USER}:${ONION_USER}" "${autostart_dir}"
}

# ======================== 首次启动欢迎引导 ========================

setup_welcome_wizard() {
    cat > /usr/local/bin/onion-welcome << 'WELCOMEPY'
#!/usr/bin/env python3
# Onion OS 26.1.0 首次启动欢迎引导

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import os
import subprocess
import sys

WELCOME_DONE = os.path.expanduser('~/.config/onion-os/welcome-done')
if os.path.exists(WELCOME_DONE):
    sys.exit(0)

class WelcomeWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        Gtk.ApplicationWindow.__init__(self, application=app, title='欢迎使用 Onion OS')
        self.set_default_size(600, 480)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_resizable(False)
        self.set_decorated(False)
        self.set_keep_above(True)

        self.steps = [
            self.step_welcome,
            self.step_wifi,
            self.step_done
        ]
        self.current = 0

        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_box)

        css = b'''
        window { background-color: #1a0a2e; border-radius: 16px; }
        .welcome-title { font-size: 28px; font-weight: bold; color: #E8DAEF; margin-top: 30px; }
        .welcome-subtitle { font-size: 16px; color: #BB8FCE; margin-top: 10px; margin-bottom: 20px; }
        .big-button { font-size: 18px; padding: 16px 40px; border-radius: 12px;
                      background-color: #8E44AD; color: white; border: none; min-height: 52px; }
        .big-button:hover { background-color: #9B59B6; }
        .big-button-alt { font-size: 18px; padding: 16px 40px; border-radius: 12px;
                          background-color: rgba(142,68,173,0.3); color: #E8DAEF; border: 1px solid #8E44AD; min-height: 52px; }
        .step-label { font-size: 14px; color: #D7BDE2; margin-top: 16px; }
        .done-icon { font-size: 64px; color: #9B59B6; }
        '''
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, 600)

        self.show_step()

    def show_step(self):
        for child in self.main_box.get_children():
            self.main_box.remove(child)
        if self.current < len(self.steps):
            self.steps[self.current]()

    def step_welcome(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_valign(Gtk.Align.CENTER)
        vbox.set_halign(Gtk.Align.CENTER)

        title = Gtk.Label()
        title.set_markup('<span size="36000" weight="bold" foreground="#E8DAEF">🎉 欢迎使用 Onion OS</span>')
        title.set_margin_bottom(10)

        subtitle = Gtk.Label()
        subtitle.set_markup('<span size="16000" foreground="#BB8FCE">让电脑更简单，让人人都会用</span>')
        subtitle.set_margin_bottom(30)

        btn = Gtk.Button(label='开始设置')
        btn.get_style_context().add_class('big-button')
        btn.set_size_request(240, 56)
        btn.connect('clicked', lambda w: self.next_step())

        dots = Gtk.Label()
        dots.set_markup('<span size="12000" foreground="#9B59B6">● ○ ○</span>')
        dots.set_margin_top(24)

        vbox.pack_start(title, False, False, 0)
        vbox.pack_start(subtitle, False, False, 0)
        vbox.pack_start(btn, False, False, 0)
        vbox.pack_start(dots, False, False, 0)
        self.main_box.pack_start(vbox, True, True, 0)
        self.show_all()

    def step_wifi(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_valign(Gtk.Align.CENTER)
        vbox.set_halign(Gtk.Align.CENTER)

        title = Gtk.Label()
        title.set_markup('<span size="24000" weight="bold" foreground="#E8DAEF">📶 连接到网络</span>')
        title.set_margin_bottom(10)

        subtitle = Gtk.Label()
        subtitle.set_markup('<span size="14000" foreground="#BB8FCE">Wi-Fi 可以让您上网、更新系统和下载应用</span>')
        subtitle.set_margin_bottom(20)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        btn_box.set_halign(Gtk.Align.CENTER)

        wifi_btn = Gtk.Button(label='连接 Wi-Fi')
        wifi_btn.get_style_context().add_class('big-button')
        wifi_btn.set_size_request(280, 56)
        wifi_btn.connect('clicked', lambda w: self.open_wifi())

        skip_btn = Gtk.Button(label='跳过，稍后设置')
        skip_btn.get_style_context().add_class('big-button-alt')
        skip_btn.set_size_request(280, 52)
        skip_btn.connect('clicked', lambda w: self.next_step())

        dots = Gtk.Label()
        dots.set_markup('<span size="12000" foreground="#9B59B6">○ ● ○</span>')
        dots.set_margin_top(24)

        btn_box.pack_start(wifi_btn, False, False, 0)
        btn_box.pack_start(skip_btn, False, False, 0)
        vbox.pack_start(title, False, False, 0)
        vbox.pack_start(subtitle, False, False, 0)
        vbox.pack_start(btn_box, False, False, 0)
        vbox.pack_start(dots, False, False, 0)
        self.main_box.pack_start(vbox, True, True, 0)
        self.show_all()

    def step_done(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_valign(Gtk.Align.CENTER)
        vbox.set_halign(Gtk.Align.CENTER)

        icon = Gtk.Label()
        icon.set_markup('<span size="48000" foreground="#9B59B6">✨</span>')
        icon.set_margin_bottom(10)

        title = Gtk.Label()
        title.set_markup('<span size="28000" weight="bold" foreground="#E8DAEF">一切就绪！</span>')
        title.set_margin_bottom(10)

        subtitle = Gtk.Label()
        subtitle.set_markup('<span size="14000" foreground="#BB8FCE">您可以随时在底部 Dock 找到常用应用</span>')
        subtitle.set_margin_bottom(20)

        btn = Gtk.Button(label='开始使用 Onion OS')
        btn.get_style_context().add_class('big-button')
        btn.set_size_request(300, 56)
        btn.connect('clicked', lambda w: self.finish())

        dots = Gtk.Label()
        dots.set_markup('<span size="12000" foreground="#9B59B6">○ ○ ●</span>')
        dots.set_margin_top(24)

        vbox.pack_start(icon, False, False, 0)
        vbox.pack_start(title, False, False, 0)
        vbox.pack_start(subtitle, False, False, 0)
        vbox.pack_start(btn, False, False, 0)
        vbox.pack_start(dots, False, False, 0)
        self.main_box.pack_start(vbox, True, True, 0)
        self.show_all()

    def next_step(self):
        self.current += 1
        self.show_step()

    def open_wifi(self):
        try:
            subprocess.Popen(['nm-connection-editor'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        self.next_step()

    def finish(self):
        os.makedirs(os.path.dirname(WELCOME_DONE), exist_ok=True)
        with open(WELCOME_DONE, 'w') as f:
            f.write('done')
        self.destroy()

class WelcomeApp(Gtk.Application):
    def __init__(self):
        Gtk.Application.__init__(self)
    def do_activate(self):
        win = WelcomeWindow(self)
        win.show_all()
        win.connect('destroy', lambda w: self.quit())
    def do_startup(self):
        Gtk.Application.do_startup(self)

if __name__ == '__main__':
    app = WelcomeApp()
    app.run()
WELCOMEPY

    chmod +x /usr/local/bin/onion-welcome

    mkdir -p "/home/${ONION_USER}/.config/autostart"
    cat > "/home/${ONION_USER}/.config/autostart/onion-welcome.desktop" << WELCOMEAUTO
[Desktop Entry]
Type=Application
Name=Onion OS Welcome
Comment=Onion OS 首次启动引导
Exec=/usr/local/bin/onion-welcome
X-GNOME-Autostart-enabled=true
WELCOMEAUTO
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/autostart/onion-welcome.desktop"
}

# ======================== 精简右键菜单 ========================

configure_simplified_menus() {
    mkdir -p "/home/${ONION_USER}/.config/Thunar"
    cat > "/home/${ONION_USER}/.config/Thunar/uca.xml" << 'UCACFG'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
    <icon>folder-new</icon>
    <name>新建文件夹</name>
    <submenu></submenu>
    <command>mkdir %f</command>
    <description>在当前目录创建新文件夹</description>
    <range></range>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>utilities-terminal</icon>
    <name>在此打开终端</name>
    <submenu></submenu>
    <command>exo-open --working-directory %f --launch TerminalEmulator</command>
    <description>在此目录打开终端</description>
    <range></range>
    <patterns>*</patterns>
    <directories/>
</action>
<action>
    <icon>document-properties</icon>
    <name>属性</name>
    <submenu></submenu>
    <command>thunar --bulk-rename %F</command>
    <description>查看文件/文件夹属性</description>
    <range>*</range>
    <patterns>*</patterns>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
</action>
</actions>
UCACFG
    chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/Thunar/uca.xml"

    # 清空桌面快捷方式（清爽桌面，所有入口走 Dock / 菜单）
    rm -f "/home/${ONION_USER}/Desktop/"*.desktop 2>/dev/null || true
}

# ======================== Live 安装器脚本 ========================

deploy_live_installer() {
    cat > /usr/local/bin/onion-live-installer.sh << LIVEINSTALLER
#!/usr/bin/env bash
set -e

is_live_environment() {
    grep -q "boot=live" /proc/cmdline 2>/dev/null && return 0
    grep -q "live-config" /proc/cmdline 2>/dev/null && return 0
    [ -d /lib/live/mount/medium ] && return 0
    [ -f /.disk/info ] && return 0
    [ -f /lib/live/boot/boot.sh ] && return 0
    return 1
}

sleep 3

if is_live_environment; then
    if [ -z "\${DISPLAY}" ]; then
        export DISPLAY=:0
    fi

    if command -v calamares &>/dev/null; then
        pkexec calamares &
    else
        zenity --error --title="安装错误" --text="找不到 Calamares 安装程序。" 2>/dev/null || true
    fi
fi
LIVEINSTALLER

    chmod +x /usr/local/bin/onion-live-installer.sh

    mkdir -p /etc/systemd/system
    cat > /etc/systemd/system/onion-live-installer.service << SYSTEMDSERVICE
[Unit]
Description=Onion OS Live Installer
After=lightdm.service display-manager.service
Wants=lightdm.service
ConditionKernelCommandLine=|boot=live
ConditionKernelCommandLine=|live-config

[Service]
Type=oneshot
ExecStart=/usr/local/bin/onion-live-installer.sh
User=${ONION_USER}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${ONION_USER}/.Xauthority
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
SYSTEMDSERVICE

    systemctl enable onion-live-installer.service 2>/dev/null || true
}

# ======================== Xfce 全局设置 ========================

configure_xfce_settings() {
    mkdir -p /home/${ONION_USER}/.config/xfce4/xfconf/xfce-perchannel-xml

    # Xfwm4 窗口管理器 (同步 Picom glx 设置)
    cat > "/home/${ONION_USER}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'XFWM4CFG'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4">
  <property name="general" type="empty">
    <property name="activate_action" type="string" value="bring"/>
    <property name="borderless_maximize" type="bool" value="true"/>
    <property name="box_move" type="bool" value="false"/>
    <property name="box_resize" type="bool" value="false"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="button_offset" type="int" value="0"/>
    <property name="button_spacing" type="int" value="0"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="cycle_apps_only" type="bool" value="false"/>
    <property name="cycle_draw_frame" type="bool" value="true"/>
    <property name="cycle_hidden" type="bool" value="true"/>
    <property name="cycle_minimum" type="bool" value="true"/>
    <property name="cycle_workspaces" type="bool" value="false"/>
    <property name="double_click_action" type="string" value="maximize"/>
    <property name="focus_delay" type="int" value="200"/>
    <property name="focus_hint" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="frame_opacity" type="int" value="95"/>
    <property name="full_width_title" type="bool" value="true"/>
    <property name="horiz_scroll_opacity" type="bool" value="false"/>
    <property name="inactive_opacity" type="int" value="92"/>
    <property name="maximized_offset" type="int" value="0"/>
    <property name="mousewheel_rollup" type="bool" value="true"/>
    <property name="move_opacity" type="int" value="85"/>
    <property name="placement_mode" type="string" value="center"/>
    <property name="placement_ratio" type="int" value="50"/>
    <property name="popup_opacity" type="int" value="100"/>
    <property name="prevent_focus_stealing" type="bool" value="false"/>
    <property name="raise_delay" type="int" value="200"/>
    <property name="raise_on_click" type="bool" value="true"/>
    <property name="raise_on_focus" type="bool" value="false"/>
    <property name="resize_opacity" type="int" value="85"/>
    <property name="scroll_workspaces" type="bool" value="true"/>
    <property name="shadow_delta_x" type="int" value="0"/>
    <property name="shadow_delta_y" type="int" value="0"/>
    <property name="shadow_opacity" type="int" value="0"/>
    <property name="show_app_icon" type="bool" value="true"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
    <property name="show_frame_shadow" type="bool" value="false"/>
    <property name="show_popup_shadow" type="bool" value="false"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="true"/>
    <property name="snap_width" type="int" value="10"/>
    <property name="sync_to_vblank" type="bool" value="true"/>
    <property name="theme" type="string" value="Arc-Darker"/>
    <property name="tile_on_move" type="bool" value="true"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="title_font" type="string" value="WenQuanYi Micro Hei Bold 11"/>
    <property name="title_horizontal_offset" type="int" value="0"/>
    <property name="titleless_maximize" type="bool" value="false"/>
    <property name="title_shadow_active" type="string" value="false"/>
    <property name="title_shadow_inactive" type="string" value="false"/>
    <property name="title_vertical_offset_active" type="int" value="0"/>
    <property name="title_vertical_offset_inactive" type="int" value="0"/>
    <property name="toggle_workspaces" type="bool" value="false"/>
    <property name="unredirect_overlays" type="bool" value="true"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="1"/>
    <property name="wrap_cycle" type="bool" value="true"/>
    <property name="wrap_layout" type="bool" value="true"/>
    <property name="wrap_resistance" type="int" value="10"/>
    <property name="wrap_windows" type="bool" value="true"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
    <property name="zoom_desktop" type="bool" value="true"/>
    <property name="vblank_mode" type="string" value="glx"/>
  </property>
</channel>
XFWM4CFG

    # Xfce 桌面设置
    cat > "/home/${ONION_USER}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << 'DESKTOPCFG'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorscreen" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/onion-os/default.png"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="file-icons" type="empty">
      <property name="show-home" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
      <property name="show-filesystem" type="bool" value="false"/>
    </property>
  </property>
</channel>
DESKTOPCFG

    # Xsettings 全局外观
    cat > "/home/${ONION_USER}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" << 'XSETTINGSCFG'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Onion-Glass"/>
    <property name="IconThemeName" type="string" value="Papirus"/>
    <property name="DoubleClickTime" type="int" value="400"/>
    <property name="DoubleClickDistance" type="int" value="5"/>
    <property name="DndDragThreshold" type="int" value="8"/>
    <property name="CursorBlink" type="bool" value="true"/>
    <property name="CursorBlinkTime" type="int" value="1200"/>
    <property name="SoundThemeName" type="string" value="default"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CanChangeAccels" type="bool" value="false"/>
    <property name="ColorPalette" type="string" value="black:white:gray50:red:purple:blue:light blue:green:yellow:orange:lavender:brown:gold1:gold2:gold3:gold4:gold5:gold6:gold7:gold8:gold9:gold10:gold11:gold12:gold13:gold14:gold15:gold16:gold17:gold18:gold19:gold20"/>
    <property name="FontName" type="string" value="WenQuanYi Micro Hei 11"/>
    <property name="IconSizes" type="string" value=""/>
    <property name="KeyThemeName" type="string" value=""/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ToolbarIconSize" type="string" value="small-toolbar"/>
    <property name="MenuImages" type="bool" value="false"/>
    <property name="ButtonImages" type="bool" value="false"/>
    <property name="MenuBarAccel" type="string" value="F10"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
    <property name="DialogsUseHeader" type="bool" value="true"/>
    <property name="TitlebarMiddleClick" type="string" value="none"/>
  </property>
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="96"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
XSETTINGSCFG

    # Whisker Menu 配置（26.1.0 紫色玻璃主题版）
    mkdir -p "/home/${ONION_USER}/.config/xfce4/panel"
    cat > "/home/${ONION_USER}/.config/xfce4/panel/whiskermenu-1.rc" << 'WHISKERRC'
button-title=Onion OS
show-button-title=true
launcher-icon-size=2
button-icon=onion-os-menu
show-favorites=true
show-commands=true
show-recent=true
recent-items-max=6
show-category-names=true
favorites=thunar.desktop,firefox-esr.desktop,garlic-claw.desktop,gnome-software.desktop,onion-master.desktop,onion-update.desktop,xfce4-settings-manager.desktop,xfce4-power-manager-settings.desktop
command-settings=xfce4-settings-manager
command-lockscreen=xflock4
command-switchuser=dm-tool switch-to-greeter
command-logoutuser=xfce4-session-logout --logout
command-restart=xfce4-session-logout --reboot
command-shutdown=xfce4-session-logout --halt
search-actions=1
position-categories-alternate=false
position-commands-alternate=true
position-search-alternate=false
category-icon-size=1
item-icon-size=2
menu-width=440
menu-height=540
menu-opacity=95
background-opacity=88
view-mode=1
sort-categories=true
WHISKERRC

    chown -R "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/xfce4"
}

# ======================== 登录期外观强制应用 ========================
# 为什么需要它：构建期写入的 xfconf XML 在真实硬件上未必被 xfdesktop 接受
# （真实显示器连接器名未知），且 Plank/picom 需要在会话内启动。此脚本在每次
# 登录时自愈式地强制套用壁纸、主题与 Dock，是“美化确实生效”的最后保障。

configure_appearance_enforcer() {
    cat > /usr/local/bin/onion-apply-appearance << 'APPLYAPPEARANCE'
#!/usr/bin/env bash
# Onion OS 外观强制应用 - 每次登录运行，确保美化生效
WALL_PNG="/usr/share/backgrounds/onion-os/default.png"
WALL_1366="/usr/share/backgrounds/onion-os/default-1366x768.png"

# 等待 xfdesktop / xfconfd 就绪
for i in $(seq 1 15); do
    if xfconf-query -c xfce4-desktop -l &>/dev/null; then break; fi
    sleep 1
done

# 低分辨率优先使用小尺寸壁纸，减小内存占用
WALL="${WALL_PNG}"
RES=$(xrandr --current 2>/dev/null | grep '\*' | head -1 | awk '{print $1}')
W=$(echo "${RES}" | cut -d'x' -f1)
if [[ -n "${W}" && "${W}" -le 1366 && -f "${WALL_1366}" ]]; then
    WALL="${WALL_1366}"
fi

# 对每一个真实 backdrop 属性（逐显示器/逐工作区）套用壁纸。
# 这样无论连接器叫 monitorVGA-1 / monitorHDMI-1 / monitorscreen 都能命中。
mapfile -t PROPS < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$')
if [[ ${#PROPS[@]} -eq 0 ]]; then
    # 没有现成属性时，手动建一个通用的
    xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/monitorscreen/workspace0/last-image \
        -n -t string -s "${WALL}" 2>/dev/null || true
    xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/monitorscreen/workspace0/image-style \
        -n -t int -s 5 2>/dev/null || true
else
    for p in "${PROPS[@]}"; do
        xfconf-query -c xfce4-desktop -p "${p}" -s "${WALL}" 2>/dev/null || true
        # 同步设置缩放方式为 5 (zoomed/拉伸填充)
        style_prop="${p%/last-image}/image-style"
        xfconf-query -c xfce4-desktop -p "${style_prop}" -n -t int -s 5 2>/dev/null || true
    done
fi

# 强制主题/图标主题（防止首次会话回退到默认）
xfconf-query -c xsettings -p /Net/ThemeName -s "Onion-Glass" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/theme -s "Arc-Darker" 2>/dev/null || true

# 刷新桌面
xfdesktop --reload 2>/dev/null || true

# 确保 Plank Dock 在运行（picom 启动后）
if command -v plank &>/dev/null && ! pgrep -x plank &>/dev/null; then
    (sleep 1 && nohup plank >/dev/null 2>&1 &) 2>/dev/null || true
fi

exit 0
APPLYAPPEARANCE
    chmod +x /usr/local/bin/onion-apply-appearance

    # 登录自启动（在 picom/plank 之后，phase=Applications）
    local autostart_dir="/home/${ONION_USER}/.config/autostart"
    mkdir -p "${autostart_dir}"
    cat > "${autostart_dir}/onion-apply-appearance.desktop" << 'APPLYAUTO'
[Desktop Entry]
Type=Application
Name=Onion Appearance
Comment=确保 Onion OS 外观正确应用
Exec=/usr/local/bin/onion-apply-appearance
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
X-GNOME-Autostart-Delay=3
APPLYAUTO
    chown -R "${ONION_USER}:${ONION_USER}" "${autostart_dir}/onion-apply-appearance.desktop"
}

# ======================== 主流程 ========================

main() {
    echo "=====> [03_desktop] 开始 Onion OS 26.1.0 macOS Dock 桌面定制 <====="

    generate_onion_icons
    configure_hidpi_autoscale
    install_themes
    setup_wallpaper
    configure_xfce_settings      # 先写桌面/xfwm/xsettings（含壁纸 backdrop）
    configure_xfce_panel         # 顶部 macOS 菜单栏
    configure_plank_dock         # 底部可放大 Dock
    configure_picom
    configure_notification_filter
    configure_simplified_menus   # 只动 Thunar 右键菜单，不再覆盖桌面/xfwm 配置
    configure_autostart
    deploy_live_installer
    setup_welcome_wizard
    configure_appearance_enforcer  # 最后部署登录期自愈强制应用

    echo "=====> [03_desktop] Onion OS 26.1.0 macOS Dock 桌面定制完成 <====="
}

main
