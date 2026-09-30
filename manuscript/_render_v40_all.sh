#!/bin/zsh
# 渲染第40版全部七份 Word 稿件 + 后处理（双写用纵向版）
#
# 铁律：
#   · qmd 是唯一信源，docx 是渲染产物，改稿只改 qmd
#   · 必须显式 --to docx，且原地渲染（不加 --output-dir）
#   · 渲染后逐份跑 _post_format_jama.py -> _post_bold_abstract.py
#     JAMA 两份再跑 _word_count_jama.py 量字数 -> _set_word_count.py 写回末行
#     （Word Count 行不在 qmd 里，每次渲染都会被抹掉，必须重注入）
#   · 双写版最后跑 _post_portrait_for_coauthor.py（纵向，剥掉横向节）
#     投稿横向版另行用 _post_landscape_jama.py 生成，仅上传、不给编辑器打开
#   · 判据 = mtime + 锚点齐全，退出码不可信
set -u

export PATH="/Library/Frameworks/R.framework/Resources/bin:/Applications/quarto/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

MD="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第40版/manuscript"
cd "$MD" || exit 1

PY=/usr/local/bin/python3
QMD=(manuscript_jama_v40.qmd jama-V40-缩写版.qmd
     manuscript_medarchive_v40.qmd manuscript_v40.qmd
     supplementary_jama_v40.qmd supplementary_medarchive_v40.qmd supplementary_v40.qmd)
# 需要写 Word Count 行的（JAMA 轨正文两份）
WC=(manuscript_jama_v40.docx jama-V40-缩写版.docx)

echo "===== 第40版渲染开始 $(date '+%F %T') ====="
fail=0
for q in $QMD; do
  echo "---- quarto render $q ----"
  /Applications/quarto/bin/quarto render "$q" --to docx 2>&1 | tail -6
  docx="${q%.qmd}.docx"
  if [ ! -f "$docx" ]; then
    echo "!! 未生成 $docx"; fail=1; continue
  fi
  echo "   生成 $(stat -f '%Sm' -t '%H:%M:%S' "$docx")  $(stat -f '%z' "$docx") 字节"
done

echo "---- 后处理：样式 + 摘要加粗（逐份） ----"
for q in $QMD; do
  docx="${q%.qmd}.docx"
  [ -f "$docx" ] || continue
  $PY _post_format_jama.py "$docx" 2>&1 | tail -2
  $PY _post_bold_abstract.py "$docx" 2>&1 | tail -1
done

echo "---- 后处理：Word Count 行（JAMA 正文两份） ----"
for docx in $WC; do
  [ -f "$docx" ] || { echo "!! 缺 $docx"; fail=1; continue; }
  n=$($PY _word_count_jama.py "$docx" | sed -n 's/^body word count: \([0-9]*\).*/\1/p')
  if [ -z "$n" ]; then echo "!! 量不到 $docx 字数"; fail=1; continue; fi
  echo "   $docx 正文 $n 词"
  $PY _set_word_count.py "$docx" "$n"
done

echo "---- 后处理：纵向（双写版），逐份剥横向节 ----"
for q in $QMD; do
  docx="${q%.qmd}.docx"
  [ -f "$docx" ] || continue
  $PY _post_portrait_for_coauthor.py "$docx" 2>&1 | tail -2
done

echo "===== 第40版渲染结束 $(date '+%F %T')  fail=$fail ====="
