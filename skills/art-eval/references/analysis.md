# 视听维度逐项分析

依据 `references/rules.md` 的维度（含非评分判断口径），对素材做系统化拆解。
**先读 `references/rules.md` 确认维度与判断口径**，再开始分析。

## 单素材分析流程

对每个素材，逐维度回答：
1. **现象**：画面/声音里实际发生了什么（具体、可指认）
2. **判断**：突出 / 稳定 / 基本成立 / 影响观看 / 严重破坏
3. **依据**：为什么这样判断（结合专业标准与具体画面/声音证据）
4. **影响与建议**：该问题如何影响表达，是否需要优先修复

输出建议用维度小标题组织，避免大段笼统评价。

## 多素材对比流程（1-4 个视频）

1. 先各自独立完成单素材分析
2. 再做**横向对比**：同一维度下，各素材谁更优、差异在哪
3. 给出推荐结论、关键胜出原因、关键风险与修复优先级；不输出分数、权重或综合分

对比时用表格更清晰：

| 维度 | 视频1 | 视频2 | 视频3 | 视频4（如有） | 对比结论 |
|------|-------|-------|-------|--------------|----------|
| 运镜 | 判断/简述 | | | | 视频1更稳，因... |
| 构图 | | | | | |
| 节奏 | | | | | |
| 色彩 | | | | | |
| 光影 | | | | | |
| 听觉 | | | | | |
| 叙事服务性 | | | | | |

## 获取素材（本地 / 直接媒体 URL / 页面 URL → 抽帧 → 抽音频）

> **重要**：视频/图片是二进制文件。本地文件直接用 Bash 读取；直接媒体 URL 用 Bash 的 curl/wget 下载；视频页面 URL / 平台链接优先用 yt-dlp 下载真实媒体。不要用 WebFetch 下载二进制媒体（WebFetch 只取网页文本）。WebFetch/WebSearch 仅用于检索专业知识或页面信息。

> **yt-dlp 是条件依赖**：本地视频和直接媒体 URL 不需要 yt-dlp；直接媒体 URL 可带查询参数（如 `.mp4?token=...`），仍按直链下载处理。YouTube / B 站 / 抖音 / X(Twitter) / 其他视频页面链接需要 yt-dlp 下载真实媒体，并可抓取 metadata、字幕、缩略图。它不替代 ffmpeg；下载完成后仍用 ffprobe/ffmpeg 抽帧、检测音轨、生成波形图/声谱图。使用 yt-dlp 时需遵守平台条款和素材授权；需要登录/会员/私有权限的内容，应由用户提供可访问文件或合法 cookies。

> **多视频务必隔离目录**：每个素材用独立工作目录 + 独立前缀，**否则后一个视频会覆盖前一个的 `input.mp4` / 帧文件，横向对比直接失效**。普通模式下产物统一放在 `eval-work/`；批次目录模式下产物统一放在 `$BATCH_DIR/eval-work/`。如果当前工作目录本身是 `works/<批次号>`，即使用户显式传入视频，也使用当前批次目录的 `eval-work/`。是否清理中间产物按用户要求决定。

> **优先使用一键准备脚本**：用本技能自带的 `scripts/prepare.sh` 一次性完成扫描/复制/下载/抽帧/声谱图，减少客户端对每条 shell 命令的确认。脚本会生成 `manifest.tsv`，后续分析直接读取该清单。

> **缺依赖时先安装；失败则中断**：若 ffmpeg/ffprobe 缺失，或页面型 URL 需要 yt-dlp 且当前环境没有安装，优先运行 `bash "$SKILL_DIR/scripts/install-deps.sh" ffmpeg yt-dlp`；Windows PowerShell 可运行 `powershell -ExecutionPolicy Bypass -File .\scripts\install-deps.ps1`；也可在准备命令里加 `--install-deps`。安装可能触发客户端权限确认、系统密码、网络访问或包管理器确认；若安装失败或当前环境受限，**中断任务**，等待用户安装好环境后重新发起。不要基于 prompt、文件名、用户描述或“已知信息”替代视频分析。

```bash
# 批次目录模式
bash "$SKILL_DIR/scripts/prepare.sh" --batch "$BATCH_DIR"

# 自动安装缺失依赖后再准备素材
bash "$SKILL_DIR/scripts/prepare.sh" --install-deps --batch "$BATCH_DIR"

# 普通显式视频，共同 prompt
bash "$SKILL_DIR/scripts/prepare.sh" --shared-prompt "共同提示词" 1.mp4 2.mp4

# 需要保存报告
bash "$SKILL_DIR/scripts/prepare.sh" --batch "$BATCH_DIR" --report
```

> `SKILL_DIR` 是本技能根目录（含 SKILL.md 的目录）。不要在用户项目目录里找 `scripts/`。

```bash
# 0) 统一工作目录（每个视频一个子目录：v1 / v2 / ...）
# 普通模式：ROOT="eval-work"
# 批次目录模式（包括在 works/<批次号> 中显式传视频）：ROOT="$BATCH_DIR/eval-work"
ROOT="eval-work"; mkdir -p "$ROOT"
V="v1"; D="$ROOT/$V"; mkdir -p "$D"   # 第二个视频改 V=v2，以此类推

# 1) 准备视频：支持本地路径、file:// 路径、直接媒体 URL、视频页面 URL
SRC="<视频URL或本地路径>"
case "$SRC" in
  file://*) SRC="${SRC#file://}" ;;
esac

if [ -f "$SRC" ]; then
  cp "$SRC" "$D/input.mp4"
else
  case "$SRC" in
    *.mp4|*.MP4|*.mov|*.MOV|*.m4v|*.M4V|*.webm|*.WEBM|*.mp4\?*|*.MP4\?*|*.mov\?*|*.MOV\?*|*.m4v\?*|*.M4V\?*|*.webm\?*|*.WEBM\?*)
      # 直接媒体 URL 下载（加防护：跟随重定向、失败即报错、限大小限时长，防超大文件填满磁盘）
      curl -L -f --max-time 120 --max-filesize 524288000 -o "$D/input.mp4" "$SRC"
      ;;
    *)
      # 页面/平台 URL：优先用 yt-dlp 下载真实媒体 + 元数据 + 字幕 + 缩略图
      # 需要 yt-dlp 和 ffmpeg；若平台需登录，用户需提供可访问文件或合法 cookies。
      yt-dlp \
        --no-playlist \
        --write-info-json \
        --write-thumbnail \
        --write-sub \
        --write-auto-sub \
        --sub-langs "zh.*,en.*" \
        --merge-output-format mp4 \
        -o "$D/source.%(ext)s" \
        "$SRC"

      # 统一复制/重封装为 input.mp4，后续 ffprobe/ffmpeg 只读这个路径
      MEDIA="$(find "$D" -maxdepth 1 -type f \( -iname 'source.mp4' -o -iname 'source.mkv' -o -iname 'source.webm' -o -iname 'source.mov' -o -iname 'source.m4v' \) | head -n 1)"
      if [ -z "$MEDIA" ]; then
        echo "yt-dlp 未产出可识别的视频文件：$SRC" >&2
        exit 1
      fi
      if [ "$MEDIA" = "$D/source.mp4" ]; then
        cp "$MEDIA" "$D/input.mp4"
      else
        ffmpeg -y -i "$MEDIA" -c copy "$D/input.mp4"
      fi
      ;;
  esac
fi
#    下载失败时检查：网络/沙箱 allowlist、防火墙、URL 是否需要鉴权/cookies、文件是否超过 500MB 上限、yt-dlp 是否安装
#    本地失败时检查：路径是否存在、是否在当前工具可读范围内、文件名是否正确引用

# 可追溯材料：
# - yt-dlp 产出的 source.info.json 可用于报告基本信息（标题、来源、时长等）
# - *.vtt/*.srt 字幕可作为听觉/语义辅助依据
# - 缩略图可作为首帧/封面参考，但不能替代逐帧分析

# 2) 关键帧抽取 —— 先取时长，再决定采样策略，保证“全片覆盖”而非只采到开头
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$D/input.mp4")
echo "时长: ${DUR}s"
#    短视频（≤ ~20s）：匀速抽帧即可
ffmpeg -i "$D/input.mp4" -vf "fps=1,scale=640:-1" -frames:v 16 "$D/${V}_frame_%03d.png"
#    长视频：用 fps=帧数/时长 做时间分桶，确保首尾都采到（示例取 16 帧覆盖全片）：
#    FPS=$(awk "BEGIN{printf \"%.4f\", 16/$DUR}")
#    ffmpeg -i "$D/input.mp4" -vf "fps=$FPS,scale=640:-1" -frames:v 16 "$D/${V}_frame_%03d.png"
```

> **抽帧原则**：单视频关键帧 ≤ 12–16 张、统一降到约 640px 宽。**不要**直接用 `select='gt(scene,N)'` 取满即停——它会把帧聚集在切换频繁的前段，导致后半段无采样却谎称“全片评测”。用 `fps=帧数/时长` 的时间分桶保证全片均匀覆盖；如确需观察剪辑点或突变，可在均匀采样之外少量补充场景变化帧。然后用 Read 查看 PNG。

```bash
# 3) 音频依据（听觉维度需要）：先用 ffprobe 检测是否有音轨
#    很多 AI 视频本身没有声音 —— 这是正常情况，不是缺陷，直接跳过听觉维度即可。
if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$D/input.mp4" | grep -q .; then
  # 有音轨：导出波形图 + 声谱图为 PNG，再用 Read 读图
  ffmpeg -i "$D/input.mp4" -filter_complex "showwavespic=s=1000x300" -frames:v 1 "$D/${V}_waveform.png"
  ffmpeg -i "$D/input.mp4" -lavfi showspectrumpic=s=1000x400 -frames:v 1 "$D/${V}_spectrogram.png"
else
  echo "无音轨：不做听觉判断"
fi

# 4) 中间产物处理
# 普通临时评测可在结束后清理：rm -rf "$ROOT"
# 批次目录评测默认保留 "$BATCH_DIR/eval-work/"，方便复查报告依据；除非用户明确要求清理
```

> **听觉是否判断，按以下顺序判定**：无音轨 → 不做听觉判断（正常，多数静音 AI 视频如此）；有音轨但无任何依据（没声谱图也没用户描述）→ 不做听觉判断并说明；有依据 → 正常分析。

> **原生音频能力**：若所在平台模型支持**直接输入音频**（如部分多模态模型），可直接喂音频文件正常评听觉，无需降级为声谱图代理；声谱图/波形图是“听不了声”时的回退方案。

## 无 ffmpeg 时的安装与阻断路径

ffmpeg 是完整逐帧/音频分析的**核心依赖**。若环境没有 ffmpeg，先尝试安装：

```bash
bash "$SKILL_DIR/scripts/install-deps.sh" ffmpeg
```

若用户不允许安装、当前平台不支持安装、网络不可用，或安装失败：
- **立即中断任务**，说明无法运行 ffmpeg/ffprobe，因此不能抽帧、检测音轨或生成声谱图
- 提示用户安装好依赖后重新发起 `/art-eval`
- 不输出正式评测、推荐结论、提示词契合度或缺陷优先级
- 不要基于 prompt、文件名、缩略图、用户描述或“已知信息”推断视频质量

## 无 yt-dlp 时的安装与阻断路径

yt-dlp 只在用户提供页面型视频 URL / 平台链接时需要。若环境没有 yt-dlp 且输入是页面型 URL，先尝试安装：

```bash
bash "$SKILL_DIR/scripts/install-deps.sh" yt-dlp
```

若用户不允许安装、当前平台不支持安装、网络不可用，或安装失败：
- 若链接是直接媒体文件 URL（如 `.mp4/.mov/.webm`），继续用 curl 下载
- 若链接是网页/平台播放页，**中断任务**；请用户安装 yt-dlp、提供可直接访问的媒体文件、本地文件，或自行下载后的文件
- 不要读取标题、描述、字幕或 prompt 后直接给出视频质量评价
- 不要用 WebFetch 把网页 HTML 当作视频素材

## I2V 专项

I2V 场景额外评估生成视频对参考图的：
- 首帧还原度
- 运动延展的合理性
- 主体在运动中的一致性（形态/材质/光影）

具体操作：准备参考图（本地路径或 URL 均可），单独抽出生成视频的**第一帧**，与参考图并排 Read 对比还原度；再看中段/末帧评估延展与一致性。

```bash
# 准备参考图 + 抽生成视频首帧（沿用上面的 $D / $V）
REF_SRC="<参考图URL或本地路径>"
case "$REF_SRC" in
  file://*) REF_SRC="${REF_SRC#file://}" ;;
esac

if [ -f "$REF_SRC" ]; then
  cp "$REF_SRC" "$D/${V}_ref.png"
else
  curl -L -f --max-time 60 --max-filesize 52428800 -o "$D/${V}_ref.png" "$REF_SRC"
fi

ffmpeg -i "$D/input.mp4" -vf "select=eq(n\,0),scale=640:-1" -frames:v 1 "$D/${V}_first.png"
# 然后 Read 这两张图对比：首帧是否忠于参考图（主体形态/构图/色调）
```

## 原则

- 每个维度判断都要落到**具体画面/声音依据**，不说空话
- 发现 AI 生成瑕疵（形变、闪烁、光影矛盾、音画错位等）要明确指出
- 不确定的现象如实标注，不臆断
