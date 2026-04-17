import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/models/saved_item.dart';

void main() {
  group('SavedItem Model Tests', () {
    test('should create SavedItem and serialize/deserialize correctly', () {
      // Use trimmed DateTime (no microseconds) to avoid precision loss
      final now = DateTime.now().subtract(Duration(microseconds: DateTime.now().microsecond));
      final item = SavedItem(
        id: 'test_id_123',
        title: 'Test Blackboard',
        type: 'blackboard',
        conversationId: 'conv_123',
        createdAt: now,
        thumbnail: 'Thumbnail text',
        description: 'Test description',
      );

      // Test serialization
      final map = item.toMap();
      expect(map['id'], 'test_id_123');
      expect(map['title'], 'Test Blackboard');
      expect(map['type'], 'blackboard');
      expect(map['conversation_id'], 'conv_123');
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['thumbnail'], 'Thumbnail text');
      expect(map['description'], 'Test description');

      // Test deserialization
      final deserialized = SavedItem.fromMap(map);
      expect(deserialized.id, item.id);
      expect(deserialized.title, item.title);
      expect(deserialized.type, item.type);
      expect(deserialized.conversationId, item.conversationId);
      expect(deserialized.createdAt, item.createdAt);
      expect(deserialized.thumbnail, item.thumbnail);
      expect(deserialized.description, item.description);
    });

    test('should return correct icon for blackboard type', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'blackboard',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.icon, '📋');
    });

    test('should return correct icon for workbook type', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'workbook',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.icon, '📝');
    });

    test('should return correct icon for notebook type', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'notebook',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.icon, '📖');
    });

    test('should return correct icon for unknown type', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'unknown',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.icon, '📄');
    });

    test('should return correct type name for blackboard', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'blackboard',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.typeName, '黑板');
    });

    test('should return correct type name for workbook', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'workbook',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.typeName, '作业本');
    });

    test('should return correct type name for notebook', () {
      final item = SavedItem(
        id: 'id1',
        title: 'Test',
        type: 'notebook',
        conversationId: 'conv1',
        createdAt: DateTime.now(),
      );

      expect(item.typeName, '笔记本');
    });
  });
}
