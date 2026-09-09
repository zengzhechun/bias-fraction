#!/usr/bin/env python3
"""Consistency audit across every rendered docx.

Stale strings = numbers that must have changed once the K=50 grid (960
conditions x 1000 reps) replaced the 640-condition grid. Any hit means the
docx predates the rebuild.
Missing strings = numbers that must be present in an up-to-date docx.

Text is pulled from both <w:t> and <m:t> nodes, because OMML maths lives in a
separate namespace and plain text extraction silently drops it.
"""
import sys, zipfile, glob, os, re
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
M = "{http://schemas.openxmlformats.org/officeDocument/2006/math}"

STALE = [
    "640 000", "576 000", "640-condition", "640 conditions",
    "0.5 bias-dominated", "0.3 mixed", "0.2 effect-dominated",
    "(12, 25)", "12, 25)", "two levels",
    # Subgroup counts: adding the K=50 level took the subgroup table from
    # 6 rows to 7, and the "other" (non-exchangeability) count from 4 to 5.
    "six pre-specified subgroups", "other four subgroups",
]
# Strings that must appear in an up-to-date docx. Regex, so that both
# separator conventions (960 000 / 960,000) count as present.
# Keyed "jama" = JAMA-truncated manuscript, "medarchive"/"base" = long form.
# The JAMA main states neither the simulation composition nor K levels (both
# live in its supplement), so its required list is deliberately shorter.
REQUIRED = {
    "jama":       [r"9[0-9]{2}[ ,]?000", r"86[0-9][ ,]?000"],
    "jama_supp":  [r"9[0-9]{2}[ ,]?000",
                   r"52\.5%\s*bias-dominated", r"12,\s*25,\s*50"],
    "medarchive": [r"9[0-9]{2}[ ,]?000", r"86[0-9][ ,]?000",
                   r"52\.5%\s*bias-dominated", r"12 to 50 negative-control"],
    "base":       [r"9[0-9]{2}[ ,]?000", r"86[0-9][ ,]?000",
                   r"52\.5%\s*bias-dominated", r"12 to 50 negative-control"],
    "supp":       [r"9[0-9]{2}[ ,]?000", r"86[0-9][ ,]?000",
                   r"52\.5%\s*bias-dominated", r"12,\s*25,\s*50"],
}


def classify(base):
    """Route a filename to its required-string bucket."""
    if "jama" in base:
        return "jama_supp" if "supplement" in base else "jama"
    if "medarchive" in base:
        return "supp" if "supplement" in base else "medarchive"
    return "supp" if "supplement" in base else "base"


def docx_text(path):
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml")
    root = ET.fromstring(xml)
    parts = []
    for el in root.iter():
        if el.tag in (W + "t", M + "t"):
            parts.append(el.text or "")
        elif el.tag == W + "tab":
            parts.append(" ")
    return "".join(parts)


def audit(path):
    txt = docx_text(path)
    base = os.path.basename(path).lower()
    kind = classify(base)
    stale = [s for s in STALE if s in txt]
    missing = [p for p in REQUIRED[kind] if not re.search(p, txt)]
    return stale, missing, len(txt)


if __name__ == "__main__":
    targets = sys.argv[1:] or sorted(glob.glob("manuscript/*.docx"))
    for p in targets:
        if not os.path.exists(p):
            print(f"MISSING FILE   {p}")
            continue
        stale, missing, n = audit(p)
        tag = "OK  " if not stale and not missing else "FAIL"
        print(f"[{tag}] {p}  (chars={n})")
        if stale:
            print(f"         stale   : {stale}")
        if missing:
            print(f"         missing : {missing}")
