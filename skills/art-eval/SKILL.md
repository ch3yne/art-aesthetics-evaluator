---
name: art-eval
description: 对 AI 生成视频（T2V 文生 / I2V 图生）做视听语言美学评测与多视频横向对比：按运镜、构图、节奏、色彩、光影、听觉、叙事服务性七个维度给非评分判断，输出提示词契合度、P0/P0i/P1 缺陷优先级、用户观点专业化验证与正式报告。当用户提供视频 URL、本地视频路径、参考图、works 批次目录，或说“评测/对比/看看这几个 AI 视频拍得怎么样”时使用。
license: MIT
compatibility: 需要 ffmpeg 与 ffprobe；页面型视频链接另需 yt-dlp。无 shell 权限或无法安装依赖时无法完成评测，应中断任务。
metadata:
  author: Cheyne
  version: "0.1.0"
  homepage: https://github.com/ch3yne/art-aesthetics-evaluator
---

# 视听语言美学评测

把抽象的观看感受转化为专业、系统化、有画面/声音依据的评测分析。服务对象通常没有视听语言专业基础，所以判断要给依据，不给分数。

**素材依据底线**：prompt、文件名、页面标题、用户描述或“已知信息”都不能替代视频画面/声音证据。拿不到帧、音频依据或已有 `eval-work` 产物时，中断任务让用户修环境，不要凭空评测。

## 一、输入识别

一个 Case 可能包含：视频（URL / 页面 URL / 本地路径 / `file://`，1–4 个）、I2V 参考图、每个视频对应的 prompt、音频依据（声谱图 / 波形图 / 字幕 / 文字描述）、人工总结或 case 分析截图、用户主观评价、批次目录。

先判定属于哪种形态，并在回答开头用一句话说明识别结果：

```text
识别：批次目录模式 / 各自 prompt / 共同 prompt / 无 prompt；用户观点：（有/无）
```

### 1. 批次目录

参数为空，或只含“当前目录 / 这一批 / 本批次”：

- 把当前工作目录作为 `BATCH_DIR`
- 按 `references/batch.md` 的规则扫描视频、prompt、补充材料并配对
- 报告写 `$BATCH_DIR/reports/评测报告-<批次目录名>.md`，依据写 `$BATCH_DIR/eval-work/`

### 2. 显式视频 + 各自 prompt

```text
xxx.mp4 提示词1 yyy.mp4 提示词2 给出报告
```

- 视频 token：本地路径、`file://`、URL，或扩展名为 `.mp4/.mov/.m4v/.webm` 的字符串
- 一个视频 token 后、下一个视频 token 前的文本 = 该视频 prompt
- “给出报告 / 保存报告 / report / save”是输出要求，不并入 prompt
- 某视频无 prompt 时照常评测，提示词契合度标注“无 prompt，不判断”

### 3. 多个视频 + 共同 prompt

```text
xxx.mp4 yyy.mp4 共同提示词 给出报告
```

先剥离用户观点；剥离后若连续多个视频 token 后只剩一段描述，则该描述为共同 prompt。用户明确写“共同提示词 / same prompt / shared prompt”时同样处理。**共同 prompt 不代表应得相同结论**——仍要分别评估各自实现程度。

### 4. 用户观点拆分

出现以下标记时，标记之前留作 prompt，标记及其之后是用户观点：`我的观点` `我觉得` `我认为` `我感觉` `我倾向` `观点：` `opinion:`。

| 输入 | 解析结果 |
|------|----------|
| `a.mp4 b.mp4 提示词1 我觉得第一个更好 给出报告` | 共同 prompt=提示词1；观点=第一个更好；要报告 |
| `a.mp4 b.mp4 我觉得第一个更好` | 无 prompt；观点=第一个更好 |
| `a.mp4 提示词1 b.mp4 提示词2 我的观点：第二个节奏更好` | 各自 prompt；观点=第二个节奏更好 |

用户观点单独记录，不写入 prompt、不参与契合度判断，但**必须优先回应**（见 `references/perception.md`）。

### 5. 批次归属优先级

只要当前工作目录本身是 `works/<批次号>`，即使显式传入视频，也视为批次模式：报告进 `reports/`，依据进 `eval-work/`。

### 6. 报告意图

出现 `给出报告` `保存报告` `出报告` `生成报告` `report` `save` 时，才生成并落盘正式报告；否则只在对话里给分析与结论。

## 二、依赖门禁（硬阻断）

1. 先检查 `ffmpeg`、`ffprobe`。输入含页面型链接时再检查 `yt-dlp`。
2. 缺失时按顺序尝试：`bash "$SKILL_DIR/scripts/install-deps.sh" ffmpeg yt-dlp` → Windows `powershell -ExecutionPolicy Bypass -File "$SKILL_DIR/scripts/install-deps.ps1"` → 准备脚本加 `--install-deps`。
3. 若安装失败、环境无法执行 shell、或读不到视频源：**立即中断**，说明缺什么、怎么装，请用户修好后重新发起。

不要在缺依赖时继续输出评测、推荐结论、契合度或缺陷优先级；也不要用 prompt、缩略图、文件名推断画质。

## 三、执行流程

1. **识别输入**：按第一节判定形态，说明识别结果。
2. **准备素材**：优先跑一键脚本，一次性完成复制/下载/抽帧/音频依据/manifest，减少逐条命令确认。
   ```bash
   # SKILL_DIR = 本技能根目录，即含 SKILL.md 的目录；用它拼绝对路径，避免依赖 cwd
   bash "$SKILL_DIR/scripts/prepare.sh" --batch "$BATCH_DIR"           # 批次目录
   bash "$SKILL_DIR/scripts/prepare.sh" --install-deps --batch "$BATCH_DIR"
   bash "$SKILL_DIR/scripts/prepare.sh" --shared-prompt "共同提示词" 1.mp4 2.mp4
   ```
   下文所有 `references/…`、`scripts/…` 均相对技能根目录；执行 shell 时用 `$SKILL_DIR` 拼绝对路径，不要在用户项目目录里找 `scripts/`。
3. **读 manifest**：读 `manifest.tsv`，列出视频-prompt 映射，避免 prompt 混用。
4. **看素材**：用 Read 逐张看关键帧；有音轨时看波形图/声谱图。抽帧与音频依据的方法、隔离目录规则见 `references/analysis.md`。
5. **用户观点定位**：有观点时先读 `references/perception.md`，判断它指向哪些维度，作为后续分析重点。
6. **提示词与人工总结对齐**：有 prompt / 人工总结时读 `references/prompt-defects.md`，建立映射并按 P0/P0i/P1 归纳。
7. **逐维度分析**：读 `references/rules.md` + `references/analysis.md`。多视频各自独立分析后做横向对比，给推荐结论、关键胜出原因、关键风险。
8. **观点融合**：在核心结论和维度分析中优先回应用户观点：支持给证据链，部分支持说明哪部分成立、哪部分需修正。
9. **产出**：默认对话输出；要报告时读 `references/report.md`，用 Write 落盘并告知路径。

## 四、参考文件路由

| 何时读 | 文件 |
|--------|------|
| 每次评测必读：七维标准、非评分判断口径、对比输出结构 | `references/rules.md` |
| 每次评测必读：抽帧/音频依据方法、I2V 专项、目录隔离 | `references/analysis.md` |
| 用户给了主观评价 | `references/perception.md` |
| 有 prompt / 人工总结 / 问题分级 | `references/prompt-defects.md` |
| 批次目录模式 | `references/batch.md` |
| 要正式报告或落盘 | `references/report.md`（含完整模板） |
| 需要解释专业概念、术语、AI 瑕疵清单 | `references/knowledge.md` |

路径均相对技能根目录。不要凭记忆复述规则细节——要判断口径时真去读。

## 五、硬约束

- **不评分**：不输出分数、权重、综合分或量化排名；用「突出 / 稳定 / 基本成立 / 影响观看 / 严重破坏」表达判断。
- **有依据**：每个判断落到具体帧、动作、构图、光影、节奏或声音证据，不用空泛形容词。
- **听觉有条件**：无音轨 → 不做听觉判断（多数静音 AI 视频如此，不是缺陷）；有音轨但无任何依据 → 说明后跳过；有依据（原生音频 / 声谱图 / 字幕描述）才评。
- **观点不盲从**：用户评价是组织线索，不是结论；证据不支持时说明差异。
- **不臆断**：不确定的现象如实标注。

## 六、产出

- 默认：对话里给分析、结论、关键风险与改进建议。
- 报告：仅在用户要求时生成，按 `references/report.md` 的结构；
  - 批次模式 → `$BATCH_DIR/reports/评测报告-<批次目录名>.md`
  - 普通模式 → 当前目录 `评测报告-<标识>.md`
  - 用户指定路径 → 按用户路径
- 分析依据（帧、波形图、声谱图）留在 `eval-work/`，默认保留供复查；用户要求清理才清。

## 七、常见退化情形（拦住这些）

| 想省事的做法 | 为什么不行 |
|--------------|------------|
| 只读了 prompt 就评价画面 | prompt 是意图，不是成品；没看帧等于没评 |
| 只抽了前几帧就说“全片” | 帧要覆盖全片，用 `fps=帧数/时长` 分桶，不要 `select='gt(scene,N)'` 取满即停 |
| 没音轨还硬评听觉 | 无依据的听觉判断是编的；标注“本 case 无可用音频依据” |
| 多个视频塞进同一个目录抽帧 | 后者覆盖前者的 `input.mp4` 与帧，横向对比直接失效 |
| 给个总分方便比较 | 违反非评分口径；要对比就分维度给差异与推荐结论 |
