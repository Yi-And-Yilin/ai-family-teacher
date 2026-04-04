import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class WorkbookWidget extends StatelessWidget {
  const WorkbookWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFE0E0E0), // 桌面背景色
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDE7), // 护眼米黄纸张
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(5, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 绘制横线和红色边线
            Positioned.fill(child: CustomPaint(painter: _WorkbookPaperPainter())),
            
            // 绘制 AI 批改痕迹
            Positioned.fill(child: CustomPaint(painter: _WorkbookMarkPainter(appProvider.workbookMarks))),

            // 内容区域
            Padding(
              padding: const EdgeInsets.only(left: 60, top: 40, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 页眉
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('日期: 2026年3月19日', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontFamily: 'serif')),
                      Text('页码: 001', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontFamily: 'serif')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // 题目区域
                  Text(
                    '题目：${appProvider.currentQuestion.isEmpty ? "请在对话框中要求 AI 出题" : appProvider.currentQuestion}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 40, color: Colors.transparent),
                  
                  // 答题区域（模拟输入）
                  const Expanded(
                    child: TextField(
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: '在这里写下你的答案...',
                        hintStyle: TextStyle(color: Colors.black26),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontSize: 16, height: 1.875, color: Colors.black87), // 1.875 对应横线间距
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbookMarkPainter extends CustomPainter {
  final List<Map<String, dynamic>> marks;
  _WorkbookMarkPainter(this.marks);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final mark in marks) {
      final type = mark['type'];
      final pos = mark['position'] ?? {'x': 100.0, 'y': 100.0};
      final dx = (pos['x'] as num).toDouble();
      final dy = (pos['y'] as num).toDouble();

      if (type == 'circle') {
        canvas.drawCircle(Offset(dx, dy), 30, paint);
      } else if (type == 'tick') {
        final path = Path()
          ..moveTo(dx - 10, dy)
          ..lineTo(dx - 2, dy + 10)
          ..lineTo(dx + 15, dy - 15);
        canvas.drawPath(path, paint);
      } else if (type == 'cross') {
        canvas.drawLine(Offset(dx - 10, dy - 10), Offset(dx + 10, dy + 10), paint);
        canvas.drawLine(Offset(dx + 10, dy - 10), Offset(dx - 10, dy + 10), paint);
      } else if (type == 'text') {
        textPainter.text = TextSpan(
          text: mark['content'] ?? '',
          style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif'),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(dx, dy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WorkbookPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..strokeWidth = 1.0;
    
    final marginPaint = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..strokeWidth = 2.0;

    // 绘制横线
    const double lineSpacing = 30.0;
    for (double y = 80; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 绘制左侧红色装饰边线
    canvas.drawLine(const Offset(50, 0), Offset(50, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
