#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 `第40版/README.md` 从「第39版的复制品」刷新为真正的第40版目录说明。

它此前是第39版 README 的原样拷贝：标题写着「第39版目录说明」，目录树里列着
第40版并不存在的条目（`_aplus_backup/`、`互动讲解器_红区决策实验室_v39draft.html`），
计数停留在 v39（R/ 32 个脚本、output/tables 24 个、eTable 1-7）。

本脚本做三件事：
  1. 产物名逐条换 v40。只换可确证的重命名，**不做 `v39`→`v40` 全局盲替换**：
     「待办」表里有「已处理（v39）」这类历史注记，盲替换会把历史写错。
  2. 只修正确凿过期的计数、限额声明与目录树条目（脚本数、表数、eTable 范围、
     正文实测字数、第40版已不存在/新增的条目）。
  3. 编号顺序与文件名不一致处（例：v40 把 MCMC 版 BA 改名 Gibbs）按磁盘实况改。

幂等：所有替换在已应用后命中 0 次并静默跳过。

用法：python3 _refresh_readme_v40.py [--dry-run]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
README = os.path.join(HERE, "README.md")
DRY = "--dry-run" in sys.argv

# ------------------------------------------------------------------ 1. 改名映射
# 顺序有意义：长的在前，避免前缀被短的先吃掉。
RENAMES = [
    ("第39版目录说明", "第40版目录说明"),
    # ---- 稿件名 ----
    ("manuscript_jama_v39", "manuscript_jama_v40"),
    ("supplementary_jama_v39", "supplementary_jama_v40"),
    ("manuscript_medarchive_v39", "manuscript_medarchive_v40"),
    ("supplementary_medarchive_v39", "supplementary_medarchive_v40"),
    ("manuscript_v39", "manuscript_v40"),
    ("supplementary_v39", "supplementary_v40"),
    ("jama-V39-缩写版", "jama-V40-缩写版"),
    # ---- 数字与表 ----
    ("v39_all_numbers.json", "v40_all_numbers.json"),
    ("v39_explainer_data.json", "v40_explainer_data.json"),
    ("v39_dual_view", "v40_dual_view"),
    ("v39_part1_bland_altman", "v40_part1_bland_altman"),
    ("v39_part1_ba_mcmc_full_stats", "v40_part1_ba_gibbs_full_stats"),
    ("v39_part2_", "v40_part2_"),
    ("v39_part3_case_verdicts", "v40_part3_case_verdicts"),
    ("v39_lookup_holdout", "v40_lookup_holdout"),
    ("v39_interval_joint_propagation", "v40_interval_joint_propagation"),
    ("v39_interval_joint_by_K", "v40_interval_joint_by_K"),
    ("v39_gdmt_missing_sensitivity", "v40_gdmt_missing_sensitivity"),
    ("v39_roc_paper_auc", "v40_roc_paper_auc"),
    ("v39_negative_control_screening", "v40_negative_control_screening"),
    ("v39_ejection_fraction", "v40_ejection_fraction"),
    ("v39_guideline_null_promotion", "v40_guideline_null_promotion"),
    # ---- 图 ----
    ("figures/v39/", "figures/v40/"),
    # ---- 脚本 ----
    ("18_v39_three_part_analysis.R", "18_v40_three_part_analysis.R"),
    ("19_v39_explainer_data.R", "19_v40_explainer_data.R"),
    ("v39_step1_ba_mcmc_2d_density.R", "v40_step1_ba_mcmc_2d_density.R"),
    ("v39_ba_mcmc_reps.rds", "v40_ba_gibbs_reps.rds"),
    ("v39_ba_mcmc_stats.rds", "v40_ba_gibbs_stats.rds"),
    ("_render_v39_all.sh", "_render_v40_all.sh"),
    ("logs/v39/", "logs/v40/"),
    ("_archive_工作长稿_v39/", "_archive_工作长稿_v38/"),
    # ---- 讲解器与文档 ----
    ("互动讲解器_v39_三部分结构.html", "互动讲解器_v40_三部分结构.html"),
    # 第40版没有 v39draft，实际存在的草稿是 v38draft
    ("互动讲解器_红区决策实验室_v39draft.html", "互动讲解器_红区决策实验室_v38draft.html"),
    # 第40版目录里这两份审稿文档实际是 v38 命名
    ("审稿报告_TraeWork_v39+...md", "审稿报告_TraeWork_v38+...md"),
    ("审稿意见处理清单_Trae_v39_2026-08-27.md", "审稿意见处理清单_Trae_v38_2026-08-27.md"),
    ("审稿意见_QoderWork_v39_2026-09-05.md", "审稿意见_QoderWork_v38_2026-09-05.md"),
    # 第40版没有 inject_emp_v39.py，实际存在的是 v38
    ("inject_emp_v39.py", "inject_emp_v38.py"),
    # 渲染铁律段与目录树根：第39版 → 第40版
    ("必须放在「第39版」的直接子目录下渲染", "必须放在「第40版」的直接子目录下渲染"),
    ("（例如 `第39版/manuscript/`）", "（例如 `第40版/manuscript/`）"),
    ("第39版/\n├── README.md", "第40版/\n├── README.md"),
    ("16 到 19 是 v39 主体", "16 到 19 是 v40 主体"),
    ("**v39 三部分分析总脚本**", "**v40 三部分分析总脚本**"),
    ("| `v39/` | **论文正式用图**", "| `v40/` | **论文正式用图**"),
    ("审稿意见处理清单_Trae_v39_....md", "审稿意见处理清单_Trae_v38_....md"),
]

# ------------------------------------------------------------- 2. 计数与事实声明
FACT_FIXES = [
    ("`R/`，35 个脚本", "`R/`，41 个脚本"),
    ("（32 个脚本，见下表）", "（41 个脚本，见下表）"),
    ("分析管线（32 个脚本，见下表）", "分析管线（41 个脚本，见下表）"),
    ("★ 全部数字与表（24 个）", "★ 全部数字与表（38 个）"),
    ("`output/tables/`，27 个", "`output/tables/`，38 个"),
    ("eMethods + eTable 1-7", "eMethods + eTable 1-12"),
    ("eMethods + eTable 1-10", "eMethods + eTable 1-12"),
    ("日志 2026-08-21 ~ 09-17",
     "日志 2026-08-21 ~ 09-05（此为该目录内的副本，持续维护的日志在 manuscript_v33/.workbuddy/memory/）"),
    # 主投稿目标那一行：v40 已出 JNO 合规缩写版；7,101 词是完全版实测
    ("主投稿目标。正文实测 **6,665 词**，超 3,000 上限近一倍，压缩尚未开始；文内 `Word Count` 声明已同步为 6,665",
     "主投稿目标。完全版正文实测 **7,101 词**；已另出 JNO 合规缩写版 "
     "（`jama-V40-缩写版.qmd/.docx`，正文 **2,990 词**，达标）。"
     "投稿上传用的横向版放在 `Submit/JAMA Network Open/manuscript/landscape_SUBMISSION_20260917/`"),
    # 逐文件表：补上第40版新增的四个脚本
    ("| `_render_v40_all.sh` | 一键渲染七份 docx 并跑后处理（纵向双写版） |",
     "| `_render_v40_all.sh` | 一键渲染七份 docx 并跑后处理（纵向双写版） |\n"
     "| `_make_landscape_v40.sh` | 另渲染一套**横向投稿版**两份正文，放进独立目录（仅上传，勿用编辑器打开） |\n"
     "| `_patch_explainer_v40.py` | 幂等补丁：讲解器内嵌 JSON 重导出 + 叙述换口径 + R 包改名 |\n"
     "| `_sync_v40_to_github.py` | 把第40版同步到 GitHub `bias-fraction` 仓（默认干跑，`--apply` 才写） |\n"
     "| `_refresh_readme_v40.py` | 本文件的刷新脚本：换产物名 + 修计数 + 补目录树条目 |"),
    # ---- 常用命令里的版本号与体检断言 ----
    ("# 渲染（在「第39版」目录下，qmd 需位于直接子目录）\ncd 第39版",
     "# 渲染（在「第40版」目录下，qmd 需位于直接子目录）\ncd 第40版"),
    ('print("段数:", x.count("<w:p ") + x.count("<w:p>"))          # 须 114',
     'print("段数:", x.count("<w:p ") + x.count("<w:p>"))          # 主稿 365 / 缩写版 363'),
    # ---- 待办第 0 条：JNO 限额实测（2026-09-17 重测） ----
    ("| 0 | **JNO 四项硬性限制全部超标（2026-09-11 实测）** | 正文 **6,665 / 3,000**；"
     "摘要 **432 / 350**；Key Points **162 / 75–100**；图表 **3 表 + 3 图 = 6 / 5**。**标题 91 字符**"
     "（JAMA 版 `Quantifying Bias in Causal Estimates Using Negative Controls: The Bias Attribution Fraction`，"
     "< 100 合规；medRxiv / 长稿版 116 字符，无此限）、参考文献 20 条合规。文内 `Word Count` 声明已同步为 "
     "**6,665**（原 6,471 因本轮补入暴露定义段与限制段披露而增加 194 词；更早的 2,949 是 2026-08-28 的"
     "硬编码残留，已清除）。三份投稿信（`Cover_Letter.txt` 与 `AI 审稿/` 下两封）已一并同步为 6,665 并"
     "改用 JAMA 版标题。**压缩尚未开始**，按用户 2026-09-11 的指示推迟到内容完整之后再统一处理；"
     "压缩阶段的优先候选是本轮新增的两句披露 |",
     "| 0 | **字数四项已达标，只剩图表数 6/5（2026-09-17 重测）** | 完全版 "
     "`manuscript_jama_v40.docx`：正文 **7,101 词**、摘要 **405 词**、Key Points **168 词**、"
     "标题 91 字符，作长稿留存不投 JNO。JNO 投稿用 **`jama-V40-缩写版.docx`**：正文 "
     "**2,990 / 3,000**、摘要 **313 / 350**、Key Points **99 / 75–100**、标题 **91 字符**，四项全达标；"
     "**唯一未达标项是图表数：3 表 + 3 图 = 6 / 5**，需再移 1 件进补充材料。文内 `Word Count` 行由 "
     "`_set_word_count.py` 在每次渲染后重新注入（qmd 里没有这一行） |"),
    # ---- 待办第 1 条：治本已在 v40 落地 ----
    ("治本：负对照改用 guideline 队列与同一 learner，重估两问全部案例数字（诊断见 "
     "`R/90_diag_nc_exposure_consistency.R`、`R/91_diag_matched_null_impact.R`） |",
     "治本：负对照改用 guideline 队列与同一 learner，重估两问全部案例数字（诊断见 "
     "`R/90_diag_nc_exposure_consistency.R`、`R/91_diag_matched_null_impact.R`）。"
     "**2026-09-17：治本已落地**——`R/92_promote_guideline_null.R` 按新口径重建经验零分布、"
     "`R/93_promote_guideline_calibration.R` 同步校准后 RR 与可信区间、"
     "`R/94_negative_control_screening_audit.R` 补四级筛选审计、"
     "`R/95_ejection_fraction_proxy_sensitivity.R` 补射血分数代理分析；已发表 rds 保留未覆盖 |"),
    # ---- 待办第 5 条：摘要已随缩写版达标 ----
    ("| 5 | 摘要 432 词，超 JAMA 上限 350 | 待压缩（见第 0 条） |",
     "| 5 | ~~摘要超 350 词~~ **已解决（2026-09-17）** | 完全版摘要 405 词；"
     "JNO 投稿用的 `jama-V40-缩写版` 摘要 **313 词**，达标。见第 0 条 |"),
    # ---- 相关仓库：R 包已改名 ----
    ("| `biasratio` | https://github.com/zengzhechun/biasratio | BAF 估计量、可信区间、两层筛检、"
     "Table 2 全部报告规则（`bf_rules()`）的 R 包实现（v0.3.1，253 个单元测试通过；归档 commit 27c6a0f） |",
     "| `bafratio` | https://github.com/zengzhechun/bafratio | BAF 估计量、可信区间、两层筛检、"
     "Table 2 全部报告规则（`baf_rules()`）的 R 包实现（**v0.4.0**，公开函数前缀统一为 `baf_*`，"
     "`R CMD check` OK、314 条断言全通过）。旧名 `biasratio` 停在 v0.3.1，仅作归档（commit 27c6a0f） |"),
    # =====================================================================
    # 2026-09-17 晚：补方向分析落地后的重测值。
    # 上面的条目把 v39 README 搬成 v40 README；下面这一批再把 v40 README
    # 里四个「方向分析加进来之前」的数换掉。分开写是因为替换要按发生顺序叠加，
    # 而且新一批在已刷新的 README 上命中 0 次、静默跳过，重跑安全。
    #
    # 计词口径：JAMA 不计结构标签，因此下表数字为净词数。连标签一起数会得到
    # 缩写版摘要 342 / Key Points 102，外部的 Word 统计显示的是后者 —— 曾据此
    # 误判摘要超标，故在说明里点明。
    # =====================================================================
    ("完全版正文实测 **7,101 词**", "完全版正文实测 **7,393 词**"),
    ("（`jama-V40-缩写版.qmd/.docx`，正文 **2,990 词**，达标）",
     "（`jama-V40-缩写版.qmd/.docx`，正文 **2,996 词**，达标）"),
    ("|   ├── jama-V40-缩写版.qmd/.docx       JNO 合规缩写版正文（2,990 词）",
     "|   ├── jama-V40-缩写版.qmd/.docx       JNO 合规缩写版正文（2,996 词）"),
    ("正文 **7,101 词**、摘要 **405 词**、Key Points **168 词**",
     "正文 **7,393 词**、摘要 **426 词**、Key Points **173 词**"),
    ("正文 **2,990 / 3,000**、摘要 **313 / 350**",
     "正文 **2,996 / 3,000**、摘要 **327 / 350**"),
    ("完全版摘要 405 词；", "完全版摘要 426 词（净词数，含标签 441）；"),
    ("摘要 **313 词**，达标。见第 0 条", "摘要 **327 词**，达标。见第 0 条"),
    # 补充材料的表号随方向分析扩到 eTable 14 / Table S16
    ("eMethods + eTable 1-12", "eMethods + eTable 1-14 + eFigure 1"),
    ("（S1-S6，Table S1-S12）", "（S1-S6，Table S1-S16 + Figure S1）"),
    ("medRxiv 是 S1-S6（Table S1-S12）", "medRxiv 与长稿是 S1-S6（Table S1-S16 + Figure S1）"),
    ("JAMA 是 eMethods + eTable 1-12",
     "JAMA 是 eMethods + eTable 1-14 + eFigure 1"),
    ("│   ├── supplementary_medarchive_v40.qmd/.docx medRxiv 补充材料（S1-S5）",
     "│   ├── supplementary_medarchive_v40.qmd/.docx medRxiv 补充材料（S1-S6）"),
    ("│   ├── supplementary_v40.qmd/.docx       完整长稿补充材料\n",
     "│   ├── supplementary_v40.qmd/.docx       完整长稿补充材料（Table S1-S16 + Figure S1）\n"),
    ("│   ├── _word_count_jama.py              字数统计\n",
     "│   ├── _word_count_jama.py              正文字数统计（只数正文）\n"
     "│   ├── _measure_jama_lengths.py         四项限额实测（标题字符 / Key Points / 摘要 / 正文）\n"),
]

# 第40版已不存在 / 新增的条目。按原文精确匹配，命中 0 次则跳过（幂等）。
TREE_EDITS = [
    # 第40版根目录没有 _aplus_backup/，换成第40版实际新增的四个脚本
    ("├── _aplus_backup/                 关键中间产物备份\n"
     "│   ├── v40_all_numbers.json\n"
     "│   ├── data/                      4 个 rds（含 GDMT / grace-period 原估计）\n"
     "│   └── landscape_SUBMISSION_clean_20260904/\n",
     "├── _render_v40_all.sh             一键渲染七份 docx（纵向双写版）\n"
     "├── _make_landscape_v40.sh         另渲染横向投稿版两份正文（仅上传）\n"
     "├── _patch_explainer_v40.py        讲解器内嵌数据与叙述换口径补丁（幂等）\n"
     "├── _sync_v40_to_github.py         同步到 GitHub bias-fraction（默认干跑）\n"),
    # manuscript/ 下补缩写版与 _set_word_count.py，去掉第39版的 _aplus_backup
    ("│   ├── 审稿意见_QoderWork_v38_2026-09-05.md\n"
     "│   └── _aplus_backup/landscape_SUBMISSION_20260905/   横向投稿版存档\n",
     "│   ├── 审稿意见_QoderWork_v38_2026-09-05.md\n"
     "│   ├── jama-V40-缩写版.qmd/.docx       JNO 合规缩写版正文（2,990 词）\n"
     "│   └── _set_word_count.py              把字数写回末行 Word Count\n"),
    # 投稿 JAMA 轨道补横向版目录。
    # 注意：old 不能是 new 的前缀，否则 old 永远命中，重跑会重复插入。
    ("│   │   ├── supplementary_jama_v40.qmd/.docx\n"
     "│   │   ├── Cover_Letter.txt\n",
     "│   │   ├── supplementary_jama_v40.qmd/.docx\n"
     "│   │   ├── landscape_SUBMISSION_20260917/  ★ 横向投稿版（仅上传，勿用编辑器打开）\n"
     "│   │   ├── Cover_Letter.txt\n"),
    # 2026-09-17 晚新增的三个根级脚本（PDF 出片、投稿树镜像、交付总审计）。
    # old 取「_patch_explainer 行 + 紧跟的 _sync_v40_to_github 行」两行相邻，
    # 而 new 里这两行不再相邻（中间夹着两个 longtrack 补丁）—— 这样 old 不是
    # new 的子串，第二次运行命中 0 次。上一版 old 只取 _patch_explainer 一行，
    # 而 new 里仍以同一行开头，于是每跑一次就再插一遍（README 里真出现了一份
    # 重复的六行块）。main() 现在有一道通用断言，这种前缀会把脚本直接拦下。
    ("├── _patch_explainer_v40.py        讲解器内嵌数据与叙述换口径补丁（幂等）\n"
     "├── _sync_v40_to_github.py",
     "├── _make_preprint_pdf_v40.sh      出 medRxiv 两份 PDF（Typst 引擎，见第七节第 10 条）\n"
     "├── _sync_submission_v40.py        把工作副本镜像进 Submit 两个目录（默认干跑，--write 落盘并校验字节一致）\n"
     "├── _audit_v40_release.py          交付前总审计（六节：docx / PDF / 完全版别名 / 投稿树时效 / 横向节 / 临时文件）\n"
     "├── _patch_explainer_v40.py        讲解器内嵌数据与叙述换口径补丁（幂等）\n"
     "├── _patch_v40_longtrack_tables.py 长稿与 medRxiv 补 7 张表 + 修 layer 1 旧表述（幂等）\n"
     "├── _patch_v40_longtrack_figorder.py  长稿与 medRxiv 图序改「图在上、题在下」（幂等）\n"
     "├── _sync_v40_to_github.py"),
]


def main():
    s = open(README, encoding="utf-8").read()
    orig = s
    log = []

    # 通用前置断言：old 不能是 new 的子串。否则替换后 old 仍然存在，每次运行
    # 都会再插一遍，脚本看起来"干跑无改动"却会不断长大。这一条已经真的踩过：
    # 目录树里插三个新脚本时 old 只取了被保留的那一行开头，跑第二遍就把六行
    # 块又写了一份进 README。
    #
    # 断言放在替换循环里、命中判定的后面，所以只在"这一对真的会触发"时才 halt。
    # 历史条目里另有一对 old 是 new 的子串（给脚本章节表插行的那个），但它在
    # 当前 README 上命中 0 次、永远不会触发，不该因此把整个脚本拦下来。
    for label, pairs in (("改名", RENAMES), ("修正", FACT_FIXES), ("目录树", TREE_EDITS)):
        for old, new in pairs:
            c = s.count(old)
            if c == 0:
                continue
            if old in new:
                raise SystemExit(
                    f"{label} 的 old 是 new 的子串，替换不幂等：{old[:70]!r}"
                )
            if c != 1 and label == "目录树":
                log.append(f"!! {label} 命中 {c} 次（预期 1，已跳过）：{old[:60]!r}")
                continue
            s = s.replace(old, new)
            log.append(f"{label} {old[:58]!r}…：{c} 处")

    print("\n".join(log) if log else "（无改动）")
    left = len([1 for m in ("v39_all_numbers", "manuscript_jama_v39", "eTable 1-7") if m in s])
    print(f"\nREADME {len(orig)} → {len(s)} 字符；抽查残留标记 {left} 个")
    if DRY:
        print("（--dry-run，未写入）")
        return
    open(README, "w", encoding="utf-8").write(s)
    print("已写入", README)


if __name__ == "__main__":
    main()
