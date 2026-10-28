# 示例 Case（用于验证技能是否正常触发）

## 用法一：调用 subagent

```
> 用 art-aesthetics-evaluator 评测这两个视频：
  https://example.com/v1.mp4
  https://example.com/v2.mp4
  我的观点：视频1运镜比视频2好看，但视频2配乐更带感
  请出一份报告并保存
```

预期：下载→抽帧（≤16张/降分辨率）→出声谱图→逐维度判断→横向对比+推荐结论→呼应"运镜/配乐"观点→保存 `评测报告-*.md`。

本地文件也支持：

```
> 用 art-aesthetics-evaluator 评测这两个视频：
  ./videos/v1.mp4
  /abs/path/to/v2.mov   # 任意绝对路径示例，按实际位置替换
  视频1 prompt：...
  视频2 prompt：...
```

预期：读取本地文件→抽帧（≤16张/降分辨率）→出声谱图→逐维度判断→提示词契合度与横向对比。

## 用法二：本地视频 + Prompt 配对示例

本目录演示「本地视频 + 每个视频一套 prompt」的输入形态。视频与截图不入库，按需自备：

```
examples/local-prompt-case/
├── v1.mp4                 # 自备
├── v1-prompt.txt
├── v2.mp4                 # 自备
├── v2-prompt.txt
├── summary.png            # 可选，自备
└── case-analysis.png      # 可选，自备
```

没有素材时，`README.md` 里有一条 `ffmpeg` 命令可生成用于验证管线的测试片段。该示例用于验证：本地路径读取、视频-prompt 映射、音频依据生成、提示词契合度和 P0/P0i/P1 缺陷优先级。

## 用法三：works 批次目录

推荐把每批视频放在独立目录：

```
works/20260614042630/
├── v1.mp4
├── v1-prompt.txt
├── v2.mp4
└── v2-prompt.txt
```

在该目录打开客户端后输入：

```
> 用 art-aesthetics-evaluator 评测当前目录这一批视频。
```

也可以用 slash command：

```
> /art-eval
> /art-eval 给出报告
```

预期：扫描当前目录→按同名规则配对视频与 prompt→抽帧/出声谱图→提示词契合度→七维非评分分析→推荐结论。若要求保存报告，报告写入当前批次的 `reports/`；分析依据写入 `eval-work/`。

## 用法四：slash command 显式传参

每个视频各自 prompt：

```
> /art-eval xxx.mp4 提示词1 yyy.mp4 提示词2 给出报告
```

多个视频共用 prompt：

```
> /art-eval xxx.mp4 yyy.mp4 共同提示词
```

共同 prompt + 用户观点：

```
> /art-eval xxx.mp4 yyy.mp4 提示词1 我觉得第一个视频比第二个视频好 给出报告
```

预期：命令先解析视频与 prompt 的对应关系，并把“我觉得第一个视频比第二个视频好”单独识别为用户观点，再交给 `art-aesthetics-evaluator` 完成评测。如果当前目录是 `works/<批次号>`，即使显式传了视频，报告和分析依据仍默认写入该批次目录的 `reports/` 与 `eval-work/`。

## 用法五：工具不可用时应中断

```
> 当前环境受限，无法运行 ffmpeg 抽帧或处理视频。请基于 prompt 和已知信息直接分析。
```

预期：中断任务，提示用户先安装/修复 ffmpeg、ffprobe（以及页面链接所需的 yt-dlp）后重新发起 `/art-eval`。不要基于 prompt、文件名、用户描述或“已知信息”输出视频质量评价。

## 用法六：其他平台

把 `skills/art-eval/SKILL.md` 作为项目说明 / 系统提示的开头，再按需附上 `skills/art-eval/references/` 里的相关文件即可；不要一次全贴，按任务挑 1–2 篇。

## 快速自检

在支持技能的客户端里输入 `有哪些技能可用？`，应能看到 `art-eval` 一个技能；
再让模型读 `skills/art-eval/SKILL.md`，它应能说出七维、非评分口径、四种输入形态与参考文件路由。
