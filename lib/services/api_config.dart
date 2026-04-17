import 'dart:io';
import 'package:flutter/foundation.dart';
import 'crypto_service.dart';
import 'database_service.dart';

/// API 提供商类型
enum APIProvider {
  glm, // GLM 在线 API (智谱AI)
  ollama, // 本地 Ollama API
  deepseek, // DeepSeek 在线 API
}

/// API 配置服务
/// 单例模式：使用 APIConfigService.instance 获取唯一实例
class APIConfigService extends ChangeNotifier {
  // ========== 单例模式 ==========
  static APIConfigService? _instance;
  bool _initialized = false;

  /// 获取单例实例
  static APIConfigService get instance {
    _instance ??= APIConfigService._();
    return _instance!;
  }

  /// 私有构造函数
  APIConfigService._();

  // 兼容旧的构造方式（不推荐，建议使用 instance）
  APIConfigService() : _initialized = false;
  // ========== 单例模式结束 ==========

  // 数据库服务
  final DatabaseService _db = DatabaseService();

  // 配置 Key 常量
  static const String _encryptedApiKeyKey = 'glm_api_key_encrypted';
  static const String _encryptedDeepseekApiKeyKey =
      'deepseek_api_key_encrypted';

  // 配置文件目录 - 放在 config 子文件夹下
  static const String _configDir = 'config';
  static const String _configFile = 'api_config.txt';

  // 默认配置
  static const String defaultOllamaUrl = 'http://192.168.4.22:11434/api/chat';
  static const String glmApiUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String deepseekApiUrl =
      'https://api.deepseek.com/chat/completions';

  // GLM 模型配置
  static const String glmTextModel = 'glm-4.7-flash'; // 免费文本模型
  static const String glmVisionModel = 'glm-4v-flash'; // 免费视觉模型

  // Ollama 模型配置
  static const String ollamaTextModel = 'qwen3.5:9b';
  static const String ollamaVisionModel = 'qwen3-vl:8b';

  // DeepSeek 模型配置
  static const String deepseekTextModel = 'deepseek-chat'; // DeepSeek 主模型
  static const String deepseekVisionModel =
      'deepseek-chat'; // DeepSeek 视觉模型（如果支持）

  // ========================================
  // 内置的加密 API Key（开发者模式）
  // 开发时通过设置界面"保存到源代码"按钮自动更新此值
  // 生产环境：此值会被编译进应用，用户无法修改
  // ========================================
  static const String _hardcodedEncryptedKey = '';

  APIProvider _currentProvider = APIProvider.glm; // 默认使用 GLM
  String _glmApiKey = '';
  String _deepseekApiKey = '';
  String _ollamaUrl = defaultOllamaUrl;
  bool _keyJustImported = false;
  bool _keySavedToSource = false; // 标记是否刚保存到源代码

  APIProvider get currentProvider => _currentProvider;
  String get glmApiKey => _glmApiKey;
  String get deepseekApiKey => _deepseekApiKey;
  String get ollamaUrl => _ollamaUrl;
  bool get keyJustImported => _keyJustImported;
  bool get keySavedToSource => _keySavedToSource;

  // 获取当前配置
  String get currentApiUrl {
    switch (_currentProvider) {
      case APIProvider.glm:
        return glmApiUrl;
      case APIProvider.ollama:
        return _ollamaUrl;
      case APIProvider.deepseek:
        return deepseekApiUrl;
    }
  }

  String get currentTextModel {
    switch (_currentProvider) {
      case APIProvider.glm:
        return glmTextModel;
      case APIProvider.ollama:
        return ollamaTextModel;
      case APIProvider.deepseek:
        return deepseekTextModel;
    }
  }

  String get currentVisionModel {
    switch (_currentProvider) {
      case APIProvider.glm:
        return glmVisionModel;
      case APIProvider.ollama:
        return ollamaVisionModel;
      case APIProvider.deepseek:
        return deepseekVisionModel;
    }
  }

  bool get isGLM => _currentProvider == APIProvider.glm;
  bool get isOllama => _currentProvider == APIProvider.ollama;
  bool get isDeepSeek => _currentProvider == APIProvider.deepseek;

  /// 检查是否有内置的 API Key
  bool get hasHardcodedKey => _hardcodedEncryptedKey.isNotEmpty;

  /// 确保配置目录存在
  Future<void> _ensureConfigDir() async {
    final dir = Directory(_configDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('[APIConfig] 创建配置目录: $_configDir');
    }
  }

  /// 初始化配置（从数据库加载）
  /// 幂等：多次调用只初始化一次
  Future<void> init() async {
    if (_initialized) {
      print('[APIConfig] 已初始化，跳过');
      return;
    }

    // Web 平台不支持数据库
    if (kIsWeb) {
      _initialized = true;
      if (_hardcodedEncryptedKey.isNotEmpty) {
        final decrypted = CryptoService.decrypt(_hardcodedEncryptedKey);
        if (decrypted != null) {
          _glmApiKey = decrypted;
        }
      }
      notifyListeners();
      return;
    }

    // 确保配置目录存在
    await _ensureConfigDir();

    // 加载 Provider 配置
    await _loadProviderConfig();

    // 尝试从数据库加载 GLM API Key
    final encryptedKeyFromDb = await _loadEncryptedKeyFromDatabase();

    if (encryptedKeyFromDb.isNotEmpty) {
      final decrypted = CryptoService.decrypt(encryptedKeyFromDb);
      if (decrypted != null) {
        _glmApiKey = decrypted;
      }
    } else if (_hardcodedEncryptedKey.isNotEmpty) {
      final decrypted = CryptoService.decrypt(_hardcodedEncryptedKey);
      if (decrypted != null) {
        _glmApiKey = decrypted;
      }
    }

    // 尝试从数据库加载 DeepSeek API Key
    final encryptedDeepseekKeyFromDb =
        await _loadEncryptedDeepseekKeyFromDatabase();

    if (encryptedDeepseekKeyFromDb.isNotEmpty) {
      final decrypted = CryptoService.decrypt(encryptedDeepseekKeyFromDb);
      if (decrypted != null) {
        _deepseekApiKey = decrypted;
      }
    }

    _initialized = true;
    notifyListeners();
  }

  /// 从数据库加载加密的 API Key
  Future<String> _loadEncryptedKeyFromDatabase() async {
    try {
      final encryptedKey = await _db.getConfig(_encryptedApiKeyKey);
      if (encryptedKey == null) {
        return '';
      }
      return encryptedKey;
    } catch (e) {
      print('[APIConfig] 从数据库读取加密 Key 失败: $e');
      return '';
    }
  }

  /// 从数据库加载加密的 DeepSeek API Key
  Future<String> _loadEncryptedDeepseekKeyFromDatabase() async {
    try {
      final encryptedKey = await _db.getConfig(_encryptedDeepseekApiKeyKey);
      if (encryptedKey == null) {
        return '';
      }
      return encryptedKey;
    } catch (e) {
      print('[APIConfig] 从数据库读取 DeepSeek 加密 Key 失败: $e');
      return '';
    }
  }

  /// 保存加密后的 API Key 到数据库
  Future<void> _saveEncryptedKeyToDatabase(String encryptedKey) async {
    try {
      await _db.setConfig(_encryptedApiKeyKey, encryptedKey);
    } catch (e) {
      print('[APIConfig] 保存加密 Key 到数据库失败: $e');
    }
  }

  /// 加载 Provider 配置
  Future<void> _loadProviderConfig() async {
    try {
      final file = File('$_configDir/$_configFile');
      if (!await file.exists()) {
        print('[APIConfig] 配置文件不存在，使用默认 Provider: GLM');
        _currentProvider = APIProvider.glm;
        return;
      }

      final content = await file.readAsString();
      final lines = content.split('\n');

      for (final line in lines) {
        if (line.startsWith('provider=')) {
          final value = line.substring('provider='.length).trim();
          if (value == 'ollama') {
            _currentProvider = APIProvider.ollama;
          } else if (value == 'deepseek') {
            _currentProvider = APIProvider.deepseek;
          } else {
            _currentProvider = APIProvider.glm;
          }
        } else if (line.startsWith('ollama_url=')) {
          _ollamaUrl = line.substring('ollama_url='.length).trim();
          if (_ollamaUrl.isEmpty) {
            _ollamaUrl = defaultOllamaUrl;
          }
        }
      }

      print('[APIConfig] 从配置文件加载 Provider: $_currentProvider');
      print('[APIConfig] Ollama URL: $_ollamaUrl');
    } catch (e) {
      print('[APIConfig] 读取配置文件失败: $e');
      _currentProvider = APIProvider.glm;
    }
  }

  /// 保存 Provider 配置
  Future<void> _saveProviderConfig() async {
    try {
      await _ensureConfigDir();
      final file = File('$_configDir/$_configFile');
      final content = '''provider=${_currentProvider.name}
ollama_url=$_ollamaUrl
''';
      await file.writeAsString(content);
      print('[APIConfig] 配置已保存到: $_configDir/$_configFile');
    } catch (e) {
      print('[APIConfig] 保存配置文件失败: $e');
    }
  }

  /// 清除"刚导入"标记
  void clearKeyImportedFlag() {
    _keyJustImported = false;
  }

  /// 清除"刚保存到源代码"标记
  void clearKeySavedToSourceFlag() {
    _keySavedToSource = false;
  }

  /// 切换 API 提供商
  Future<void> setProvider(APIProvider provider) async {
    _currentProvider = provider;
    await _saveProviderConfig();
    notifyListeners();
  }

  /// 设置 GLM API Key（加密后保存到数据库）
  Future<void> setGLMApiKey(String apiKey) async {
    _glmApiKey = apiKey;

    // 加密后保存到数据库
    final encrypted = CryptoService.encrypt(apiKey);
    if (encrypted == null) {
      print('[APIConfig] GLM API Key 加密失败');
      return;
    }

    await _saveEncryptedKeyToDatabase(encrypted);

    print('[APIConfig] 内存中的 API Key 已更新');
    print('');

    notifyListeners();
  }

  /// 设置 DeepSeek API Key（加密后保存到数据库）
  Future<void> setDeepseekApiKey(String apiKey) async {
    _deepseekApiKey = apiKey;

    // 加密后保存到数据库
    final encrypted = CryptoService.encrypt(apiKey);
    if (encrypted == null) {
      print('[APIConfig] DeepSeek API Key 加密失败');
      return;
    }

    await _db.setConfig(_encryptedDeepseekApiKeyKey, encrypted);

    print('[APIConfig] DeepSeek API Key 已更新');
    print('');

    notifyListeners();
  }

  /// 将当前 API Key 加密并保存到源代码文件
  /// 仅在开发阶段使用，需要热重启才能生效
  Future<bool> saveApiKeyToSourceCode() async {
    if (_glmApiKey.isEmpty) {
      debugPrint('[APIConfig] 没有可保存的 API Key');
      return false;
    }

    // Web 平台不支持文件写入
    if (kIsWeb) {
      debugPrint('[APIConfig] Web 平台不支持写入源代码');
      return false;
    }

    try {
      final encrypted = CryptoService.encrypt(_glmApiKey);
      if (encrypted == null) {
        debugPrint('[APIConfig] API Key 加密失败');
        return false;
      }
      final file = File('lib/services/api_config.dart');

      if (!await file.exists()) {
        debugPrint('[APIConfig] 找不到 api_config.dart 文件');
        return false;
      }

      String content = await file.readAsString();

      // 使用正则替换硬编码值
      final pattern =
          RegExp(r"static const String _hardcodedEncryptedKey = '[^']*';");
      final replacement =
          "static const String _hardcodedEncryptedKey = 'xy7MPOnCW6ShMnOWzkVlbbebwFpxUvADGJXwSGHMpoazcQVKI3+KkgWiHSkSBfqE4khTXle49GW8sbXlyD02zg==';";

      if (pattern.hasMatch(content)) {
        content = content.replaceAll(pattern, replacement);
        await file.writeAsString(content);

        _keySavedToSource = true;
        debugPrint('[APIConfig] API Key 已加密并写入源代码，请热重启应用');
        return true;
      } else {
        debugPrint('[APIConfig] 找不到 _hardcodedEncryptedKey 定义');
        return false;
      }
    } catch (e) {
      debugPrint('[APIConfig] 写入源代码失败: $e');
      return false;
    }
  }

  /// 设置 Ollama URL
  Future<void> setOllamaUrl(String url) async {
    _ollamaUrl = url;
    await _saveProviderConfig();
    notifyListeners();
  }

  /// 检查当前配置是否有效
  bool get isConfigValid {
    switch (_currentProvider) {
      case APIProvider.glm:
        return _glmApiKey.isNotEmpty;
      case APIProvider.ollama:
        return _ollamaUrl.isNotEmpty;
      case APIProvider.deepseek:
        return _deepseekApiKey.isNotEmpty;
    }
  }

  /// 获取配置状态描述
  String get configStatus {
    switch (_currentProvider) {
      case APIProvider.glm:
        if (_glmApiKey.isEmpty) {
          return 'GLM API: 未配置 API Key';
        }
        return 'GLM API: 已配置 (${glmTextModel})';
      case APIProvider.ollama:
        return 'Ollama: $_ollamaUrl';
      case APIProvider.deepseek:
        if (_deepseekApiKey.isEmpty) {
          return 'DeepSeek API: 未配置 API Key';
        }
        return 'DeepSeek API: 已配置 (${deepseekTextModel})';
    }
  }

  /// 获取 API Key 的掩码显示（用于调试）
  String get apiKeyMask {
    if (_glmApiKey.isEmpty) return '(未设置)';
    if (_glmApiKey.length <= 10) return '***';
    return '${_glmApiKey.substring(0, 4)}...${_glmApiKey.substring(_glmApiKey.length - 4)}';
  }

  /// 清除保存的 API Key（允许重新输入）
  Future<void> clearApiKey() async {
    _glmApiKey = '';
    try {
      await _db.deleteConfig(_encryptedApiKeyKey);
      print('[APIConfig] 已从数据库删除加密 Key');
    } catch (e) {
      print('[APIConfig] 删除加密 Key 失败: $e');
    }
    notifyListeners();
  }
}
