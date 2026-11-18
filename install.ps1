<#
.SYNOPSIS
  PS 输入法助手 · 一键安装器（Windows PowerShell 5.1+，普通用户权限）

.DESCRIPTION
  从 GitHub 克隆项目后运行本脚本，自动完成：
  1. 安装 AutoHotkey v1.1（已有则跳过；本地无安装包时从官方源下载并校验 SHA256）
  2. 部署核心脚本到 D:\AutoHotkey\Scripts，并确保 UTF-8 BOM
  3. 注册开机自启（HKCU Run，无需管理员权限）
  4. 启动脚本并执行安装后自检

.PARAMETER InstallDir
  AutoHotkey 安装目录，默认 D:\AutoHotkey

.PARAMETER SetupExe
  本地安装包路径，用于离线安装。不传时优先用脚本同目录的
  AutoHotkey_*_setup.exe，仍没有则从官方 GitHub Release 下载。

.PARAMETER NoStart
  仅安装部署，不立即启动脚本。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -SetupExe C:\Downloads\AutoHotkey_1.1.37.02_setup.exe
#>
[CmdletBinding()]
param(
    [string]$InstallDir = 'D:\AutoHotkey',
    [string]$SetupExe,
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- 固定常量（官方发布版本，可复核）----
$AhkVersion = '1.1.37.02'
$AhkExeName = "AutoHotkey_${AhkVersion}_setup.exe"
$AhkUrl     = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v${AhkVersion}/${AhkExeName}"
$AhkSha256  = '49A48E879F7480238D2FE17520AC19AFE83685AAC0B886719F9E1EAC818B75CC'
$ScriptName = 'PS_AutoIME.ahk'

$RepoDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$AhkExe     = Join-Path $InstallDir 'AutoHotkey.exe'
$ScriptsDir = Join-Path $InstallDir 'Scripts'
$DstScript  = Join-Path $ScriptsDir $ScriptName
$RunKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$RunName    = 'PS_AutoIME'

function Write-Step  ($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok    ($msg) { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn2 ($msg) { Write-Host "    [!]  $msg" -ForegroundColor Yellow }

# ---- 0. 检查核心脚本 ----
$srcScript = Join-Path $RepoDir $ScriptName
if (-not (Test-Path -LiteralPath $srcScript)) {
    throw "未找到核心脚本 $srcScript 。请在项目根目录运行本脚本。"
}

# ---- 1. 安装 AutoHotkey ----
Write-Step '检查 AutoHotkey 运行时'
if (Test-Path -LiteralPath $AhkExe) {
    Write-Ok "已安装：$AhkExe"
} else {
    $setupPath = $null
    $downloaded = $false

    if ($SetupExe -and (Test-Path -LiteralPath $SetupExe)) {
        $setupPath = $SetupExe
    }
    if (-not $setupPath) {
        $local = Get-ChildItem -LiteralPath $RepoDir -Filter 'AutoHotkey_*_setup.exe' -File -ErrorAction SilentlyContinue |
                 Select-Object -First 1
        if ($local) { $setupPath = $local.FullName }
    }
    if (-not $setupPath) {
        $setupPath = Join-Path $env:TEMP $AhkExeName
        Write-Host "    本地无安装包，正在从官方源下载 $AhkExeName ..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $AhkUrl -OutFile $setupPath -UseBasicParsing
        $downloaded = $true
        Write-Ok "下载完成：$setupPath"
    }

    $hash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash
    if ($hash -ne $AhkSha256) {
        if ($downloaded) { Remove-Item -LiteralPath $setupPath -Force -ErrorAction SilentlyContinue }
        throw "安装包 SHA256 校验失败！期望 $AhkSha256，实际 $hash 。已停止安装。"
    }
    Write-Ok 'SHA256 校验通过'

    Write-Host "    静默安装到 $InstallDir ..." -ForegroundColor Gray
    Start-Process -FilePath $setupPath -ArgumentList '/S', '/U64', "/D=$InstallDir" -Wait
    if (-not (Test-Path -LiteralPath $AhkExe)) {
        throw "安装后仍未找到 $AhkExe ，请手动安装 AutoHotkey 后重试。"
    }
    Write-Ok "安装完成：$AhkExe"
    if ($downloaded) { Remove-Item -LiteralPath $setupPath -Force -ErrorAction SilentlyContinue }
}

# ---- 2. 部署核心脚本并规范编码 ----
Write-Step '部署核心脚本'
New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null
$text = [IO.File]::ReadAllText($srcScript, [Text.Encoding]::UTF8)
$text = $text.TrimStart([char]0xFEFF)
[IO.File]::WriteAllText($DstScript, $text, (New-Object Text.UTF8Encoding($true)))
Write-Ok "脚本已部署：$DstScript"
Write-Ok 'UTF-8 BOM 已规范化（避免中文注释乱码）'

# ---- 3. 注册开机自启 ----
Write-Step '注册开机自启'
$cmd = '"{0}" "{1}"' -f $AhkExe, $DstScript
New-ItemProperty -Path $RunKey -Name $RunName -Value $cmd -PropertyType String -Force | Out-Null
Write-Ok "自启项 $RunName = $cmd"

# ---- 4. 启动 ----
if (-not $NoStart) {
    Write-Step '启动脚本'
    Start-Process -FilePath $AhkExe -ArgumentList ('"{0}"' -f $DstScript)
    Write-Ok '已启动，请查看任务栏托盘绿色 H 图标'
}

# ---- 5. 安装后自检 ----
Write-Step '安装后自检'
$bom = [IO.File]::ReadAllBytes($DstScript)[0..2] -join ','
$checks = [ordered]@{
    'AutoHotkey 主程序'   = (Test-Path -LiteralPath $AhkExe)
    '核心脚本已部署'       = (Test-Path -LiteralPath $DstScript)
    '脚本含 UTF-8 BOM'     = ($bom -eq '239,187,191')
    '开机自启已注册'       = ((Get-ItemProperty -Path $RunKey -Name $RunName -ErrorAction SilentlyContinue).$RunName -eq $cmd)
}
foreach ($k in $checks.Keys) {
    if ($checks[$k]) { Write-Ok $k } else { Write-Warn2 "$k —— 未通过，请人工检查" }
}

Write-Host "`n安装完成。下一步：打开 Photoshop，按 Ctrl+Alt+F10 切中文、Ctrl+Alt+F9 切英文做验证。" -ForegroundColor Cyan
