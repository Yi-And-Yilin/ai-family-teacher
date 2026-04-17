import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class NotebookWidget extends StatelessWidget {
  const NotebookWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    print('[E2E-DEBUG] ✅ NotebookWidget.build() called');
    print(
        '[E2E-DEBUG] streamingNotebookContent length: ${appProvider.streamingNotebookContent.length}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      color: const Color(0xFFF0F0F0), // 灰白色桌面
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 螺旋装订孔背景
          Positioned(
            left: -15,
            top: 40,
            bottom: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ringHeight = 8.0;
                final ringSpacing = 6.0;
                final availableHeight = constraints.maxHeight;
                final ringCount = ((availableHeight + ringSpacing) /
                        (ringHeight + ringSpacing))
                    .floor()
                    .clamp(1, 20);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      List.generate(ringCount, (index) => _buildBindingRing()),
                );
              },
            ),
          ),

          // 笔记本主体
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(4, 4)),
                // 模拟多张纸堆叠的边沿
                const BoxShadow(
                    color: Colors.white, blurRadius: 0, offset: Offset(2, 2)),
                BoxShadow(
                    color: Colors.grey[300]!,
                    blurRadius: 0,
                    offset: const Offset(3, 3)),
              ],
            ),
            child: Stack(
              children: [
                // 方格背景纹理
                Positioned.fill(
                    child: CustomPaint(painter: _NotebookGridPainter())),

                // 笔记内容输入区
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 我的笔记',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                      ),
                      const Divider(
                          height: 30, thickness: 2, color: Colors.black12),
                      Expanded(
                        child: TextField(
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: '开始记录学习笔记...',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 14, height: 1.5),
                          onChanged: (content) =>
                              appProvider.updateNoteContent(content),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBindingRing() {
    return Container(
      width: 30,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          colors: [Colors.grey[600]!, Colors.grey[300]!, Colors.grey[600]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _NotebookGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.05)
      ..strokeWidth = 1.0;

    const double gridSize = 20.0;

    // 绘制垂直线
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 绘制水平线
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
