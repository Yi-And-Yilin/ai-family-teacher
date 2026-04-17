# 数据库更新指南

## 何时需要更新

新增表、更改表结构时需要更新。

## 操作步骤（只需两步）

### 1. 升级版本号

文件：`lib/services/database_service.dart`

```dart
static const int _databaseVersion = 9;  // 例如从 8 改成 9
```

### 2. 在 onUpgrade 中添加建表语句

在同一文件找到 `_upgradeDatabase` 方法，在最后添加：

```dart
if (oldVersion < 9) {  // 与版本号一致
  await db.execute('''
    CREATE TABLE IF NOT EXISTS your_new_table (
      id TEXT PRIMARY KEY,
      -- 其他列...
      created_at INTEGER NOT NULL
    )
  ''');
}
```

## 注意事项

- 使用 `CREATE TABLE IF NOT EXISTS` - 新装和升级都能正常工作
- 不要在 `onCreate` 里加新表，只在 `onUpgrade` 里加
- 每个版本只加一次，注释写清楚是哪个版本添加的
