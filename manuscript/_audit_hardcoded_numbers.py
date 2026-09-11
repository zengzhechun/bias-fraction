#!/usr/bin/env python3
"""List every numeric literal written directly into qmd prose.

Numbers inside inline R (`` `r ...` ``) or fenced code blocks are computed from
v39_all_numbers.json and update themselves. Numbers typed into prose do not: they
are the ones that rot when the data changes (eg "six pre-specified subgroups"
after the K=50 level was added, or "2 negative-control outcomes" where K is a
count, not a level count).

This script strips both inline R and code blocks, then reports what is left so
each can be checked by eye against the source data.
"""
import re, sys, glob, os

NUM = re.compile(r"(?<![\w.$-])(\d[\d,]*(?:\.\d+)?)(?![\w])")


def prose_only(src: str) -> str:
    """Remove fenced code blocks and inline R, keeping paragraph structure."""
    out = []
    in_block = False
    for line in src.split("\n"):
        if re.match(r"^\s*```", line):
            in_block = not in_block
            out.append("")
            continue
        if in_block:
            out.append("")
            continue
        out.append(re.sub(r"`r [^`]*`", "\x00", line))
    return "\n".join(out)


def scan(path: str):
    src = open(path, encoding="utf-8").read()
    lines = prose_only(src).split("\n")
    hits = []
    for i, line in enumerate(lines, 1):
        if not line.strip() or line.lstrip().startswith("#"):
            # keep headings out: they carry table/figure numbers only
            continue
        for m in NUM.finditer(line):
            # context window, with the match marked
            a = max(0, m.start() - 60)
            b = min(len(line), m.end() + 60)
            ctx = line[a:m.start()] + "[" + m.group(1) + "]" + line[m.end():b]
            hits.append((i, m.group(1), " ".join(ctx.split())))
    return hits


if __name__ == "__main__":
    targets = sys.argv[1:] or sorted(glob.glob("manuscript/*.qmd"))
    for p in targets:
        if ".bak" in p or not os.path.exists(p):
            continue
        hits = scan(p)
        print("=" * 78)
        print(f"{os.path.basename(p)}  ({len(hits)} numeric literals in prose)")
        print("=" * 78)
        for ln, val, ctx in hits:
            print(f"  L{ln:<5} {val:<12} {ctx[:118]}")
        print()
