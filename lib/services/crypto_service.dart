import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

/// 加密服务
/// 使用 AES 加密算法保护敏感数据
class CryptoService {
  // 从应用标识生成固定密钥（32字节用于 AES-256）
  static final Key _key = _deriveKey('Pdflew83%dlfjM<dfesdfWD');
  // 使用固定的 IV（16字节）- 必须固定，否则每次运行解密都会失败
  static final IV _iv = IV.fromUtf8('LoPdpsdie93=2ld{'); // 正好16字节

  /// 从字符串派生加密密钥
  static Key _deriveKey(String seed) {
    final bytes = utf8.encode(seed);
    final hash = sha256.convert(bytes);
    final keyBytes = Uint8List.fromList(hash.bytes.sublist(0, 32));
    return Key(keyBytes);
  }

  /// 加密字符串（失败返回null）
  static String? encrypt(String plainText) {
    if (plainText.isEmpty) return '';

    try {
      final encrypter = Encrypter(AES(_key));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('[CryptoService] 加密失败: $e');
      return null;
    }
  }

  /// 解密字符串（失败返回null）
  static String? decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return '';

    try {
      final encrypter = Encrypter(AES(_key));
      return encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (e) {
      print('[CryptoService] 解密失败: $e');
      return null;
    }
  }

  /// 检查字符串是否已加密（简单判断：是否为有效的 base64）
  static bool isEncrypted(String text) {
    if (text.isEmpty) return false;
    try {
      final decoded = base64Decode(text);
      return decoded.length % 16 == 0;
    } catch (_) {
      return false;
    }
  }
}
