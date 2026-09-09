"""Post-process JAMA docx for human-AI co-authoring: strip the landscape section.

The Tencent Docs local editor silently truncates ALL content AFTER a
landscape (w:orient="landscape") section break on open/save (see #43/#44/#80 in
the project work log; the worst incident silently dropped the entire latter
half of the manuscript). The earlier A4 -> Letter + pgMar fix in
_post_landscape_jama.py did NOT prevent the truncation, because the landscape
section break itself is the trigger, not the page dimensions or margins.

For human-AI co-authoring we therefore REMOVE the landscape section break
ENTIRELY, so Fig 2 + Table 2 flow inside the single remaining portrait section
and the editor can open the full manuscript without dropping the latter half.

The SUBMISSION version keeps landscape via _post_landscape_jama.py (it is never
opened by the co-authoring editor, only uploaded). After any quarto render, run
EITHER _post_landscape_jama.py (submission) OR this script (co-authoring), never
both, on the same file.

ROBUSTNESS (fix for #80): the landscape block is located with a block-safe regex
that matches the <w:sectPr>...</w:sectPr> containing w:orient="landscape"
regardless of attribute order or of the (legacy) duplicate <w:pgMar> child that
_post_landscape_jama.py used to emit. An earlier order-sensitive LAND_RE failed
to match that duplicate-pgMar block and left the section unstripped, so the
"portrait" output was still landscape and the editor truncated it again.
Usage:
    python _post_portrait_for_coauthor.py <manuscript.docx>
"""
import sys
import re
import zipfile
import shutil
from pathlib import Path

# Block-safe: the <w:sectPr>...</w:sectPr> block that contains
# w:orient="landscape". The (?!</?w:sectPr>) guard keeps the match inside a
# single section block. Attribute-order and duplicate-pgMar tolerant.
LAND_RE = re.compile(
    r'<w:sectPr>(?:(?!</?w:sectPr>).)*?w:orient="landscape".*?</w:sectPr>',
    re.S,
)
# Degenerate empty section break that pandoc emits at the START of the landscape
# div (before Fig 2). Self-closing and without any properties; removing it folds
# the surrounding paragraphs back into the single portrait section.
EMPTY_RE = re.compile(r'<w:sectPr/>')


def main(docx):
    src = Path(docx)
    if not src.exists():
        sys.exit(f"not found: {docx}")
    tmp = src.with_suffix(".docx.tmp")

    with zipfile.ZipFile(src, "r") as zin, \
         zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "word/document.xml":
                txt = data.decode("utf-8")
                n1 = len(LAND_RE.findall(txt))
                n2 = len(EMPTY_RE.findall(txt))
                txt = LAND_RE.sub("", txt)
                txt = EMPTY_RE.sub("", txt)
                data = txt.encode("utf-8")
                print(f"removed landscape sectPr x{n1}, empty sectPr x{n2}")
            zout.writestr(item, data)

    shutil.move(tmp, src)
    print(f"saved {docx}")


if __name__ == "__main__":
    main(sys.argv[1])
