# 批次目录自动识别

本文件约定一种可复用的批次目录结构，让用户可以把一批待评测视频与对应 prompt 放在同一目录中，然后直接在该目录打开对话调用评测。

## 推荐目录结构

```text
works/
└── 20260614042630/
    ├── v1.mp4
    ├── v1-prompt.txt
    ├── v2.mp4
    ├── v2-prompt.txt
    ├── summary.png              # 可选：人工总结 / 问题归纳
    ├── case-analysis.png        # 可选：case 分析 / 问题帧截图
    ├── reports/                 # 自动产出：正式报告
    └── eval-work/               # 自动产出：抽帧、波形图、声谱图等分析中间产物
```

推荐规则：
- 一个批次一个目录，例如 `works/20260614042630`、`works/20260701093000`
- 视频文件支持：`*.mp4`、`*.mov`、`*.m4v`、`*.webm`
- prompt 文件推荐命名：`<视频基名>-prompt.txt`
  - `v1.mp4` → `v1-prompt.txt`
  - `shotA.mov` → `shotA-prompt.txt`
- 补充分析材料可放同目录，常见命名：
  - `summary*.png/jpg/jpeg/webp`
  - `case-analysis*.png/jpg/jpeg/webp`
  - `analysis*.txt/md`

## 用户调用方式

当用户在批次目录中打开对话时，可以直接说：

```text
评测当前目录这一批视频。
```

或指定目录：

```text
评测 works/20260614042630 这一批视频。
```

## 自动扫描流程

如果用户说“当前目录”“这一批”“这个 works 批次”等，先用 Bash 扫描目录。

```bash
# 当前批次目录；如果用户指定了路径，把 BATCH_DIR 改成指定目录
BATCH_DIR="."

# 1) 列出候选视频
find "$BATCH_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.webm' \) | sort

# 2) 列出 prompt 文本
find "$BATCH_DIR" -maxdepth 1 -type f \( -iname '*-prompt.txt' -o -iname '*.prompt.txt' -o -iname 'prompt*.txt' \) | sort

# 3) 列出可选补充材料
find "$BATCH_DIR" -maxdepth 1 -type f \( \
  -iname 'summary*' -o -iname '*summary*' -o \
  -iname 'case-analysis*' -o -iname '*analysis*' \
\) | sort
```

## 视频与 prompt 配对规则

优先级从高到低：

1. **同基名配对**：`<base>.mp4` 对 `<base>-prompt.txt`
2. **同基名点分隔配对**：`<base>.mp4` 对 `<base>.prompt.txt`
3. **序号配对**：`v1.mp4` 对 `v1-prompt.txt`，`video2.mp4` 对 `video2-prompt.txt`
4. **只有一个视频和一个 prompt**：默认配对
5. **无法唯一配对**：不要猜；先说明未配对文件，让用户确认

示例映射表：

| 视频 | Prompt | 状态 |
|------|--------|------|
| `v1.mp4` | `v1-prompt.txt` | 已配对 |
| `v2.mp4` | `v2-prompt.txt` | 已配对 |

## 批次评测要求

识别完批次后：

1. 把每个视频作为独立素材处理，使用 `references/analysis.md` 的隔离目录规则抽帧和提取音频依据
2. 把每个 prompt 按 `references/prompt-defects.md` 处理，建立视频-prompt 映射和提示词契合度判断
3. 把 summary/case-analysis 等补充材料作为人工总结或问题优先级参考
4. 输出时先说明本次识别到的批次目录、视频数量、prompt 配对情况、补充材料数量
5. 若视频超过 4 个，先说明默认仅支持 1-4 个视频对比，并询问用户是否分批或指定前 4 个

## 批次输出归属

批次模式下，所有生成产物默认归属到该批次目录，不要散落到技能目录或调用者的其他工作目录。
只要当前工作目录本身是 `works/<批次号>`，即使用户显式传入视频文件（例如 `/art-eval 1.mp4 2.mp4 共同提示词 给出报告`），也要继承当前批次目录作为输出归属。

推荐输出结构：

```text
works/20260614042630/
├── reports/
│   └── 评测报告-20260614042630.md
└── eval-work/
    ├── v1/
    │   ├── input.mp4
    │   ├── v1_frame_001.png
    │   ├── v1_waveform.png
    │   └── v1_spectrogram.png
    └── v2/
        └── ...
```

规则：
- 若用户要求保存正式报告，默认写入 `$BATCH_DIR/reports/评测报告-<批次目录名>.md`
- 抽帧、波形图、声谱图等分析产物默认写入 `$BATCH_DIR/eval-work/`
- 显式视频输入不改变输出归属；当前目录是批次目录时，仍输出到该批次目录
- 如果用户明确指定其他输出路径，以用户指定为准
- 若只是对话输出、不要求保存报告，可以不创建 `reports/`
- 不要自动删除批次目录下的 `reports/`；`eval-work/` 是否清理按用户要求决定

## 推荐批次报告文件名

如果用户要求保存报告，默认保存到批次目录下的 `reports/`：

```text
reports/评测报告-<批次目录名>.md
```

例如：

```text
works/20260614042630/reports/评测报告-20260614042630.md
```
