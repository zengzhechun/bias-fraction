#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 互动讲解器_v40_三部分结构.html 的旧口径内容换成指南口径。

背景
  该文件此前只是 v39 讲解器的复制改名：标题/页脚已写「第40版」「v40_all_numbers.json」，
  但内嵌的 const N 仍是 v39 数字，正文叙述也停留在旧口径。本脚本做三件事：
    1. const N  ←  output/tables/v40_all_numbers.json（indent=2，与原文键序、缩进一致）
    2. 正文叙述换口径（案例数字、校准 P 示意图、负对照面板说明、缺失处理表、包名）
    3. R 包改名同步：biasratio v0.3.1 → bafratio v0.4.0，ber_screen() → baf_screen()

const X 不动：它来自 output/tables/v40_explainer_data.json，而 R/19 重跑后
输出与文件逐字节相同（该脚本只依赖仿真 RDS，与第三部分换口径无关）。

用法：python3 _patch_explainer_v40.py            # 直接改写
      python3 _patch_explainer_v40.py --dry-run  # 只打印将发生的替换
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HTML = os.path.join(HERE, "互动讲解器_v40_三部分结构.html")
NUMBERS = os.path.join(HERE, "output", "tables", "v40_all_numbers.json")

DRY = "--dry-run" in sys.argv

# --------------------------------------------------------------- 1. 内嵌数据


def json_span(s, name):
    """返回 const <name> = { ... } 中花括号的 [start, end)。"""
    m = re.search(r"const\s+" + name + r"\s*=", s)
    if not m:
        raise SystemExit("找不到声明：const %s" % name)
    i = s.index("{", m.start())
    depth = 0
    instr = False
    esc = False
    for j in range(i, len(s)):
        c = s[j]
        if instr:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                instr = False
        else:
            if c == '"':
                instr = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return i, j + 1
    raise SystemExit("花括号不配对：%s" % name)


# --------------------------------------------------------- 校准 P 示意钟形曲线
# 轴映射与图内刻度一致：x = 340 + (lnRR + 0.2) * 700
#   lnRR = -0.4 → x = 200；-0.2 → 340；0 → 480
MU_B = -0.1678          # 指南口径 μ̂_B
SIGMA_B = 0.1129        # 指南口径 σ̂_B
X_OF = lambda v: 340.0 + (v + 0.2) * 700.0
Y_BASE = 195.0
Y_PEAK = 50.0
AMP = Y_BASE - Y_PEAK


def bell_path(n=41, zmax=3.0):
    pts = []
    for k in range(n):
        z = -zmax + 2 * zmax * k / (n - 1)
        v = MU_B + z * SIGMA_B
        y = Y_BASE - AMP * math.exp(-0.5 * z * z)
        pts.append((X_OF(v), y))
    d = "M%.1f %.1f" % pts[0]
    for x, y in pts[1:]:
        d += " L%.1f %.1f" % (x, y)
    d += " L%.1f %.1f L%.1f %.1f Z" % (pts[-1][0], Y_BASE, pts[0][0], Y_BASE)
    return d


OLD_PATH_RE = re.compile(r'<path d="M180\.4 194\.7.*?data-page-node-id="SwbivF4DpDvSHoYNlBlXN7"/>', re.S)

# ------------------------------------------------------------- 2. 精确替换表
REPS = [
    # --- 决策台四个输入框的默认值（GDMT 案例） ---
    ('id="dcP" step="0.0001" value="0.0452"', 'id="dcP" step="0.0001" value="0.1026"'),
    ('id="dcBF" step="0.001" value="0.510"', 'id="dcBF" step="0.001" value="0.460"'),
    ('id="dcLo" step="0.001" value="0.356"', 'id="dcLo" step="0.001" value="0.186"'),
    ('id="dcHi" step="0.001" value="0.603"', 'id="dcHi" step="0.001" value="0.619"'),
    # --- 校准 P 示意图的标题与标注 ---
    ("为什么校准 P 值 = 0.94：观测估计恰好落在偏倚分布正中央",
     "为什么校准 P 值 = 0.894：观测估计恰好落在偏倚分布正中央"),
    ("为什么校准 p 值 = 0.94？观测估计恰好落在偏倚分布的正中央",
     "为什么校准 p 值 = 0.894？观测估计恰好落在偏倚分布的正中央"),
    ('> = −0.190</tspan>', '> = −0.168</tspan>'),
    ('<line x1="168" y1="143" x2="288" y2="131" stroke="#A93226"',
     '<line x1="168" y1="143" x2="300" y2="108" stroke="#A93226"'),
    ("K 个负对照拟合出钟形（中心 −0.190，宽度 0.068）；观测估计几乎就在峰顶 → 校准 p = 0.94",
     "K 个负对照拟合出钟形（中心 −0.168，宽度 0.113）；观测估计几乎就在峰顶 → 校准 p = 0.894"),
    ("钟形是 K 个负对照拟合出的经验零分布（中心 −0.190，宽度 0.068）。观测估计 ln(RR) = −0.184 几乎落在峰顶，"
     "说明“表观差异”几乎就是未测量偏倚本身，于是校准 P = 0.94：",
     "钟形是 K 个负对照拟合出的经验零分布（中心 −0.168，宽度 0.113）。观测估计 ln(RR) = −0.184 落在峰顶附近，"
     "说明“表观差异”几乎就是未测量偏倚本身，于是校准 P = 0.894："),
    # --- 因子档位论证里的对照值 ---
    ("本研究负对照面板拟合出的 μ̂_B（−0.190）", "本研究负对照面板拟合出的 μ̂_B（−0.168）"),
    ('低于</b>案例面板拟合出的 0.068', '低于</b>案例面板拟合出的 0.113'),
    # --- 负对照面板说明：6 个临床域 + 四级筛选 ---
    ("<h4 data-page-node-id=\"1udVU7DHQGk4ctU3b39fH3\">12 个负对照，跨 7 个临床域</h4>",
     "<h4 data-page-node-id=\"1udVU7DHQGk4ctU3b39fH3\">12 个负对照，跨 6 个临床域</h4>"),
    ("<td data-page-node-id=\"HH9aCGuny52N4xhdj16Hnm\">12 个负对照，跨 7 个临床域</td>",
     "<td data-page-node-id=\"HH9aCGuny52N4xhdj16Hnm\">12 个负对照，跨 6 个临床域</td>"),
    ("（均 ≥50 事件，全部留一法稳健）", "（分析窗内均 ≥50 事件，全部留一法稳健）"),
    ('<b data-page-node-id="UByvCKIewQ7OuNbgUFu4mP">7 个临床域</b>覆盖：感染、胃肠道、外伤、皮肤、眼科、骨骼肌肉、泌尿生殖。'
     '三项选用标准：① 无药理因果通道；② 至少 50 事件保证 TMLE 估计稳定；③ 跨 7 个不同临床域以降低对照间相关。',
     '<b data-page-node-id="UByvCKIewQ7OuNbgUFu4mP">6 个临床域</b>覆盖：感染、胃肠道、外伤、眼科、风湿、泌尿。'
     '候选清单在筛选前即按四个层级预先设定并逐条机械执行：20 个候选 → 代码可行性 16（删 4）→ 住院 ≥50 例 14（删 2）'
     '→ 分析窗内 ≥50 事件 12（删 2）。两个定量阈值先于筛选固定，没有任何一条因估计值的方向或强度被删。'),
    ("每一项 RR &lt; 1（即 ln(RR) &lt; 0），共同驱动",
     "12 条中 10 条 RR &lt; 1、2 条（fall 1.20、gout 1.14）RR &gt; 1，因此面板为「以保护性为主但并非全部保护」，共同驱动"),
    ('B</sub> = −0.190、σ̂<sub', 'B</sub> = −0.168、σ̂<sub'),
    ('B</sub> = 0.068。</p>', 'B</sub> = 0.113。</p>'),
    # --- GDMT 暴露定义（≥2/3，不是 ≥3） ---
    ('>≥3 类 GDMT</b>（ACEI/ARB/ARNI + β 阻滞剂 + MRA）',
     '>≥2/3 类 GDMT</b>（ACEI/ARB/ARNI + β 阻滞剂 + MRA 三类基石药物中至少两类）'),
    ('未达 GDMT</b>（&lt;3 类）', '未达 GDMT</b>（&lt;2 类）'),
    # --- TARGET 表 / 结局行 ---
    ("未校准 RR 0.83 / 0.68，校准后 1.01 / 0.83", "未校准 RR 0.83 / 0.68，校准后 0.98 / 0.81"),
    ('<td data-page-node-id="knV2oHoYopas6ttWZzUn9v">β 阻滞剂：未校准 RR 0.83 → 校准 1.01（p=0.94）；'
     'GDMT：0.68 → 0.83（p=0.045）。校准后保护性关联在 β 阻滞剂中消失、在 GDMT 中存留。</td>',
     '<td data-page-node-id="knV2oHoYopas6ttWZzUn9v">β 阻滞剂：未校准 RR 0.83 → 校准 0.98（p=0.894）；'
     'GDMT：0.68 → 0.81（p=0.103）。校准后两个问题的保护性关联都与经验零分布无法区分，两者均未通过层 1。</td>'),
    # --- 指标解释：BAF 蛋糕比喻、OBF 描述 ---
    ("BAF = 0.91 意思是：这块蛋糕的九成一是偏倚，真正的“效应”只剩不到一成。",
     "BAF = 0.87 意思是：这块蛋糕的八成七是偏倚，真正的“效应”只剩一成多。"),
    ("β 受体阻滞剂病例：OBF = 0.190 / 0.184 ≈ 1.03，估计出的偏倚比整个观测关联还大一点，"
     "即“那个 0.83 的 RR 几乎可以被偏倚全盘解释”。",
     "β 受体阻滞剂病例：OBF = 0.168 / 0.184 ≈ 0.91，估计出的偏倚已接近整个观测关联的大小，"
     "即“那个 0.83 的 RR 里有九成可由偏倚解释”。"),
    # --- 缺失处理敏感性表 ---
    ("<tr><td style=\"text-align:left\">归为未优化（发表口径）</td><td>0.682</td><td>0.045</td>"
     "<td><b>0.510</b></td><td style=\"text-align:left\">competitive, no verdict</td></tr>",
     "<tr><td style=\"text-align:left\">归为未优化（发表口径）</td><td>0.682</td><td>0.103</td>"
     "<td><b>0.460</b></td><td style=\"text-align:left\">competitive, no verdict</td></tr>"),
    ("<tr><td style=\"text-align:left\">完整案例（删除不确定者）</td><td>0.684</td><td>0.045</td>"
     "<td>0.514</td><td style=\"text-align:left\">not usable</td></tr>",
     "<tr><td style=\"text-align:left\">完整案例（删除不确定者）</td><td>0.684</td><td>0.104</td>"
     "<td>0.463</td><td style=\"text-align:left\">competitive, no verdict</td></tr>"),
    ("<tr><td style=\"text-align:left\">归为已优化（相反极端）</td><td>0.912</td><td>0.204</td>"
     "<td>0.655</td><td style=\"text-align:left\">not usable</td></tr>",
     "<tr><td style=\"text-align:left\">归为已优化（相反极端）</td><td>0.912</td><td>0.526</td>"
     "<td>0.676</td><td style=\"text-align:left\">not usable as effect evidence</td></tr>"),
    ("<tr><td style=\"text-align:left\">多重插补（m = 10，Rubin）</td><td>0.745</td><td>0.281</td>"
     "<td>0.664</td><td style=\"text-align:left\">not usable</td></tr>",
     "<tr><td style=\"text-align:left\">多重插补（m = 10，Rubin）</td><td>0.745</td><td>0.338</td>"
     "<td>0.598</td><td style=\"text-align:left\">not usable as effect evidence</td></tr>"),
    ("<p class=\"val\">结论：四种口径都拿不出可用判定；发表口径是四者中最宽松的一个，定性结论不依赖它。</p>",
     "<p class=\"val\">结论：四种口径都拿不出可用判定；其中两种（发表口径与完整案例）落在「competitive, no verdict」，"
     "另两种直接落到「not usable as effect evidence」。发表口径是四者中最宽松的一个，定性结论不依赖它。</p>"),
    # --- Q4：换口径后的案例数字 ---
    ("<p>GDMT：未校准 RR <b>0.68</b>、校准后 <b>0.83</b>、cal_p <b>0.045</b>、BAF <b>0.510</b>"
     "（95% CI 0.356–0.603）、P(bias-dominated) <b>0.648</b>、查表桶 7、判读仍「competitive, no verdict」。"
     "BB：cal_p 0.946、BAF 0.907（微整）。</p>",
     "<p>GDMT：未校准 RR <b>0.68</b>、校准后 <b>0.81</b>、cal_p <b>0.103</b>、BAF <b>0.460</b>"
     "（95% CI 0.186–0.619）、P(bias-dominated) <b>0.502</b>、查表桶 6、判读仍「competitive, no verdict」。"
     "BB：校准后 RR <b>0.98</b>、cal_p <b>0.894</b>、BAF <b>0.875</b>（95% CI 0.385–0.992）、"
     "判读仍「not usable as effect evidence」。</p>"),
    ("<p><b>判读变了没有</b>：方向没变，GDMT 仍是「不能用作效应证据、只能作假设生成」；"
     "但数字语义变了，从原先「显著（p=0.007）」变成「不显著、压在边界（p=0.045）」，"
     "BAF 反而从 0.45 升到 0.51，更靠红区。换句话说，A+ 让 GDMT 的偏倚主导证据更干净，而不是更弱。</p>",
     "<p><b>判读变了没有</b>：两问的判读都没变。换口径后两个问题都未通过层 1，"
     "BAF 分别为 0.875（β 阻滞剂）与 0.460（GDMT），对应「not usable as effect evidence」与"
     "「competitive, no verdict」两档，与换口径前一致。变化的是量的位置：GDMT 的校准 P 从 0.045 移到 0.103，"
     "BAF 从 0.510 回落到 0.460，进入 1/3–0.5 的混合区；β 阻滞剂的 BAF 从 0.907 微降到 0.875，"
     "但其可信区间由窄变宽（半宽 0.127 → 0.304），判读由点估计与区间共同决定，仍落在偏倚主导侧。</p>"),
    # --- 附录 A：R 包改名与版本 ---
    ("附录 A · biasratio 包的 R 接口与可视化", "附录 A · bafratio 包的 R 接口与可视化"),
    (" biasratio R package &middot; code and visualization",
     " bafratio R package v0.4.0 &middot; code and visualization"),
    ('<code data-page-node-id="6V9HFXDIfbCIb7aAH5a7IY">biasratio</code>（开发代号 BRisk）',
     '<code data-page-node-id="6V9HFXDIfbCIb7aAH5a7IY">bafratio</code>（v0.4.0）'),
    ('remotes::install_github("zengzhechun/biasratio")\nlibrary(biasratio)',
     'remotes::install_github("zengzhechun/bafratio")\nlibrary(bafratio)'),
    (">BRisk two-layer screening</text>", ">bafratio two-layer screening</text>"),
    # --- 第二步/第三步：经验零分布拟合说明（首轮补丁后自查补漏） ---
    ("例如：β 受体阻滞剂不可能预防白内障，但 MIMIC-IV 中达标组的白内障发生率也是 3.2% vs 4.2%，RR≈0.76。"
     "这 0.76 的\"保护\"只能来自 HCE 这类混杂，正是我们要校准的偏倚的直接证据。",
     "例如：β 受体阻滞剂不可能预防白内障，但在这份指南限制队列里，达标组与未达标组仍给出白内障 RR = 0.95 的偏离，"
     "更明显的是肌腱炎 0.67、骨关节炎 0.73、消化道出血 0.79，而跌倒 1.19、痛风 1.14 则落在相反一侧"
     "（12 条负对照的 RR 从 0.46 到 1.19）。这些偏离只能来自 HCE 这类混杂，正是我们要校准的偏倚的直接证据。"),
    ("选用 12 个负对照，全部偏向保护一侧，拟合出 μ̂<sub data-page-node-id=\"4Rp6gjFA5Bb83KvBdW8rpt\">B</sub> = -0.190（",
     "选用 12 个负对照，其中 10 条落在保护一侧、2 条落在相反一侧，拟合出 "
     "μ̂<sub data-page-node-id=\"4Rp6gjFA5Bb83KvBdW8rpt\">B</sub> = -0.168（"),
    ("方向推 0.19），σ̂<sub data-page-node-id=\"FSVXJobHEGWvmDCII6Hqch\">B</sub> = 0.068（各对照间偏倚相当一致）。",
     "方向推 0.17），σ̂<sub data-page-node-id=\"FSVXJobHEGWvmDCII6Hqch\">B</sub> = 0.113（对照间偏倚有一定离散）。"),
    ("放进以 -0.190 为中心的偏倚钟形里，该估计落在正中央，说明",
     "放进以 -0.168 为中心的偏倚钟形里，该估计落在峰顶附近，说明"),
    ("于是校准 P = 0.94：扣除偏倚后没有证据显示真实效应存在。",
     "于是校准 P = 0.894：扣除偏倚后没有证据显示真实效应存在。"),
    # ===== 第二轮：决策台语义对齐论文 + ZH 中文映射补漏（09-17 晚间） =====
    # 论文口径（manuscript_jama_v40.qmd）：两问都未通过层 1，但判读仍由 BAF 查表给出，
    # 即 Q1 = not usable、Q2 = competitive。旧代码 `!pass → not usable` 会覆盖 Q2 的判读。
    (":'≥ 0.05，扣除系统偏倚后信号不再显著。层 2 不再需要，结论直接为不可用作效应证据。'}</div></div>",
     ":'≥ 0.05，扣除系统偏倚后信号不再显著，任何以层 1 为前置的报告规则（R1 到 R4）都会扣下这个估计。"
     "判定因此完全交给层 2 的 BAF 查表。'}</div></div>"),
    ("const final = !pass ? 'not usable as effect evidence' : v;",
     "const final = v;   /* 判定来自层 2 查表：层 1 只决定 R1–R4 是否宣称可用，不改变 BAF 给出的判读 */"),
    ("　|　CI half-width ${f(half,4)} (${cls==='窄'?'narrow':'wide'})</div>\n     </div>`;",
     "　|　CI half-width ${f(half,4)} (${cls==='窄'?'narrow':'wide'})</div>\n"
     "       ${pass?'':'<div class=\"sub\" style=\"margin-top:5px;font-family:var(--font)\">"
     "报告规则后果：R0 会宣称可用（未校准），R1 到 R4 因层 1 未通过而全部扣下。</div>'}\n"
     "     </div>`;"),
    # --- 2.6 策略级联 / 2.8 稳健性 的中文映射：R/18 在 v40 改写了标签文本，映射键须同步 ---
    ("'R3 R1 + BAF 95% CI contained in one zone':'R3　R1 ＋ BAF 区间整体落在同一分区',",
     "'R3 R1 + whole BAF credible interval clear of the bias-dominated zone (< 0.5)':"
     "'R3　R1 ＋ BAF 可信区间整体避开偏倚主导区（< 0.5）',"),
    ("'C2 BAF 95% CI contained in one zone, alone':'C2　仅 BAF 区间同分区（不用层 1）'};",
     "'C2 whole BAF credible interval clear of the bias-dominated zone (< 0.5), alone':"
     "'C2　仅 BAF 可信区间避开偏倚主导区（不用层 1）'};"),
    # 注意：new 不得包含 old，否则 s.count(old) 永远 ≥1，替换会重复插入
    (":'负对照 K = 25',\n   'bias exchangeability held'",
     ":'负对照 K = 25',\n   'K = 50 negative controls':'负对照 K = 50',\n   'bias exchangeability held'"),
    # --- 4.2 局限：K 梯度已扩到 50 档，叙述与取值同步 ---
    ("K 从 12 增到 25，区间中位半宽由", "K 从 12 增到 50，区间中位半宽由"),
    ("  setTxt('lm6',f(gg('K = 25 negative controls').median_half_width,4));",
     "  setTxt('lm6',f(gg('K = 50 negative controls').median_half_width,4));"),
]

GLOBAL_SUBS = [
    ("ber_screen", "baf_screen"),          # 公开 API 前缀已统一为 baf_*
    ("fig-biasratio-", "fig-bafratio-"),   # 4 个图容器 id + 4 个 demos 数据 id 同步改名
]


def main():
    s = open(HTML, encoding="utf-8").read()
    orig = s
    log = []

    # ---- 1. const N ----
    a, b = json_span(s, "N")
    newN = json.dumps(json.load(open(NUMBERS, encoding="utf-8")),
                      indent=2, ensure_ascii=False)
    same = (s[a:b] == newN)
    log.append("const N: %d → %d 字符（源 %s）%s" % (b - a, len(newN), os.path.basename(NUMBERS),
                                                "，内容已一致" if same else ""))

    # ---- 2. 钟形路径 ----
    new_path = '<path d="%s" fill="#A93226" fill-opacity="0.13" stroke="#A93226" stroke-width="2.5" stroke-linejoin="round" data-page-node-id="SwbivF4DpDvSHoYNlBlXN7"/>' % bell_path()
    n_path = len(OLD_PATH_RE.findall(s))
    if n_path == 0 and new_path in s:
        log.append("SVG 钟形路径：已按 μ=−0.168 / σ=0.113 重绘，跳过")
    elif n_path != 1:
        raise SystemExit("钟形 path 匹配 %d 次，预期 1 次" % n_path)
    else:
        log.append("SVG 钟形路径：按 μ=−0.168 / σ=0.113 重绘（41 个采样点）")

    # ---- 3. 精确替换（幂等：已替换过的条目跳过，不再重复断言） ----
    done = 0
    for old, new in REPS:
        if old in new:
            # new 包含 old 时 s.count(old) 恒 ≥1，重跑会重复插入
            raise SystemExit("REPS 定义错误（new 包含 old，不可幂等）：%r" % old[:70])
        c = s.count(old)
        if c == 0 and new in s:
            continue                       # 已应用
        if c != 1:
            raise SystemExit("替换锚点命中 %d 次（预期 1）：%r" % (c, old[:70]))
        s = s.replace(old, new)
        done += 1
    log.append("精确替换 %d/%d 处（其余此前已应用）" % (done, len(REPS)))

    s = OLD_PATH_RE.sub(new_path, s)

    # ---- 4. 全局替换 ----
    for old, new in GLOBAL_SUBS:
        c = s.count(old)
        s = s.replace(old, new)
        log.append("全局 %r → %r：%d 处" % (old, new, c))

    # ---- 5. 回填 const N（放在最后，避免上面替换扰动偏移） ----
    a, b = json_span(s, "N")
    s = s[:a] + newN + s[b:]

    print("=== 变更 ===")
    for x in log:
        print("  -", x)
    print("  - 文件长度 %d → %d 字符" % (len(orig), len(s)))

    if DRY:
        print("\n（--dry-run，未写入）")
        return
    open(HTML, "w", encoding="utf-8").write(s)
    print("\n已写入 %s" % HTML)


if __name__ == "__main__":
    main()
