#!/bin/zsh
# 生成第40版 JAMA 投稿用的横向版 docx（两份正文），放进独立目录。
#
# 为什么必须重新渲染：
#   `_render_v40_all.sh` 的最后一步是 `_post_portrait_for_coauthor.py`，它把
#   `w:orient="landscape"` 的 sectPr 整段剥掉。所以工作位的 docx 里已经没有横向节，
#   直接对它们跑 `_post_landscape_jama.py` 只会打印 "no landscape sectPr found"。
#
# 铁律：
#   · 横向版只用于上传，绝不放进腾讯文档编辑器打开（编辑器会静默截断其后内容）
#   · 横向 与 纵向 是互斥的两套后处理，绝不对同一个文件都跑
#   · 工作位的纵向 docx 必须原样还原（本脚本先备份、后还原，md5 不变）
set -u

export PATH="/Library/Frameworks/R.framework/Resources/bin:/Applications/quarto/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

ROOT="/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第40版"
MD="$ROOT/manuscript"
SUB="$ROOT/Submit/JAMA Network Open/manuscript/landscape_SUBMISSION_20260917"
BAK="$ROOT/manuscript/_portrait_backup_$$"
PY=/usr/local/bin/python3

mkdir -p "$SUB" "$BAK"
cd "$MD" || exit 1

echo "===== 横向投稿版生成 $(date '+%F %T') ====="
fail=0
for stem in manuscript_jama_v40 jama-V40-缩写版; do
  echo "---- $stem ----"
  cp "$stem.docx" "$BAK/$stem.docx" || { fail=1; continue; }
  md5_before=$(md5 -q "$stem.docx")

  /Applications/quarto/bin/quarto render "$stem.qmd" --to docx 2>&1 | tail -2
  [ -f "$stem.docx" ] || { echo "!! 渲染失败"; fail=1; continue; }

  $PY _post_format_jama.py "$stem.docx" 2>&1 | tail -1
  $PY _post_bold_abstract.py "$stem.docx" 2>&1 | tail -1
  n=$($PY _word_count_jama.py "$stem.docx" | sed -n 's/^body word count: \([0-9]*\).*/\1/p')
  if [ -n "$n" ]; then
    echo "   正文 $n 词"
    $PY _set_word_count.py "$stem.docx" "$n" 2>&1 | tail -1
  else
    echo "!! 量不到字数"; fail=1
  fi
  $PY _post_landscape_jama.py "$stem.docx" 2>&1 | tail -2

  mv "$stem.docx" "$SUB/$stem.docx"
  cp "$BAK/$stem.docx" "$stem.docx"
  md5_after=$(md5 -q "$stem.docx")
  if [ "$md5_before" = "$md5_after" ]; then
    echo "   工作位纵向版已还原，md5 $md5_before 不变"
  else
    echo "!! 工作位还原异常 $md5_before -> $md5_after"; fail=1
  fi
done

rm -rf "$BAK"
echo "===== 结束 $(date '+%F %T')  fail=$fail ====="
ls -la "$SUB"
