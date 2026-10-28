# 视听语言美学评测技能

对 AI 生成视频（T2V 文生 / I2V 图生）做视听语言美学评测：把「这个视频好不好看」的直觉，拆成有画面/声音依据的专业判断。

按 [Agent Skills](https://agentskills.io/specification) 规范组织：**一个技能、一个入口、按需加载**。

作者：Cheyne <contact@ch3yne.com> · 版本 0.1.0 · MIT

## 能力

| 维度 | 说明 |
|------|------|
| 七维分析 | 运镜、构图、节奏、色彩、光影、听觉、叙事服务性 |
| 非评分口径 | 突出 / 稳定 / 基本成立 / 影响观看 / 严重破坏，不给分数与权重 |
| 横向对比 | 1–4 个视频各自分析后对比，给推荐结论、关键胜出原因、关键风险 |
| 提示词契合度 | 有 prompt 时判断高/中/低，并按 P0 / P0i / P1 归纳缺陷优先级 |
| 用户观点验证 | 把「第一个更高级」这类直觉扩写成专业表述，并用证据校准 |
| I2V 专项 | 首帧还原度、运动延展合理性、运动中一致性 |
| 报告 | 要报告时才套模板落盘 |

听觉默认按「模型无法直接听声」处理：用 ffmpeg 导出波形图/声谱图，或用户提供的字幕/描述作为依据；无依据时明确不做听觉判断。

## 安装

技能目录是 `skills/art-eval/`。装到哪个位置由你使用的 agent 客户端决定，下文用 `<skills-dir>` 表示该客户端的技能目录。

```bash
# 复制
cp -R skills/art-eval <skills-dir>/

# 或软链（保持单一源，便于跟进本仓库更新）
ln -s "$PWD/skills/art-eval" <skills-dir>/art-eval
```

支持插件市场的客户端也可以按插件方式安装：

```text
/plugin marketplace add ch3yne/art-aesthetics-evaluator
/plugin install art-eval@art-aesthetics-evaluator
```

布局同时兼容 `npx skills add <repo> --skill art-eval`，但本仓库暂未发布到 skills.sh。

## 依赖

| 依赖 | 用途 | 缺失后果 |
|------|------|----------|
| ffmpeg / ffprobe | 抽帧、音轨检测、波形图、声谱图 | **无法评测**，必须中断 |
| yt-dlp | 页面型视频链接（B 站/YouTube/抖音等） | 只用直链或本地文件时不需要 |

```bash
# 在仓库内
bash skills/art-eval/scripts/install-deps.sh yt-dlp      # 只补 yt-dlp
bash skills/art-eval/scripts/install-deps.sh            # 补齐 ffmpeg + yt-dlp
powershell -ExecutionPolicy Bypass -File .\skills\art-eval\scripts\install-deps.ps1

# 技能已安装后，用技能根目录拼绝对路径
bash "<skills-dir>/art-eval/scripts/install-deps.sh" yt-dlp
```

脚本幂等，已装的会跳过；自动尝试 Homebrew / apt-get / dnf / yum / pacman / zypper / apk / winget，yt-dlp 另有 `pipx` / `pip --user` 兜底。也可在准备素材时顺带安装：`prepare.sh --install-deps`。

## 用法

自然语言即可触发：

```text
评测这两个 AI 视频，我的观点是第一个运镜更好：
https://example.com/v1.mp4
https://example.com/v2.mp4
```

支持自定义命令的客户端也可以用斜杠命令：

```text
/art-eval
/art-eval v1.mp4 提示词1 v2.mp4 提示词2 给出报告
/art-eval v1.mp4 v2.mp4 共同提示词 我觉得第一个更好
```

### 批次目录模式

在 `works/<批次号>/` 里打开对话，直接说「评测当前目录这一批视频」：

```text
works/20260614042630/
├── v1.mp4                 # 视频
├── v1-prompt.txt          # 对应 prompt（<视频基名>-prompt.txt）
├── v2.mp4
├── v2-prompt.txt
├── summary.png            # 可选：人工总结
├── case-analysis.png      # 可选：case 分析截图
├── reports/               # 产出：评测报告
└── eval-work/             # 产出：抽帧、波形图、声谱图、manifest
```

一键准备素材（减少逐条命令确认）：

```bash
bash skills/art-eval/scripts/prepare.sh --batch works/20260614042630
bash skills/art-eval/scripts/prepare.sh --install-deps --batch works/20260614042630
```

## 仓库结构

```
.
├── skills/art-eval/
│   ├── SKILL.md              # 入口：输入解析 → 依赖门禁 → 9 步流程 → 参考文件路由
│   ├── references/           # 按场景加载，不一次性全读
│   │   ├── rules.md          # 七维标准 + 非评分判断口径（必读）
│   │   ├── analysis.md       # 抽帧/音频依据方法、目录隔离、I2V 专项（必读）
│   │   ├── perception.md     # 用户口语 → 专业语言
│   │   ├── prompt-defects.md # 提示词契合度 + P0/P0i/P1
│   │   ├── batch.md          # 批次目录扫描与配对
│   │   ├── report.md         # 报告规则 + 完整模板
│   │   └── knowledge.md      # 专业概念与 AI 瑕疵清单
│   └── scripts/
│       ├── prepare.sh        # 一键准备：复制/下载/抽帧/音频依据/manifest
│       ├── install-deps.sh
│       └── install-deps.ps1
├── .claude-plugin/marketplace.json   # 仓库即插件市场
├── .claude/agents/                   # 可选增强层：subagent（上下文隔离）
├── .claude/commands/art-eval.md      # 可选增强层：/art-eval 薄壳
├── examples/                         # 输入模板与用法示例（媒体素材不入库）
├── tools/check_skill.py              # 结构校验（CI 用）
└── works/                            # 运行时批次目录（gitignore）
```

## 开发

```bash
python3 tools/check_skill.py    # 校验 frontmatter、命名、体积、引用路径、仓外引用、marketplace 一致性
```

CI（`.github/workflows/validate.yml`）在 push/PR 时同样执行。

### 改哪里

| 想改什么 | 改哪里 |
|----------|--------|
| 评测维度、判断口径、非评分表达 | `skills/art-eval/references/rules.md` |
| 流程、输入解析、依赖门禁、文件路由 | `skills/art-eval/SKILL.md` |
| 抽帧/音频依据方法、I2V 专项 | `skills/art-eval/references/analysis.md` |
| 用户观点转专业语言 | `skills/art-eval/references/perception.md` |
| 提示词契合度、P0/P0i/P1 | `skills/art-eval/references/prompt-defects.md` |
| 批次目录扫描与配对 | `skills/art-eval/references/batch.md` |
| 报告结构与模板 | `skills/art-eval/references/report.md` |
| 素材准备与依赖安装 | `skills/art-eval/scripts/` |
| 插件市场元数据 | `.claude-plugin/marketplace.json` |

### 约定

- **单一信息源**：同一段规则只出现在一个文件里。
- **渐进披露**：`SKILL.md` 保持 500 行以内；新增细节写进 `references/`，并同步更新 SKILL.md 的路由表。
- **引用只往下一层**：`SKILL.md` 引用 `references/x.md` 或 `scripts/x.sh`；reference 之间不互相跳转，避免链式读取。
- **不引用仓外路径**：文档、注释、脚本里不得出现家目录路径、绝对路径或任何客户端的安装目录。安装位置一律写占位符 `<skills-dir>`；脚本内部只用运行时推导的 `$SKILL_DIR`。校验脚本会拦截。
- **命名**：技能目录名 = frontmatter `name`，小写连字符。
- **版本**：`VERSION` 是唯一来源，须与 `.claude-plugin/marketplace.json` 的 `metadata.version` 一致。

## 边界

- 不绕过平台限制：需要登录/会员/私有权限的视频，请提供可访问文件或合法 cookies。
- 不在缺依赖时硬评：拿不到帧与音频依据就中断，而不是拿 prompt 编评测。
- 页面链接只取真实媒体：不用网页抓取代替视频素材。

## License

MIT
