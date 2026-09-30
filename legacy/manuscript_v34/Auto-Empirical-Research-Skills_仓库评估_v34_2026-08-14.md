# Auto-Empirical-Research-Skills 仓库评估报告

- **仓库**：https://github.com/brycewang-stanford/Auto-Empirical-Research-Skills（brycewang-stanford，CoPaper.AI / Stanford REAP）
- **评估日期/时间**：2026-08-14（CST）
- **版本**：v1
- **评估方式**：GitHub API 元数据 + 仓库树（4,376 个文件）+ 关键技能文件全文阅读（`skills/48-de-AIGC-skills` 全套、README、INSTALL、CHANGELOG、SECURITY-SCAN-REPORT、eval-harness 结构）+ 近期提交与 issue 记录

---

## 1. 项目概述

### 背景与定位

该仓库是一个**面向实证研究的 AI Agent 技能（Skills）聚合与评测平台**，自称"精选 23,000+ Agent Skills，覆盖 8 大社会科学学科"。实际结构是：把约 70 个第三方技能仓库按编号目录（`skills/00`–`skills/72`）vendor 进单一 monorepo，并在其上叠加三层自研设施：

1. **benchmark/**：18 个方法学基准案例（DID、IV、RD、Bartik、DML、双重稳健、事件研究、合成控制、中介分析、Oaxaca、分位数、生存分析等），每个含参考论文与数据；
2. **eval-harness/**：技能质量评测框架（scenario + toml 配置，含 `de-aigc-structural.toml`、`english-deslop.toml` 等场景）；
3. **工程化设施**：根路由 SKILL.md、provenance.json 上游来源追踪、SECURITY-SCAN-REPORT.md、CI（含 OSSF Scorecard）、tests/tools。

### 核心功能

- **实证研究流水线**：`00-Full-empirical-analysis-skill_StatsPAI/Python/Stata/R` 等"20 分钟可复现实证论文"端到端技能（数据清洗→建模→表格→复现包）；
- **因果推断教学/工具**：MixtapeTools（Causal Inference: The Mixtape 配套）、marginaleffects、pyfixest 技能；
- **学术写作与降 AI 味**：`48-de-AIGC-skills`（中英双语降 AIGC，六步闭环 + 22 英文/17 中文模式库）、`44-humanizer_academic`（医学/学术英文）、`45/46` deslop/stop-slop、`47-avoid-ai-writing`、`49-humanize-chinese`、`70-ssci-polish`；
- **文献检索工具**：lit-review-agent-tools、Unpaywall/NBER API 技能、paper 下载（scansci-pdf）。

### 适用场景与目标用户

经济学、管理学、金融、社会学等社会科学实证研究者（Stata 为主，Python/R 次之），使用 **Claude Code / Claude Agent** 运行时；以及想批量评测"研究 Agent 技能质量"的工具开发者。**医学/流行病学/方法学研究者不是其目标用户。**

---

## 2. 质量评估

| 维度 | 评估 | 依据 |
|---|---|---|
| 文档完整性与清晰度 | ★★★★☆ | README 五语言（英文 71KB 详尽；**中文仅 5.6KB，明显薄弱**）；INSTALL/CONTRIBUTING/CHANGELOG/CITATION.cff 齐全；根 SKILL.md 有路由说明 |
| 项目结构规范性 | ★★★★☆ | monorepo 编号清晰；benchmark/eval-harness/tests 分离；provenance.json 追踪上游来源；比一般"技能堆"规范得多 |
| 维护活跃度 | ★★★★★ | 创建于 2026-04-03；最近提交 2026-08-10（评估前 4 天）；**3,403 star / 444 fork；0 个未关闭 issue**（已处理至 #67）；CI + Scorecard 持续运行 |
| 许可证 | ★★☆☆☆ | 仓库级 `LICENSE` 为 "Other / NOASSERTION"，**无标准开源许可证**；且 vendor 了约 70 个上游仓库的代码，许可证高度异质，商用/再分发有合规风险 |
| 功能实用性与独特性 | ★★★★☆ | de-AIGC-skills 的"结构性指纹 + 主张-证据核对 + 硬性红线"设计在同类降 AI 工具中独特且克制；18 方法 benchmark 对技能评测有价值；但 23k+ 技能中大量是同质镜像 |

**其他观察**：主页指向商业站点 copaper.ai（"20 分钟完成一篇可复现的规范实证论文"是营销话术）；"Stanford REAP" 是斯坦福农村教育行动项目的关联背景，仓库本身是社区/单一维护者主导，学术背书程度应审慎看待。

---

## 3. 对比分析

### 与"默认方案"（不装任何技能、靠模型裸写）相比

| 优势 | 不足 |
|---|---|
| de-AIGC 类模式库把"降 AI 味"从玄学变成可执行的规则（EN01–EN22、句长方差、主张-证据核对） | 规则是经验性的，不保证通过特定检测器；学术诚信声明要求作者全程负责 |
| 基准案例 + eval-harness 提供可量化的技能质量评测，而非靠口碑 | benchmark 面向社科方法（DID/IV/RD…），对医学方法学论文（TMLE/负对照校准）无现成案例 |
| 节省了逐个搜索上游技能仓库的发现成本 | 23k 技能的选择成本极高；大部分与单一课题无关 |

### 与"直接安装上游仓库"相比

- 优势：统一 provenance 追踪 + 安全扫描 + 一致性维护；
- 不足：多一层版本滞后；vendor 副本的许可证问题反而集中暴露。

### 关键限制

1. **运行时绑定**：技能是 Claude Code / Claude Agent 的 SKILL.md 格式，**不能直接安装进其他 Agent 运行时**（含本会话的 DeepSeek Harness）；移植需要手工改写为提示词/流程。
2. **学科错配**：主体是社会科学实证（首要语言 Stata），对医学/临床流行病学/方法学论文只有写作类技能（de-AIGC、humanizer、ssci-polish）可迁移。
3. **供应链风险**：第三方 vendor 代码 + 无标准许可证；虽有安全扫描报告，机构用户仍需自行复核。

---

## 4. 结论

### 是否值得安装：分场景（明确推荐意见）

- **社会科学实证研究者 + Claude Code 运行时**：**值得选装**。建议只装 `00-*` 流水线（按自己语言选 Stata/Python/R）、`48-de-AIGC-skills`、`45/46` 写作类，并利用 benchmark 做技能评测；不建议全量安装（23k 技能无意义且引入合规负担）。
- **医学/方法学研究者（本文场景）**：**不值得整体安装**；值得**抽取个别 SKILL.md 作为写作规范参照**（这正是本会话已做的，见下）。
- **其他 Agent 运行时（如 DeepSeek Harness）**：无法直接安装，只能把 SKILL.md 当作过程规范移植。

### 对本 v34 论文的应用价值（重点审查结论）

| 技能 | 对本论文的价值 | 采用情况 |
|---|---|---|
| `48-de-AIGC-skills` | **高**：英文模式库（EN01–EN22）+ 六步闭环 + 五维量表直接适用于本方法学论文 | ✅ 已用于 v34 全文起草与投稿包审计（见 `AI痕迹审计_de-AIGC_v34_2026-08-14.md`：命中 0 处 🔴 模式，EN21 两处已修，五维自评 48.1/50，A 级） |
| `44-humanizer_academic` | 中：生物医学写作模式语料，可作后续润色参照 | 部分吸收（未直接引用其文件） |
| `45/46` deslop/stop-slop | 中：通用英文去套话清单 | 原则已内化 |
| `70-ssci-polish` | 低-中：投稿润色流程 | 暂未采用 |
| `00-*` 实证流水线 | 低：本课题已有完整 R/Quarto 流水线（`R/`、`analysis/`），且其面向 Stata/Python 社科场景 | 不采用 |
| benchmark / eval-harness | 低：18 个基准均为社科方法，无 TMLE/负对照校准类基准 | 不采用 |

### 一句话总结

**该仓库质量与活跃度在技能聚合类项目中属上乘，但对本论文而言，"整体安装"收益极低；真正有用的是把 `de-aigc-skills` 作为写作与审计规范（已执行并形成审计报告），其余技能可忽略。** 最适合它的用户是使用 Claude Code 的经济学/社会科学实证研究者，或需要评测研究 Agent 技能质量的工具开发者；医学方法学论文、非 Claude 运行时、有许可证合规顾虑的机构均可不安装。

---

*（本评估基于 2026-08-14 抓取的 GitHub API 元数据与仓库文件快照；star/fork/issue 数字以 API 返回为准。引用来源：仓库 README、INSTALL.md、CHANGELOG.md、SECURITY-SCAN-REPORT.md、.gitmodules、`skills/48-de-AIGC-skills/` 全套文件。）*
