import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class WorkbookWidget extends StatelessWidget {
  const WorkbookWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    print('[E2E-DEBUG] ✅ WorkbookWidget.build() called');
    print(
        '[E2E-DEBUG] streamingWorkbookContent length: ${appProvider.streamingWorkbookContent.length}');
    final workbookContent = appProvider.streamingWorkbookContent;
    final hasContent = workbookContent.isNotEmpty;

    return Container(
      color: Colors.white,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3EBFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
                child: CustomPaint(painter: _WorkbookPaperPainter())),
            Positioned.fill(
                child: CustomPaint(
                    painter: _WorkbookMarkPainter(appProvider.workbookMarks))),
            Padding(
              padding: const EdgeInsets.only(
                  left: 55, top: 20, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: hasContent
                        ? SingleChildScrollView(
                            child: Text(
                              workbookContent,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                                height: 1.6,
                              ),
                            ),
                          )
                        : const Center(
                            child: Text(
                              '请在对话框中要求 AI 出题',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
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
        canvas.drawLine(
            Offset(dx - 10, dy - 10), Offset(dx + 10, dy + 10), paint);
        canvas.drawLine(
            Offset(dx + 10, dy - 10), Offset(dx - 10, dy + 10), paint);
      } else if (type == 'text') {
        textPainter.text = TextSpan(
          text: mark['content'] ?? '',
          style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif'),
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
      ..color = Colors.blue.withOpacity(0.08)
      ..strokeWidth = 1.0;

    final marginPaint = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..strokeWidth = 2.0;

    const double lineSpacing = 24.0;
    for (double y = 30; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    canvas.drawLine(const Offset(45, 0), Offset(45, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
