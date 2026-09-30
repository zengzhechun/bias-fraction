# Cover Letter：JAMA Network Open 投稿

| 项目 | 内容 |
|---|---|
| **生成模型** | Doubao（豆包） |
| **生成日期** | 2026-09-05 (UTC+8) |
| **目标期刊** | JAMA Network Open |
| **文章类型** | Original Investigation |
| **论文标题** | Quantifying Bias in Causal Estimates Using Negative Controls: The Bias Attribution Fraction |
| **通讯作者** | Zhechun Zeng, MD, MPH |

---

September 11, 2026

The Editors
JAMA Network Open
American Medical Association
330 N Wabash Ave, Suite 39300
Chicago, IL 60611

Dear Editors,

We are pleased to submit our manuscript entitled **"Quantifying Bias in Causal Estimates Using Negative Controls: The Bias Attribution Fraction"** for consideration as an **Original Investigation** in JAMA Network Open.

Observational comparative effectiveness studies increasingly adopt target trial emulation and doubly robust estimation, yet these advances cannot eliminate unmeasured confounding. Existing tools, including E-values and negative-control calibration, either return a threshold or a binary calibrated *P* value, without quantifying how much of the surviving signal is attributable to systematic bias. We propose the **Bias Attribution Fraction (BAF)**, a bounded metric on a [0, 1] scale computed from quantities that the empirical-calibration pipeline already produces, requiring no additional data. In a factorial simulation of 960,000 repetitions, adding BAF to the calibrated *P* value improved discrimination of bias-dominated estimates (AUC, 0.787 to 0.918) and reduced the misuse rate from 36.0% to 2.9%. In a TARGET-compliant target trial emulation of beta-blocker therapy among 14,677 patients with heart failure (MIMIC-IV), BAF revealed that one clinical question was bias-dominated (BAF = 0.91) and the other fell in a competitive zone (BAF = 0.51) despite rigorous design and doubly robust estimation.

We believe this work is well suited to JAMA Network Open because it addresses a methodological gap directly relevant to the interpretation of observational evidence across clinical specialties, provides a fully reproducible open-source implementation (the `biasratio` R package and an interactive explainer), and includes a real-world clinical demonstration rather than a purely theoretical treatment. The manuscript contains 6,665 words of text (excluding abstract, references, tables, and figure legends), 3 tables, and 3 figures. We note that the text exceeds the journal's 3,000-word limit for Original Investigations, and that the combined table and figure count is 6 against a limit of 5. The length reflects three components that we believe are each necessary to the claim: the metric definition and interval construction, the 960,000-repetition simulation that calibrates the decision rule against known truth, and the two-question case study that demonstrates the rule on real data. If the editors prefer, we are glad to shorten the text and to move one exhibit (Table 2 or Figure 2) to the Supplementary file; we would welcome the editors' guidance on which reduction they would find most useful.

We confirm that:

- This manuscript is original, has not been published previously in whole or in part, and is not under consideration elsewhere.
- All authors have read and approved the final manuscript and agree with its submission to JAMA Network Open.
- All authors report no conflicts of interest. The corresponding author (Dr. Zeng) is the developer of the `biasratio` R package, released under the MIT license; this does not constitute a financial conflict of interest.
- This research received no specific grant from any funding agency in the public, commercial, or not-for-profit sectors.
- The MIMIC-IV and MIMIC-IV-ECG data are available through PhysioNet to credentialed users; all analysis code, the `biasratio` R package (version 0.3.1), and an interactive graphical explainer are publicly available on GitHub.
- The authors used artificial intelligence tools (DeepSeek V4 Pro, Kimi K3, GLM 5.3, ChatGPT 5.5, and Tencent WorkBuddy) for code development, manuscript editing, and language polishing. All AI-assisted content was critically reviewed and revised by the authors, who take full responsibility for the content of this manuscript.
- No related manuscripts from the same study have been published, posted, or submitted elsewhere.

Please address all correspondence concerning this manuscript to:

**Zhechun Zeng, MD, MPH**
Beijing Anzhen Hospital, Capital Medical University
Beijing Institute of Heart, Lung and Blood Vessel Diseases
Tongzhou Campus, No. 225 Songzhuang South 1st Street
Tongzhou District, Beijing 101149, China
Email: zengzhechun@icloud.com

Thank you for your consideration. We look forward to your response.

Sincerely,

Zhechun Zeng, MD, MPH
on behalf of all authors

---

## 起草说明

1. **文章类型**：Original Investigation。JNO 的方法学论文通常归为此类。如改为 Research Letter 或其他类型，需相应调整字数声明和描述。

2. **核心发现段落**：使用三个关键数字组（960,000 次仿真 / AUC 0.787→0.918 / 误用率 36.0%→2.9%；14,677 名患者 / BAF 0.91 和 0.51），符合 JAMA 风格：用具体数字而非笼统描述说明贡献。

3. **为什么适合 JNO**：强调三点：跨专科的方法学相关性、完全可复现的开源实现、真实世界临床演示（而非纯理论）。

4. **声明部分**：按 JAMA 系列要求包含原创性、作者批准、利益冲突（特别说明作者自有 R 包不构成财务 COI）、资金、数据可及性、AI 使用披露、相关论文披露。

5. **AI 使用披露**：JAMA 系列 2024 年起要求在投稿时披露 AI 使用，已按论文中 AI Use Disclosure 的内容写入。

6. **字数确认（2026-09-11 实测）**：正文 **6,665 words**，JNO Original Investigation 上限 3,000，**超出 3,665 词**；摘要 432（上限 350）、Key Points 162（上限 75–100）、表 3 + 图 3 = 6（上限 5）**亦均超标**。上文第 3 段已按真实数字改写，超标事实以正式披露写入正文段落，内部审核标记已全部清除。

7. **JNO Cover Letter 要求**：Cover letter 为推荐提交（recommended rather than required），需包含通讯作者完整联系方式、披露相关论文、阐明贡献。本信已覆盖全部要求。
