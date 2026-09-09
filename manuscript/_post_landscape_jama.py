"""Post-process JAMA Network Open docx for landscape section.

Renders a single landscape section (Fig 2 + Table 2) at US Letter dimensions
(11 x 8.5 in) with 1 in top/bottom and 1.333 in left/right margins, matching
the portrait section's page size so the rest of the manuscript stays at Letter.
Pandoc emit A4 (11906 x 16838 twips) by default and leave out pgMar, which
would otherwise be inherited from the body sectPr; both are corrected here so
the table column widths set by flextable (8.33 in landscape body width) line
up with the actual page.

IDEMPOTENT AND ROBUST:
- The landscape section is located by a block-safe regex that matches the
  <w:sectPr> ... </w:sectPr> block containing w:orient="landscape", regardless
  of attribute order or of how many <w:pgMar> children it already has.
- Inside that block we force the pgSz to Letter landscape and collapse any
  number of <w:pgMar> children down to exactly ONE with our fixed margins.
  Re-running therefore never produces a duplicate pgMar (the earlier bug that
  broke _post_portrait_for_coauthor.py's regex and left the section unstripped).
"""
import sys
import re
import zipfile
import shutil
from pathlib import Path

LANDSCAPE_W = 15840   # 11 in
LANDSCAPE_H = 12240   # 8.5 in
MARGIN_TB   = 1440    # 1 in
MARGIN_LR   = 1920    # 1.333 in
MARGIN_HF   = 720     # 0.5 in

NEW_PGSZ = (
    f'<w:pgSz w:w="{LANDSCAPE_W}" w:h="{LANDSCAPE_H}" w:orient="landscape"/>'
)
PGMAR = (
    f'<w:pgMar w:top="{MARGIN_TB}" w:right="{MARGIN_LR}" '
    f'w:bottom="{MARGIN_TB}" w:left="{MARGIN_LR}" '
    f'w:header="{MARGIN_HF}" w:footer="{MARGIN_HF}" w:gutter="0"/>'
)

# Block-safe: the <w:sectPr>...</w:sectPr> that contains w:orient="landscape".
# The negative-lookahead guard (?!</?w:sectPr>) keeps the match inside a single
# section block even though sectPr does not nest.
LAND_BLOCK_RE = re.compile(
    r'<w:sectPr>(?:(?!</?w:sectPr>).)*?w:orient="landscape".*?</w:sectPr>',
    re.S,
)
# Any pgSz carrying orient="landscape", independent of attribute order.
PGSZ_LAND_RE = re.compile(r'<w:pgSz\s+[^>]*w:orient="landscape"[^>]*/>')
# Any pgMar child (used to strip duplicates before re-adding exactly one).
PGMAR_RE = re.compile(r'<w:pgMar[^>]*/>')


def fix_block(blk):
    # Force Letter landscape pgSz.
    blk = PGSZ_LAND_RE.sub(NEW_PGSZ, blk)
    # Collapse every existing pgMar (handles the legacy duplicate-pgMar case).
    blk = PGMAR_RE.sub("", blk)
    # Re-insert exactly one pgMar immediately after the pgSz.
    blk = PGSZ_LAND_RE.sub(NEW_PGSZ + PGMAR, blk)
    return blk


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
                n = len(LAND_BLOCK_RE.findall(txt))
                if n:
                    txt = LAND_BLOCK_RE.sub(lambda m: fix_block(m.group(0)), txt)
                    print(f"fixed landscape sectPr block(s): {n}")
                else:
                    print("no landscape sectPr found; no change")
                data = txt.encode("utf-8")
            zout.writestr(item, data)

    shutil.move(tmp, src)
    print(f"saved {docx}")


if __name__ == "__main__":
    main(sys.argv[1])
