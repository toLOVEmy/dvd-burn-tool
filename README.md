# DVD Burn Tool — 使用电脑刻录光盘

[![GitHub](https://img.shields.io/badge/GitHub-toLOVEmy/dvd--burn--tool-blue)](https://github.com/toLOVEmy/dvd-burn-tool)
[![Gitee](https://img.shields.io/badge/Gitee-wenchaoxu/dvd--burn--tool-red)](https://gitee.com/wenchaoxu/dvd-burn-tool)

**Windows DVD+RW 不封盘刻录与追加工具**

本项目提供一套 PowerShell 脚本，通过 Windows 内置的 IMAPI2 COM 组件实现：
- **首次刻录**：空白 DVD+RW 光盘的首次写入（不封盘）
- **追加刻录**：已刻录但未封盘的光盘继续追加文件
- **跨主机使用**：脚本可放在 U 盘随身携带，到任何 Windows 7+ 主机上直接运行

---

## 目录

- [为什么需要这个工具](#为什么需要这个工具)
- [文件说明](#文件说明)
- [快速开始](#快速开始)
- [脚本详细用法](#脚本详细用法)
- [手动命令参考](#手动命令参考)
- [技术原理](#技术原理)
- [跨主机使用](#跨主机使用)
- [常见问题](#常见问题)
- [许可证](#许可证)

---

## 为什么需要这个工具

Windows 系统自带的光盘刻录功能（资源管理器右键「刻录到光盘」）**默认会封盘**，封盘后的光盘无法再追加文件，这对于：

- 备份日志文件（每天追加一次）
- 交付项目文件（分批交付）
- 长期归档（不断补充数据）

等场景非常不便。

本工具通过 IMAPI2 的 `ForceMediaToBeClosed = $false` 参数，实现了 **不封盘写入**，刻录完成后光盘仍处于 Open 状态，可以随时再次追加。

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `append_to_disc_portable.ps1` | **主脚本** — v3 全能版，自动识别空白盘/追加盘并处理 |
| `手动命令.txt` | 常用命令速查 |
| `README.md` | 本文档 |

---

## 快速开始

### 环境要求

| 要求 | 说明 |
|------|------|
| 操作系统 | Windows 7 / 8 / 10 / 11（64 位或 32 位均可） |
| 光盘类型 | DVD+RW / DVD-RW |
| 刻录机 | 任何支持 DVD 刻录的驱动器 |
| 权限 | 以管理员身份运行 PowerShell |
| 额外软件 | **无需安装任何软件**（使用 Windows 内置的 IMAPI2 组件） |

### 第一步：查看光驱

以管理员身份打开 PowerShell，进入脚本所在目录，运行：

```powershell
# 允许执行脚本（首次运行需要）
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 查看光驱列表
.\append_to_disc_portable.ps1 -ShowDrives
```

输出示例：

```
=== Scanning optical drives ===
[0] DVD-RW DA8AESH    (Drive: F:)
Use -RecorderIdx N to select the correct drive.
```

### 第二步：首次刻录（空白盘）

```powershell
.\append_to_disc_portable.ps1 -Path "D:\我的文件" -RecorderIdx 0
```

脚本会自动检测到空白盘，创建新文件系统并刻录，**不会封盘**。

### 第三步：追加文件（已刻录的光盘）

```powershell
.\append_to_disc_portable.ps1 -Path "D:\新增文件\日志.txt" -RecorderIdx 0
```

脚本会自动导入光盘上已有的文件系统，保留旧文件的同时追加新文件。

---

## 脚本详细用法

### 参数说明

| 参数 | 别名 | 说明 | 默认值 |
|------|------|------|--------|
| `-Path` | `-SourceDir` | 要刻录的文件或文件夹路径 | 脚本所在目录 |
| `-RecorderIdx` | — | 光驱序号（从 0 开始） | 0 |
| `-ShowDrives` | — | 列出所有光驱后退出 | — |

### 使用示例

```powershell
# 列出所有光驱
.\append_to_disc_portable.ps1 -ShowDrives

# 追加整个文件夹到光盘
.\append_to_disc_portable.ps1 -Path "D:\backup\project" -RecorderIdx 0

# 追加单个文件到光盘
.\append_to_disc_portable.ps1 -Path "D:\report.pdf" -RecorderIdx 0

# 追加单个文件（使用别名 -SourceDir）
.\append_to_disc_portable.ps1 -SourceDir "D:\data\file.txt" -RecorderIdx 0

# 如果有多个光驱，指定第二个
.\append_to_disc_portable.ps1 -Path "E:\files" -RecorderIdx 1

# 不指定路径：刻录脚本所在目录的全部文件
.\append_to_disc_portable.ps1 -RecorderIdx 0
```

### 脚本输出解读

```
=== Scanning optical drives ===
[0] DVD-RW DA8AESH    (Drive: F:)

=== 1. Select recorder [0] ===
DVD-RW DA8AESH
Drive: F:

=== 2. Check disc status ===
Status: 4  (Blank=False, Open=True, Closed=False)
Free: 4467.19 MB
Disc type: EXISTING (append)

=== 3. Source path ===
D:\my_files
3 file(s) to write:
    doc1.pdf  (1024.5 KB)
    doc2.pdf  (2048.0 KB)
    notes.txt  (12.3 KB)

=== 4. Existing disc - import filesystem ===
OK - existing files preserved

=== 5. Write to disc (not finalized) ===
Adding folder: D:\my_files
Burning to disc, please wait...
Done!

=== 6. Verify ===
F:\ has 8 files:
Name            Length
----            ------
doc1.pdf        1049088
doc2.pdf        2097152
notes.txt       12595
probe.ps1       3340
... (已有文件)

=== 7. Disc status after burn ===
Status: 4  (Open - can append again)

[SUCCESS] Files appended successfully! Disc still open.
[TIP]    Run again with new files to append more.
```

### 光盘状态码说明

| 状态码 | 含义 | 能否写入 |
|--------|------|---------|
| 0 | 无介质 | ❌ 盘片未插入 |
| 1 | 空白盘 | ✅ 首次刻录 |
| 4 | Open（未封盘、可写入） | ✅ 追加刻录 |
| 6 | Appendable + Open | ✅ 追加刻录 |
| 8 | Closed/Finalized（已封盘） | ❌ 无法再写入 |

---

## 手动命令参考

以下常用命令摘自 `手动命令.txt`：

```powershell
# 允许执行脚本
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 列出光盘
powershell -File .\append_to_disc_portable.ps1 -ShowDrives

# 追加单个文件
powershell -File .\append_to_disc_portable.ps1 -SourceDir "G:\data\file.txt" -RecorderIdx 0

# 追加整个文件夹
powershell -File .\append_to_disc_portable.ps1 -Path "G:\data" -RecorderIdx 0
```

---

## 技术原理

### IMAPI2 COM 组件

Windows 自带的 Image Mastering API v2（IMAPI2）提供了光盘刻录的 COM 接口。本脚本使用以下核心对象：

| COM 对象 | 作用 |
|----------|------|
| `MsftDiscMaster2` | 枚举系统中的刻录机 |
| `MsftDiscRecorder2` | 操作指定的刻录机 |
| `MsftDiscFormat2Data` | 数据刻录格式控制 |
| `MsftFileSystemImage` | 构建 ISO/UDF 文件系统 |

### 不封盘的核心参数

```powershell
$df.ForceMediaToBeClosed = $false
```

设置此参数后，刻录完成后光盘不会封盘，保留为 Open 状态，后续可以继续追加。

### 追加刻录的关键步骤

1. 通过 `$df.MultisessionInterfaces` 获取光盘的多区段接口
2. 将多区段接口传递给 `$fsi.MultisessionInterfaces`
3. 调用 `$fsi.ImportFileSystem()` 导入光盘上已有的文件系统（保留旧文件）
4. 使用 `$rootDir.AddTree()` 添加新文件
5. 写入光盘（不封盘）

### 文件系统格式

脚本默认使用 **UDF + Joliet**（对应 `FileSystemsToCreate = 7`）：
- Joliet：保证 Windows 兼容性（长文件名支持）
- UDF：支持多区段（Multisession），这是追加功能的基础

---

## 跨主机使用

### 便携用法

```powershell
# 1. 把以下文件复制到 U 盘：
#    - append_to_disc_portable.ps1
#    - 手动命令.txt
#    - 你要追加的文件（放在一个文件夹里）

# 2. 到另一台 Windows 主机上：
#    - 插入光盘和 U 盘
#    - 以管理员身份打开 PowerShell
#    - 进入 U 盘目录运行
#    - 先 -ShowDrives 查看光驱序号
#    - 再 -Path 指定文件位置刻录

# 示例（U 盘在 E:）：
E:\> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
E:\> .\append_to_disc_portable.ps1 -ShowDrives
E:\> .\append_to_disc_portable.ps1 -Path "E:\要追加的文件" -RecorderIdx 0
```

### 跨主机条件

只要满足以下条件，任何 Windows 主机都可使用：
1. 光盘**未封盘**（状态码为 1、4 或 6）
2. 主机有 DVD 刻录机
3. 主机运行 Windows 7+
4. 以**管理员身份**运行 PowerShell

---

## 常见问题

### Q: 直接用右键「刻录到光盘」会不会封盘？

**会。** Windows 资源管理器的「刻录到光盘」功能默认会封盘（Finalize），封盘后无法再追加任何数据。请使用本脚本进行刻录。

### Q: 光盘刻了一半失败了怎么办？

如果刻录过程中断（如断电、光盘弹出），光盘可能处于不稳定状态。建议：
1. 如果是 DVD-RW：用 IMAPI 擦除后重新使用
2. 如果是 DVD+RW：IMAPI 自动管理，通常可以直接覆盖

### Q: 追加的文件和已有文件重名怎么办？

`AddTree` 添加文件时，如果光盘上已有同名文件，**新文件会覆盖旧文件**。注意验证最终结果。

### Q: 为什么 UDF 文件系统导入失败了？

部分品牌的光盘或旧刻录机的多区段信息不完整，可能导致 `ImportFileSystem()` 失败。本脚本 v3 版本已内置自动降级机制——导入失败时自动回退到新建文件系统（但会丢失已有文件），不会直接崩溃。

### Q: 最多可以追加多少次？

理论上 DVD+RW 支持约 **1000 次** 写入/擦除循环。但每追加一次会增加一个区段（Session），UDF 文件系统有区段数量上限（通常约 200-300 个），所以实际可追加次数约为 200 次左右。建议重要数据另存备份。

### Q: 脚本报错「无法对 Null 数组进行索引」？

这通常是因为 `VolumePathStrings` COM 属性在特定系统上返回空数组。v3 版本已增加 WMI 回退机制和更完善的错误处理。如果仍然遇到，请确保以管理员身份运行。

### Q: 空白盘报错无法刻录？

确保光盘类型为 DVD+RW 或 DVD-RW，且刻录机支持该格式。DVD-ROM（只读盘）无法写入，CD-RW 需要不同的刻录参数。

---

## 许可证

本项目仅用于学习和个人使用。代码基于 Windows IMAPI2 系统组件开发，不依赖任何第三方软件。
