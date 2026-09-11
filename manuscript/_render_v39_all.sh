#!/bin/zsh
# 渲染第39版全部六份 Word 稿件 + 后处理（双写用纵向版）
#
# 铁律：
#   · qmd 是唯一信源，docx 是渲染产物，改稿只改 qmd
#   · 必须显式 --to docx，且原地渲染（不加 --output-dir）
#   · 渲染后跑 _post_format_jama.py -> _post_bold_abstract.py
#   · 双写版再跑 _post_portrait_for_coauthor.py（纵向）；投稿版跑 _post_landscape_jama.py
#     两者绝不对同一个文件都跑
#   · 判据 = mtime + 锚点齐全，退出码不可信
set -u

export PATH="/Library/Frameworks/R.framework/Resources/bin:/Applications/quarto/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

MD="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版/manuscript"
cd "$MD" || exit 1

QMD=(manuscript_jama_v39.qmd manuscript_medarchive_v39.qmd manuscript_v39.qmd
     supplementary_jama_v39.qmd supplementary_medarchive_v39.qmd supplementary_v39.qmd)

echo "===== 第39版渲染开始 $(date '+%F %T') ====="
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

echo "---- 后处理：JAMA 正稿样式 ----"
/usr/local/bin/python3 _post_format_jama.py
/usr/local/bin/python3 _post_bold_abstract.py

echo "---- 后处理：纵向（双写版），逐份 ----"
for q in $QMD; do
  docx="${q%.qmd}.docx"
  [ -f "$docx" ] || continue
  /usr/local/bin/python3 _post_portrait_for_coauthor.py "$docx" 2>&1 | tail -2
done

echo "===== 第39版渲染结束 $(date '+%F %T')  fail=$fail ====="
