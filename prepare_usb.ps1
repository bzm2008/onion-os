# 准备 U 盘用于刻录 ISO
# 请以管理员身份运行

Write-Host "=== Onion OS U盘准备工具 ===" -ForegroundColor Green
Write-Host ""

# 列出所有磁盘
Write-Host "可用磁盘列表：" -ForegroundColor Yellow
Get-Disk | Select-Object Number, FriendlyName, Size, BusType, MediaType | Format-Table -AutoSize

Write-Host ""
Write-Host "警告：请选择正确的磁盘编号！选择错误会清空硬盘数据！" -ForegroundColor Red
Write-Host ""

$diskNumber = Read-Host "请输入U盘的磁盘编号 (通常是 1 或 2)"

# 确认
Write-Host ""
Write-Host "你选择了磁盘 $diskNumber" -ForegroundColor Yellow
$confirm = Read-Host "确认要清空这个磁盘吗？(输入 YES 确认)"

if ($confirm -ne "YES") {
    Write-Host "操作已取消" -ForegroundColor Red
    exit
}

# 清理磁盘
Write-Host "正在清理磁盘 $diskNumber..." -ForegroundColor Yellow
Clear-Disk -Number $diskNumber -RemoveData -Confirm:$false

# 创建新分区
Write-Host "创建新分区..." -ForegroundColor Yellow
$partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize

# 格式化
Write-Host "格式化分区..." -ForegroundColor Yellow
Format-Volume -Partition $partition -FileSystem FAT32 -NewFileSystemLabel "ONION-OS" -Confirm:$false

# 分配盘符
Write-Host "分配盘符..." -ForegroundColor Yellow
$volume = Get-Partition -DiskNumber $diskNumber | Get-Volume
$driveLetter = $volume.DriveLetter

Write-Host ""
Write-Host "U盘准备完成！盘符: $driveLetter`:" -ForegroundColor Green
Write-Host ""
Write-Host "现在你可以用 Rufus 选择 $driveLetter`: 盘刻录 ISO 了" -ForegroundColor Green

pause
