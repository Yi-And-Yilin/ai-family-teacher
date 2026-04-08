import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _glmApiKeyController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  bool _obscureApiKey = true;
  bool _showImportSuccess = false;
  bool _showSaveToSourceSuccess = false;
  bool _isSavingToSource = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<AppProvider>().apiConfig;
      _glmApiKeyController.text = config.glmApiKey;
      _ollamaUrlController.text = config.ollamaUrl;
      
      // 检查是否刚导入 API Key
      if (config.keyJustImported) {
        setState(() => _showImportSuccess = true);
        config.clearKeyImportedFlag();
      }
      
      // 检查是否刚保存到源代码
      if (config.keySavedToSource) {
        setState(() => _showSaveToSourceSuccess = true);
        config.clearKeySavedToSourceFlag();
      }
    });
  }

  @override
  void dispose() {
    _glmApiKeyController.dispose();
    _ollamaUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF7C4DFF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'API 设置',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          final config = appProvider.apiConfig;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 导入成功提示
                if (_showImportSuccess) _buildImportSuccessBanner(),
                
                // 保存到源代码成功提示
                if (_showSaveToSourceSuccess) _buildSaveToSourceSuccessBanner(),
                
                // 当前状态卡片
                _buildStatusCard(config),
                const SizedBox(height: 24),
                
                // API 提供商选择
                _buildSectionTitle('API 提供商'),
                const SizedBox(height: 12),
                _buildProviderSelector(config),
                const SizedBox(height: 24),
                
                // 根据选择显示不同配置
                if (config.isGLM) ...[
                  _buildSectionTitle('GLM API 配置'),
                  const SizedBox(height: 12),
                  _buildGLMConfig(config),
                ] else ...[
                  _buildSectionTitle('Ollama 配置'),
                  const SizedBox(height: 12),
                  _buildOllamaConfig(config),
                ],
                
                const SizedBox(height: 32),
                
                // 模型信息
                _buildModelInfo(config),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImportSuccessBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'API Key 已成功导入并加密存储！',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showImportSuccess = false),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'api_key.txt 文件内容已自动清空',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveToSourceSuccessBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.code, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'API Key 已加密并写入源代码！',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showSaveToSourceSuccess = false),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '请按 R 热重启应用以使更改生效',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(APIConfigService config) {
    final isValid = config.isConfigValid;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isValid
              ? [const Color(0xFF66BB6A), const Color(0xFF43A047)]
              : [const Color(0xFFFFA726), const Color(0xFFF57C00)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isValid ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isValid ? Icons.check_circle : Icons.warning,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValid ? 'API 已配置' : 'API 未配置',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.configStatus,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                if (config.isGLM && config.glmApiKey.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Key: ${config.apiKeyMask}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A237E),
      ),
    );
  }

  Widget _buildProviderSelector(APIConfigService config) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProviderOption(
            config,
            APIProvider.glm,
            'GLM 在线 API',
            '智谱AI - 免费 Flash 模型',
            Icons.cloud,
            '使用在线服务，需要 API Key',
          ),
          const Divider(height: 1),
          _buildProviderOption(
            config,
            APIProvider.ollama,
            'Ollama 本地 API',
            '本地部署 - 私有化运行',
            Icons.computer,
            '需要本地运行 Ollama 服务',
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOption(
    APIConfigService config,
    APIProvider provider,
    String title,
    String subtitle,
    IconData icon,
    String description,
  ) {
    final isSelected = config.currentProvider == provider;
    
    return InkWell(
      onTap: () => config.setProvider(provider),
      borderRadius: BorderRadius.vertical(
        top: provider == APIProvider.glm ? const Radius.circular(16) : Radius.zero,
        bottom: provider == APIProvider.ollama ? const Radius.circular(16) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF7C4DFF).withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Radio<APIProvider>(
              value: provider,
              groupValue: config.currentProvider,
              onChanged: (v) => config.setProvider(v!),
              activeColor: const Color(0xFF7C4DFF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGLMConfig(APIConfigService config) {
    final hasKey = config.glmApiKey.isNotEmpty;
    final hasHardcoded = config.hasHardcodedKey;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasKey ? Icons.verified : Icons.key,
                color: hasKey ? Colors.green : const Color(0xFF7C4DFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'API Key',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasKey ? Colors.green : Colors.grey[800],
                ),
              ),
              const Spacer(),
              if (hasHardcoded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '已内置',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (hasKey)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '已加密存储',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _glmApiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              hintText: hasKey ? '••••••••••••••••' : '输入你的 GLM API Key',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[400],
                ),
                onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) {
              print('');
              print('[SettingsScreen] ========== TextField onChanged ==========');
              print('[SettingsScreen] 用户输入的值: "$value"');
              print('[SettingsScreen] 用户输入的值长度: ${value.length}');
              print('[SettingsScreen] 值是否为空: ${value.isEmpty}');
              
              if (value.isNotEmpty) {
                print('[SettingsScreen] 值不为空，调用 setGLMApiKey...');
                config.setGLMApiKey(value);
              } else {
                print('[SettingsScreen] 值为空，跳过保存');
              }
              print('[SettingsScreen] ========== TextField onChanged 结束 ==========');
              print('');
            },
          ),
          const SizedBox(height: 12),
          
          // 开发者模式：保存到源代码按钮
          if (!kIsWeb) ...[
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_circle, color: Colors.orange[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '开发者模式',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '将 API Key 加密后写入源代码，下次启动自动加载（生产环境用）',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: hasKey && !_isSavingToSource
                          ? () async {
                              setState(() => _isSavingToSource = true);
                              final success = await config.saveApiKeyToSourceCode();
                              setState(() => _isSavingToSource = false);
                              
                              if (success && mounted) {
                                setState(() => _showSaveToSourceSuccess = true);
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('保存失败，请检查控制台日志')),
                                );
                              }
                            }
                          : null,
                      icon: _isSavingToSource
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_isSavingToSource ? '保存中...' : '保存到源代码'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.purple[300], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasHardcoded 
                        ? '已使用内置 API Key，可在上方更新后保存'
                        : '输入 API Key 后，可保存到源代码作为内置默认值',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOllamaConfig(APIConfigService config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, color: Color(0xFF7C4DFF), size: 20),
              const SizedBox(width: 8),
              const Text(
                '服务地址',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ollamaUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:11434/api/chat',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) => config.setOllamaUrl(value),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[300], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '确保 Ollama 服务已启动，并安装了 qwen3.5:9b 和 qwen3-vl:8b 模型',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInfo(APIConfigService config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('当前使用的模型'),
          const SizedBox(height: 16),
          _buildModelItem(
            '文本模型',
            config.currentTextModel,
            Icons.text_fields,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildModelItem(
            '视觉模型',
            config.currentVisionModel,
            Icons.image,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildModelItem(String label, String model, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                model,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}