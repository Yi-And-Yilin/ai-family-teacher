import 'dart:ui';
import 'package:flutter/material.dart';

/// iOS 风格设计常量
/// 基于 iOS 设计规范和配色方案
class iOSTheme {
  // ===== 配色系统 =====
  
  /// iOS 系统蓝色（用户消息气泡）
  static const Color blue = Color(0xFF007AFF);
  
  /// iOS 系统浅灰（AI 消息气泡背景）
  static const Color lightGray = Color(0xFFF2F2F7);
  
  /// iOS 系统中灰（次要文本、分隔线）
  static const Color systemGray = Color(0xFF8E8E93);
  
  /// iOS 系统浅灰 2（输入框背景）
  static const Color systemGray5 = Color(0xFFE5E5EA);
  
  /// iOS 系统浅灰 3（更浅的背景）
  static const Color systemGray6 = Color(0xFFF2F2F7);
  
  /// 纯白背景
  static const Color white = Color(0xFFFFFFFF);
  
  /// 主文本颜色（接近黑色）
  static const Color label = Color(0xFF000000);
  
  /// 次要文本颜色（中灰）
  static const Color secondaryLabel = Color(0xFF3C3C43);
  
  /// 三级文本颜色（浅灰）
  static const Color tertiaryLabel = Color(0xFF8E8E93);
  
  // ===== 阴影系统 =====
  
  /// 微妙阴影（卡片、输入框）
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];
  
  /// 浅色斜阴影（消息气泡）
  static const List<BoxShadow> bubbleShadow = [
    BoxShadow(
      color: Color(0x08000000),
      offset: Offset(2, -2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];
  
  // ===== 圆角半径 =====
  
  /// 小圆角（按钮、标签）
  static const double radiusSmall = 8.0;
  
  /// 中圆角（输入框、卡片）
  static const double radiusMedium = 12.0;
  
  /// 大圆角（气泡、弹窗）
  static const double radiusLarge = 20.0;
  
  /// 超大圆角（完全圆形）
  static const double radiusExtraLarge = 24.0;
  
  // ===== 间距系统 =====
  
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 16.0;
  static const double spacingXLarge = 20.0;
  static const double spacingXXLarge = 24.0;
  
  // ===== 字体大小 =====
  
  /// iOS 大标题（进入时）
  static const double largeTitle = 24.0;
  
  /// iOS 标题 1
  static const double title1 = 17.0;
  
  /// iOS 标题 2
  static const double title2 = 15.0;
  
  /// iOS 正文（大）
  static const double body = 16.0;
  
  /// iOS 正文（标准）
  static const double subhead = 15.0;
  
  /// iOS 脚注
  static const double footnote = 13.0;
  
  /// iOS 说明文字
  static const double caption1 = 12.0;
  
  // ===== 毛玻璃效果 =====
  
  /// 创建 iOS 风格毛玻璃背景
  static Widget frostedGlass({
    required Widget child,
    double blur = 10.0,
    Color tint = Colors.white,
    double opacity = 0.8,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          color: tint.withOpacity(opacity),
          child: child,
        ),
      ),
    );
  }
  
  // ===== 滚动效果 =====
  
  /// iOS 弹性滚动物理
  static const ScrollPhysics bouncingScroll = BouncingScrollPhysics();
  
  // ===== 动画 =====
  
  /// iOS 标准动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  /// 快速动画
  static const Duration fastAnimation = Duration(milliseconds: 200);
}
