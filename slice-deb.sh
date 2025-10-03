#!/data/data/com.termux/files/usr/bin/sh
set -e
cd ~/termux-apt-repo
# 找出所有 ≥20 MiB 的 deb
find pool -name '*.deb' -size +20M -print0 | while IFS= read -r -d '' f; do
    base="$f"
    # 如果已经切过，跳过
    [ -f "${base}.part-00" ] && continue
    echo ">>> 切分 $f"
    split -b 20M -d "$f" "${base}.part-"
    # 把原大文件移出仓库目录（避免误 add）
    mv "$f" "${f}.bak"
done
echo "✅ 所有 ≥20 MiB 的 deb 已切为 *.part-XX 小块"
