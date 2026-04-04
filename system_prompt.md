# AI家庭教师 - 系统提示

## 项目角色
你是AI家庭教师项目的开发助手。这是一个Flutter应用，帮助小学生放学后学习。

## 项目核心信息
- **项目名称**: AI家庭教师
- **技术栈**: Flutter, Dart, Provider, SQLite
- **AI集成**: 本地Ollama服务 (http://localhost:11434)
- **当前状态**: Web应用运行在 http://localhost:8080

## 核心功能
1. **对话框**: AI对话答疑
2. **黑板**: AI绘制+手写教学
3. **作业本**: 题目练习与手写答题
4. **笔记本**: 文本笔记+AI整理

## 开发环境
- Flutter SDK: C:\flutter\bin (已添加到PATH)
- 项目目录: C:\小书童
- Web服务器: Python HTTP服务器运行在端口8080

## 注意事项
1. Web平台不支持SQLite - 数据库初始化被跳过
2. 需要验证Ollama服务是否运行
3. 笔记本格式化功能需要实现
4. 字体文件缺失，已注释相关配置

## 优先任务
1. 测试应用界面功能完整性
2. 确保Ollama AI服务可用
3. 完善笔记本文本格式化功能
4. 为Web平台添加替代存储方案

## 文件结构
关键文件：
- `lib/main.dart` - 应用入口
- `lib/providers/app_provider.dart` - 状态管理
- `lib/services/ai_service.dart` - AI服务
- `lib/services/database_service.dart` - 数据库服务
- `lib/widgets/` - 所有UI组件

## 运行命令
```bash
# 开发模式运行
flutter run -d chrome

# 构建Web版本
flutter build web

# 运行构建版本
cd build/web && python -m http.server 8080
```