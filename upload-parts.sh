#!/data/data/com.termux/files/usr/bin/sh
set -e
cd ~/termux-apt-repo
parts=$(find pool -name '*.deb.part-*' | sort)
for f in $parts; do
  echo ">>> 上传 $f"
  git add "$f"
  git commit -m "add $(basename "$f")"
  timeout 150 git push origin main  # 2分30秒超时
  [ $? -eq 0 ] && echo "$f 完成" || echo "$f 超时，继续下一块"
done
echo ">>> 所有块传完，开始合并"
# 按原始文件名合并
find pool -name '*.deb.part-00' | while read p; do
  deb=${p%.part-00}
  cat "${deb}.part-"* > "$deb"
  git add "$deb"
done
git commit -m "merge all large debs"
git push origin main
