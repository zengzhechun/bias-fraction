# 审稿意见：Bias Fraction 论文第 34 版（v34）

| 项目 | 内容 |
|---|---|
| **审稿人** | WorkBuddy 智能审稿（GLM 模型，独立于作者与 DeepSeek V4 PRO 修改者） |
| **审稿日期与时间** | 2026 年 8 月 12 日 22:54（GMT+8） |
| **审稿版本** | manuscript_v34（BF 主指标切换版，由 DeepSeek V4 PRO 自 v33 修改） |
| **审稿范围** | 完全版正文+补充材料（manuscript/manuscript_v34.qmd、supplementary_v34.qmd）、投稿版正文+补充材料（Submit/JAMA Network Open/ 下四份稿件）、R 分析代码（R/00_config.R、R/01_bsr_core.R、analysis/run_bsr_analysis_v34.R、run_sim_worker_v34.R、merge_sim_results_v34.R、generate_figures_v34.R）、模拟与分析输出（output/ 下 rds/csv/日志）、references.bib 全部约 40 条文献逐条核实 |
| **验证手段** | Fieller 二次型手工推导复核；R 现场读取 simulation_merged_v34.rds / bsr_results_v34.rds 复算正文全部关键数值；docx XML 提取核对图注渲染；WebSearch 逐条核实文献真实性与元数据 |

---

## 总体结论

**推荐：中等修改（moderate revision）后可投稿。**

v34 的指标切换（BF 升主指标、BER 降辅助）**方向正确、实现基本可靠**：分区数学等价性成立、v33 的"点估计落在自身 CI 之外"病理已被"bootstrap 中位数点估计"修复、模拟分类准确率经共同随机数方案逐区完全复现（80.0/41.8/95.1）、正文关键数值经现场复算全部吻合。写作层面 AI 痕迹极低（两版正文 0 处 em dash、0–1 处套话词），明显优于 v33。

但存在 **5 个必须在投稿前修复的 Major 问题**：3 条参考文献含虚构作者/错误元数据（AI 幻觉典型模式）、3 处交叉引用断裂（含指向不存在的 Table S4 共 4 处）、1 个代码–论文论证缺口（null 条件被排除出 BF 统计与"BF 在零效应处天然有限"的卖点直接矛盾）。

---

## 一、全面审稿：指标切换合理性评估

### 1.1 切换的核心主张与验证结果

| # | 主张 | 验证结果 |
|---|---|---|
| 1 | BF 三区（>0.5 / 1/3–0.5 / <1/3）与 BER 三区（>1 / 0.5–1 / <0.5）单调一一对应 | ✅ 数学验证成立（BF = BER/(1+BER) 严格递增）；模拟分类准确率逐区与 v33 完全一致，切换未改变分类语义 |
| 2 | 有界尺度 [0,1] 消除 BER=∞ 病例、SL 配置间不稳定被压缩（BER 变 20 倍，BF 仅动 0.02） | ✅ 数据支持（SL 三配置 BER 17.8→413.2，BF 0.896→0.918） |
| 3 | bootstrap 中位数点估计与 CI 同源，修复 v33 SL 完整库点估计（413.2）落在自身 CI 上限（204.8）之外的病理 | ✅ v34 中 SL 完整库 BF 0.918 ∈ CI [0.718, 0.995] |
| 4 | BF 在零效应处 = 1，天然有限，无需特例处理 | ⚠️ **论证缺口，见 G1**——模拟代码恰恰在 null 条件丢弃了 BF（bf_true=NaN），该优势未被任何模拟统计展示 |
| 5 | BF 估计量在可交换条件下近似无偏（+2.1%），而 BER 相对偏倚 +137%~+319% | ✅ 现场复算通过（四配置均值 137.1 / 140.6 / 145.9 / 318.9%） |

### 1.2 论证缺口（需补强，不阻塞投稿）

- **G1（最重要）— null 条件的沉默**：论文将"BF 在 ψ=0 处取 1、天然有限"作为相对 BER 的核心卖点（Discussion 亦重申"removes ... its infinite values at the null"），但 `run_sim_worker_v34.R` 中 `bf_true_finite <- if (is.finite(bsr_true)) bf_true else NA_real_` 使全部 48 个 null 条件（336 中的 48）的 bf_true/bf_rel_bias/bf_rmse 均为 NaN，被排除出一切 BF 汇总统计。**卖点的直接演示场景在模拟中恰好是空白**。建议：null 条件按 bf_true=1 纳入 BF 偏倚/RMSE 统计（此时 BF 的 RMSE 天然有限而 BER 的相对偏倚无定义——这恰是最有说服力的对照），或在正文明确说明排除逻辑及理由。
- **G2 — 点估计口径差异未充分披露**：BB 案例 plug-in BF = 0.968（由原估计直算）vs bootstrap 中位数 BF = 0.906；BER 9.6 vs 30.4，相差逾 3 倍。v34 仅在 Methods 有一句方法论说明，Results 未报告两种口径的对照值。审稿人极可能追问"为何不报 plug-in"。建议在 eAppendix 9 补一张两口径对照小表。
- **G3 — Fieller 与 bootstrap CI 的分歧未讨论**：BB 的 Fieller 置信集为 exterior（无界，仅排除 [−1.62, 1.45]），蕴含 |ρ| ≥ 1.45 即 BF ≥ 0.592；bootstrap CI 下界 0.740。两法给出的"最保守边界"不同，正文只用一句话带过（"the zone assignment is unaffected"）。建议在 eAppendix 1 补 2–3 句解释差异来源（v11 取 bootstrap 方差 vs 抽样方差、符号比值 vs 绝对比值）。
- **G4 — 阈值解释小瑕**：正文称阈值 1/3 与 0.5 "correspond to factors of 2 in the bias-to-effect relationship"。严格说 BF>0.5 ⟺ |μ_B|>|ψ̃|（偏倚大于效应），BF>1/3 ⟺ BER>0.5（偏倚大于效应的一半）；"factors of 2"的表述对应后者而非前者，两个阈值并不对应同一个"2 倍"关系。建议改为精确表述。

### 1.3 结构与逻辑

- v34 将 Methods/Results 统一重组、Simulation 与 Case Study 平行呈现，逻辑清晰，优于 v33。
- OBF（旧"bias fraction"）改名并降为描述性对照量、BER 降为辅助显示（eTable 1），命名体系自洽。
- GDMT 定位为"illustrative known-effect comparison, not a formal validation"——措辞恰当，避免了过度声明。
- Limitations 覆盖了单中心、协变量有限、BF≈1 的解释上限、fall 对照的潜在因果通路，诚实充分。

---

## 二、代码正确性验证

### 2.1 核心函数逐行审查结论

| 函数 | 结论 |
|---|---|
| `ber_to_bf` / `bf_to_ber` | ✅ 互逆变换正确 |
| `bsr_bootstrap()`（B=2000，重抽样 NC、logit 尺度 percentile CI、bootstrap 中位数点估计） | ✅ 实现正确；⚠️ `log_bsr` 的 floor `pmax(., 1e-4)` 在论文/补充材料均未文档化（对 BER 上界影响极小，但应披露） |
| `bsr_fieller()` | ✅ 二次型系数 A = m2²−z²v22、B = −2(m1m2−z²v12)、C = m1²−z²v11 经手工推导复核正确；v12 = −v11（主估计与 NC 独立）假设合理；interior/exterior 判定正确 |
| `bsr_classify()` | ✅ BF 阈值 + CI 双重判定与 BER 阈值分区严格等价 |
| `run_bsr_analysis_v34.R` | ✅ Fieller 的 v11 取 bootstrap 方差的实现与补充材料描述一致；LOO/SL/宽限期敏感性流程正确 |
| `merge_sim_results_v34.R` | ✅ 每配置 mean 的聚合逻辑正确（rds 存比例单位，CSV ×100，口径一致） |
| `generate_figures_v34.R` | ✅ 7 图生成逻辑与日志数值对上 |

### 2.2 数值复现验证（现场 R 复算，全部通过）

| 正文数值 | 复算值 | 结论 |
|---|---|---|
| BB：BF 0.91 [0.74, 0.99]、calibrated RR 1.01、cal p 0.943 | 1.0063 / 0.9433 | ✅ |
| BB：μ̂_B = −0.190、σ̂_B = 0.068、uncal RR 0.83 | −0.1905 / 0.0680 / 0.8317 | ✅ |
| GDMT：uncal 0.65 → cal 0.78、cal p 0.007、BF 0.45 mixed | 0.6456 / 0.7811 / 0.0066 | ✅ |
| GDMT Fieller interior [0.42, 1.80]；BB exterior [−1.62, 1.45] | 0.4238–1.7953 / −1.6167–1.4520 | ✅ |
| SL 三配置 BF 0.90/0.90/0.92；LOO 0.89–0.99 | 日志一致 | ✅ |
| 模拟：overall 69.8、BD 80.0、CP 41.8、SD 95.1；null 拒绝率 3.3% | 日志一致 | ✅（共同随机数方案成功复现 v33 全部分区准确率） |
| BF 相对偏倚 exV0 +2.1%（范围 +1.8~+2.3%）；exV3 −31.7% | 2.30/2.06/2.33/1.84 → 均值 2.13 | ✅ |
| **BER 相对偏倚 "+137% to +319%"** | 四配置均值 318.9 / 140.6 / 137.1 / 145.9% | ✅ 数值正确（137.1→137、318.9→319）——但为**硬编码**且引用的 Table S4 不存在，见 X2 |
| bf_rmse 均值 0.135 / 中位 0.119 | 0.135 / 0.119 | ✅ |
| Abstract（投稿版与完全版）"calibrated RR, 1.01" | 1.0063 | ✅ 硬编码正确（建议改内联） |

### 2.3 代码–论文不一致清单

- **C1**：null 条件 bf_true = NaN（48/336）——见 G1。这是代码实现选择与论文卖点之间的最大缺口。
- **C2**：论文称违反可交换性的 30% NC 为 "randomly selected"，代码实现为**确定性后 30% 位置**（`rep(bias_mu, n_nc - n_ex)` 后接 `rep(bias_mu + 0.15, n_ex)`）。分布上等价（对本模拟的统计结论无影响），但描述不精确，审稿人对照代码会质疑。建议二选一：改代码为真随机（需重跑），或改文字为 "a fixed subset"/"the last 30%"。
- **C3**：`bsr_bootstrap` 的 log_bsr floor 1e-4 未在 eAppendix 9 披露。
- **C4**（已妥善处理 ✓）：30% 违反在 K=12/K=25 时实际为 33.3%/32.0%，eTable 2 注释已文档化。

---

## 三、英文写作质量与文献核实

### 3.1 AI 生成痕迹审查（两版正文逐句 + 词频统计）

**结论：干净，明显优于 v33，de-AIGC 审计声明可信。**

- em dash：完全版 0 处、投稿版 0 处。
- AI 高频套话词（notably/importantly/moreover/furthermore/crucial/pivotal/comprehensive/robust/landscape/underscore/leverage 等 28 词表）：完全版仅 1 处 "robust"（Fieller's theorem supplies a robustness check——用法正常），投稿版 0 处。
- 人工逐句抽查（Introduction/Discussion/Limitations/Abstract）：句式多变、信息密度高、无三段式排比堆砌、无空洞总结句。"the direction that flatters the estimate"（投稿版 Results）等表达自然。Key Points 的 "This methodological demonstration does not establish that beta-blockers are ineffective" 重复出现 3 次（Key Points/Abstract/Discussion），系刻意的风险沟通，可保留。
- 投稿版 AI Use Disclosure 已按 JAMA Netw Open 要求列明全部工具并声明作者责任 ✓。

### 3.2 文献核实（WebSearch 逐条，重点 6 条 + 此前已核约 34 条）

**核实为真实且元数据/引用数字全部正确：**

| 引用键 | 核实结果 |
|---|---|
| ren2026tte | ✅ JAMA Netw Open 2026;9(2):e2558262（PMID 41712213）。三个被引数字逐一核实无误：237 项研究、"only 73 (30.8%) addressed unmeasured confounding"、"103 studies (43.5%) did not report all 7 methodologic components"。修改摘要遗留的"逐字核对"事项由本审稿替代完成 |
| cashin2025target | ✅ TARGET 声明真实：BMJ 2025;390:e087179（2025-09-03 发表，与 JAMA 同步）。bib 的 20 位作者列表与真实文献逐一吻合，DOI/页码正确 |
| parrini2024olderbb | ✅ J Clin Med 2024;13(7):2119，前三作者（Parrini/Lucà/Rao）与 et al. 正确 |
| 其余经典文献（MERIT-HF、CIBIS-II、COPERNICUS、DAPA-HF、EMPEROR-Reduced、simpson2006、shrank2011、lipsitch2010、schuemie2014/2018、fieller1954、morris2019、hernan2016、johnson2023mimic、vanderweele2017、suissa2008、langan2018recordpe 等） | ✅ 前轮已核，元数据正确 |

**发现 3 条含虚构内容/错误元数据的条目（🔴 必须修复，AI 幻觉作者名的典型模式——用领域内真实学者名张冠李戴）：**

| 引用键 | 问题 | 修正 |
|---|---|---|
| **fister2016hrguided** | 标题/期刊/年/卷/期/页均真实，但 **5 位作者中 4 位虚构**：bib 写 "Fister, Zabel, Schmidt, Hnatkova, Malik, Faber"；真实作者为 **Fister M, Mikuz U, Starc V, Vrtovec B, Haddad F**（Zabel/Schmidt/Hnatkova/Malik/Faber 均非本文作者）。且 **DOI 错误**：bib 为 ...2016.**02**.002，真实为 ...2016.**01**.002 | 全部替换作者列 + 修正 DOI |
| **titratehf2024** | TITRATE-HF 研究真实存在，但 **bib 期刊论文条目为拼凑**：标题 "TITRATE-HF: Real-world GDMT sequencing and titration patterns..." 系虚构；真实发表的 EJHF 论文标题为 "Contemporary guideline-directed medical therapy in de novo, chronic, and worsening heart failure patients: First data from the TITRATE-HF study"，**一作为 Malgie J**（Brugts JJ 为末位作者），卷期页 26(**7**):**1549–1560**（非 26(Suppl 2):S35–S37），DOI 10.1002/ejhf.32**67**（非 3287）；bib 所列 "Hoes AW" 不在该文作者列表 | 整条重写为 Malgie J, Wilde MI, Clephas PRD, ... Brugts JJ. Eur J Heart Fail. 2024;26(7):1549-1560. doi:10.1002/ejhf.3267，并核对正文引用处的具体陈述是否与该文一致 |
| **bok2024bbadjustment** | 标题/期刊/卷/期/页/DOI 正确，但 **第 2、3 作者虚构**：bib 写 "Bok, Wells DA, Vest TA, and others"；真实为 **Bok RW, Lacoste JL, Fang W, Kido K**（仅 4 位作者，无 "others"） | 替换作者列 |

**建议**：投稿前对 references.bib 全量再做一次机械化核对（Crossref DOI 反查），凡作者列与 DOI 元数据不符者一律以 Crossref 为准。

### 3.3 交叉引用与编号系统（🔴 必须修复）

- **X1**：正文 Methods（两版）称 "a TARGET checklist is provided in **eAppendix 10**"，但 TARGET 清单实际在 **eAppendix 5**；eAppendix 10 是一致性证明（Consistency property）。完全版与投稿版均错。
- **X2**："Table S4" 共 **4 处**引用指向不存在的表：完全版正文 2 处（Results 两段，其中一处支撑 "+137% to +319%"）、投稿版 2 处（Results 1 处 "Table S4 in the Supplement"、Discussion 1 处隐含同源）。两版补充材料均只有 eTable 1–6。**"+137% to +319%" 数值本身已验证正确，但支撑表缺失**——建议在补充材料新增该表（每配置 BER/BF 相对偏倚对照，数据已在 table02 与 rds 中）并统一改引用为 eTable 编号。
- **X3**：完全版补充材料存在 **两套表编号并存**：Table S1（NC 表）、Table S7/S8（Ren 框架）与 eTable 1–6 混用。JAMA 系投稿规范要求统一 eTable/eFigure 前缀，应全部并入 eTable 序列。
- **X4**（Minor）：投稿版 Methods 提 "Twelve negative control outcomes ... (Table 2)"，但投稿版正文表编号为 Table 1（模拟）与 Table 2（NC），一致 ✓；完全版同名表亦为 Table 2 ✓。此项无问题，列出以示已查。

### 3.4 图注与渲染（docx 提取验证）

- 完全版 **Figure 1（DAG）图注**含大量 LaTeX 数学（$U$、$\hat{\mu}_B$、$\tilde{\psi}$、BF 公式），docx 提取验证已正确转换为 Word 数学（OMML），**v33 的图注转义坑未复发** ✓。
- 补充材料 eFigure 1 同图图注已改用纯文本（与 v33.2 约定一致）✓。
- 两版正文其余 fig.cap 均为纯文本 ✓。

---

## 四、分级问题清单

### 🔴 Major（投稿前必须修复）

| # | 问题 | 位置 | 修复建议 |
|---|---|---|---|
| M1 | fister2016hrguided：4/5 作者虚构 + DOI 错 | references.bib | 替换为真实作者列（Fister M, Mikuz U, Starc V, Vrtovec B, Haddad F），DOI 改 10.1016/j.jelectrocard.2016.01.002 |
| M2 | titratehf2024：标题/一作/卷期页/DOI 全错 | references.bib 及正文引用处 | 重写为 Malgie J, et al. EJHF 2024;26(7):1549-1560, doi:10.1002/ejhf.3267；核对正文陈述 |
| M3 | bok2024bbadjustment：第 2/3 作者虚构 | references.bib | 改为 Bok RW, Lacoste JL, Fang W, Kido K |
| M4 | Table S4 引用 4 处指向不存在的表 | 两版正文 Results/Discussion | 补充材料新增该表（数据已在 output/tables 及 rds 中）并统一编号，或改引现有表 |
| M5 | TARGET checklist 位置错引（eAppendix 10 → 应为 5） | 两版 Methods | 改为 eAppendix 5 |

### 🟡 Moderate（强烈建议，影响审稿通过率）

| # | 问题 | 修复建议 |
|---|---|---|
| M6 | null 条件（48/336）被排除出 BF 全部汇总统计，与"BF 在零效应处天然有限"卖点矛盾（C1/G1） | 按 bf_true=1 纳入统计并报告，或正文明确说明排除逻辑 |
| M7 | "randomly selected 30%" 与代码确定性实现不符（C2） | 改文字或改代码（后者需重跑模拟） |
| M8 | plug-in vs bootstrap 中位数点估计差异（0.968 vs 0.906；BER 30.4 vs 9.6）未报告对照（G2） | eAppendix 补两口径对照表 |

### 🟢 Minor（建议）

| # | 问题 | 修复建议 |
|---|---|---|
| m1 | log_bsr floor 1e-4 未文档化（C3） | eAppendix 9 加一句 |
| m2 | Fieller vs bootstrap CI 分歧仅一句带过（G3） | eAppendix 1 补 2–3 句 |
| m3 | "factors of 2" 阈值表述不精确（G4） | 改为精确不等式表述 |
| m4 | 补充材料 Table S1/S7/S8 与 eTable 双编号系统（X3） | 统一为 eTable 序列 |
| m5 | Abstract "calibrated RR, 1.01" 与 "+137% to +319%" 为硬编码 | 改为内联计算（数值已验证正确，纯稳健性考虑） |
| m6 | 投稿版未报告 GDMT 的 Fieller 结果（完全版有 interior [0.42, 1.80]） | 视篇幅补一句或保留现状 |
| m7 | 修改摘要遗留的合作作者邮箱占位符、Data Sharing Statement 的 Zenodo DOI | 投稿前补齐（作者自查清单） |

---

## 五、审稿方法学说明（可复现性）

本次审稿的全部验证可由以下入口复现：
1. Fieller 系数推导：按 `bsr_fieller()` 源码符号手工展开 (m2−ρm1) 的二次型；
2. 数值复现：`Rscript` 读取 `output/simulation/simulation_merged_v34.rds`（336×22）与 `output/data/bsr_results_v34.rds`，aggregate 按 ex_violation×n_nc×bias_sigma 求 mean；
3. 文献核实：WebSearch/Crossref 按 DOI 与标题反查；
4. 图注渲染：python zipfile + ElementTree 提取 docx 的 w:t/m:t。

---

## 六、结语

v34 是一次质量明显的跃升：指标切换数学上站得住、工程上复现得了、文字上几乎无 AI 痕迹。当前距离投稿的差距集中在**参考文献诚信层**（3 条幻觉条目——这是外部审稿人一查一个准的硬伤）与**交叉引用一致性**（Table S4/eAppendix 10 两处指向错误），加上 null 条件论证缺口这一个"卖点自证"问题。按上述 M1–M8 清单修复后，本文具备在 JAMA Network Open 方法学子栏目竞争的实力。

—— 审稿人：WorkBuddy（GLM），2026-08-12 22:54 GMT+8
