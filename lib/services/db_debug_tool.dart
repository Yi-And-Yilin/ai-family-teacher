import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

/// 数据库调试工具
/// 用于在开发时查看数据库内容，方便 AI 辅助调试
class DBDebugTool {
  /// 打印所有表名和记录数
  static Future<String> getAllTablesSummary(Database db) async {
    final buffer = StringBuffer();
    buffer.writeln('=== 数据库表概览 ===');
    
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'"
      );
      
      for (var table in tables) {
        final name = table['name'] as String;
        try {
          final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $name');
          final count = countResult.first['count'];
          buffer.writeln('- $name: $count 条记录');
        } catch (e) {
          buffer.writeln('- $name: 读取失败 ($e)');
        }
      }
    } catch (e) {
      buffer.writeln('读取表列表失败: $e');
    }
    
    return buffer.toString();
  }

  /// 打印指定表的内容
  static Future<String> getTableContent(
    Database db, 
    String tableName, {
    int limit = 20,
    String? orderBy,
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('=== 表: $tableName ===');
    
    try {
      final rows = await db.query(
        tableName,
        limit: limit,
        orderBy: orderBy,
        where: where,
        whereArgs: whereArgs,
      );
      
      if (rows.isEmpty) {
        buffer.writeln('(空表)');
      } else {
        // 打印列名
        final columns = rows.first.keys.toList();
        buffer.writeln('列: ${columns.join(", ")}');
        buffer.writeln('-' * 50);
        
        // 打印数据
        for (var i = 0; i < rows.length; i++) {
          buffer.writeln('[$i] ${_formatRow(rows[i])}');
        }
        
        if (rows.length == limit) {
          buffer.writeln('... (仅显示前 $limit 条)');
        }
      }
    } catch (e) {
      buffer.writeln('读取失败: $e');
    }
    
    return buffer.toString();
  }

  /// 打印表结构
  static Future<String> getTableSchema(Database db, String tableName) async {
    final buffer = StringBuffer();
    buffer.writeln('=== 表结构: $tableName ===');
    
    try {
      final columns = await db.rawQuery(
        "PRAGMA table_info($tableName)"
      );
      
      for (var col in columns) {
        final name = col['name'];
        final type = col['type'];
        final notNull = col['notnull'] == 1 ? 'NOT NULL' : '';
        final pk = col['pk'] == 1 ? 'PRIMARY KEY' : '';
        buffer.writeln('- $name: $type $notNull $pk'.trim());
      }
    } catch (e) {
      buffer.writeln('读取失败: $e');
    }
    
    return buffer.toString();
  }

  /// 打印完整的数据库状态（供 AI 分析用）
  static Future<String> getFullDatabaseState(Database db) async {
    final buffer = StringBuffer();
    buffer.writeln('\n====== 数据库完整状态 ======\n');
    
    // 获取所有表
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'"
    );
    
    for (var table in tables) {
      final name = table['name'] as String;
      buffer.writeln(await getTableSchema(db, name));
      buffer.writeln(await getTableContent(db, name, limit: 5));
      buffer.writeln('');
    }
    
    buffer.writeln('====== 状态结束 ======\n');
    return buffer.toString();
  }

  /// 格式化单行数据
  static String _formatRow(Map<String, dynamic> row) {
    return row.entries.map((e) {
      var value = e.value;
      if (value != null && value.toString().length > 50) {
        value = '${value.toString().substring(0, 50)}...';
      }
      return '${e.key}=$value';
    }).join(', ');
  }

  /// 调试时打印到控制台
  static Future<void> debugPrintAll(Database db) async {
    if (kDebugMode) {
      debugPrint(await getFullDatabaseState(db));
    }
  }

  /// 执行原始 SQL 查询（调试用）
  static Future<String> executeQuery(Database db, String sql) async {
    final buffer = StringBuffer();
    buffer.writeln('=== SQL: $sql ===');
    
    try {
      final results = await db.rawQuery(sql);
      for (var i = 0; i < results.length; i++) {
        buffer.writeln('[$i] ${_formatRow(results[i])}');
      }
      buffer.writeln('共 ${results.length} 条记录');
    } catch (e) {
      buffer.writeln('执行失败: $e');
    }
    
    return buffer.toString();
  }
}

/// 使用示例：
/// 
/// ```dart
/// final db = await DatabaseService().database;
/// 
/// // 查看所有表概览
/// print(await DBDebugTool.getAllTablesSummary(db));
/// 
/// // 查看特定表内容
/// print(await DBDebugTool.getTableContent(db, 'messages', limit: 10));
/// 
/// // 查看表结构
/// print(await DBDebugTool.getTableSchema(db, 'users'));
/// 
/// // 执行自定义查询
/// print(await DBDebugTool.executeQuery(db, 'SELECT * FROM users WHERE name LIKE "%小明%"'));
/// 
/// // 获取完整状态（供 AI 分析）
/// print(await DBDebugTool.getFullDatabaseState(db));
/// ```
