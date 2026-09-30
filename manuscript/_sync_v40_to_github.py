#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把「第40版」的内容同步到 GitHub 论文仓 bias-fraction。

原则
  1. 只要论文全文与代码，不要原始数据与大体积 rds。
  2. 沿用仓库既有的目录约定：
       manuscript/  = qmd 源文件 + 渲染辅助脚本
       paper/       = 渲染产物 docx
       submission/  = 投稿用 qmd / 投稿信 / csl / bib
       R/           = R 分析管线
       output/figures, output/tables = 图与表
       simulation/  = 模拟脚本与小体积结果
       Target/      = TARGET 报告规范材料
  3. 单文件 > 1 MB 的 .rds / .RData 一律不搬（模拟中间对象，可由脚本重跑）。
  4. 明确排除：各类 _backup / _archive / _prerender / logs 之外的历史目录、
     Submit 下的嵌套副本、期刊要求 PDF。

用法
  python3 _sync_v40_to_github.py          # 干跑，只打印计划
  python3 _sync_v40_to_github.py --apply  # 真正复制
"""
import os
import shutil
import sys

SRC = os.path.dirname(os.path.abspath(__file__))
DST = "/Users/zengzhechun/SynologyDrive/Github/bias-fraction"

# ---------------------------------------------------------------- 目录级同步
# (源相对目录, 目标相对目录, 大小上限字节, 排除的扩展名集合)
DIR_JOBS = [
    ("R", "R", None, set()),
    ("output/figures", "output/figures", None, set()),
    ("output/tables", "output/tables", None, set()),
    ("analysis", "analysis", None, set()),
    ("Target", "Target", None, set()),
    ("logs", "logs/v40", None, set()),
    # 模拟目录：只搬脚本、小 CSV 与 < 1 MB 的结果对象
    ("output/simulation", "simulation", 1_000_000, {".rds"}),
]

# 模拟目录里体积虽小但需要保留的 rds（脚本重跑代价高，体积却只有几 KB）
SIM_SMALL_RDS = [
    "v40_lookup_holdout.rds",
    "v40_gdmt_missing_sensitivity.rds",
    "v40_ba_gibbs_stats.rds",
]

# ---------------------------------------------------------------- 单文件同步
FILE_JOBS = [
    # 稿件源文件
    ("manuscript/manuscript_jama_v40.qmd", "manuscript/manuscript_jama_v40.qmd"),
    ("manuscript/manuscript_medarchive_v40.qmd", "manuscript/manuscript_medarchive_v40.qmd"),
    ("manuscript/manuscript_v40.qmd", "manuscript/manuscript_v40.qmd"),
    ("manuscript/supplementary_jama_v40.qmd", "manuscript/supplementary_jama_v40.qmd"),
    ("manuscript/supplementary_medarchive_v40.qmd", "manuscript/supplementary_medarchive_v40.qmd"),
    ("manuscript/supplementary_v40.qmd", "manuscript/supplementary_v40.qmd"),
    # JNO 合规缩写版（2026-09-17 交付）：正文 ≤3,000 词，是实际投稿用的那一份
    ("manuscript/jama-V40-缩写版.qmd", "manuscript/jama-V40-缩写版.qmd"),
    # 渲染产物 docx
    ("manuscript/manuscript_jama_v40.docx", "paper/manuscript_jama_v40.docx"),
    ("manuscript/jama-V40-缩写版.docx", "paper/jama-V40-缩写版.docx"),
    ("manuscript/manuscript_medarchive_v40.docx", "paper/manuscript_medarchive_v40.docx"),
    ("manuscript/manuscript_v40.docx", "paper/manuscript_v40.docx"),
    ("manuscript/supplementary_jama_v40.docx", "paper/supplementary_jama_v40.docx"),
    ("manuscript/supplementary_medarchive_v40.docx", "paper/supplementary_medarchive_v40.docx"),
    ("manuscript/supplementary_v40.docx", "paper/supplementary_v40.docx"),
    # 渲染辅助脚本与文献样式
    ("manuscript/_post_format_jama.py", "manuscript/_post_format_jama.py"),
    ("manuscript/_post_bold_abstract.py", "manuscript/_post_bold_abstract.py"),
    ("manuscript/_post_landscape_jama.py", "manuscript/_post_landscape_jama.py"),
    ("manuscript/_post_portrait_for_coauthor.py", "manuscript/_post_portrait_for_coauthor.py"),
    ("manuscript/_word_count_jama.py", "manuscript/_word_count_jama.py"),
    ("manuscript/_set_word_count.py", "manuscript/_set_word_count.py"),
    # 该脚本在「第40版/manuscript/」下没有，只存在于投稿副本里
    ("Submit/JAMA Network Open/manuscript/_sync_docx_to_qmd.py", "manuscript/_sync_docx_to_qmd.py"),
    ("manuscript/_audit_stale_numbers.py", "manuscript/_audit_stale_numbers.py"),
    ("manuscript/_audit_hardcoded_numbers.py", "manuscript/_audit_hardcoded_numbers.py"),
    ("manuscript/references.bib", "manuscript/references.bib"),
    ("manuscript/american-medical-association.csl", "manuscript/american-medical-association.csl"),
    ("manuscript/vancouver.csl", "manuscript/vancouver.csl"),
    ("_render_v40_all.sh", "manuscript/_render_v40_all.sh"),
    ("_make_landscape_v40.sh", "manuscript/_make_landscape_v40.sh"),
    ("_patch_explainer_v40.py", "manuscript/_patch_explainer_v40.py"),
    ("_sync_v40_to_github.py", "manuscript/_sync_v40_to_github.py"),
    ("_refresh_readme_v40.py", "manuscript/_refresh_readme_v40.py"),
    # 投稿材料
    ("Submit/JAMA Network Open/manuscript/manuscript_jama_v40.qmd", "submission/manuscript_jama_v40.qmd"),
    ("Submit/JAMA Network Open/manuscript/supplementary_jama_v40.qmd", "submission/supplementary_jama_v40.qmd"),
    # 2026-09-30 修正：Submit 下的「缩写版」已改名为 jama-V40-投稿版.qmd
    ("Submit/JAMA Network Open/manuscript/jama-V40-投稿版.qmd", "submission/jama-V40-投稿版.qmd"),
    ("Submit/JAMA Network Open/medRxiv_prep/manuscript_medarchive_v40.qmd", "submission/manuscript_medarchive_v40.qmd"),
    ("Submit/JAMA Network Open/medRxiv_prep/supplementary_medarchive_v40.qmd", "submission/supplementary_medarchive_v40.qmd"),
    # 2026-09-30：投稿信已按上传顺序编号为 `01 Cover_Letter.txt`（仓内仍用原简洁名）
    ("Submit/JAMA Network Open/manuscript/01 Cover_Letter.txt", "submission/Cover_Letter.txt"),
    # 2026-09-30 实质投稿件（JNO 系统实际上传的那两份；仓内去掉上传序号）
    ("Submit/JAMA Network Open/manuscript/02 manuscript-JNO-V40.docx", "paper/manuscript-JNO-V40.docx"),
    ("Submit/JAMA Network Open/manuscript/03 supplementary_JNO_v40.docx", "paper/supplementary-JNO_v40.docx"),
    ("Submit/JAMA Network Open/manuscript/AI 审稿/CoverLetter_JNO投稿_审核clean_20260905.md",
     "submission/CoverLetter_JNO投稿_审核clean_20260905.md"),
    ("Submit/JAMA Network Open/manuscript/AI 审稿/CoverLetter_JNO投稿_Doubao_20260905_0055.md",
     "submission/CoverLetter_JNO投稿_Doubao_20260905_0055.md"),
    ("Submit/JAMA Network Open/manuscript/references.bib", "submission/references.bib"),
    ("Submit/JAMA Network Open/manuscript/american-medical-association.csl", "submission/american-medical-association.csl"),
    ("Submit/JAMA Network Open/manuscript/vancouver.csl", "submission/vancouver.csl"),
    # 可交互讲解器（Pages 入口另由 index.html 承担）
    ("互动讲解器_v40_三部分结构.html", "互动讲解器_v40_三部分结构.html"),
    ("互动讲解器_v40_三部分结构.html", "index.html"),
    ("算法说明_临床版_v1.html", "算法说明_临床版_v1.html"),
    # 文档
    ("本轮修改清单_2026-09-11.md", "docs/本轮修改清单_2026-09-11.md"),
    ("同事审稿意见_应对方案_2026-09-11.md", "docs/同事审稿意见_应对方案_2026-09-11.md"),
    ("biasratio包审计_2026-09-11.md", "docs/biasratio包审计_2026-09-11.md"),
    ("命名备选方案_BF与贝叶斯因子区分_2026-09-11.md", "docs/命名备选方案_BF与贝叶斯因子区分_2026-09-11.md"),
    ("README.md", "docs/第40版_README.md"),
]


def iter_dir_job(src_rel, max_bytes, skip_ext):
    base = os.path.join(SRC, src_rel)
    for dp, dns, fns in os.walk(base):
        dns[:] = [d for d in dns if not d.startswith("_backup")]
        for fn in fns:
            if fn.startswith("."):
                continue
            ext = os.path.splitext(fn)[1].lower()
            full = os.path.join(dp, fn)
            rel = os.path.relpath(full, base)
            size = os.path.getsize(full)
            if ext in skip_ext:
                if os.path.basename(rel) not in SIM_SMALL_RDS:
                    continue
            if max_bytes is not None and size > max_bytes:
                continue
            yield full, rel, size


def main():
    apply = "--apply" in sys.argv
    total = 0
    lines = []
    for src_rel, dst_rel, max_bytes, skip_ext in DIR_JOBS:
        n = 0
        b = 0
        for full, rel, size in iter_dir_job(src_rel, max_bytes, skip_ext):
            n += 1
            b += size
            tag = "覆盖" if os.path.exists(os.path.join(DST, dst_rel, rel)) else "新增"
            lines.append(f"  [{tag}] {src_rel}/{rel}  ({size/1024:.0f} KB)  ->  {dst_rel}/{rel}")
            if apply:
                out = os.path.join(DST, dst_rel, rel)
                os.makedirs(os.path.dirname(out), exist_ok=True)
                shutil.copy2(full, out)
        total += b
        lines.append(f"== 目录 {src_rel} -> {dst_rel}：{n} 个文件，{b/1048576:.1f} MB")
    for src_rel, dst_rel in FILE_JOBS:
        full = os.path.join(SRC, src_rel)
        if not os.path.exists(full):
            lines.append(f"  [缺失] {src_rel}")
            continue
        size = os.path.getsize(full)
        total += size
        tag = "覆盖" if os.path.exists(os.path.join(DST, dst_rel)) else "新增"
        lines.append(f"  [{tag}] {src_rel}  ({size/1024:.0f} KB)  ->  {dst_rel}")
        if apply:
            out = os.path.join(DST, dst_rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            shutil.copy2(full, out)

    print("\n".join(lines))
    print(f"\n合计 {total/1048576:.1f} MB" + ("" if apply else "  （干跑，未写入任何文件）"))


if __name__ == "__main__":
    main()
