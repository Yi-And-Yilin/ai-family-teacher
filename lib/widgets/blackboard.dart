import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:ui' as ui;

import '../providers/app_provider.dart';

class BlackboardWidget extends StatefulWidget {
  const BlackboardWidget({super.key});

  @override
  State<BlackboardWidget> createState() => _BlackboardWidgetState();
}

class _BlackboardWidgetState extends State<BlackboardWidget> {
  final List<Stroke> _strokes = [];
  Color _currentColor = Colors.white;
  final double _currentWidth = 3.0;
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    print('[E2E-DEBUG] ✅ BlackboardWidget.build() called');
    print(
        '[E2E-DEBUG] streamingBlackboardContent length: ${appProvider.streamingBlackboardContent.length}');
    final blackboardElements = appProvider.blackboardElements;
    final streamingContent = appProvider.streamingBlackboardContent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B3022),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black26, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              // 黑板背景纹理
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(painter: _BlackboardTexturePainter()),
                ),
              ),

              // AI绘制的内容（手写笔迹层）
              CustomPaint(
                painter: _BlackboardPainter(blackboardElements),
                size: Size.infinite,
              ),

              // 流式文本内容层（支持LaTeX）
              if (streamingContent.isNotEmpty)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: _buildStreamingContent(streamingContent),
                ),

              // 孩子手写层
              _buildStudentDrawingLayer(),

              // 工具栏
              _buildToolbar(),

              // 底部粉笔槽装饰
              _buildChalkTray(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建流式内容（支持LaTeX公式）
  Widget _buildStreamingContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // 检测是否包含LaTeX公式 $$...$$
      if (line.contains(r'$$')) {
        widgets.add(_buildLatexLine(line));
      } else {
        widgets.add(_buildTextLine(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 构建包含LaTeX公式的行
  Widget _buildLatexLine(String line) {
    final parts = <Widget>[];
    final regex = RegExp(r'\$\$(.+?)\$\$');
    int lastEnd = 0;

    for (final match in regex.allMatches(line)) {
      // 添加公式前的文本
      if (match.start > lastEnd) {
        final text = line.substring(lastEnd, match.start);
        if (text.isNotEmpty) {
          parts.add(_buildTextSpan(text));
        }
      }

      // 添加LaTeX公式
      final latex = match.group(1) ?? '';
      parts.add(_buildLatexFormula(latex));

      lastEnd = match.end;
    }

    // 添加最后的文本
    if (lastEnd < line.length) {
      final text = line.substring(lastEnd);
      if (text.isNotEmpty) {
        parts.add(_buildTextSpan(text));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: parts,
      ),
    );
  }

  /// 构建LaTeX公式组件
  Widget _buildLatexFormula(String latex) {
    try {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Math.tex(
          latex,
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          mathStyle: MathStyle.display,
        ),
      );
    } catch (e) {
      // LaTeX解析失败，显示原文
      return _buildTextSpan('\$\$$latex\$\$');
    }
  }

  /// 构建普通文本行
  Widget _buildTextLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _buildTextSpan(text),
    );
  }

  /// 构建文本组件
  Widget _buildTextSpan(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'serif',
        height: 1.5,
        shadows: [
          Shadow(color: Colors.white24, blurRadius: 2),
        ],
      ),
    );
  }

  Widget _buildStudentDrawingLayer() {
    return Stack(
      children: [
        CustomPaint(
          painter: _StrokePainter(_strokes),
          size: Size.infinite,
        ),
        CustomPaint(
          painter: _CurrentStrokePainter(
              _currentPoints, _currentColor, _currentWidth),
          size: Size.infinite,
        ),
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          _buildToolButton(
              icon: Icons.edit,
              color: Colors.white,
              onTap: () => _selectColor(Colors.white)),
          _buildToolButton(
              icon: Icons.edit,
              color: Colors.yellow[200]!,
              onTap: () => _selectColor(Colors.yellow[200]!)),
          _buildToolButton(
              icon: Icons.edit,
              color: Colors.pink[100]!,
              onTap: () => _selectColor(Colors.pink[100]!)),
          const SizedBox(height: 12),
          _buildToolButton(
              icon: Icons.layers_clear,
              color: Colors.white70,
              onTap: _clearAll),
        ],
      ),
    );
  }

  Widget _buildChalkTray() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 10,
        decoration: BoxDecoration(color: Colors.black38, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, -2))
        ]),
      ),
    );
  }

  Widget _buildToolButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDrawing = true;
      _currentPoints = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;
    setState(() => _currentPoints.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _isDrawing = false;
      _strokes.add(Stroke(
          points: List.from(_currentPoints),
          color: _currentColor,
          width: _currentWidth));
      _currentPoints.clear();
    });
  }

  void _selectColor(Color color) => setState(() => _currentColor = color);
  void _clearAll() => setState(() => _strokes.clear());
}

// --- 纹理绘制 (模拟粉笔灰) ---
class _BlackboardTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    final random = ui.Gradient.linear(Offset.zero,
        Offset(size.width, size.height), [Colors.white10, Colors.transparent]);
    // 这里简单画一些随机点模拟灰尘，实际可以用图片纹理
    for (int i = 0; i < 100; i++) {
      canvas.drawCircle(
          Offset(size.width * (i / 100), size.height * ((i * 7 % 100) / 100)),
          1,
          paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// --- 笔划模型 ---
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  const Stroke(
      {required this.points, this.color = Colors.white, this.width = 3.0});
}

// --- 笔划绘制 (粉笔效果) ---
class _StrokePainter extends CustomPainter {
  final List<Stroke> strokes;
  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5) // 粉笔模糊效果
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CurrentStrokePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double width;
  _CurrentStrokePainter(this.points, this.color, this.width);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5)
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++)
      path.lineTo(points[i].dx, points[i].dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BlackboardPainter extends CustomPainter {
  final List<dynamic> elements;
  _BlackboardPainter(this.elements);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final element in elements) {
      final type = element['type'] ?? 'text';
      final content = element['content'];
      final position = element['position'] ?? {'x': 0.0, 'y': 0.0};
      final style = element['style'] ?? {};

      if (type == 'text') {
        textPainter.text = TextSpan(
          text: content.toString(),
          style: TextStyle(
            color: _getColor(style['color']).withOpacity(0.9),
            fontSize: (style['fontSize'] ?? 14.0).toDouble(),
            fontFamily: 'Chalkboard', // 尝试使用粉笔字体，如果系统没有则回退
            shadows: [
              Shadow(color: Colors.white.withOpacity(0.3), blurRadius: 2)
            ],
          ),
        );
        textPainter.layout();
        textPainter.paint(
            canvas, Offset(position['x'].toDouble(), position['y'].toDouble()));
      }
    }
  }

  Color _getColor(dynamic colorData) {
    if (colorData is String && colorData.startsWith('#')) {
      return Color(int.parse(colorData.substring(1), radix: 16) + 0xFF000000);
    }
    return Colors.white;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
