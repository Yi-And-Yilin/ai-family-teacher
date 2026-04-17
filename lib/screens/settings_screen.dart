import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_config.dart';
import '../i18n/translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _glmApiKeyController = TextEditingController();
  final _deepseekApiKeyController = TextEditingController();
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
      _deepseekApiKeyController.text = config.deepseekApiKey;
      _ollamaUrlController.text = config.ollamaUrl;

      // Check if API key was just imported
      if (config.keyJustImported) {
        setState(() => _showImportSuccess = true);
        config.clearKeyImportedFlag();
      }

      // Check if key was just saved to source code
      if (config.keySavedToSource) {
        setState(() => _showSaveToSourceSuccess = true);
        config.clearKeySavedToSourceFlag();
      }
    });
  }

  @override
  void dispose() {
    _glmApiKeyController.dispose();
    _deepseekApiKeyController.dispose();
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
        title: Text(
          Translations().t('settings_api_title'),
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          final config = appProvider.apiConfig;
          final t = Translations();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Import success banner
                if (_showImportSuccess) _buildImportSuccessBanner(),

                // Save to source success banner
                if (_showSaveToSourceSuccess) _buildSaveToSourceSuccessBanner(),

                // Status card
                _buildStatusCard(config),
                const SizedBox(height: 24),

                // Language setting
                _buildSectionTitle(t.t('settings_section_language')),
                const SizedBox(height: 12),
                _buildLanguageSelector(),
                const SizedBox(height: 24),

                // API provider selection
                _buildSectionTitle(t.t('settings_section_provider')),
                const SizedBox(height: 12),
                _buildProviderSelector(config),
                const SizedBox(height: 24),

                // Show config based on selection
                if (config.isGLM) ...[
                  _buildSectionTitle(t.t('settings_section_glm_config')),
                  const SizedBox(height: 12),
                  _buildGLMConfig(config),
                ] else if (config.isDeepSeek) ...[
                  _buildSectionTitle(t.t('settings_section_deepseek_config')),
                  const SizedBox(height: 12),
                  _buildDeepseekConfig(config),
                ] else ...[
                  _buildSectionTitle(t.t('settings_section_ollama_config')),
                  const SizedBox(height: 12),
                  _buildOllamaConfig(config),
                ],

                const SizedBox(height: 32),

                // Model info
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
              Expanded(
                child: Text(
                  Translations().t('settings_import_success'),
                  style: const TextStyle(
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
            child: Text(
              Translations().t('settings_api_key_cleared_hint'),
              style: const TextStyle(color: Colors.white, fontSize: 13),
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
              Expanded(
                child: Text(
                  Translations().t('settings_saved_to_source'),
                  style: const TextStyle(
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
            child: Text(
              Translations().t('settings_hot_restart_hint'),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                  isValid ? Translations().t('settings_api_configured') : Translations().t('settings_api_not_configured'),
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
                if (config.isDeepSeek && config.deepseekApiKey.isNotEmpty) ...[
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

  Widget _buildLanguageSelector() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final currentLang = appProvider.language;
        final t = Translations();
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
              _buildLanguageOption(
                appProvider,
                'zh',
                t.t('settings_language_zh'),
                t.t('settings_language_en'),
                currentLang == 'zh',
              ),
              const Divider(height: 1),
              _buildLanguageOption(
                appProvider,
                'en',
                t.t('settings_language_en'),
                t.t('settings_language_zh'),
                currentLang == 'en',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    AppProvider appProvider,
    String lang,
    String displayName,
    String subtitle,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await appProvider.setLanguage(lang);
          if (mounted) {
            setState(() {});
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                lang == 'zh' ? Icons.language : Icons.translate,
                color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF7C4DFF)
                            : const Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF7C4DFF),
                  size: 24,
                ),
            ],
          ),
        ),
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
            Translations().t('settings_glm_online'),
            Translations().t('settings_glm_desc'),
            Icons.cloud,
            Translations().t('settings_provider_online_hint'),
          ),
          const Divider(height: 1),
          _buildProviderOption(
            config,
            APIProvider.deepseek,
            Translations().t('settings_deepseek_online'),
            Translations().t('settings_deepseek_desc'),
            Icons.auto_awesome,
            Translations().t('settings_provider_online_hint'),
          ),
          const Divider(height: 1),
          _buildProviderOption(
            config,
            APIProvider.ollama,
            Translations().t('settings_ollama_local'),
            Translations().t('settings_ollama_desc'),
            Icons.computer,
            Translations().t('settings_provider_ollama_hint'),
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
    final t = Translations();

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
                t.t('settings_api_key'),
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
                  child: Text(
                    t.t('settings_built_in'),
                    style: const TextStyle(
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
                  child: Text(
                    t.t('settings_encrypted'),
                    style: const TextStyle(
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
              hintText: hasKey ? '••••••••••••••••' : t.t('settings_glm_key_hint'),
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
              
              if (value.isNotEmpty) {
                print('[SettingsScreen] 值不为空，调用 setGLMApiKey...');
                config.setGLMApiKey(value);
              } else {
                print('[SettingsScreen] 值为空，跳过保存');
              }
              print('');
            },
          ),
          const SizedBox(height: 12),

          // Developer mode: save to source code button
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
                        t.t('settings_developer_mode'),
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
                    t.t('settings_developer_mode_desc'),
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
                                  SnackBar(content: Text(t.t('settings_save_failed'))),
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
                      label: Text(_isSavingToSource ? t.t('settings_saving') : t.t('settings_save_to_source')),
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
                        ? t.t('settings_builtin_key_hint')
                        : t.t('settings_save_to_source_hint'),
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

  Widget _buildDeepseekConfig(APIConfigService config) {
    final hasKey = config.deepseekApiKey.isNotEmpty;
    final t = Translations();

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
                t.t('settings_api_key'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasKey ? Colors.green : Colors.grey[800],
                ),
              ),
              const Spacer(),
              if (hasKey)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t.t('settings_encrypted'),
                    style: const TextStyle(
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
            controller: _deepseekApiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              hintText: hasKey ? '••••••••••••••••' : t.t('settings_deepseek_key_hint'),
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
              if (value.isNotEmpty) {
                print('[SettingsScreen] DeepSeek Key 不为空，调用 setDeepseekApiKey...');
                config.setDeepseekApiKey(value);
              } else {
                print('[SettingsScreen] DeepSeek Key 值为空，跳过保存');
              }
              print('');
            },
          ),
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
                    t.t('settings_deepseek_fetch_hint'),
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
    final t = Translations();

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
              Text(
                t.t('settings_ollama_url_label'),
                style: const TextStyle(
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
                    t.t('settings_ollama_hint'),
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
    final t = Translations();

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
          _buildSectionTitle(t.t('settings_current_model_title')),
          const SizedBox(height: 16),
          _buildModelItem(
            t.t('settings_text_model'),
            config.currentTextModel,
            Icons.text_fields,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildModelItem(
            t.t('settings_vision_model'),
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