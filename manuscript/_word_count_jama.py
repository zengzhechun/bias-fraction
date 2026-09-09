"""JAMA Network Open body word count for the rendered docx.

Counts Introduction through Conclusions. Excludes the title block, Key Points,
abstract, references, tables, figure captions, and Article Information.

Text is extracted with stdlib zipfile + ElementTree rather than python-docx,
because `Paragraph.text` in python-docx skips OMML (<m:t>) content; Word's own
word count includes it, so our count must too.
"""

import re
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
M = "{http://schemas.openxmlformats.org/officeDocument/2006/math}"

PATH = "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第38版/manuscript/manuscript_jama_v38.docx"

START = {"Introduction"}
STOP = {"References", "Article Information", "Figure Legends"}
CAPTION_STYLES = {
    "Image Caption",
    "Table Caption",
    "Captioned Figure",
    "Caption",
    "Figure Caption",
}
CAPTION_RE = re.compile(r"^(Figure|Fig\.|Table|eTable|eFigure)\s*\d*\s*\.?\s")


def para_text(p):
    """Concatenate every w:t and m:t descendant, in document order."""
    parts = []
    for el in p.iter():
        if el.tag == W + "t" or el.tag == M + "t":
            parts.append(el.text or "")
    return "".join(parts)


def para_style(p):
    ppr = p.find(W + "pPr")
    if ppr is None:
        return ""
    ps = ppr.find(W + "pStyle")
    if ps is None:
        return ""
    return ps.get(W + "val") or ""


def body_items(root):
    body = root.find(W + "body")
    for child in body:
        if child.tag == W + "p":
            yield ("p", child)
        elif child.tag == W + "tbl":
            yield ("tbl", child)


def main(path=PATH):
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml")
    root = ET.fromstring(xml)

    started = False
    total = 0
    counted = 0
    skipped_captions = 0
    for kind, el in body_items(root):
        if kind == "tbl":
            continue
        text = para_text(el).strip()
        style = para_style(el)
        if not started:
            if style.startswith("Heading") and text in START:
                started = True
            continue
        if style.startswith("Heading") and text in STOP:
            break
        if style in CAPTION_STYLES or CAPTION_RE.match(text):
            skipped_captions += 1
            continue
        words = [w for w in text.split() if re.search(r"[A-Za-z0-9]", w)]
        total += len(words)
        counted += 1

    print(f"body word count: {total}  (paragraphs counted: {counted}, "
          f"captions skipped: {skipped_captions})")
    print(f"remaining vs 3000: {3000 - total}")
    return total


if __name__ == "__main__":
    main(*sys.argv[1:])
