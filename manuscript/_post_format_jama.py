import docx
from docx.enum.text import WD_LINE_SPACING, WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE

path = "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版/manuscript/manuscript_jama_v39.docx"
doc = docx.Document(path)

targets = ["Normal"]
for s in doc.styles:
    if s.type == WD_STYLE_TYPE.PARAGRAPH and s.name.startswith("Heading"):
        targets.append(s.name)

n_changed = 0
for name in targets:
    st = doc.styles[name]
    pf = st.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.DOUBLE
    pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    n_changed += 1

# 图注与表注不跟随正文的双倍行距：JAMA 图注与表注用小字号单倍行距。
# 原先 ImageCaption / TableCaption 两个样式都没有定义字号与行距，
# 于是继承了 Normal 的 12 pt 双倍行距，736 字符的图注要占掉约 4.4 英寸，
# 把图挤得很小，且放大后图注会被整段挤到下一页。
from docx.shared import Pt

caption_styles = ["Image Caption", "Table Caption"]
n_cap = 0
for _nm in caption_styles:
    if _nm not in [_s.name for _s in doc.styles]:
        print("!! 缺少样式:", _nm)
        continue
    _st = doc.styles[_nm]
    _st.font.size = Pt(9)
    _pf = _st.paragraph_format
    _pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
    _pf.space_before = Pt(6)
    _pf.space_after = Pt(6)
    _pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
    n_cap += 1

print("caption styles -> 9pt single:", n_cap, caption_styles)

doc.save(path)
print("formatted styles:", n_changed, targets[:6], "..." if len(targets) > 6 else "")
