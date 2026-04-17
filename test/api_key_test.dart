import 'package:flutter_test/flutter_test.dart';
import 'package:ai_family_teacher/services/api_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('API Key 从数据库加载测试', () async {
    // 初始化 sqflite_ffi
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // 初始化配置
    await APIConfigService.instance.init();
    
    // 检查 API Key
    final apiKey = APIConfigService.instance.glmApiKey;
    
    print('\n========== API Key 测试结果 ==========');
    print('API Key 长度: ${apiKey.length}');
    print('API Key 掩码: ${APIConfigService.instance.apiKeyMask}');
    print('配置状态: ${APIConfigService.instance.configStatus}');
    print('是否有效: ${APIConfigService.instance.isConfigValid}');
    print('========================================\n');
    
    expect(apiKey.length, greaterThan(0), reason: 'API Key 应该从数据库加载成功');
    expect(APIConfigService.instance.isConfigValid, isTrue, reason: '配置应该有效');
  });
}
