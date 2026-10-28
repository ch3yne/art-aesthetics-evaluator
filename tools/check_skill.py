#!/usr/bin/env python3
"""校验本仓库是否符合 Agent Skills 规范与仓库自身约定。

检查项：
  1. 每个 skills/<name>/SKILL.md 存在且 frontmatter 合法
  2. name 与目录同名、符合 hyphen-case、<=64 字符
  3. description 非空、<=1024 字符、不含尖括号
  4. SKILL.md <= 500 行（渐进披露上限）
  5. SKILL.md 中提到的 references/、scripts/ 文件真实存在
  6. references/ 下每个文件都在 SKILL.md 路由表里被提到
  7. scripts/ 下的 shell 脚本可执行
  8. .claude-plugin/marketplace.json 的 skills 路径存在、version 与 VERSION 一致
  9. 仓库内文本文件不引用仓外路径（家目录、绝对路径、客户端安装目录）

用法：python3 tools/check_skill.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
REF_RE = re.compile(r"(?<![\w/])((?:references|scripts)/[A-Za-z0-9._-]+\.[A-Za-z0-9]+)")

# 第 9 项检查：文本文件里禁止出现的仓外路径形态。
# SKIP_REL_FILES 中是本地个人文件（含本机路径）与校验器自身。
TEXT_SUFFIXES = {".md", ".markdown", ".sh", ".bash", ".ps1", ".py", ".json", ".yml", ".yaml", ".txt"}
EXTRA_TEXT_NAMES = {".gitignore", ".gitattributes", ".editorconfig", "Makefile", "Dockerfile"}
SKIP_DIR_PARTS = {".git", "node_modules", "eval-work", "reports", "__pycache__", ".venv", "venv"}
SKIP_REL_FILES = {"tools/check_skill.py", "AGENTS.md", "CLAUDE.md"}
OUT_OF_TREE_PATTERNS = [
    (re.compile(r"(?<![A-Za-z0-9._~])~/"), "家目录路径 ~/"),
    (re.compile(r"/Users/[A-Za-z0-9._-]"), "用户主目录绝对路径"),
    (re.compile(r"/home/[A-Za-z0-9._-]"), "Linux 用户主目录绝对路径"),
    (re.compile(r"(?<![A-Za-z0-9._])/root/"), "root 主目录绝对路径"),
    (re.compile(r"[A-Za-z]:[\\/](?:Users|Documents and Settings)[\\/]", re.IGNORECASE), "Windows 用户目录路径"),
    (re.compile(r"\$HOME\b|\$\{HOME\}"), "$HOME 引用"),
    (re.compile(r"CLAUDE_SKILL_DIR|CODEX_HOME|CLAUDE_CONFIG_DIR"), "客户端专有环境变量"),
    (re.compile(r"(?<![A-Za-z0-9_/])\.workbuddy/"), "客户端安装目录"),
    (re.compile(r"(?<![A-Za-z0-9_/])\.(?:claude|agents|codex|gemini|cursor)/(?:skills|rules)/"), "客户端技能/规则目录"),
]

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def parse_frontmatter(text: str, path: Path) -> tuple[dict, str] | tuple[None, str]:
    if not text.startswith("---\n"):
        err(f"{path.relative_to(ROOT)}: 缺少 YAML frontmatter（首行须为 ---）")
        return None, text
    end = text.find("\n---", 4)
    if end == -1:
        err(f"{path.relative_to(ROOT)}: frontmatter 未闭合")
        return None, text
    block, body = text[4:end], text[end + 4:]
    data: dict[str, str] = {}
    for line in block.splitlines():
        if not line.strip() or line.lstrip().startswith("#") or line.startswith((" ", "\t")):
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m:
            data[m.group(1)] = m.group(2).strip().strip("\"'")
    return data, body


def check_skill(skill_dir: Path) -> None:
    rel = skill_dir.relative_to(ROOT)
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        err(f"{rel}: 缺少 SKILL.md")
        return

    text = skill_md.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(text, skill_md)
    if fm is None:
        return

    name = fm.get("name", "")
    if not name:
        err(f"{rel}: frontmatter 缺少 name")
    else:
        if name != skill_dir.name:
            err(f"{rel}: name '{name}' 与目录名 '{skill_dir.name}' 不一致")
        if not NAME_RE.match(name):
            err(f"{rel}: name '{name}' 不符合 hyphen-case（小写字母/数字/连字符，不可首尾连字符）")
        if len(name) > 64:
            err(f"{rel}: name 超过 64 字符")

    desc = fm.get("description", "")
    if not desc:
        err(f"{rel}: frontmatter 缺少 description")
    else:
        if len(desc) > 1024:
            err(f"{rel}: description 超过 1024 字符（当前 {len(desc)}）")
        if "<" in desc or ">" in desc:
            err(f"{rel}: description 不能包含尖括号")

    lines = len(text.splitlines())
    if lines > 500:
        err(f"{rel}: SKILL.md 有 {lines} 行，超过 500 行上限，应下沉到 references/")

    for target in sorted(set(REF_RE.findall(text))):
        if not (skill_dir / target).is_file():
            err(f"{rel}: SKILL.md 引用了不存在的文件 {target}")

    ref_dir = skill_dir / "references"
    if ref_dir.is_dir():
        for ref in sorted(ref_dir.iterdir()):
            if ref.is_file() and ref.name not in body:
                warn(f"{rel}: references/{ref.name} 未在 SKILL.md 中提及（可能成为孤儿文件）")

    for script in sorted((skill_dir / "scripts").glob("*")) if (skill_dir / "scripts").is_dir() else []:
        if script.suffix in {".sh", ".py"} and not (script.stat().st_mode & 0o111):
            err(f"{rel}: scripts/{script.name} 没有可执行权限")


def check_marketplace() -> None:
    mf = ROOT / ".claude-plugin" / "marketplace.json"
    if not mf.is_file():
        err(".claude-plugin/marketplace.json 缺失")
        return
    try:
        data = json.loads(mf.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        err(f"marketplace.json JSON 解析失败: {exc}")
        return

    for field in ("name", "owner", "plugins"):
        if field not in data:
            err(f"marketplace.json 缺少字段 {field}")

    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    meta_version = data.get("metadata", {}).get("version")
    if meta_version != version:
        err(f"marketplace.json metadata.version ({meta_version}) 与 VERSION ({version}) 不一致")

    for plugin in data.get("plugins", []):
        for skill_path in plugin.get("skills", []):
            target = (ROOT / skill_path).resolve()
            if not target.is_dir():
                err(f"marketplace.json 中 {plugin.get('name')} 的 skills 路径不存在: {skill_path}")
            elif not (target / "SKILL.md").is_file():
                err(f"{skill_path} 缺少 SKILL.md")


def check_no_external_refs() -> None:
    """仓库内文档、注释、配置不得引用仓外路径。

    技能要被分发到任意客户端的任意目录，写死家目录或绝对路径会让
    用户在别处照抄命令时失败；安装位置统一用占位符表达。
    """
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if any(part in SKIP_DIR_PARTS for part in rel.parts):
            continue
        if str(rel) in SKIP_REL_FILES:
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in EXTRA_TEXT_NAMES:
            continue
        # 个人本地文件不入库，允许包含本机路径
        if path.name.endswith(".local.md"):
            continue
        if len(rel.parts) > 2 and rel.parts[0] == "works":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for pattern, label in OUT_OF_TREE_PATTERNS:
                if pattern.search(line):
                    err(f"{rel}:{lineno}: 引用了仓外路径（{label}）: {line.strip()[:70]}")


def main() -> int:
    skills_root = ROOT / "skills"
    skill_dirs = sorted(p for p in skills_root.iterdir() if p.is_dir()) if skills_root.is_dir() else []
    if not skill_dirs:
        err("skills/ 下没有任何技能目录")

    for skill_dir in skill_dirs:
        check_skill(skill_dir)
    check_marketplace()
    check_no_external_refs()

    for msg in warnings:
        print(f"警告  {msg}")
    for msg in errors:
        print(f"错误  {msg}")

    if errors:
        print(f"\n失败：{len(errors)} 个错误，{len(warnings)} 个警告")
        return 1
    print(f"\n通过：{len(skill_dirs)} 个技能，{len(warnings)} 个警告")
    return 0


if __name__ == "__main__":
    sys.exit(main())
