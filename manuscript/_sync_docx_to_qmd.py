#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
_sync_docx_to_qmd.py —— 反向同步：把用户在 docx 里对「纯文字」的编辑，无损搬回 qmd。

原则（与用户约定，2026-09-03）：
  1. 只同步正文散文（Introduction ~ Conclusions），不动 YAML / 代码块 / 表格 / 图 / 图注表注。
  2. 数字、内联 R、数学公式、引文、加粗/斜体一律视为「不透明」，绝不手改，只做位置对齐。
  3. 只应用「词」层面的改动；涉及不透明的差异、以及纯插入（新增词）会标记为 warning，不写入 qmd。
  4. 采用「位置补丁」：只替换被改动的词，其余字符（含空格、标点、加粗、公式、内联 R）原样保留。
  5. 自动归一化 pandoc 智能排版（弯引号/长短连字符/负号），比较时忽略纯标点，避免假阳性。

用法：
  python _sync_docx_to_qmd.py --dry-run          # 只报告 diff，不写文件（默认）
  python _sync_docx_to_qmd.py --apply            # 应用散文改动到 qmd（先自动备份 .bak_sync）
  python _sync_docx_to_qmd.py --qmd <q> --docx <d> --apply   # 指定文件（测试/迁移用）
"""
import sys
import re
import shutil
import difflib
from pathlib import Path
from docx import Document
from docx.oxml.ns import qn

# ---------------------------------------------------------------- 路径配置
QMD_PATH = "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版/Submit/JAMA Network Open/manuscript/manuscript_jama_v39.qmd"
DOCX_PATH = "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版/Submit/JAMA Network Open/manuscript/manuscript_jama_v39.docx"

BODY_SECTIONS = ("Introduction", "Methods", "Results", "Discussion",
                 "Limitations", "Conclusions")

OPAQUE = "\u27e6OP\u27e7"          # ⟦OP⟧ 占位符
WORD_RE = re.compile(r"\S+")       # 非空白词
# 不透明片段：内联 R（可带紧邻的 % 或连字符后缀，如 `r x`%、`r length(lookup)`-bucket）/ 数学 / 引文 / 加粗。
# 注意：正文散文无单星号斜体，故不再匹配 `*…*`，避免误伤。
OPAQUE_RE = re.compile(
    r"(`r[^`]*`(?:%|-\S+)?|\$\$.*?\$\$|\$[^$]+\$|\[@[^\]\[]*\]|\*\*[^*]+\*\*)"
)

# pandoc 智能排版会把直引号/连字符转成弯引号/长短连字符，比较前归一化。
SMART_MAP = str.maketrans({
    "\u2019": "'",   # ’
    "\u2018": "'",   # ‘
    "\u201c": '"',   # “
    "\u201d": '"',   # ”
    "\u2013": "-",   # –
    "\u2014": "-",   # —
    "\u2212": "-",   # − 负号
    "\u00a0": " ",   # 不换行空格
    "\u2026": "...", # …
})
EDGE_PUNCT = re.compile(r"^[.,;:!?()\[\]{}\'\"/]+|[.,;:!?()\[\]{}\'\"/]+$")


def classify(word):
    """把词归为：None(纯标点，丢弃) / OPAQUE(含数字) / 小写词。"""
    w = word.translate(SMART_MAP)
    w = EDGE_PUNCT.sub("", w)
    if not w:
        return None
    if re.search(r"\d", w):
        return OPAQUE
    return w.lower()

# ---------------------------------------------------------------- qmd 解析

def parse_qmd_blocks(qmd_text):
    """抽取正文散文块，返回 [(start_line, end_line, text, section)]，end_line 为闭区间。"""
    lines = qmd_text.split("\n")
    blocks = []
    section = None
    buf_start = None
    buf_lines = []
    in_code = False
    in_caption = False

    def flush():
        nonlocal buf_start, buf_lines
        if buf_start is None:
            return
        # 合并缓冲为一个块（多行段落用单个空格连接，qmd 段落本身多为单行）
        text = " ".join(l.strip() for l in buf_lines if l.strip())
        if text and section in BODY_SECTIONS:
            blocks.append((buf_start, buf_start + len(buf_lines) - 1, text, section))
        buf_start = None
        buf_lines = []

    for i, line in enumerate(lines):
        s = line.strip()
        # 代码块
        if s.startswith("```"):
            if not in_code:
                flush()
            in_code = not in_code
            continue
        if in_code:
            continue
        # YAML / 标题 / 图注表注 div
        if s.startswith("## "):
            flush()
            section = s[3:].strip()
            continue
        if s.startswith(":::") or s == ":::":
            if s.startswith("::: {"):
                flush()
                in_caption = s.startswith("::: {custom-style=\"Table Caption\"}")
            elif s == ":::":
                flush()
                in_caption = False
            continue
        if in_caption:
            continue
        # 独立显示公式（只含 $$...$$）整段跳过
        if s.startswith("$$") and s.endswith("$$"):
            flush()
            continue
        # 空行 = 段分隔
        if not s:
            flush()
            continue
        # 正文散文行
        if buf_start is None:
            buf_start = i
        buf_lines.append(line)
    flush()
    return blocks


# ---------------------------------------------------------------- qmd 词元化

def tokenize_qmd(block_text):
    """把 qmd 块切成原子 [(kind, value, start, end)]，kind ∈ {w, op}。"""
    atoms = []
    pos = 0
    for m in OPAQUE_RE.finditer(block_text):
        pre = block_text[pos:m.start()]
        for wm in WORD_RE.finditer(pre):
            atoms.append(("w", wm.group(0), pos + wm.start(), pos + wm.end()))
        atoms.append(("op", m.group(0), m.start(), m.end()))
        pos = m.end()
    pre = block_text[pos:]
    for wm in WORD_RE.finditer(pre):
        atoms.append(("w", wm.group(0), pos + wm.start(), pos + wm.end()))
    return atoms


def reduce_seq(items):
    """把 [(kind, value), ...] 归约为 (seq, idxmap)。

    seq：普通词 -> 小写词；含数字 / 不透明 -> OPAQUE；纯标点丢弃。
    idxmap[i]：折叠后第 i 位对应的原 items 索引。
    qmd 与 docx 两侧用同一函数，保证归约语义完全一致。
    不折叠连续 OPAQUE：本稿数学/内联 R/数字均一一对应，折叠反而会吞掉内联 R 渲染出的文本词。
    """
    seq = []
    idxmap = []
    for idx, (kind, value) in enumerate(items):
        if kind == "w":
            c = classify(value)
            if c is None:
                continue          # 纯标点，不参与对齐
            token = c
        else:
            token = OPAQUE
        seq.append(token)
        idxmap.append(idx)
    return seq, idxmap


# ---------------------------------------------------------------- docx 抽取

def para_tokens(p):
    """抽取 docx 段落原子 [(kind, value)]，kind ∈ {w, op}。

    w  = 普通词（逐词拆分，供词级 diff 用）
    op = 不透明单元：数学公式（m:oMath）、加粗/斜体 run（对应 qmd 的 **…** / *…*）、
         上标 run（引文，对应 qmd 的 [@…]）。
    数字在 reduce 阶段再归入不透明，这里只按 run 的格式属性区分。
    """
    tokens = []
    for child in p._p:
        tag = child.tag
        if tag == qn("w:r"):
            rpr = child.find(qn("w:rPr"))
            bold = italic = sup = False
            if rpr is not None:
                bold = rpr.find(qn("w:b")) is not None
                italic = rpr.find(qn("w:i")) is not None
                vert = rpr.find(qn("w:vertAlign"))
                sup = vert is not None and vert.get(qn("w:val")) == "superscript"
            text = "".join(t.text or "" for t in child.iter(qn("w:t")))
            if not text:
                continue
            if bold or italic or sup:
                # 加粗/斜体/上标整段视为一个不透明单元
                tokens.append(("op", text))
            else:
                for wm in WORD_RE.finditer(text):
                    tokens.append(("w", wm.group(0)))
        elif tag in (qn("m:oMath"), qn("m:r")):
            # 数学公式（pandoc 输出为 m:oMath 包裹 m:r/m:t）
            text = "".join(t.text or "" for t in child.iter(qn("m:t")))
            if text:
                tokens.append(("op", text))
    return tokens


# 正文散文在 docx 里的段落样式；其余样式（Table Caption / Image Caption /
# Bibliography / Title / Author / Date / Heading 2 等）一律跳过。
PROSE_STYLES = ("Body Text", "First Paragraph")


def extract_docx_prose(doc):
    """抽取正文散文段落 [(index, [tokens])]，按样式 + 节标题精确过滤。

    docx 由 pandoc 生成，样式名稳定：正文散文 = 'Body Text' / 'First Paragraph'；
    图注='Image Caption'、表注='Table Caption'、参考文献='Bibliography'、节标题='Heading 2'。
    据此过滤比「正则猜图注表注」可靠得多，可彻底排除 Table 1 的表注、Figure 图注、
    参考文献条目等非散文段落。
    """
    out = []
    section = None
    for i, p in enumerate(doc.paragraphs):
        style = p.style.name
        if style == "Heading 2":
            t = p.text.strip()
            # 进入正文节：Introduction/Methods/Results/Discussion/Limitations/Conclusions
            if t in BODY_SECTIONS:
                section = t
            else:
                # Key Points / Abstract / References / Figure Legends / Article Information 等
                # 之后的段落不属于正文散文，停止收集。
                section = None
            continue
        if section not in BODY_SECTIONS:
            continue
        if style not in PROSE_STYLES:
            continue
        toks = para_tokens(p)
        words = [v for k, v in toks if k == "w"]
        if not words:
            continue
        out.append((i, toks))
    return out


# ---------------------------------------------------------------- diff 与 apply

def is_inline_r_atom(atom):
    """判断 qmd 原子是否为内联 R（value 以反引号 r 开头）。"""
    return atom[1].startswith("`r")


def diff_pair(q_block, d_tokens):
    """比较一个 qmd 块与 docx 段，返回 (changed, opcodes, q_atoms, q_seq, d_seq, q_map, d_map)。"""
    q_atoms = tokenize_qmd(q_block)
    q_items = [(k, v) for k, v, _, _ in q_atoms]
    d_items = [(k, v) for k, v in d_tokens]
    q_seq, q_map = reduce_seq(q_items)
    d_seq, d_map = reduce_seq(d_items)
    sm = difflib.SequenceMatcher(None, q_seq, d_seq, autojunk=False)
    opcodes = sm.get_opcodes()
    changed = False
    for tag, i1, i2, j1, j2 in opcodes:
        if tag == "equal":
            continue
        q_sub = q_seq[i1:i2]
        d_sub = d_seq[j1:j2]
        # 内联 R 渲染成文本词（如 `r ci_class` -> "narrow"）：机器输出，非散文改动，跳过
        if (tag == "replace" and len(q_sub) == 1 and q_sub[0] == OPAQUE
                and len(d_sub) == 1 and d_sub[0] != OPAQUE
                and is_inline_r_atom(q_atoms[q_map[i1]])):
            continue
        if any(x != OPAQUE for x in q_sub) or any(x != OPAQUE for x in d_sub):
            changed = True
    return changed, opcodes, q_atoms, q_seq, d_seq, q_map, d_map


def build_new_block(q_block, q_atoms, d_tokens, q_seq, d_seq, q_map, d_map, opcodes):
    """依据 opcodes 重建 qmd 块：支持词级替换（含不等长）与删除；涉及不透明的差异一律跳过。

    采用「跨度替换」：一段连续 qmd 词原子 -> 新文本（docx 词以单空格连接，或空串表示删除）。
    纯插入（q 侧为空、d 侧有词）不做自动处理，交给人工（见 main 的 warning）。
    """
    spans = []  # (start, end, new_text)
    for tag, i1, i2, j1, j2 in opcodes:
        if tag == "equal":
            continue
        q_sub = q_seq[i1:i2]
        d_sub = d_seq[j1:j2]
        # 涉及不透明（数字/公式/引文/加粗）的差异，保守跳过，交给人工
        if any(x == OPAQUE for x in q_sub) or any(x == OPAQUE for x in d_sub):
            continue
        q_atom_ids = [q_map[k] for k in range(i1, i2)]
        d_token_ids = [d_map[k] for k in range(j1, j2)]
        if tag in ("replace", "delete"):
            q_word_atoms = [qid for qid in q_atom_ids if q_atoms[qid][0] == "w"]
            if not q_word_atoms:
                continue          # 纯插入，跳过（交人工）
            start = q_atoms[q_word_atoms[0]][2]
            end = q_atoms[q_word_atoms[-1]][3]
            if tag == "delete":
                # 删除：吞掉词后紧跟的一个空格，避免残留双空格
                if q_block[end:end + 1] == " ":
                    end += 1
                spans.append((start, end, ""))
            else:
                new_words = [d_tokens[dt][1] for dt in d_token_ids if d_tokens[dt][0] == "w"]
                if not new_words:
                    continue
                first_val = q_atoms[q_word_atoms[0]][1]
                last_val = q_atoms[q_word_atoms[-1]][1]
                # 保留首词大写
                if first_val[:1].isupper():
                    new_words[0] = new_words[0][:1].upper() + new_words[0][1:]
                # 保留末词尾标点
                trailing = re.search(r"[.,;:]+$", last_val)
                if trailing and not re.search(r"[.,;:]+$", new_words[-1]):
                    new_words[-1] = new_words[-1] + trailing.group(0)
                spans.append((start, end, " ".join(new_words)))
        # insert 不处理

    if not spans:
        return q_block, False

    new = q_block
    for start, end, new_text in sorted(spans, key=lambda s: -s[0]):
        new = new[:start] + new_text + new[end:]
    return new, True


# ---------------------------------------------------------------- 主流程

def _argval(args, flag):
    """取 --flag value；支持 --flag=value 与 --flag value 两种写法。"""
    for i, a in enumerate(args):
        if a == flag and i + 1 < len(args):
            return args[i + 1]
        if a.startswith(flag + "="):
            return a[len(flag) + 1:]
    return None


def main():
    args = sys.argv[1:]
    do_apply = "--apply" in args
    dry = "--dry-run" in args or not do_apply

    qmd_path = _argval(args, "--qmd") or QMD_PATH
    docx_path = _argval(args, "--docx") or DOCX_PATH

    qmd_text = Path(qmd_path).read_text(encoding="utf-8")
    blocks = parse_qmd_blocks(qmd_text)
    # 与 extract_docx_prose 对齐：跳过「只有不透明单元、无普通词」的块（如独立的加粗小标题）
    blocks = [b for b in blocks if any(k == "w" for k, *_ in tokenize_qmd(b[2]))]
    doc = Document(docx_path)
    d_paras = extract_docx_prose(doc)

    print(f"qmd 散文块 = {len(blocks)}，docx 散文段 = {len(d_paras)}")
    if len(blocks) != len(d_paras):
        print("⚠️ 数量不一致，无法按序一一对应，请检查解析逻辑。")
        for b in blocks:
            print("  Q:", b[0], b[3], b[2][:50])
        for d in d_paras:
            print("  D:", d[0], d[1][:3])
        sys.exit(1)

    edits = []   # (start_line, end_line, new_block)
    warnings = []
    for bi, (s, e, q_text, sec) in enumerate(blocks):
        d_idx, d_toks = d_paras[bi]
        changed, opcodes, q_atoms, q_seq, d_seq, q_map, d_map = diff_pair(q_text, d_toks)
        if not changed:
            continue
        new_block, ok = build_new_block(q_text, q_atoms, d_toks, q_seq, d_seq, q_map, d_map, opcodes)
        if ok:
            edits.append((s, e, new_block, sec, d_idx, q_text))
        else:
            warnings.append((sec, d_idx, q_text[:60]))

    if not edits and not warnings:
        print("✅ 无散文改动（docx 与 qmd 一致）。")
        return

    # 报告
    for s, e, new_block, sec, d_idx, old in edits:
        print(f"\n🖊 检测到散文改动 [{sec}] docx段#{d_idx} qmd行 {s+1}-{e+1}")
        # 用简单 diff 展示词级差异
        old_words = old.split()
        new_words = new_block.split()
        sm = difflib.SequenceMatcher(None, old_words, new_words)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag == "equal":
                continue
            print(f"   {tag}: {' '.join(old_words[i1:i2])!r} -> {' '.join(new_words[j1:j2])!r}")
    for w in warnings:
        print(f"\n⚠️ 有改动但未自动应用（含数字/公式/引文，需人工）：[{w[0]}] docx段#{w[1]} {w[2]}")

    if dry:
        print("\n（dry-run，未写文件。加 --apply 应用。）")
        return

    # apply：从后往前替换（保持行号有效）
    if edits:
        bak = qmd_path + ".bak_sync"
        shutil.copy2(qmd_path, bak)
        print(f"\n已备份 qmd -> {bak}")
        lines = qmd_text.split("\n")
        for s, e, new_block, sec, d_idx, old in sorted(edits, key=lambda x: -x[0]):
            # 块多为单行；多行块用新文本覆盖整段
            lines[s:e + 1] = [new_block]
        Path(qmd_path).write_text("\n".join(lines), encoding="utf-8")
        print(f"✅ 已应用 {len(edits)} 处散文改动到 qmd。")


if __name__ == "__main__":
    main()
