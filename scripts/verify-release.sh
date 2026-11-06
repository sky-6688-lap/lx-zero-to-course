#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_ref="${1:-WORKTREE}"
verify_root="$repo_root"
temp_dir=""

cleanup() {
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}
trap cleanup EXIT

if [[ "$target_ref" != "WORKTREE" ]]; then
  temp_dir="$(mktemp -d)"
  git -C "$repo_root" archive "$target_ref" | tar -x -C "$temp_dir"
  verify_root="$temp_dir"
fi

python3 - "$verify_root" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys

root = Path(sys.argv[1])

required_files = [
    "SKILL.md",
    "README.md",
    "agents/openai.yaml",
    "assets/report-example.html",
    "references/course-type-routing.md",
    "references/knowledge-assets.md",
    "references/beginner-path.md",
    "references/lesson-kit.md",
    "references/teaching-objectives.md",
    "references/course-structure.md",
    "references/learning-experience.md",
    "references/self-check.md",
    "references/html-report.md",
    "references/boundaries.md",
    "tests/test-cases.md",
    "tests/regression-checklist.md",
    "tests/iteration-protocol.md",
]

for relative in required_files:
    if not (root / relative).is_file():
        raise SystemExit(f"校验失败：缺少 {relative}")

skill = (root / "SKILL.md").read_text(encoding="utf-8")
if not skill.startswith("---\n") or "name: lx-zero-to-course" not in skill:
    raise SystemExit("校验失败：SKILL.md frontmatter 不完整")

checks = {
    "SKILL.md": [
        "## 主线：三个问题做出一节课",
        "### 第 1 问：谁问过你什么",
        "## 产出：课程包四件",
        "不假设用户装了别的 Skill",
        "《个人经验产品化》的构想单",
        "D. 我已经讲过一节了",
        "带引号的原话",
        "### 时长决定教案和页纲的规模",
        "10 分钟（线上短分享）",
    ],
    "references/beginner-path.md": [
        "## 〇、带东西来的用户",
        "跳过状态选择和第 1 问",
        "### 2. 已经讲过一节的人（状态 D）",
        "### 收口后他又补了一句",
        "## 二、第 1 问：谁问过你什么",
        "## 六、完整示例对话",
    ],
    "agents/openai.yaml": ['display_name: "零基础做课 Skill"'],
    "assets/report-example.html": [
        '<span class="group-title">这节课是什么</span>',
        '<span class="group-title">这节课怎么讲</span>',
        '<span class="group-title">幻灯片页纲</span>',
        '<span class="group-title">今天怎么开始</span>',
        "<span>零基础做课 Skill</span>",
        "<h2>被问到时怎么答</h2>",
    ],
    "references/html-report.md": [
        "## 二、四组固定结构",
        "一、这节课是什么",
        "二、这节课怎么讲",
        "三、幻灯片页纲",
        "四、今天怎么开始",
        "唯一的改写许可：开场钩子",
        "改前改后两栏文字",
        "**07 被问到时怎么答**",
        "10 分钟 8 行、20 分钟 10–12 行",
    ],
    "references/lesson-kit.md": [
        "## 二、教案（核心件）",
        "## 三、幻灯片页纲（按时长定页数）",
        "### 10 分钟精简版",
        "### 45 / 60 分钟版",
        "10 分钟版的页纲固定 8 页",
        "### 被问到时怎么答（只写 3 个）",
        "## 七、讲超时了，砍哪里",
        "### 现场讲和录播的差别",
    ],
    "references/boundaries.md": [
        "## 一、本 Skill 的完成边界",
        "## 四、完整收尾",
        "报告中不出现任何外部链接、二维码、报名入口",
    ],
    "references/course-type-routing.md": [
        "## 二、判断该做哪一种",
        "## 三、不确定时的默认路径",
    ],
    "tests/test-cases.md": [
        "## 15. 收口后用户又补一句",
        "## 16. 已经讲过一节，效果不好",
        "## 18. 学员问了一个他答不上的问题",
    ],
}

for relative, markers in checks.items():
    text = (root / relative).read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"校验失败：{relative} 缺少关键内容：{marker}")

report_html = (root / "assets/report-example.html").read_text(encoding="utf-8")
layout_markers = [
    ".steps{display:grid;grid-template-columns:repeat(3,1fr)",
    ".decision,.facts,.steps,.timeline,.two-col{grid-template-columns:1fr}",
]
layout_positions = [report_html.find(marker) for marker in layout_markers]
if -1 in layout_positions or layout_positions != sorted(layout_positions):
    raise SystemExit("校验失败：四步流程卡的桌面与手机样式缺失或顺序错误")

if "min-width:640px" not in report_html:
    raise SystemExit("校验失败：大纲表格缺少窄屏横向滚动兜底")

import re

link_pattern = re.compile(r"https?://(?!github\.com)[^\s)）\"'<>]+")
contact_pattern = re.compile(r"(微信号?|QQ|电话|手机号)\s*[:：]\s*\S")

for relative in required_files:
    path = root / relative
    text = path.read_text(encoding="utf-8")
    # 不出现外部文章链接、外部购买入口与任何联系方式
    found_link = link_pattern.search(text)
    if found_link:
        raise SystemExit(f"校验失败：{relative} 仍包含外部链接：{found_link.group(0)}")
    if contact_pattern.search(text):
        raise SystemExit(f"校验失败：{relative} 仍包含联系方式")

class ReportParser(HTMLParser):
    pass

ReportParser().feed(report_html)
print(f"内容防回退校验通过：{sys.argv[1]}")
PY

if [[ "$target_ref" == "WORKTREE" ]]; then
  git -C "$repo_root" diff --check
fi
