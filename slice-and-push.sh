#!/data/data/com.termux/files/usr/bin/sh
set -e
cd ~/termux-apt-repo
# 1. 切分 >20M 的 deb
find pool -name '*.deb' -size +20M -print0 | while IFS= read -r -d '' f; do
  [ -f "${f}.part-00" ] && continue
  echo ">>> 切分 $f"
  split -b 20M -d "$f" "${f}.part-"
  mv "$f" "${f}.bak"                 # 原文件移出仓库
done
# 2. 只传小块（断点续传）
parts=$(find pool -name '*.deb.part-*' | sort)
for p in $parts; do
  git add "$p"
  git commit -m "add $(basename "$p")"
  timeout 150 git push origin main --force-with-lease || true
done
# 3. 本地合并成原 deb
find pool -name '*.deb.part-00' | while read p; do
  deb=${p%.part-00}
  cat "${deb}.part-"* > "$deb"
  git add "$deb"
done
git commit -m "merge large debs"
git push origin main --force-with-lease
