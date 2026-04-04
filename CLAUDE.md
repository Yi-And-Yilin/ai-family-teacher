# 小书童项目 - 开发指南

## 重要配置与注意事项

### 1. Flutter 环境位置

**Flutter SDK 路径**：`C:\flutter`

**错误做法**：使用 Bash 工具执行 `flutter` 命令会报错 `command not found`

**正确做法**：在 Windows CMD/PowerShell 中使用完整路径或通过环境变量调用

---

### 2. Android SDK 配置

**SDK 路径**：`C:\Users\Administrator\AppData\Local\Android\Sdk`

**环境变量**：
```cmd
setx ANDROID_HOME "C:\Users\Administrator\AppData\Local\Android\Sdk"
setx PATH "%ANDROID_HOME%\platform-tools;%%ANDROID_HOME%\cmdline-tools\bin;%PATH%"
```

**验证安装**：
```cmd
echo %ANDROID_HOME%
dir "%ANDROID_HOME%\platform-tools"
```

---

### 3. Flutter 构建命令（Windows 环境）

**❌ 错误做法**：使用 Bash 工具执行 `flutter` 命令会报错 `command not found`

**✅ 正确做法**：Flutter 在 Windows 上需要通过系统命令执行

在 Windows CMD/PowerShell 中构建 APK：
```cmd
cd "C:\小书童"
flutter build apk --release --split-per-abi
```

在 Windows CMD/PowerShell 中运行应用：
```cmd
flutter run -d chrome
```

**原因**：Flutter SDK 安装在 Windows 系统路径下，Bash 会话中未配置到 PATH

---

### 2. Ollama 网络访问配置

当前配置使用电脑局域网 IP：`192.168.4.22`

文件位置：`lib/services/ai_service.dart`

```dart
final String _ollamaUrl = 'http://192.168.4.22:11434/api/chat';
```

**如果 IP 地址变化**，需要手动修改此文件或：
1. 重启电脑后检查新 IP
2. 使用 `ipconfig` 查看当前网络配置
3. 修改两处：VLService 和 AIService 中的 URL

---

### 3. 防火墙设置

确保 Ollama 服务端口（11434）在防火墙中允许：

```cmd
netsh advfirewall firewall show rule name=all | findstr 11434
```

如果未找到，需要添加入站规则允许 11434 端口。

---

### 4. 快速命令参考

| 任务 | 命令 |
|------|------|
| 构建 APK | `flutter build apk --release --split-per-abi` |
| 构建 Web | `flutter build web` |
| 运行调试 | `flutter run -d chrome` |
| 代码检查 | `flutter analyze` |
| 代码格式化 | `flutter format .` |
| 查看 IP | `ipconfig \| findstr IPv4` |

---

### 5. 部署步骤

1. **构建 APK**：
   ```cmd
   flutter build apk --release --split-per-abi
   ```

2. **获取 APK 文件**：
   - 位置：`C:\小书童\build\app\outputs\apk\release\`
   - 文件：`app-armeabi-v7a.apk`、`app-arm64-v8a.apk`、`app-x86_64.apk`

3. **安装到手机**：
   - 通过微信/QQ 发送 APK 到手机
   - 或 USB 拷贝安装
   - 手机上需要"允许安装未知来源应用"

---

## 项目信息

- **产品名称**：小书童 (AI Family Teacher)
- **技术栈**：Flutter 3.41.5 + Provider + SQLite + Ollama
- **AI 模型**：qwen3.5:9b (文本) + qwen3-vl:8b (视觉)
- **目标用户**：中小学生及其家长
