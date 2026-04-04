# Flutter 安装指南 (Windows)

## 1. 下载 Flutter SDK
- 访问 Flutter 官网：https://flutter.dev/docs/get-started/install/windows
- 下载最新稳定版的 Flutter SDK (flutter_windows_xxx.zip)
- 建议将 SDK 解压到 `C:\src\flutter` (或任意无空格路径)

## 2. 设置环境变量
- 将 Flutter 的 `bin` 目录添加到系统 PATH：
  - 例如：`C:\src\flutter\bin`
- 步骤：
  1. 右键点击“此电脑” -> 属性 -> 高级系统设置 -> 环境变量
  2. 在“用户变量”或“系统变量”中找到 `Path`，点击编辑
  3. 添加 Flutter bin 目录的完整路径
  4. 确定保存

## 3. 运行 Flutter Doctor
- 打开 PowerShell 或命令提示符
- 执行以下命令：
  ```
  flutter doctor
  ```
- 该命令会检查缺失的依赖（如 Android Studio、VS Code 等）
- 根据提示安装所需组件（如 Android SDK、许可协议等）

## 4. 安装 Android Studio (如需开发 Android 应用)
- 下载并安装 Android Studio：https://developer.android.com/studio
- 启动 Android Studio，完成初始设置
- 安装 Android SDK（通过 SDK Manager）
- 设置 Android 模拟器或连接真实设备

## 5. 安装 VS Code (推荐)
- 下载 VS Code：https://code.visualstudio.com/
- 安装 Flutter 扩展：在扩展商店搜索“Flutter”并安装

## 6. 验证安装
- 打开新的终端窗口，运行：
  ```
  flutter --version
  ```
- 应该显示 Flutter 版本信息

## 7. 运行本项目
- 在本项目目录下执行：
  ```
  flutter run
  ```
- 如果连接了设备或模拟器，应用将启动

## 注意事项
- 确保网络畅通，Flutter 可能需要下载额外资源
- 如果遇到防火墙问题，可能需要配置代理
- 安装过程中可能需要同意 Android 许可协议（运行 `flutter doctor --android-licenses`）

## 快速脚本（可选）
如果你喜欢使用 PowerShell 脚本安装，可以创建一个 `install_flutter.ps1` 文件，内容如下：

```powershell
# 下载 Flutter SDK
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.0-stable.zip"
$installPath = "C:\src\flutter"
$zipPath = "$env:TEMP\flutter.zip"

Write-Host "正在下载 Flutter SDK..." -ForegroundColor Green
Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath

Write-Host "正在解压到 $installPath..." -ForegroundColor Green
Expand-Archive -Path $zipPath -DestinationPath "C:\src"
Remove-Item $zipPath

# 添加环境变量（需要管理员权限）
Write-Host "请手动将 $installPath\bin 添加到系统 PATH 环境变量" -ForegroundColor Yellow
```

运行脚本需要管理员权限，且需要根据最新版本调整 URL。

## 更多帮助
- 官方文档：https://flutter.dev/docs
- 中文社区：https://flutter.cn