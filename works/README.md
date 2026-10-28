# works 批次目录

这里用于放真实待评测批次。推荐一个批次一个目录：

```text
works/
└── 20260614042630/
    ├── v1.mp4
    ├── v1-prompt.txt
    ├── v2.mp4
    └── v2-prompt.txt
```

## 命名约定

- 视频文件支持：`*.mp4`、`*.mov`、`*.m4v`、`*.webm`
- prompt 文件推荐：`<视频基名>-prompt.txt`
- 示例：
  - `v1.mp4` 对应 `v1-prompt.txt`
  - `shotA.mov` 对应 `shotA-prompt.txt`

## 使用方式

在某个批次目录中打开你的 agent 客户端（把工作目录指向该批次目录）：

```bash
cd works/20260614042630
# 在此目录启动你使用的客户端
```

然后输入：

```text
评测当前目录这一批视频。
```

系统会扫描当前目录，按同名规则配对视频与 prompt，并执行抽帧、音频依据生成、提示词契合度、七维非评分分析和推荐结论。

如果客户端频繁要求确认 shell 命令，可先运行一键准备脚本：

```bash
bash ../../skills/art-eval/scripts/prepare.sh --batch . --report
bash ../../skills/art-eval/scripts/prepare.sh --install-deps --batch . --report
```

之后让模型读取 `eval-work/manifest.tsv` 和各视频目录下的抽帧/声谱图即可。

如果你在批次目录里显式传入视频，也仍然使用当前批次目录作为输出归属：

```text
/art-eval 1.mp4 2.mp4 共同提示词 给出报告
```

报告仍写入 `reports/`，分析依据仍写入 `eval-work/`。

## 输出位置

批次相关产物默认留在当前批次目录下：

```text
works/20260614042630/
├── reports/
│   └── 评测报告-20260614042630.md
└── eval-work/
    ├── v1/
    └── v2/
```

- 正式报告默认保存到 `reports/`
- 抽帧、波形图、声谱图等分析依据默认保存到 `eval-work/`
- `eval-work/` 默认保留，方便复查；需要清理时可明确要求

## 补充材料

如果有人工总结或 case 分析，可以放在同一目录中，例如：

```text
summary.png
case-analysis.png
analysis.md
```

这些材料会作为提示词契合度和 P0/P0i/P1 缺陷优先级的参考。

## 页面链接

批次目录也可以放 URL 清单或说明文本，但最稳妥的方式仍是放本地视频文件。
如果需要评测 YouTube / B 站 / 抖音 / X 等页面链接，请确保运行环境安装了 `yt-dlp` 和 `ffmpeg`。
缺依赖时先运行：

```bash
bash ../../skills/art-eval/scripts/prepare.sh --install-deps --batch . --report
```

若当前客户端无法运行 shell、ffmpeg/ffprobe 或无法安装依赖，应中断任务，等环境修复后重新发起；不要基于页面标题、说明文本或 prompt 直接评测视频质量。
yt-dlp 产出的 `*.info.json`、字幕和缩略图会作为可追溯材料保存在 `eval-work/` 对应视频目录中。
