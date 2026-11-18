# PS 快捷键输入法助手（PS_AutoIME）

让 Photoshop 在**中文输入法状态下依然能用单字母快捷键**（B/V/M/T 等），同时不打断中文输入。

> 适用：Windows + AutoHotkey v1.1 + Photoshop（已在 PS CC 2018 / 19.1.5 验证）。脚本按进程名 `Photoshop.exe` 匹配，与 PS 版本无关。

---

## 一、项目简介

### 问题背景

在 PS 中按 `B`、`V`、`M` 等单字母快捷键时，如果输入法处于中文状态，字母会被输入法当成拼音吞掉并弹出候选框，PS 根本收不到按键，快捷键全部失效。

### 根因

Windows 键盘事件先送达输入法，再由输入法决定是否转发给应用：

| 输入法状态 | 字母键去向 | PS 快捷键 |
|---|---|---|
| 中文 | 被输入法拦截组词，弹候选框 | 失效 |
| 英文 | 直达 PS | 正常 |

这是系统层机制，**PS 内部没有任何设置可以绕开**。本项目不改 PS、不改按键映射，而是让"中文"只在你真正打字时出现：脚本识别你是否在 PS 里编辑文字，自动切换输入法。

### 项目文件

| 文件 | 用途 |
|---|---|
| `PS_AutoIME.ahk` | 核心脚本（AutoHotkey v1 语法，UTF-8 with BOM） |
| `install.ps1` | 一键安装器（检测/安装 + 部署 + 自启 + 自检） |
| `bootstrap.ps1` | Git 一键安装入口（克隆仓库 + 调用安装器） |
| `PS中文快捷键-解决方案与使用说明.md` | 方案对比、原理与完整使用说明（本文的深入版） |
| `LICENSE` / `.gitignore` | 许可证与仓库排除规则 |

> 第三方安装包 `AutoHotkey_*_setup.exe` **不在仓库中**，由安装器从官方源下载；仓库仅含脚本文本，体积小且可审计。

---

## 二、主要功能

- **自动切换**：进入 PS 文字编辑 → 自动切中文；退出编辑 → 自动切英文，快捷键即时恢复
- **多入口识别**：双击图层缩略图进入编辑、文字工具点击画布、I 形光标输入框均覆盖
- **编辑会话保持**：同一文字层内中英文混排时，你手动按 `Shift` 切出的英文状态不会被脚本覆盖
- **三种提交键**：`Esc`、`小键盘回车`、`Ctrl+回车` 退出编辑时自动切英文（主键盘回车是换行，故意不处理）
- **免配置**：自动枚举系统已加载的输入法布局，按语言 ID 识别中/英，无需手填 HKL 代码
- **强制中文**：切中文时调用 `ImmSetOpenStatus`，把搜狗从英文模式拨回中文
- **手动热键**：`Ctrl+Alt+F9/F10/F11/F12/F8` 分别用于切英文、切中文、暂停、查布局、看快照
- **日志诊断**：`PS_AutoIME.log` 记录每次点击的判断与切换结果，超过 400 KB 自动清空
- **开机自启**：写入注册表 `HKCU\...\Run`，普通用户权限即可
- **版本无关**：按进程名匹配，PS 升级到 2024/2025 仍可用

---

## 三、环境与依赖要求

| 项目 | 要求 | 备注 |
|---|---|---|
| 操作系统 | Windows（推荐 64 位） | 依赖 `imm32` 输入法接口 |
| Photoshop | 任意版本（已验证 CC 2018 19.1.5，64 位） | 按 `Photoshop.exe` 进程名匹配 |
| 输入法 | 一个中文输入法 + 一个英文键盘布局 | 已验证：搜狗拼音（`0804`）+ 美式键盘（`0409`）；脚本按语言 ID 自动识别 |
| AutoHotkey | **v1.1**（安装器固定下载 1.1.37.02） | **不要装 v2**，语法不兼容 |
| 脚本编码 | UTF-8 **with BOM** | 无 BOM 时 AHK 按 GBK 解析，中文注释与提示会乱码 |
| 权限 | 脚本与 PS 保持**同一权限级别** | PS 若以管理员运行，脚本也须以管理员运行，否则热键被 UIPI 拦截 |

---

## 四、安装教程

### 4.1 系统预设（建议先做，一次到位）

1. 输入法只保留两个：**中文输入法**（如搜狗拼音）+ **英语(美国) 美式键盘**。
2. 启用每应用独立输入法：控制面板 → 时钟和区域 → 语言 → 高级设置 → 勾选 **"允许我为每个应用窗口使用不同的输入法"**。
3. 搜狗建议设置：属性设置 → 常用 → 初始状态设为 **中文**；属性设置 → 按键 → 中英文切换改为 **Ctrl**（默认 Shift 画图时易误碰）。

### 4.2 图形界面安装（备选方式）

> 一键安装（第五章）会自动完成这一步。仅当你想手动控制安装选项时按本节操作：先从 [AutoHotkey 官方 Release](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v1.1.37.02) 下载 `AutoHotkey_1.1.37.02_setup.exe`，再按下面步骤。

1. 双击安装包。安装包无代码签名，SmartScreen 提示时选 **更多信息 → 仍要运行**。
2. 架构选 **Unicode 64-bit**（与 64 位 PS 及 `imm32` 接口位数一致，成功率最高）。
3. `location` 页设为 `D:\AutoHotkey`（纯英文、无空格；不要装进 `C:\Program Files` 或 PS 目录）。
4. `options` 页：勾选 **Install script compiler**、**Default to UTF-8**、**Enable drag & drop**；不勾选 Separate taskbar buttons、Add 'Run with UI Access'。
5. `install` 页点 Install，完成后 Close。
6. 验证：`D:\AutoHotkey\AutoHotkey.exe` 存在；任一 `.ahk` 文件右键菜单出现 **Run Script**。

> 安装包来自 AutoHotkey 官方 GitHub Release，SHA256：
> `49A48E879F7480238D2FE17520AC19AFE83685AAC0B886719F9E1EAC818B75CC`

### 4.3 部署脚本与自启

手动部署等价于一键脚本的第 2~4 步：

```powershell
New-Item -ItemType Directory -Force "D:\AutoHotkey\Scripts"
Copy-Item ".\PS_AutoIME.ahk" "D:\AutoHotkey\Scripts\PS_AutoIME.ahk" -Force
Start-Process "D:\AutoHotkey\AutoHotkey.exe" -ArgumentList '"D:\AutoHotkey\Scripts\PS_AutoIME.ahk"'
```

---

## 五、一键安装方式与命令

### 5.1 从 GitHub 一键安装（推荐）

在任意目录打开 PowerShell（**普通权限即可**），执行一条命令完成"克隆 + 安装 + 初始化"：

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/nongrujiu99/ps-autoime/main/bootstrap.ps1 | iex"
```

`bootstrap.ps1` 会依次：检查 git → 克隆仓库到 `%TEMP%\ps-autoime` → 调用 `install.ps1`。这是使用者获取项目后自动完成初始化的标准入口。

> 若你更希望**先克隆、再手动安装**（便于审阅代码后执行），分两步：
> ```powershell
> git clone https://github.com/nongrujiu99/ps-autoime.git
> cd ps-autoime
> powershell -ExecutionPolicy Bypass -File .\install.ps1
> ```

### 5.2 本地已有源码时的安装器

在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

`install.ps1` 自动完成：**检测/安装 AutoHotkey（本地无安装包则从官方源下载并校验 SHA256）→ 部署脚本并规范 UTF-8 BOM → 注册开机自启 → 启动 → 自检**，全程无需管理员权限。

可用参数：

| 参数 | 默认 | 用途 |
|---|---|---|
| `-InstallDir` | `D:\AutoHotkey` | 指定安装目录 |
| `-SetupExe <路径>` | 无 | 离线安装包路径，跳过网络下载 |
| `-NoStart` | 关 | 只安装部署，不立即启动 |

示例：`powershell -ExecutionPolicy Bypass -File .\install.ps1 -SetupExe C:\Downloads\AutoHotkey_1.1.37.02_setup.exe`

### 5.3 等效手动命令（逐条可复制）

仓库**不收录第三方安装包**（见 `.gitignore`），需自行从官方源获取并校验：

```powershell
# 1) 下载官方安装包（3.27 MB）
$url = 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v1.1.37.02/AutoHotkey_1.1.37.02_setup.exe'
Invoke-WebRequest $url -OutFile "$env:TEMP\ahk_setup.exe"

# 2) 校验 SHA256，必须等于下一行，否则删除文件（哈希以官方 Release 为准，升级版本时同步更新）
(Get-FileHash "$env:TEMP\ahk_setup.exe" -Algorithm SHA256).Hash
# 期望：49A48E879F7480238D2FE17520AC19AFE83685AAC0B886719F9E1EAC818B75CC

# 3) 静默安装（/U64 指定 64 位；/D 必须是最后一个参数、不加引号）
Start-Process "$env:TEMP\ahk_setup.exe" -ArgumentList '/S','/U64','/D=D:\AutoHotkey' -Wait

# 4) 部署脚本
New-Item -ItemType Directory -Force "D:\AutoHotkey\Scripts" | Out-Null
Copy-Item ".\PS_AutoIME.ahk" "D:\AutoHotkey\Scripts\PS_AutoIME.ahk" -Force

# 5) 注册开机自启
$cmd = '"D:\AutoHotkey\AutoHotkey.exe" "D:\AutoHotkey\Scripts\PS_AutoIME.ahk"'
New-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "PS_AutoIME" -Value $cmd -PropertyType String -Force | Out-Null

# 6) 立即启动
Start-Process "D:\AutoHotkey\AutoHotkey.exe" -ArgumentList '"D:\AutoHotkey\Scripts\PS_AutoIME.ahk"'
```

> 若静默参数 `/S` 在你的环境不生效，请改用 [4.2 图形界面安装（备选方式）](#42-图形界面安装备选方式)，再从第 4 步继续。

### 5.4 验证安装

```powershell
Test-Path "D:\AutoHotkey\AutoHotkey.exe"                                       # 应输出 True
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name PS_AutoIME
(Get-Content "D:\AutoHotkey\Scripts\PS_AutoIME.ahk" -Encoding Byte -TotalCount 3) -join ','   # 应输出 239,187,191，即 UTF-8 BOM
```

任务栏托盘应出现**绿色 H 图标**；`D:\AutoHotkey\Scripts\PS_AutoIME.log` 会生成运行日志。运行 `install.ps1` 时它自身也会打印四项自检结果。

---

## 六、日常使用方式

### 6.1 自动行为

| 你在做什么 | 脚本动作 | 输入法 |
|---|---|---|
| 用移动/画笔/选框等工具在画布操作 | 识别为非编辑 | 英文，单字母快捷键可用 |
| 文字工具单击画布、双击图层缩略图进入编辑 | 识别为进入编辑 | 中文，可直接打拼音 |
| 编辑中挪光标、拖选文字 | 保持现状，不干预 | 维持你当前的中文/英文 |
| 按 `Esc` / `小键盘回车` / `Ctrl+回车` | 结束编辑 | 英文，快捷键即时恢复 |
| 在 PS 窗口之外的任何软件 | 不介入 | 系统原样 |

### 6.2 热键速查

| 热键 | 作用 |
|---|---|
| `Ctrl+Alt+F9` | 强制切英文（任何窗口可用，用于自测） |
| `Ctrl+Alt+F10` | 强制切中文（任何窗口可用，用于自测） |
| `Ctrl+Alt+F11` | 暂停 / 恢复脚本（需要完全手动时用） |
| `Ctrl+Alt+F12` | 弹出当前输入法布局代码与已加载布局数 |
| `Ctrl+Alt+F8` | 弹出状态快照（布局、光标形态、焦点窗口句柄） |

### 6.3 中英文混排（同一文字层）

输入法状态是**窗口级**的，PS 不会告诉系统"光标现在落在英文段还是中文段"，因此脚本**无法自动判断**同一层内每段文字该用哪种语言。正确做法：

1. 进入文字编辑 → 脚本自动切中文，打中文。
2. 要打英文字母 → 轻按一次 `Shift`（或你设置的切换键）切到英文，输入后再按一次切回。
3. 编辑中挪光标、拖选**不会**把你切回中文；只有退出编辑才自动回英文。

> 数字和括号在中文状态下直接上屏，无需切换。文字编辑中按 `B`/`V`/`M` 只会输入字母，不会切换工具——这是 PS 文字工具的独占行为，与输入法无关。

### 6.4 修改脚本后重载

双击 `D:\AutoHotkey\Scripts\PS_AutoIME.ahk` 即可。脚本设了单实例模式，会自动关闭旧版本、启动新版本。

> 用编辑器保存时务必选择 **UTF-8 with BOM**。不要用 Windows 记事本直接覆盖保存（可能丢失 BOM 导致中文乱码）。

### 6.5 查看日志

```
D:\AutoHotkey\Scripts\PS_AutoIME.log
```

每行记录时间、光标形态、目标输入法、切换是否成功。排查时按 `Ctrl+Alt+F8` 快照，再对照日志判断问题在"识别"还是"切换"环节。

---

## 七、常见问题

**Q1：中文状态下按 B 仍然弹候选框？**
A：先确认托盘有绿色 H 图标（脚本在运行）、未被 `Ctrl+Alt+F11` 暂停；再确认 PS 与脚本权限级别一致（PS 管理员运行则脚本也要管理员运行）。仍不行时按 `Ctrl+Alt+F8` 结合日志定位。

**Q2：双击托盘图标弹出了一个代码窗口？**
A：那是 AutoHotkey 的脚本监视器（调试窗口），关闭它即可。关闭主窗口可能同时结束脚本，如托盘图标消失，重新双击 `.ahk` 启动。

**Q3：搜狗停在英文模式，切过去打不出中文？**
A：脚本切中文时已调用 `ImmSetOpenStatus` 尝试拨回；若你的搜狗版本不响应，设 搜狗 → 属性设置 → 常用 → 初始状态 = 中文，或按 `Ctrl+Alt+F10` 手动切一次。

**Q4：为什么主键盘回车不切英文？**
A：主键盘 `Enter` 在 PS 文字编辑中是**换行**而非提交，监听它会在每次换行时打断中文输入。提交请用 `小键盘回车` 或 `Ctrl+回车`。

**Q5：PS 升级到 2024/2025 还能用吗？**
A：可以。脚本按进程名 `Photoshop.exe` 匹配，与版本无关。

**Q6：会影响微信、浏览器等别的软件吗？**
A：不会。脚本逻辑只在 `WinActive(Photoshop.exe)` 时生效，其他窗口完全不受影响。

**Q7：如何卸载 / 关闭开机自启？**
A：临时暂停按 `Ctrl+Alt+F11`；彻底退出在托盘右键 → Exit。删除自启：

```powershell
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name PS_AutoIME
```

**Q8：不想装任何软件有替代方案吗？**
A：有。用系统"每应用独立输入法"把 PS 固定为英文键盘，打中文时按一次切换键。详见 `PS中文快捷键-解决方案与使用说明.md` 第五节。

---

## 八、截图展示

> **当前状态：项目目录中尚无截图文件。** 为避免误导，以下仅列出建议补充的**真实截图位置**及应展示的界面/操作流程，不包含任何虚构图片或链接。
>
> 补充方式：将实拍截图保存到项目根目录的 `images/` 文件夹，再把下表的占位说明替换为 `![说明](images/文件名.png)`。

| 编号 | 建议文件名 | 应展示的界面 / 操作流程 | 状态 |
|---|---|---|---|
| S1 | `images/01-files.png` | 资源管理器中本项目的 4 个交付文件，展示项目构成 | 待补充 |
| S2 | `images/02-install-arch.png` | AutoHotkey 安装向导的架构选择页，选中 **Unicode 64-bit** | 待补充 |
| S3 | `images/03-install-options.png` | 安装向导 `options` 页的勾选状态（UTF-8、compiler 等） | 待补充 |
| S4 | `images/04-tray-icon.png` | 任务栏托盘的**绿色 H 图标**，以及右键菜单（Exit / Reload） | 待补充 |
| S5 | `images/05-shortcut-b.png` | **核心验收**：PS 中文输入法状态下在画布按 `B`，工具切为画笔且**不弹候选框** | 待补充 |
| S6 | `images/06-text-edit-cn.png` | 文字工具进入编辑后的画布、图层面板 T 图标、右下角输入法显示"中" | 待补充 |
| S7 | `images/07-mixed-text.png` | 同一文字层内中英文混排（如"2026款"），文字被选中的状态与输入法显示 | 待补充 |
| S8 | `images/08-log.png` | 记事本打开 `PS_AutoIME.log`，展示一次点击的"光标→目标→成功"记录 | 待补充 |

> 如需要，可优先补 S4、S5、S6 三张——它们分别证明"脚本已运行""快捷键恢复""中文输入正常"，是用户最关心的三个画面。

---

## 九、文件结构

```
PS快捷键/                          ← 公开仓库内容
├── README.md                      # 本文档
├── LICENSE                        # MIT 许可证 + 第三方声明
├── .gitignore                     # 排除内部记忆、日志、第三方安装包
├── bootstrap.ps1                  # Git 一键安装入口（克隆 + 调用安装器）
├── install.ps1                    # 一键安装器（检测/安装/部署/自启/自检）
├── PS_AutoIME.ahk                 # 核心脚本（源文件）
└── PS中文快捷键-解决方案与使用说明.md   # 原理、方案对比与进阶说明

不纳入公开仓库（均由 .gitignore 排除）：
.workbuddy/                        # 本地工作记忆与部署记录
AutoHotkey_*_setup.exe             # 第三方 GPL 安装包，安装时从官方源下载
PS_AutoIME.log                     # 运行日志，含本机窗口句柄等诊断信息

安装后（使用者本机）：
D:\AutoHotkey\
├── AutoHotkey.exe                 # 程序本体
└── Scripts\
    ├── PS_AutoIME.ahk             # 部署后的脚本
    └── PS_AutoIME.log             # 运行日志（自动生成）
```

> **安全说明**：仓库为公开仓库，仅含脚本与文档，不含任何密钥、访问令牌、账号密码或 CI Secret。安装脚本从官方 HTTPS 源下载 AutoHotkey，并用固定 SHA256 校验，不执行任何凭据写入。

---

## 十、免责声明

本方案为效率工具与产品设计参考，脚本通过系统接口切换输入法，非 Adobe 官方方案。请在个人设备上先小范围验证，再决定是否长期使用；修改系统输入法设置前请知悉原有配置以便回退。

> 本方案为产品设计参考，具体实施请结合公司合规与法务要求确认。
