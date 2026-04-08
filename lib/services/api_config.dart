import 'dart:io';
import 'package:flutter/foundation.dart';
import 'crypto_service.dart';

/// API 提供商类型
enum APIProvider {
  glm,     // GLM 在线 API (智谱AI)
  ollama,  // 本地 Ollama API
}

/// API 配置服务
class APIConfigService extends ChangeNotifier {
  // 配置文件目录 - 放在 config 子文件夹下
  static const String _configDir = 'config';
  static const String _encryptedKeyFile = 'api_key_encrypted.txt';
  static const String _configFile = 'api_config.txt';
  
  // 默认配置
  static const String defaultOllamaUrl = 'http://192.168.4.22:11434/api/chat';
  static const String glmApiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  
  // GLM 模型配置
  static const String glmTextModel = 'glm-4.7-flash';      // 免费文本模型
  static const String glmVisionModel = 'glm-4v-flash';     // 免费视觉模型
  
  // Ollama 模型配置
  static const String ollamaTextModel = 'qwen3.5:9b';
  static const String ollamaVisionModel = 'qwen3-vl:8b';
  
  // ========================================
  // 内置的加密 API Key（开发者模式）
  // 开发时通过设置界面"保存到源代码"按钮自动更新此值
  // 生产环境：此值会被编译进应用，用户无法修改
  // ========================================
  static const String _hardcodedEncryptedKey = '';
  
  APIProvider _currentProvider = APIProvider.glm;  // 默认使用 GLM
  String _glmApiKey = '';
  String _ollamaUrl = defaultOllamaUrl;
  bool _keyJustImported = false;
  bool _keySavedToSource = false;  // 标记是否刚保存到源代码
  
  APIProvider get currentProvider => _currentProvider;
  String get glmApiKey => _glmApiKey;
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
    }
  }
  
  String get currentTextModel {
    switch (_currentProvider) {
      case APIProvider.glm:
        return glmTextModel;
      case APIProvider.ollama:
        return ollamaTextModel;
    }
  }
  
  String get currentVisionModel {
    switch (_currentProvider) {
      case APIProvider.glm:
        return glmVisionModel;
      case APIProvider.ollama:
        return ollamaVisionModel;
    }
  }
  
  bool get isGLM => _currentProvider == APIProvider.glm;
  bool get isOllama => _currentProvider == APIProvider.ollama;
  
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
  
  /// 初始化配置（从文件加载）
  Future<void> init() async {
    print('');
    print('[APIConfig] ========== 初始化开始 ==========');
    
    // Web 平台不支持文件操作
    if (kIsWeb) {
      print('[APIConfig] Web 平台，使用硬编码 Key');
      if (_hardcodedEncryptedKey.isNotEmpty) {
        _glmApiKey = CryptoService.decrypt(_hardcodedEncryptedKey);
      }
      notifyListeners();
      return;
    }
    
    // 确保配置目录存在
    await _ensureConfigDir();
    
    // 加载 Provider 配置
    await _loadProviderConfig();
    
    // 加载 API Key（优先级：加密文件 > 硬编码）
    print('[APIConfig] ---------- 加载 API Key ----------');
    
    // 尝试从加密文件加载
    final encryptedKeyFromFile = await _loadEncryptedKeyFromFile();
    
    if (encryptedKeyFromFile.isNotEmpty) {
      print('[APIConfig] 从文件加载到加密 Key，尝试解密...');
      _glmApiKey = CryptoService.decrypt(encryptedKeyFromFile);
      print('[APIConfig] 解密后长度: ${_glmApiKey.length}');
    } else if (_hardcodedEncryptedKey.isNotEmpty) {
      print('[APIConfig] 使用硬编码的加密 Key');
      _glmApiKey = CryptoService.decrypt(_hardcodedEncryptedKey);
      print('[APIConfig] 解密后长度: ${_glmApiKey.length}');
    }
    
    print('[APIConfig] 最终加载的 API Key 长度: ${_glmApiKey.length}');
    print('[APIConfig] 最终加载的 API Key: "$_glmApiKey"');
    print('[APIConfig] ========== 初始化结束 ==========');
    print('');
    
    notifyListeners();
  }
  
  /// 从文件加载加密的 API Key
  Future<String> _loadEncryptedKeyFromFile() async {
    try {
      final file = File('$_configDir/$_encryptedKeyFile');
      if (!await file.exists()) {
        print('[APIConfig] 加密 Key 文件不存在: $_configDir/$_encryptedKeyFile');
        return '';
      }
      
      final content = await file.readAsString();
      final encryptedKey = content.trim();
      
      print('[APIConfig] 从文件读取到加密 Key 长度: ${encryptedKey.length}');
      print('[APIConfig] 加密 Key 内容: "$encryptedKey"');
      
      return encryptedKey;
    } catch (e) {
      print('[APIConfig] 读取加密 Key 文件失败: $e');
      return '';
    }
  }
  
  /// 保存加密后的 API Key 到文件
  Future<void> _saveEncryptedKeyToFile(String encryptedKey) async {
    try {
      await _ensureConfigDir();
      final file = File('$_configDir/$_encryptedKeyFile');
      await file.writeAsString(encryptedKey);
      print('[APIConfig] 加密 Key 已保存到: $_configDir/$_encryptedKeyFile');
    } catch (e) {
      print('[APIConfig] 保存加密 Key 文件失败: $e');
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
  
  /// 设置 GLM API Key（加密后保存到文件）
  Future<void> setGLMApiKey(String apiKey) async {
    print('');
    print('[APIConfig] ========== 设置 API Key 开始 ==========');
    print('[APIConfig] 收到的原始输入长度: ${apiKey.length}');
    print('[APIConfig] 收到的原始输入: "$apiKey"');
    
    _glmApiKey = apiKey;
    
    // 加密后保存到文件
    print('[APIConfig] 正在加密...');
    final encrypted = CryptoService.encrypt(apiKey);
    print('[APIConfig] 加密后的密文: "$encrypted"');
    
    await _saveEncryptedKeyToFile(encrypted);
    
    print('[APIConfig] 内存中的 API Key 已更新');
    print('[APIConfig] ========== 设置 API Key 结束 ==========');
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
      final file = File('lib/services/api_config.dart');
      
      if (!await file.exists()) {
        debugPrint('[APIConfig] 找不到 api_config.dart 文件');
        return false;
      }
      
      String content = await file.readAsString();
      
      // 使用正则替换硬编码值
      final pattern = RegExp(
        r"static const String _hardcodedEncryptedKey = '[^']*';"
      );
      final replacement = "static const String _hardcodedEncryptedKey = 'xy7MPOnCW6ShMnOWzkVlbbebwFpxUvADGJXwSGHMpoazcQVKI3+KkgWiHSkSBfqE4khTXle49GW8sbXlyD02zg==';";
      
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
      final file = File('$_configDir/$_encryptedKeyFile');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('[APIConfig] 删除加密 Key 文件失败: $e');
    }
    notifyListeners();
  }
}