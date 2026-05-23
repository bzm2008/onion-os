# Onion OS 26.0.3 - 执行指南

## 重要说明

**当前环境：Windows**  
此项目需要在 **Linux 环境**（推荐 Debian 12 或 Ubuntu 22.04+）中执行构建。

## 已完成的工作

### 1. 新增文件

| 文件路径 | 说明 |
|---------|------|
| `config/security/onion-master.py` | Onion 安全管家主程序（图形化安全工具） |
| `config/security/nftables.conf` | nftables 防火墙配置文件 |
| `config/security/onion-firewall.service` | 防火墙 systemd 服务文件 |
| `modules/05_security_tools.sh` | 安全工具与 QQ 安装模块脚本 |

### 2. 更新的文件

| 文件路径 | 修改内容 |
|---------|---------|
| `build_onion_os.sh` | 添加了 05_security_tools.sh 模块到构建流程 |
| `config/preseed.cfg` | 添加了安全工具包到预装软件列表 |
| `README.md` | 更新了功能说明文档 |

## 功能概述

### Onion 安全管家
- 快速清理系统垃圾
- Rootkit 检测（rkhunter）
- 系统安全审计（lynis）
- 防火墙状态查看
- Garlic Claw 服务监控

### QQ Linux 版
- 腾讯官方最新版 QQ for Linux
- 自动创建桌面快捷方式

### 安全加固
- nftables 防火墙默认拒绝入站连接
- Garlic Claw Gateway 仅监听 127.0.0.1:18789

## 在 Linux 系统中构建

### 前置要求

1. **宿主系统**：Debian 12 (Bookworm) 或 Ubuntu 22.04+
2. **磁盘空间**：至少 15GB 可用空间
3. **内存**：至少 4GB RAM
4. **权限**：需要 root 权限

### 构建步骤

```bash
# 1. 进入项目目录
cd onion-os

# 2. 赋予所有脚本执行权限
chmod +x build_onion_os.sh modules/*.sh

# 3. 执行构建（需要 root 权限）
sudo ./build_onion_os.sh
```

### 构建产物

构建成功后，ISO 镜像将位于：
```
output/onion-os-26.0.3-home-amd64.iso
```

## 直接安装体验

本项目已升级为“直接安装”方案。构建出的 ISO 镜像包含了 **Calamares 图形化安装器**。

### 1. 安装过程
当您从 U 盘或虚拟机启动 ISO 后，系统会自动进入全屏的图形化安装向导。您只需按照向导提示：
- 选择语言和时区
- 选择键盘布局
- 划分磁盘分区（支持自动擦除全盘或手动分区）
- 创建您的用户名和密码

### 2. 离线且极速
安装过程完全离线，所有预装的软件（WPS、微信、Garlic Claw、安全工具等）都已打包在 `squashfs` 中，安装仅仅是文件复制过程，通常在几分钟内即可完成。

## 常见问题

### Q: 为什么当前是 Windows 环境？
A: 此项目需要在 Linux 环境中构建。请将整个 `onion-os` 目录复制到 Debian/Ubuntu 系统中执行。

### Q: chroot 目录为空怎么办？
A: `build_onion_os.sh` 会自动通过 `debootstrap` 重新构建完整的 chroot 环境。

### Q: 如何测试安装镜像？
A: 使用 VirtualBox/VMware 挂载 ISO 并启动测试，或使用 `qemu`：
```bash
qemu-system-x86_64 -cdrom output/onion-os-26.0.3-home-amd64.iso -m 4G -enable-kvm
```

## 文件清单

```
onion-os/
├── build_onion_os.sh              # 主构建脚本（已更新）
├── modules/
│   ├── 01_base.sh
│   ├── 02_apps.sh
│   ├── 03_desktop.sh
│   ├── 04_garlic_claw.sh
│   └── 05_security_tools.sh      # 新增：安全工具模块
├── config/
│   ├── preseed.cfg                # 已更新：预装安全工具
│   └── security/
│       ├── onion-master.py        # 新增：安全管家主程序
│       ├── nftables.conf          # 新增：防火墙配置
│       └── onion-firewall.service # 新增：防火墙服务
├── README.md                       # 已更新：功能说明
└── EXECUTION_GUIDE.md             # 本文档
```
