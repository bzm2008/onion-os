# 将 ISO 刻录到 U 盘
# 请以管理员身份运行 PowerShell，然后执行此脚本

param(
    [string]$DriveLetter = "D",
    [string]$IsoPath = "E:\llinux os\onion-os\output\onion-os-26.0.3-home-amd64.iso"
)

Write-Host "=== Onion OS ISO 刻录工具 ===" -ForegroundColor Green
Write-Host ""

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "错误：请以管理员身份运行 PowerShell！" -ForegroundColor Red
    Write-Host "右键点击 PowerShell 图标，选择'以管理员身份运行'" -ForegroundColor Yellow
    pause
    exit
}

# 检查 ISO 文件
if (-not (Test-Path $IsoPath)) {
    Write-Host "错误：找不到 ISO 文件: $IsoPath" -ForegroundColor Red
    pause
    exit
}

Write-Host "ISO 文件: $IsoPath" -ForegroundColor Cyan
Write-Host "目标盘符: ${DriveLetter}:" -ForegroundColor Cyan
Write-Host ""

# 获取磁盘编号
$volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
if (-not $volume) {
    Write-Host "错误：找不到 ${DriveLetter}: 盘" -ForegroundColor Red
    pause
    exit
}

$partition = Get-Partition -DriveLetter $DriveLetter
$disk = Get-Disk -Number $partition.DiskNumber

Write-Host "磁盘信息:" -ForegroundColor Yellow
Write-Host "  磁盘编号: $($disk.Number)" -ForegroundColor White
Write-Host "  磁盘名称: $($disk.FriendlyName)" -ForegroundColor White
Write-Host "  磁盘大小: $([math]::Round($disk.Size/1GB, 2)) GB" -ForegroundColor White
Write-Host ""

# 警告
Write-Host "⚠️  警告：这将清空 ${DriveLetter}: 盘的所有数据！" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "输入 YES 确认刻录"

if ($confirm -ne "YES") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    pause
    exit
}

# 使用 diskpart 清理磁盘并写入 ISO
Write-Host ""
Write-Host "步骤 1: 清理磁盘..." -ForegroundColor Yellow

$diskpartScript = @"
select disk $($disk.Number)
clean
convert mbr
exit
"@

$diskpartScript | diskpart | Out-Null

Write-Host "步骤 2: 挂载 ISO..." -ForegroundColor Yellow
$isoDrive = (Mount-DiskImage -ImagePath $IsoPath -PassThru | Get-Volume).DriveLetter
Write-Host "ISO 已挂载到 ${isoDrive}:" -ForegroundColor Green

Write-Host "步骤 3: 复制文件到 U 盘..." -ForegroundColor Yellow

# 创建新分区并格式化
$diskpartScript2 = @"
select disk $($disk.Number)
create partition primary
format fs=fat32 quick label=ONION-OS
assign letter=$DriveLetter
active
exit
"@

$diskpartScript2 | diskpart | Out-Null

# 复制 ISO 内容
$sourcePath = "${isoDrive}:"
$destPath = "${DriveLetter}:"

Write-Host "正在复制文件，请耐心等待..." -ForegroundColor Yellow
Copy-Item -Path "$sourcePath\*" -Destination $destPath -Recurse -Force

Write-Host "步骤 4: 卸载 ISO..." -ForegroundColor Yellow
Dismount-DiskImage -ImagePath $IsoPath

Write-Host ""
Write-Host "✅ 刻录完成！${DriveLetter}: 盘现在可以用来启动 Onion OS 了！" -ForegroundColor Green
Write-Host ""
Write-Host "使用方法：" -ForegroundColor Cyan
Write-Host "  1. 重启电脑" -ForegroundColor White
Write-Host "  2. 按 F12/F2/DEL 进入启动菜单（不同电脑按键不同）" -ForegroundColor White
Write-Host "  3. 选择从 USB 启动" -ForegroundColor White
Write-Host ""

pause
