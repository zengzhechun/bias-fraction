# biasratio 包与 v39 稿件一致性审计

日期：2026-09-11
包路径：`/Users/zengzhechun/SynologyDrive/Github/biasratio`
对照稿件：`第39版/manuscript/`（JAMA 轨道 + 长稿轨道，共 4 份 qmd）

## 结论

**包需要更新，共 5 处，但没有一处是功能性故障。** 223 个单元测试全部通过，工作树干净，`bf_reliability` 的 12 个分桶与 v39 稿件查找表逐值一致。需要改的是版本号、几处过期数值、数据来源标注、以及论文报告规则与包内函数之间的一个语义缺口。

## 健康基线（无需改动）

| 项目 | 实测 |
|---|---|
| 测试 | 223 通过 / 0 失败（11 个测试文件） |
| git | HEAD = `ec65bb6`，工作树干净 |
| `med_ci_width` 属性 | 0.1298899，与 v39 的 `part2.ci_width.median_half_width` = 0.12988986 一致 |
| `bf_reliability` 12 桶 | `bf_center` / `p_bias_dom_narrow` / `p_bias_dom_wide` 与 v39 `part2.lookup` 逐值一致 |
| 点估计三区分类 | 包与论文分区完全一致（6 个测试点全部一致） |

## 待更新项

### 1. 稿件引用的包版本号过期（优先级最高）

`DESCRIPTION` 的 `Version: 0.3.0`，但四份 qmd 都写 `biasratio (version 0.2.1)`。

| 文件 | 行 | 现状 |
|---|---|---|
| `manuscript/manuscript_jama_v39.qmd` | 251 | R 版本声明句写 0.2.1 |
| `manuscript/manuscript_jama_v39.qmd` | 649 | Data Sharing 写 0.2.1，并写 `archived at commit 36bf9ba` |
| `manuscript/manuscript_medarchive_v39.qmd` | 151 | 同上 |
| `manuscript/manuscript_medarchive_v39.qmd` | 271 | 同上 |
| `Submit/JAMA Network Open/manuscript/AI 审稿/CoverLetter_JNO投稿_审核clean_20260905.md` | 23 | Cover Letter 写 0.2.1 |
| `Submit/JAMA Network Open/manuscript/AI 审稿/CoverLetter_JNO投稿_Doubao_20260905_0055.md` | 36 | Cover Letter 写 0.2.1 |

补充：`36bf9ba` 是 v0.2.1 的提交，v0.3.0 是 `e6d5f91`。若按「实际使用版本」如实申报，commit 也需一并改为 `e6d5f91`。

### 2. `med_ci_width` 陈旧数值共 7 处

真值为 **0.1298899**；陈旧处写作 `0.133` 或 `0.130`。

| 文件 | 行 | 现值 | 应改 |
|---|---|---|---|
| `NEWS.md` | 16 | `med_ci_width = 0.133` | 0.130（或 0.1299） |
| `NEWS.md` | 24 | `med_ci_width`（0.130） | 一致化 |
| `R/ber-screen.R` | 70 | roxygen「default 0.133」 | 0.130 |
| `R/ber-screen.R` | 219 | 代码回退值 `0.133` | 0.1298899 |
| `R/data.R` | 61 | roxygen「0.130」 | 0.1299 |
| `man/ber_screen.Rd` | 56 | 自动生成，同 R 源 | 重新生成 |
| `man/bf_reliability.Rd` | 15 | 自动生成，同 R 源 | 重新生成 |

只有 `data-raw/make-reliability.R`（第 21、55 行）写对了。注意 `man/` 由 roxygen2 生成，改完 `R/*.R` 后必须重跑 `devtools::document()`，不要手改 `.Rd`。

### 3. 数据来源标注自相矛盾

同一个包内对 `bf_reliability` 的来源有四种说法：

| 位置 | 说法 |
|---|---|
| `attr(bf_reliability, "source")` | manuscript **v38**，五因素全因子，**960** 条件 × 1000 = 960,000 |
| `R/data.R` 第 64 行 `@source` | manuscript **v37**（**640** conditions） |
| `R/data.R` 第 46 行正文 | manuscript v38，五因素全因子 |
| `R/ber-screen.R` 第 4 行文件头 | v37 discussion |
| `man/bf_reliability.Rd` 第 19 行 | manuscript v37（640 conditions） |

以 `attr(source)` 为准（v38 / 960 条件）。`R/ber-screen.R` 第 4 行与 `NEWS.md` 第 4 行的「v37 discussion」是记录设计提出时间的溯源注记，可保留但建议加「design originated in」字样以免被误读成数据来源。

### 4. 论文的 R2 / R3 / C1 / C2 在包内无法表达

这是唯一一处**语义层面**的缺口，需要用户裁决后再动。

包内 `bf_classify(bf, ciLo, ciHi)` 带区间时判的是「整个区间是否落在**效应主导区**（BF < 1/3）」；论文 R3 / C2 判的是「整个区间是否**避开偏倚主导区**（BF ≤ 0.5）」。这是两个不同的问题。实测分歧：

| 输入 | 包 `bf_classify` | 论文 R3 判可用 |
|---|---|---|
| BF=0.45, CI=[0.30, 0.48] | `mixed` | TRUE ← 分歧 |
| BF=0.40, CI=[0.20, 0.49] | `mixed` | TRUE ← 分歧 |
| BF=0.20, CI=[0.10, 0.30] | `effect-dominated` | TRUE |
| BF=0.45, CI=[0.31, 0.53] | `mixed` | FALSE |
| BF=0.60, CI=[0.40, 0.80] | `mixed` | FALSE |

论文 Table 2 的规则清单与包内覆盖情况：

| 规则 | 论文判据 | 包 | 状态 |
|---|---|---|---|
| R0 | 未校准 P < .05 | 无 | 未覆盖（包外可算） |
| R1 | 校准 P < .05 | `ber_screen()` 层 1 | 已覆盖 |
| R2 | 层 1 + BF **点估计** < 0.5 | 无二元判据 | 需手写 |
| R3 | 层 1 + BF **区间上界** ≤ 0.5 | 无 | 需手写 |
| **R4** | 层 1 + P(BD) < 15% | **`ber_screen()` 的 `effect-evidence` 档** | **已覆盖** |
| C1 | BF 点估计 < 0.5，无层 1 | 无 | 无法表达 |
| C2 | BF 区间上界 ≤ 0.5，无层 1 | 无 | 无法表达 |

实测确认 R4 已覆盖：`ber_screen()` 的层 1 判据是 `cal_p < 0.05`，`effect-evidence` 档判据是 `p_bias_dom < 0.15`，与论文 R4 定义一致。

缺口本身不是错误，是接口不全：论文 Data Sharing 声明包提供「the two-layer screening rule」，读者会预期能复现 Table 2 全部 7 条规则，而目前只有 R1 与 R4 可以。

### 5. 区间覆盖率的披露缺失

v39 报三档覆盖率 71.1%（总体）/ 58.5%（窄）/ 83.8%（宽），并在 S11 量化了被省略的那一项（联合传播后 78.8% → 97.7%，半宽中位数 0.132 → 0.222）。包内在 `R/`、`man/`、`vignettes/`、`README`、`NEWS` 中均不出现 coverage 字样，也没有任何关于区间欠覆盖的提示。

`ber_screen()` 的 verdict 与 `bf_classify()` 的区间判据都建立在同一个后验区间上，读者若把区间当名义 95% 使用会高估把握度。

## 建议的修改方案

**第一组（纯改文档与常数，无风险，建议直接做）**

1. 四份 qmd + 两份 Cover Letter：`version 0.2.1` → `0.3.0`；commit `36bf9ba` → `e6d5f91`。
2. 第 2 节 5 处源文件数值改为 0.1299（或统一引用属性，不再写死字面量）。
3. 第 3 节 `R/data.R` 第 64 行 `@source` 与 `R/ber-screen.R` 第 4 行统一到 v38 / 960。
4. 重跑 `devtools::document()` 重新生成 `man/`。
5. `DESCRIPTION` 建议同步升 `0.3.1`，`NEWS.md` 补一条改动记录。

**第二组（需要用户先定方案）**

6. 是否新增 `bf_rules()` / `bf_rule_r2()` / `bf_rule_r3()` 一类导出函数，让 Table 2 的 7 条规则可以直接复现；若新增，`bf_classify` 带区间时的文档需明确它判的是「区间是否整体落在某一区」，与 R3 的「区间是否避开偏倚主导区」不是同一件事。
7. 是否在 `ber_screen()` 文档与 `bf_reliability` 文档中补一句区间欠覆盖的提示（引用 v39 S11 的联合传播结果）。

## 复核命令

```bash
cd /Users/zengzhechun/SynologyDrive/Github/biasratio
export PATH="/Library/Frameworks/R.framework/Resources/bin:$PATH"

# 测试
Rscript -e 'devtools::test()'

# 属性值与真值核对
Rscript -e 'load("data/bf_reliability.rda"); print(attr(bf_reliability,"med_ci_width"))'

# 陈旧字面量
grep -n "0.133\|0.130" NEWS.md R/ber-screen.R R/data.R man/ber_screen.Rd man/bf_reliability.Rd
```
