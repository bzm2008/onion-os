# Onion OS 26.1.0 - 执行指南

## 重要说明

**当前开发/构建环境：Windows + WSL Debian**  
Onion OS 的 ISO 构建需要在 Linux 环境中执行（推荐 Debian 12 / Ubuntu 22.04+；本机使用 WSL Debian 完成构建）。Windows 工作区只保存源码与最终复制出的 ISO。

## 26.1.0 已完成的工作

### 1. 版本目标

26.1.0 基于 26.0.6 开发，重点解决历史版本“桌面美化没有真正应用到安装后系统”的问题，并将桌面体验升级为更接近 macOS 的开箱即用风格。

核心目标：
- 类 macOS 顶部细菜单栏 + 底部 Dock；
- Plank 真 Dock，支持悬停放大、弹跳动画与玻璃风主题；
- Picom 主线兼容配置，提供 dual_kawase 模糊、圆角、柔光阴影、渐入渐出；
- `/etc/skel` 配置固化，确保 Calamares 创建的新用户继承主题、壁纸、Dock 与自启动项；
- `onion-apply-appearance` 登录自愈，逐显示器强制应用壁纸、主题、Picom、Plank 与缩放；
- 自动 HiDPI / 小屏 / 超宽屏适配；
- 保留老旧显卡、低分辨率、安全模式、低内存模式等启动入口。

### 2. 新增/重点文件

| 文件路径 | 说明 |
|---------|------|
| `modules/07_finalize.sh` | 构建收尾模块：同步用户配置到 `/etc/skel`，校验关键美化资源，防止安装后丢失主题/Dock |
| `modules/03_desktop.sh` | 26.1.0 桌面核心：Onion-Glass 主题、Plank Dock、Picom、壁纸、欢迎引导、自动缩放、登录自愈 |
| `repackage_2610_iso.sh` | 本地临时重封装脚本，用于在 chroot 热修补后重新生成 26.1.0 ISO |
| `build-logs/build-26.1.0-20260606-014925.log` | 本机构建日志，记录完整构建成功与 `BUILD_EXIT_CODE=0` |

### 3. 更新的文件

| 文件路径 | 修改内容 |
|---------|---------|
| `build_onion_os.sh` | 版本更新为 `26.1.0`，构建流程加入 `07_finalize.sh` |
| `README.md` | 更新为 26.1.0 功能说明、桌面布局、构建产物路径 |
| `EXECUTION_GUIDE.md` | 本文档，更新当前构建与验证口径 |
| `modules/02_apps.sh` | 安装 Plank、Picom、显示/音频/硬件适配相关工具 |
| `modules/03_desktop.sh` | 重写桌面体验，确保美化写入用户配置并可同步到 `/etc/skel` |

## 在 Linux/WSL 中构建

### 前置要求

1. **宿主系统**：Debian 12/13、Ubuntu 22.04+ 或 WSL Debian；
2. **磁盘空间**：至少 15GB 可用空间，推荐 30GB+；
3. **内存**：至少 4GB RAM，推荐 8GB+；
4. **权限**：需要 root 权限；
5. **网络**：构建时需要访问 Debian 镜像源和第三方软件源。

### 构建步骤

```bash
# 1. 进入项目目录
cd onion-os

# 2. 赋予脚本执行权限
chmod +x build_onion_os.sh modules/*.sh

# 3. 执行构建（需要 root 权限）
sudo ./build_onion_os.sh
```

### 构建产物

构建成功后，ISO 镜像会复制到本地工作区：

```text
output/onion-os-26.1.0-home-amd64.iso
```

本机当前镜像绝对路径：

```text
e:\llinux os\onion-os\output\onion-os-26.1.0-home-amd64.iso
```

> 注意：`output/` 和 `*.iso` 已被 `.gitignore` 排除，ISO 文件不会直接提交到 GitHub。GitHub 仓库只保存源码、构建脚本和文档。

## 本次构建验证结果

本机 26.1.0 构建日志：

```text
build-logs/build-26.1.0-20260606-014925.log
```

关键结果：

- `07_finalize.sh` 已执行；
- `/etc/skel` 同步完成；
- 关键美化资源校验通过：`全部关键美化资源就位 ✓`；
- `grub-mkrescue` 成功生成 ISO；
- ISO 已复制到 Windows 输出目录；
- 日志结尾包含 `BUILD_EXIT_CODE=0`。

已验证当前 ISO 中包含：

- `/live/filesystem.squashfs`；
- `/boot/grub/grub.cfg`；
- `启动 Onion OS 26.1.0 Home` GRUB 菜单字符串。

## 启动与安装

### 1. U 盘安装

使用 Rufus、Ventoy 或 Linux `dd` 将 ISO 写入 U 盘：

```bash
sudo dd if=output/onion-os-26.1.0-home-amd64.iso of=/dev/sdX bs=4M status=progress
```

从 U 盘启动后，系统会进入 Live 桌面并自动弹出 Calamares 图形化安装器。

### 2. 虚拟机体验

推荐配置：

- 2 核 CPU；
- 4GB 内存（最低 2GB）；
- 20GB+ 虚拟硬盘；
- 显卡优先使用默认 VMSVGA/VMware SVGA；
- 如黑屏或分辨率异常，选择 GRUB 中的兼容模式/低分辨率模式。

QEMU 示例：

```bash
qemu-system-x86_64 -cdrom output/onion-os-26.1.0-home-amd64.iso -m 4G -enable-kvm
```

## 桌面体验说明

26.1.0 默认桌面结构：

- 顶部：Xfce 细菜单栏，左侧 Onion 菜单，右侧网络/音量/电池/时钟；
- 底部：Plank Dock，包含浏览器、文件管理器、应用商店、微信、Garlic Claw、系统更新、设置；
- 背景：Onion OS 紫色渐变壁纸；
- 视觉：Onion-Glass 深紫液态玻璃主题；
- 动画：Plank 悬停放大/弹跳 + Picom 模糊/圆角/淡入淡出；
- 首次登录：欢迎向导 + Wi-Fi 引导；
- 每次登录：`onion-apply-appearance` 自动修正主题、壁纸、Dock 与缩放。

## 常见问题

### Q: 为什么 ISO 不上传 GitHub？

A: ISO 体积约 1.4GB，属于构建产物，已通过 `.gitignore` 排除。GitHub 仓库只同步源码、脚本和文档；ISO 留在本机 `output/` 目录，后续如需发布应上传到专门的下载/OTA 存储。

### Q: 为什么之前美化没有应用？

A: 历史版本主要把配置写进 live 用户家目录，安装后 Calamares 新建用户不会继承；此外 Picom 配置包含主线版本不支持的动画语法，可能导致合成器启动失败。26.1.0 通过 `/etc/skel`、`07_finalize.sh` 和 `onion-apply-appearance` 解决这些问题。

### Q: 如果启动后没有 Dock 怎么办？

A: 先等待 2-5 秒，Plank 会在登录后延迟启动。如果仍未出现，可在终端执行：

```bash
onion-apply-appearance
plank &
```

### Q: 如果老旧显卡动画卡顿怎么办？

A: 使用 GRUB 的兼容模式/低分辨率模式启动，Picom 会自动回退到 xrender fallback 配置，保留基本阴影和淡入淡出。

## 文件清单

```text
onion-os/
├── build_onion_os.sh              # 主构建脚本（26.1.0）
├── modules/
│   ├── 01_base.sh                 # 基础系统/内核/网络/硬件适配
│   ├── 02_apps.sh                 # Xfce/Plank/Picom/应用/字体/工具
│   ├── 03_desktop.sh              # 桌面、Dock、主题、壁纸、欢迎向导、登录自愈
│   ├── 04_garlic_claw.sh          # Garlic Claw AI 助手
│   ├── 05_security_tools.sh       # 安全工具模块
│   ├── 06_ota_update.sh           # OTA 更新系统
│   └── 07_finalize.sh             # 收尾固化与美化资源校验
├── config/
│   ├── preseed.cfg
│   └── security/
├── output/                        # 本机构建产物（git 忽略）
│   └── onion-os-26.1.0-home-amd64.iso
├── README.md
└── EXECUTION_GUIDE.md
```
