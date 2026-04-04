#!/usr/bin/env python3
"""测试 VL 模型是否能正确解析图片"""
import base64
import json
import requests
import os

# 配置
OLLAMA_URL = "http://localhost:11434/api/chat"
VL_MODEL = "qwen3-vl:8b"
TEXT_MODEL = "qwen3.5:9b"
IMAGE_PATH = "homework_example.jpg"

# VL 模型的系统提示
VL_SYSTEM_PROMPT = '''你是"小书童"学习助手的图像解析模块。你的任务是解析学生上传的图片，提取其中的关键信息。

【背景信息】
- 小书童是一个面向中小学生的AI学习助手
- 学生会拍照上传题目、作业、笔记等
- 你的解析结果将交给另一个AI模型进行批改和讲解

【你的任务】
请仔细分析图片，提取以下信息（如果存在）：

1. 【题目内容】
   - 完整的题目文字
   - 题目类型（选择题/填空题/解答题/应用题等）
   - 学科（数学/语文/英语/物理/化学等）

2. 【学生答案】（如果有）
   - 学生的解答过程
   - 学生的最终答案
   - 学生做的标记或圈画

3. 【图形/图表】（如果有）
   - 几何图形的关键信息（点、线、角、形状、垂直、平行等）
   - 图表数据
   - 坐标系信息

4. 【其他信息】
   - 批改痕迹（红色勾叉等）
   - 老师评语
   - 其他重要标记

【输出要求】
请以JSON格式输出，结构如下：
```json
{
  "has_question": true或false,
  "has_student_answer": true或false,
  "subject": "学科",
  "question_type": "题型",
  "question_content": "题目完整内容",
  "student_answer": "学生最终答案",
  "student_process": "学生解答过程",
  "graphics_info": {
    "type": "图形类型",
    "elements": ["关键元素列表"]
  },
  "correction_marks": "批改痕迹描述",
  "other_info": "其他重要信息",
  "raw_text": "图片中识别到的所有文字"
}
```

注意：
- 如果某些信息不存在，对应字段填 null
- 数学公式尽量用文字描述清楚
- 图形信息要描述具体，便于后续理解'''

TEXT_SYSTEM_PROMPT = '''你是"小书童"，一个亲切、耐心的AI学习伙伴。

【你的身份】
- 你是学生的好朋友和学习助手
- 你擅长用简单易懂的方式讲解知识
- 你会鼓励学生，帮助他们建立学习信心

【你的能力】
- 解答各学科问题（数学、语文、英语、科学等）
- 批改作业并给出详细讲解
- 根据学生的错题出变式题帮助巩固
- 给出个性化的学习建议

【你的风格】
- 语言亲切自然，像朋友一样交流
- 讲解时循序渐进，不跳步骤
- 发现错误时先肯定对的，再指出问题
- 多用鼓励的话语'''

def load_image_as_base64(image_path):
    """读取图片并转换为 base64"""
    with open(image_path, 'rb') as f:
        return base64.b64encode(f.read()).decode('utf-8')

def test_vl_model(image_base64, user_message="请分析这张图片中的学习内容"):
    """测试 VL 模型"""
    print("\n" + "="*60)
    print("Step 1: 调用 VL 模型 (qwen3-vl:8b)")
    print("="*60)
    
    request_body = {
        "model": VL_MODEL,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": VL_SYSTEM_PROMPT
            },
            {
                "role": "user",
                "content": user_message,
                "images": [image_base64]
            }
        ]
    }
    
    print(f"\n请求模型: {VL_MODEL}")
    print(f"用户消息: {user_message}")
    print(f"图片大小: {len(image_base64)} bytes (base64)")
    
    try:
        response = requests.post(
            OLLAMA_URL,
            headers={"Content-Type": "application/json"},
            json=request_body,
            timeout=300
        )
        
        if response.status_code == 200:
            data = response.json()
            content = data.get("message", {}).get("content", "")
            print("\n--- VL 模型响应 ---")
            print(content)
            print("--- 响应结束 ---")
            return content
        else:
            print(f"错误: HTTP {response.status_code}")
            print(response.text)
            return None
    except Exception as e:
        print(f"请求失败: {e}")
        return None

def test_text_model(user_message, vl_result):
    """测试文本模型"""
    print("\n" + "="*60)
    print("Step 2: 调用文本模型 (qwen3.5:9b)")
    print("="*60)
    
    # 组合用户消息和 VL 结果
    combined_content = f"{user_message}\n\n【图片解析结果】\n{vl_result}"
    
    request_body = {
        "model": TEXT_MODEL,
        "stream": False,
        "messages": [
            {
                "role": "system",
                "content": TEXT_SYSTEM_PROMPT
            },
            {
                "role": "user",
                "content": combined_content
            }
        ]
    }
    
    print(f"\n请求模型: {TEXT_MODEL}")
    print(f"输入内容长度: {len(combined_content)} 字符")
    
    try:
        response = requests.post(
            OLLAMA_URL,
            headers={"Content-Type": "application/json"},
            json=request_body,
            timeout=120
        )
        
        if response.status_code == 200:
            data = response.json()
            content = data.get("message", {}).get("content", "")
            print("\n--- 文本模型响应 ---")
            print(content)
            print("--- 响应结束 ---")
            return content
        else:
            print(f"错误: HTTP {response.status_code}")
            print(response.text)
            return None
    except Exception as e:
        print(f"请求失败: {e}")
        return None

def main():
    print("="*60)
    print("多模态模型测试")
    print("="*60)
    
    # 检查图片文件是否存在
    if not os.path.exists(IMAGE_PATH):
        print(f"错误: 图片文件不存在: {IMAGE_PATH}")
        return
    
    print(f"\n加载图片: {IMAGE_PATH}")
    image_base64 = load_image_as_base64(IMAGE_PATH)
    print(f"图片已加载，base64 长度: {len(image_base64)}")
    
    # 用户消息
    user_message = "请帮我看看这道题做得对不对"
    
    # Step 1: 调用 VL 模型
    vl_result = test_vl_model(image_base64, user_message)
    
    if vl_result:
        # Step 2: 调用文本模型
        text_result = test_text_model(user_message, vl_result)
        
        if text_result:
            print("\n" + "="*60)
            print("测试完成！")
            print("="*60)
            
            # 保存结果到文件
            with open("test_result.json", "w", encoding="utf-8") as f:
                json.dump({
                    "user_message": user_message,
                    "vl_result": vl_result,
                    "text_result": text_result
                }, f, ensure_ascii=False, indent=2)
            print("\n结果已保存到 test_result.json")
    else:
        print("\nVL 模型测试失败，请检查 Ollama 是否运行以及模型是否已安装")
        print("运行命令检查: ollama list")
        print("安装 VL 模型: ollama pull qwen3-vl:8b")

if __name__ == "__main__":
    main()
