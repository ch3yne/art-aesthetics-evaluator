# 本地视频 + Prompt 配对示例

本目录演示「本地视频 + 每个视频一套 prompt + 可选人工总结」的输入形态。

为保持仓库轻量，**示例视频与截图不入库**，按下表自备即可。

## 文件

| 文件 | 说明 | 是否入库 |
|------|------|----------|
| `v1.mp4` / `v2.mp4` | 待评测视频 | 否，自备 |
| `v1-prompt.txt` / `v2-prompt.txt` | 各视频对应 prompt | 是 |
| `summary.png` | 可选：人工问题总结截图 | 否，自备 |
| `case-analysis.png` | 可选：case 分析截图 | 否，自备 |

## 没有素材时生成测试片段

仅用于验证脚本管线（抽帧、音轨、manifest），画面本身没有美学信息，不要拿它做评测结论：

```bash
cd examples/local-prompt-case
for i in 1 2; do
  ffmpeg -y -f lavfi -i "testsrc2=size=640x360:rate=24:duration=3" \
         -f lavfi -i "sine=frequency=$((200 + i * 100)):duration=3" \
         -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "v$i.mp4"
done
```

## 用法

在仓库根目录下运行支持技能的客户端，然后输入：

```text
评测这两个本地视频，并结合各自 prompt 和人工总结截图：

视频1：
路径：examples/local-prompt-case/v1.mp4
prompt 文件：examples/local-prompt-case/v1-prompt.txt

视频2：
路径：examples/local-prompt-case/v2.mp4
prompt 文件：examples/local-prompt-case/v2-prompt.txt

补充材料（如有）：
examples/local-prompt-case/summary.png
examples/local-prompt-case/case-analysis.png

请输出：
1. 七个视听维度的判断与依据
2. 各视频的提示词契合度
3. P0/P0i/P1 缺陷优先级
4. 推荐结论、关键风险与改进建议
```

## 预期行为

- 读取本地视频而不是下载 URL
- 每个视频独立抽帧，避免帧文件互相覆盖
- 检测音轨并导出声谱图 / 波形图
- 将 prompt 作为生成意图依据，而不是混用两个视频的 prompt
- 有人工总结截图时，作为缺陷优先级参考
