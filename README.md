# Onion OS 26.1.0 Home Edition

> 层层精简，层层用心

Onion OS 是一款基于 Debian 12 (Bookworm) 的定制 Linux 桌面操作系统，专为老旧硬件（2GB+ 内存）和电脑初学者设计。系统自带**离线图形化安装器**，安装后无需命令行操作，所有功能均可通过图形界面完成。

26.1.0 核心改进：
- **真·macOS 风格 Dock**：底部 Plank 程序坞，悬停放大 + 弹跳动画，顶部细菜单栏放系统托盘/时钟
- **美化必达**：所有桌面配置写入 `/etc/skel`，安装后的新用户也能继承主题、壁纸与 Dock（修复历史顽疾）
- **液态玻璃风格**：半透明深紫主题 + dual_kawase 模糊 + 圆角 + 柔光阴影
- **稳定的合成器**：Picom 配置改用主线 10.x 兼容写法，杜绝因解析失败而黑屏/无效果
- **登录自愈**：`onion-apply-appearance` 每次登录强制套用壁纸/主题/Dock，逐显示器适配
- **智能缩放**：开机自动检测分辨率，适配 DPI / 顶栏高度 / Dock 图标 / 字体大小
- **WiFi 即连**：全系无线固件 + iwd 后端 + rfkill 自解锁

---

## 项目简介

| 项目 | 说明 |
|------|------|
| 名称 | Onion OS |
| 版本 | 26.1.0 Home Edition |
| 底层系统 | Debian 12 (Bookworm) Stable |
| 桌面环境 | Xfce 4.18 + Plank Dock |
| 窗口合成器 | Picom (glx + dual_kawase blur + 圆角) |
| 显示管理器 | LightDM（自动登录） |
| 系统语言 | 简体中文 (zh_CN.UTF-8) |
| 网络管理 | NetworkManager + iwd |
| WiFi 固件 | Intel / Realtek / Atheros / Broadcom / Mediatek |
| AI 助手 | Garlic Claw（基于 OpenClaw） |

## 技术架构

```
┌─────────────────────────────────────────────┐
│             Onion OS 26.1.0                  │
├─────────────────────────────────────────────┤
│  Garlic Claw (AI)  │  应用商店 (Flatpak)    │
├─────────────────────────────────────────────┤
│  WPS Office │ 微信 │ Firefox ESR │ Fcitx5   │
├─────────────────────────────────────────────┤
│  Xfce 4.18 + Plank Dock + Picom 液态玻璃    │
├─────────────────────────────────────────────┤
│  LightDM + Plymouth │ NM + iwd │ 自动缩放   │
├─────────────────────────────────────────────┤
│  Debian 12 (Bookworm) + Linux Kernel        │
├─────────────────────────────────────────────┤
│  nftables 防火墙 │ systemd │ sudo           │
└─────────────────────────────────────────────┘
```

## 项目结构

```
onion-os/
├── build_onion_os.sh          # 主构建脚本
├── modules/                   # 模块脚本
│   ├── 01_base.sh             # 基础系统配置
│   ├── 02_apps.sh             # 应用软件安装
│   ├── 03_desktop.sh          # 桌面定制与美化
│   └── 04_garlic_claw.sh      # Garlic Claw AI 助手
├── config/                    # 配置文件
│   ├── preseed.cfg            # Debian 自动安装应答
│   ├── desktop-files/         # .desktop 启动器
│   ├── xfce-panel/            # Xfce 面板配置
│   ├── thunar-uca/            # Thunar 右键菜单
│   ├── first-run/             # 首次配置向导
│   ├── security/              # 安全加固配置
│   └── lightdm/               # LightDM 配置
└── artwork/                   # 壁纸与品牌素材
```

## 构建方法

### 环境要求

- **宿主系统**：Debian 12 (Bookworm) 或 Ubuntu 22.04+
- **磁盘空间**：至少 15GB 可用空间
- **内存**：至少 4GB RAM
- **网络**：需要稳定的互联网连接（国内镜像源）

### 构建步骤

```bash
# 1. 克隆项目
git clone https://github.com/your-org/onion-os.git
cd onion-os

# 2. 赋予执行权限
chmod +x build_onion_os.sh modules/*.sh

# 3. 执行构建（需要 root 权限）
sudo ./build_onion_os.sh
```

构建完成后，ISO 镜像文件位于 `output/onion-os-26.1.0-home-amd64.iso`。

### 构建流程

```
build_onion_os.sh
  ├── 1. 环境检查与依赖安装
  ├── 2. debootstrap 构建 base 系统
  ├── 3. chroot 环境执行模块脚本
  │   ├── 01_base.sh            → APT源/内核/语言/用户/网络/系统标识
  │   ├── 02_apps.sh            → Xfce/Plank/LightDM/WPS/微信/Firefox/Fcitx5/应用商店
  │   ├── 03_desktop.sh         → 主题/壁纸/顶栏/Plank Dock/Picom/右键菜单/自启动
  │   ├── 04_garlic_claw.sh     → Node.js/OpenClaw/Gateway/防火墙/配置向导
  │   ├── 05_security_tools.sh  → Onion安全管家/安全扫描工具/QQ Linux版
  │   ├── 06_ota_update.sh      → OTA 更新客户端/systemd 定时器/GUI 更新工具
  │   └── 07_finalize.sh        → 配置固化到 /etc/skel（确保安装后美化生效）
  ├── 4. 生成 initramfs
  ├── 5. 清理 chroot
  └── 6. 打包 ISO 镜像
```

## 安装方法

### 方式一：U 盘安装（推荐）

1. 使用 Rufus（Windows）或 dd（Linux）将 ISO 写入 U 盘：
   ```bash
   sudo dd if=onion-os-26.1.0-home-amd64.iso of=/dev/sdX bs=4M status=progress
   ```
2. 将 U 盘插入目标电脑，从 U 盘启动
3. 系统启动后会**自动全屏弹出图形化安装程序 (Calamares)**。
4. 按照向导提示进行分区、创建用户，等待安装完成即可直接重启进入系统。

### 方式二：虚拟机体验

1. 在 VirtualBox / VMware 中创建新虚拟机
2. 分配 2GB+ 内存、20GB+ 磁盘
3. 挂载 ISO 镜像启动
4. 在启动向导中选择 "Install Onion OS 26.1.0" 进行一键安装。

### 桌面布局 (26.1.0 macOS 风格)

```
┌──────────────────────────────────────────────┐
│ 🧅 Onion OS                          🔊 📶 🕐 │  ← 顶部细菜单栏 (玻璃)
├──────────────────────────────────────────────┤
│                                              │
│          桌面壁纸 (Onion OS 紫色渐变)          │
│                                              │
│                                              │
│      ╭────────────────────────────────╮      │
│      │ 🌐 📁 🛒 💬 🧄 ⟳ ⚙   (悬停放大) │      │  ← 底部 Plank Dock
│      ╰────────────────────────────────╯      │
└──────────────────────────────────────────────┘
```

- 顶栏左侧 Onion 开始菜单，右侧网络/音量/电池/时钟
- 底部 Plank Dock 居中排列常用应用，鼠标悬停时图标放大 1.5x

### 智能缩放 (HiDPI)

系统首次登录时自动检测屏幕分辨率并调整界面大小（顶栏高度 + Dock 图标 + 字体）：

| 分辨率 | DPI | 顶栏高度 | Dock 图标 | 光标大小 | 字体大小 |
|--------|-----|---------|----------|---------|---------|
| 4K+ (≥3840) | 192 | 36px | 64px | 36 | 14 |
| 2K (≥2560) | 144 | 32px | 56px | 30 | 12 |
| 1080p (≥1920) | 96 | 30px | 48px | 24 | 11 |
| 768p-1080p | 96 | 26-28px | 40-44px | 22 | 10 |
| <768p | 96 | 24px | 30-34px | 18 | 9 |

可通过 `onion-scale` 命令手动重新缩放。

### Garlic Claw 命令

```bash
garlic-claw              # 启动 AI 对话
garlic-claw ask "问题"   # 直接提问
garlic-claw config       # 重新配置 API Key
garlic-claw status       # 查看 Gateway 服务状态
garlic-claw version      # 查看版本号
```

## 核心功能详解

### 1. 预装软件

- **WPS Office**：完整办公套件，兼容 Microsoft Office 格式
- **微信**：通过 deepin-wine 运行，支持基本聊天功能
- **Firefox ESR**：长期支持版浏览器，安全稳定
- **Fcitx5 拼音**：智能中文输入法，Shift 切换中英文
- **应用商店**：GNOME Software + Flathub，一键安装海量应用

### 2. Garlic Claw AI 助手

Garlic Claw 是 Onion OS 的标志性功能，基于 OpenClaw 深度定制：

- **独立终端客户端**：在独立终端窗口内与 AI 对话，无需浏览器
- **开机自启 Gateway**：登录后 AI 能力即就绪
- **安全加固**：服务端口仅监听 127.0.0.1，禁止远程访问
- **文件管理器集成**：右键任意文件即可让 AI 分析
- **多模型支持**：Kimi / OpenAI / DeepSeek / 智谱 GLM

### 5. 系统优化

- **swappiness=10**：减少交换分区使用，提升旧硬件响应
- **单工作区**：简化用户认知，避免工作区混淆
- **自动登录**：开机直接进入桌面，无需输入密码
- **sudo 免密**：安装软件无需反复输入密码
- **日志限容**：系统日志最大 200MB，防止磁盘膨胀

## 安全说明

- Garlic Claw Gateway 服务端口 (18789) 仅监听 `127.0.0.1`
- nftables 防火墙规则阻止外部访问 AI 服务端口
- API Key 以 600 权限保存在 `~/.openclaw/config.json`
- 默认用户 `onion` 具有 sudo 权限（免密）
- root 账户已禁用直接登录

## 常见问题

**Q: 构建过程中 WPS/微信下载失败怎么办？**

A: 由于网络波动，第三方软件下载可能失败。这不影响系统构建，用户可以在系统安装后通过应用商店或手动下载安装。

**Q: Garlic Claw 提示"OpenClaw 未安装"怎么办？**

A: 在终端中运行以下命令完成安装：
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

**Q: 如何切换输入法？**

A: 按 `Shift` 键切换中英文输入，或点击右下角输入法图标选择。

**Q: 如何连接 Wi-Fi？**

A: 点击右下角网络图标 → 选择 Wi-Fi 名称 → 输入密码。

**Q: 系统对硬件的最低要求？**

A: 2GB 内存、20GB 磁盘空间、x86_64 处理器。推荐 4GB 内存以获得更流畅体验。

## 许可证

本项目基于 GPL-3.0 许可证开源。

各预装软件遵循其各自的开源或商业许可证：
- WPS Office: WPS 个人版许可协议
- 微信: 腾讯软件许可协议
- Firefox ESR: Mozilla Public License 2.0
- OpenClaw: 遵循 OpenClaw 官方许可
