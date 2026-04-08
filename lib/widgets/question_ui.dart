import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

import '../providers/app_provider.dart';
import '../prompts/question_generator_prompt.dart';

/// 题目展示和答题组件
class QuestionUIWidget extends StatefulWidget {
  final QuestionData question;
  final Function(String answer) onAnswerSubmitted;
  final bool showAnswer;
  final String? correctAnswer;
  final String? userAnswer;

  const QuestionUIWidget({
    super.key,
    required this.question,
    required this.onAnswerSubmitted,
    this.showAnswer = false,
    this.correctAnswer,
    this.userAnswer,
  });

  @override
  State<QuestionUIWidget> createState() => _QuestionUIWidgetState();
}

class _QuestionUIWidgetState extends State<QuestionUIWidget> {
  String? _selectedOption;
  final TextEditingController _textController = TextEditingController();
  AnswerMode _answerMode = AnswerMode.selection;
  
  // 手写相关
  final List<Stroke> _strokes = [];
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;
  Color _penColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    // 根据题目类型设置默认答题模式
    if (widget.question.type == QuestionType.choice) {
      _answerMode = AnswerMode.selection;
    } else {
      _answerMode = AnswerMode.typing;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目头部
          _buildHeader(),
          
          // 题目内容
          _buildQuestionContent(),
          
          // 选项区域（选择题）
          if (widget.question.type == QuestionType.choice && 
              widget.question.options != null)
            _buildOptions(),
          
          // 答题模式切换
          if (widget.question.type != QuestionType.choice)
            _buildAnswerModeSelector(),
          
          // 答题区域
          _buildAnswerArea(),
          
          // 提交按钮
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getQuestionTypeLabel(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getDifficultyColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getDifficultyLabel(),
              style: TextStyle(color: _getDifficultyColor(), fontSize: 11),
            ),
          ),
          const Spacer(),
          Text(
            widget.question.subject,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: widget.question.content,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16, height: 1.6),
          code: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey[200],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: widget.question.options!.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final optionKey = String.fromCharCode(65 + index); // A, B, C, D
          final isSelected = _selectedOption == optionKey;
          final isCorrect = widget.showAnswer && 
                           widget.correctAnswer == optionKey;
          final isWrong = widget.showAnswer && 
                         widget.userAnswer == optionKey && 
                         widget.correctAnswer != optionKey;

          return GestureDetector(
            onTap: widget.showAnswer ? null : () {
              setState(() => _selectedOption = optionKey);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF7C4DFF).withOpacity(0.1)
                    : isCorrect
                        ? Colors.green.withOpacity(0.1)
                        : isWrong
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7C4DFF)
                      : isCorrect
                          ? Colors.green
                          : isWrong
                              ? Colors.red
                              : Colors.grey[200]!,
                  width: isSelected || isCorrect || isWrong ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFF7C4DFF)
                          : isCorrect
                              ? Colors.green
                              : isWrong
                                  ? Colors.red
                                  : Colors.transparent,
                      border: Border.all(
                        color: isSelected || isCorrect || isWrong
                            ? Colors.transparent
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        optionKey,
                        style: TextStyle(
                          color: isSelected || isCorrect || isWrong
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  if (isWrong)
                    const Icon(Icons.cancel, color: Colors.red, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnswerModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: AnswerMode.values.map((mode) {
          final isSelected = _answerMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _answerMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7C4DFF) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getModeLabel(mode),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnswerArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _answerMode == AnswerMode.typing
            ? _buildTypingArea()
            : _answerMode == AnswerMode.handwriting
                ? _buildHandwritingArea()
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildTypingArea() {
    return Container(
      key: const ValueKey('typing'),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: _textController,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: '在这里输入你的答案...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildHandwritingArea() {
    return Container(
      key: const ValueKey('handwriting'),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        children: [
          // 手写画布
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _isDrawing = true;
                _currentPoints = [details.localPosition];
              });
            },
            onPanUpdate: (details) {
              if (!_isDrawing) return;
              setState(() => _currentPoints.add(details.localPosition));
            },
            onPanEnd: (details) {
              if (!_isDrawing) return;
              setState(() {
                _isDrawing = false;
                if (_currentPoints.isNotEmpty) {
                  _strokes.add(Stroke(
                    points: List.from(_currentPoints),
                    color: _penColor,
                    width: 2.0,
                  ));
                }
                _currentPoints.clear();
              });
            },
            child: Container(
              color: Colors.transparent,
              child: CustomPaint(
                painter: _HandwritingPainter(_strokes, _currentPoints, _penColor),
                size: Size.infinite,
              ),
            ),
          ),
          
          // 工具栏
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                // 颜色选择
                _buildColorButton(Colors.blue),
                _buildColorButton(Colors.red),
                _buildColorButton(Colors.green),
                const SizedBox(width: 8),
                // 清除按钮
                GestureDetector(
                  onTap: () => setState(() => _strokes.clear()),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _penColor == color;
    return GestureDetector(
      onTap: () => setState(() => _penColor = color),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.showAnswer ? null : _submitAnswer,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            widget.showAnswer ? '已提交' : '提交答案',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _submitAnswer() {
    String answer = '';
    
    if (widget.question.type == QuestionType.choice) {
      answer = _selectedOption ?? '';
    } else if (_answerMode == AnswerMode.typing) {
      answer = _textController.text.trim();
    } else if (_answerMode == AnswerMode.handwriting) {
      // 手写答案，暂时用占位符，后续可以集成手写识别
      answer = '[手写答案]';
      // 可以将strokes保存起来供后续识别
    }
    
    if (answer.isNotEmpty) {
      widget.onAnswerSubmitted(answer);
    }
  }

  String _getQuestionTypeLabel() {
    switch (widget.question.type) {
      case QuestionType.choice: return '选择题';
      case QuestionType.fill: return '填空题';
      case QuestionType.calculation: return '计算题';
      case QuestionType.application: return '应用题';
    }
  }

  String _getDifficultyLabel() {
    switch (widget.question.difficulty) {
      case QuestionDifficulty.easy: return '简单';
      case QuestionDifficulty.medium: return '中等';
      case QuestionDifficulty.hard: return '困难';
    }
  }

  Color _getDifficultyColor() {
    switch (widget.question.difficulty) {
      case QuestionDifficulty.easy: return Colors.green;
      case QuestionDifficulty.medium: return Colors.orange;
      case QuestionDifficulty.hard: return Colors.red;
    }
  }

  String _getModeLabel(AnswerMode mode) {
    switch (mode) {
      case AnswerMode.selection: return '选择';
      case AnswerMode.typing: return '打字';
      case AnswerMode.handwriting: return '手写';
    }
  }
}

enum AnswerMode {
  selection,
  typing,
  handwriting,
}

// 手写笔划
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  
  const Stroke({
    required this.points,
    this.color = Colors.blue,
    this.width = 2.0,
  });
}

// 手写绘制器
class _HandwritingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  
  _HandwritingPainter(this.strokes, this.currentPoints, this.currentColor);
  
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制已完成的笔划
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }
    
    // 绘制当前笔划
    if (currentPoints.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      final path = Path()
        ..moveTo(currentPoints[0].dx, currentPoints[0].dy);
      for (int i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _HandwritingPainter oldDelegate) => true;
}
