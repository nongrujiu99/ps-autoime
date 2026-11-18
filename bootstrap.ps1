<#
.SYNOPSIS
  Git 一键安装入口：克隆仓库 → 调用 install.ps1 → 完成初始化。

.DESCRIPTION
  面向最终用户的最小操作入口。只需在一台干净的 Windows 电脑上执行一条命令，
  即可从公开仓库获取项目并自动完成 AutoHotkey 安装、脚本部署、开机自启与启动。

  本脚本不内置任何凭据；仓库为公开仓库，克隆走 HTTPS 匿名读取。

.PARAMETER InstallDir
  AutoHotkey 安装目录，默认 D:\AutoHotkey

.PARAMETER CloneDir
  克隆目标目录，默认 %TEMP%\ps-autoime

.PARAMETER RepoUrl
  仓库地址，默认 https://github.com/nongrujiu99/ps-autoime.git

.PARAMETER NoStart
  透传给 install.ps1：只安装不启动。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1 -InstallDir D:\Tools\AutoHotkey
#>
[CmdletBinding()]
param(
    [string]$InstallDir = 'D:\AutoHotkey',
    [string]$CloneDir   = (Join-Path $env:TEMP 'ps-autoime'),
    [string]$RepoUrl    = 'https://github.com/nongrujiu99/ps-autoime.git',
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'

function Write-Step ($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   ($msg) { Write-Host "    [OK] $msg" -ForegroundColor Green }

# ---- 0. 检查 git ----
Write-Step '检查 git'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw '未检测到 git。请先安装 Git for Windows：https://git-scm.com/download/win'
}
Write-Ok "git $(git --version)"

# ---- 1. 克隆仓库 ----
Write-Step "克隆仓库到 $CloneDir"
if (Test-Path -LiteralPath $CloneDir) {
    Write-Host '    目录已存在，执行 git pull 更新 ...' -ForegroundColor Gray
    git -C $CloneDir pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw 'git pull 失败，请检查本地是否有未提交改动。' }
} else {
    git clone --depth 1 $RepoUrl $CloneDir
    if ($LASTEXITCODE -ne 0) { throw 'git clone 失败，请检查网络或仓库地址。' }
}
Write-Ok '仓库就绪'

# ---- 2. 调用安装器 ----
$installer = Join-Path $CloneDir 'install.ps1'
if (-not (Test-Path -LiteralPath $installer)) {
    throw "克隆结果中缺少 install.ps1：$installer"
}
Write-Step '调用一键安装器'
$installArgs = @('-ExecutionPolicy', 'Bypass', '-File', $installer, '-InstallDir', $InstallDir)
if ($NoStart) { $installArgs += '-NoStart' }
& powershell @installArgs
if ($LASTEXITCODE -ne 0) { throw '安装器执行失败，请根据上方输出排查。' }

Write-Step '完成'
Write-Host "    项目位置：$CloneDir" -ForegroundColor Gray
Write-Host '    验证方法：打开 Photoshop，按 Ctrl+Alt+F10 / F9 测试输入法切换。' -ForegroundColor Cyan
