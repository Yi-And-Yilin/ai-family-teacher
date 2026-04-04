# CodeBuddy Configuration - AI家庭教师项目

> 此文件为CodeBuddy自动加载的配置文件，提供项目上下文信息

## 🏆 项目标识
- **项目名称**: AI家庭教师 (AI Family Teacher)
- **项目类型**: Flutter跨平台应用
- **开发状态**: 开发中，Web版本已部署
- **项目路径**: `C:\小书童`

## 📱 应用信息
- **应用名称**: ai_family_teacher
- **目标用户**: 小学生及家长
- **核心功能**:
  - AI对话答疑 (对话框组件)
  - 手写教学 (黑板组件)
  - 作业练习 (作业本组件)
  - 笔记整理 (笔记本组件)

## 🛠 技术栈
- **框架**: Flutter 3.41.4 (Dart 3.11.1)
- **状态管理**: Provider 6.1.1
- **数据库**: SQLite (sqflite 2.3.0)
- **网络请求**: http 1.1.0 + dio 5.4.0
- **AI集成**: 本地Ollama (http://localhost:11434, 模型llama2)
- **本地存储**: shared_preferences 2.2.2

## 📁 项目结构
```
C:\小书童\
├── lib/                    # Flutter源代码
│   ├── main.dart          # 应用入口
│   ├── providers/         # 状态管理
│   │   └── app_provider.dart
│   ├── services/          # 服务层
│   │   ├── ai_service.dart    # AI服务
│   │   └── database_service.dart # 数据库
│   ├── models/            # 数据模型
│   │   ├── user.dart
│   │   ├── question.dart
│   │   ├── note.dart
│   │   ├── mistake_book.dart
│   │   └── conversation.dart
│   ├── screens/           # 页面
│   │   └── home_screen.dart
│   └── widgets/           # UI组件
│       ├── blackboard.dart    # 黑板
│       ├── workbook.dart      # 作业本
│       ├── notebook.dart      # 笔记本
│       ├── dialog_area.dart   # 对话框
│       ├── component_controller.dart
│       └── component_switcher.dart
├── planning/              # 设计文档
├── assets/               # 静态资源
├── web/                  # Web平台文件
├── build/web/            # 构建输出
└── pubspec.yaml          # 项目配置
```

## 🔧 开发环境
- **Flutter SDK**: `C:\flutter\bin` (已添加到PATH)
- **运行命令**: `flutter run -d chrome`
- **构建命令**: `flutter build web`
- **Web服务器**: Python HTTP服务器 (端口8080)
- **访问地址**: http://localhost:8080

## ⚡ 当前状态
### ✅ 已完成
1. Flutter SDK配置完成
2. 项目架构搭建完成
3. 核心UI组件开发完成
4. 数据库设计实现
5. AI服务集成配置
6. Web平台适配完成
7. 应用已构建并部署到Web服务器

### 🔄 进行中
1. Web应用运行在 http://localhost:8080
2. 测试Ollama AI服务连接
3. 完善笔记本格式化功能

### ⚠️ 已知限制
1. **Web平台数据库限制**: SQLite不支持Web平台，数据不持久化
2. **笔记本功能**: 文本格式化功能待实现 (加粗、标题、列表)
3. **AI服务**: 需要验证Ollama服务是否运行
4. **字体文件**: NotoSansSC字体缺失，已注释相关配置

## 🎯 优先任务
1. **测试应用功能** - 验证所有组件正常工作
2. **验证Ollama连接** - 确保本地AI服务可用
3. **完善笔记本功能** - 实现文本格式化
4. **Web存储方案** - 添加shared_preferences或IndexedDB支持
5. **移动端适配** - 测试Android/iOS平台运行

## 🔗 关键链接
- **本地Web应用**: http://localhost:8080
- **Ollama服务**: http://localhost:11434
- **Flutter文档**: https://flutter.dev
- **项目GitHub**: (未配置)

## 📝 代码示例
```dart
// 运行应用
flutter run -d chrome

// 构建Web版本
flutter build web

// 启动本地服务器
cd build/web && python -m http.server 8080
```

## 🚨 故障排除
### Web应用无法访问
1. 检查Python服务器是否运行: `netstat -an | grep :8080`
2. 重启服务器: `cd build/web && python -m http.server 8080`
3. 重新构建: `flutter clean && flutter build web`

### Flutter命令找不到
1. 检查PATH: `echo %PATH%` (Windows) 或 `echo $PATH` (Linux/Mac)
2. Flutter SDK路径: `C:\flutter\bin`

### AI服务不可用
1. 检查Ollama是否运行: `curl http://localhost:11434/api/tags`
2. 启动Ollama服务 (如果已安装)

---

*本文件由CodeBuddy自动加载，提供项目上下文信息。最后更新: 2026-03-19*