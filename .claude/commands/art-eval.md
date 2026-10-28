---
description: 评测当前批次目录或指定视频，支持视频-prompt 配对、共同 prompt、用户观点与报告保存。
argument-hint: "[视频/URL prompt ...] [给出报告]"
---

# /art-eval

本命令是 `art-eval` 技能的**入口薄壳**：解析与执行规则只在 `skills/art-eval/SKILL.md` 维护一份，这里不复述。

用户原始参数：

```text
$ARGUMENTS
```

## 执行

1. 调用 `art-eval` 技能；未被自动激活时，直接读 `skills/art-eval/SKILL.md` 并按其执行。
2. 把 `$ARGUMENTS` 按 SKILL.md「一、输入识别」的四种形态解析：批次目录 / 各自 prompt / 共同 prompt / 无 prompt；用户观点单独剥离。
3. 按 SKILL.md「四、参考文件路由」按需加载 `references/`，不要一次性全读。
4. 先说明识别结果（形态 + 是否有用户观点 + 是否需要报告），再进入流程。
5. 含 `给出报告 / 保存报告 / 出报告 / 生成报告 / report / save` 时按 `references/report.md` 落盘。

不要在命令文件里重复解析细节——重复即漂移。
