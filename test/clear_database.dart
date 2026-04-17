import 'package:ai_family_teacher/services/database_service.dart';

void main() async {
  final db = DatabaseService();
  print('Clearing all data...');
  await db.clearAllData();
  print('Done!');
}
