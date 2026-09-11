"""Re-apply JAMA structured-abstract label formatting after `quarto render`.

Quarto/pandoc renders `*Importance.*` as italic runs; JAMA Network Open wants the
label in bold. Because the docx is regenerated on every render, this must be run
after each render. Safe to run repeatedly.

Also sets the abstract section to single spacing if needed (left untouched by
default; see DOUBLE_SPACE flag).
"""

import sys
import docx

PATH = "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版/manuscript/manuscript_jama_v39.docx"

LABELS = [
    "Importance.",
    "Objective.",
    "Design, Setting, and Participants.",
    "Exposures.",
    "Main Outcomes and Measures.",
    "Results.",
    "Conclusions and Relevance.",
]


def main(path=PATH):
    doc = docx.Document(path)
    paras = doc.paragraphs

    # Locate the Abstract section: between the "Abstract" heading and the next
    # heading at the same level ("Introduction").
    start = end = None
    for i, p in enumerate(paras):
        if p.text.strip() == "Abstract" and start is None:
            start = i
        elif start is not None and p.style.name.startswith("Heading") and i > start:
            end = i
            break
    if start is None:
        print("ERROR: 'Abstract' heading not found")
        return 1
    if end is None:
        end = len(paras)

    n = 0
    for p in paras[start + 1:end]:
        txt = p.text
        if not txt:
            continue
        for lab in LABELS:
            if txt.startswith(lab):
                acc = 0
                for r in p.runs:
                    if acc < len(lab):
                        r.bold = True
                        r.italic = False
                    acc += len(r.text)
                n += 1
                break

    doc.save(path)
    print(f"bolded {n} abstract labels (paragraphs {start + 1}..{end - 1})")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
