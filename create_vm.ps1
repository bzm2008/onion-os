# 创建 Onion OS 虚拟机
# 请以管理员身份运行 PowerShell

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$VMName = "Onion-OS-26.0.1"
$ISOPath = "E:\llinux os\onion-os\onion-os-26.0.1-home-amd64.iso"
$VMPath = "E:\VirtualBox VMs"

Write-Host "=== 创建 Onion OS 虚拟机 ===" -ForegroundColor Green
Write-Host ""

# 检查 ISO 文件
if (-not (Test-Path $ISOPath)) {
    Write-Host "错误：找不到 ISO 文件: $ISOPath" -ForegroundColor Red
    exit
}

Write-Host "ISO 文件: $ISOPath" -ForegroundColor Cyan
Write-Host ""

# 创建虚拟机目录
New-Item -ItemType Directory -Force -Path $VMPath | Out-Null

# 1. 创建虚拟机
Write-Host "步骤 1: 创建虚拟机..." -ForegroundColor Yellow
& $VBoxManage createvm --name $VMName --ostype "Debian_64" --register --basefolder $VMPath

# 2. 配置硬件
Write-Host "步骤 2: 配置硬件..." -ForegroundColor Yellow
# 内存 4GB
& $VBoxManage modifyvm $VMName --memory 4096
# 2个CPU
& $VBoxManage modifyvm $VMName --cpus 2
# 启用 IO APIC
& $VBoxManage modifyvm $VMName --ioapic on
# 启用 EFI（可选，传统BIOS更兼容）
# & $VBoxManage modifyvm $VMName --firmware efi

# 3. 创建虚拟硬盘
Write-Host "步骤 3: 创建虚拟硬盘..." -ForegroundColor Yellow
$DiskPath = "$VMPath\$VMName\$VMName.vdi"
& $VBoxManage createhd --filename $DiskPath --size 20480 --format VDI

# 4. 添加存储控制器
Write-Host "步骤 4: 配置存储..." -ForegroundColor Yellow
& $VBoxManage storagectl $VMName --name "SATA Controller" --add sata --controller IntelAhci
& $VBoxManage storageattach $VMName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $DiskPath

# 5. 添加光驱并挂载 ISO
& $VBoxManage storagectl $VMName --name "IDE Controller" --add ide
& $VBoxManage storageattach $VMName --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $ISOPath

# 6. 配置显卡（VBoxSVGA + 足够显存可减少 Linux 客户机黑屏；3D 在部分主机上反而不稳定故关闭）
Write-Host "步骤 5: 配置显卡..." -ForegroundColor Yellow
& $VBoxManage modifyvm $VMName --vram 256
& $VBoxManage modifyvm $VMName --graphicscontroller vboxsvga
& $VBoxManage modifyvm $VMName --accelerate3d off

# 7. 配置网络
Write-Host "步骤 6: 配置网络..." -ForegroundColor Yellow
& $VBoxManage modifyvm $VMName --nic1 nat

# 8. 启用远程桌面（可选）
# & $VBoxManage modifyvm $VMName --vrde on

# 9. 设置启动顺序
& $VBoxManage modifyvm $VMName --boot1 dvd
& $VBoxManage modifyvm $VMName --boot2 disk

Write-Host ""
Write-Host "=== 虚拟机创建完成！===" -ForegroundColor Green
Write-Host ""
Write-Host "虚拟机名称: $VMName" -ForegroundColor Cyan
Write-Host "内存: 4GB" -ForegroundColor Cyan
Write-Host "CPU: 2核" -ForegroundColor Cyan
Write-Host "硬盘: 20GB" -ForegroundColor Cyan
Write-Host "ISO: $ISOPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "启动命令:" -ForegroundColor Yellow
Write-Host "  & '$VBoxManage' startvm '$VMName'" -ForegroundColor White
Write-Host ""
Write-Host "或者在 VirtualBox 管理界面中手动启动" -ForegroundColor Yellow
Write-Host ""

# 自动启动
$start = Read-Host "是否立即启动虚拟机? (Y/N)"
if ($start -eq "Y" -or $start -eq "y") {
    Write-Host "正在启动虚拟机..." -ForegroundColor Green
    & $VBoxManage startvm $VMName
}
