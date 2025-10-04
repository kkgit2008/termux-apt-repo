#!/data/data/com.termux/files/usr/bin/sh
echo ">>>start update.sh"

set -e
POOL="pool"
DIST="dists/stable"
#ARCHS="aarch64 arm i686 x86_64"
ARCHS="aarch64"

rm -rf "$DIST"
mkdir -p "$DIST"/{main,bootstrap}

# 更健壮的 awk 脚本来生成 Packages 文件
# 它会在每个包信息块之间自动添加空行
# --- 开始替换 ---

echo ">>>start write file Packages"

for arch in $ARCHS; do
    out="$DIST/main/binary-$arch"
    mkdir -p "$out"
    echo "  Processing architecture: $arch"

    # 使用一个极简的 awk 脚本来过滤包
    # 它会：
    # 1. 逐行读取 apt-repo 的输出。
    # 2. 当遇到 "Architecture: <目标架构>" 时，标记接下来的行 需要保留。
    # 3. 当标记为“保留”时，打印该行。
    # 4. 当遇到一个空行时，说明一个包的信息块结束，重置标记。
    ../../../files/usr/bin/apt-repo pool | awk -v target_arch="$arch" '
        /^[^ ]/ { hdr=$0 }          # 非空行先存起来
        /^Architecture:[ \t]*"'"$arch"'"/ { print hdr; print; while ((getline)>0 && !/^$/) print; print "" }
    ' > "$out/Packages"

    # 压缩生成 Packages.gz
    gzip -9 -c "$out/Packages" > "$out/Packages.gz"

    # 打印日志，方便确认文件是否生成以及大小是否合理
    echo "  - Packages file size: $(stat -c%s "$out/Packages") bytes"
    echo "  - Packages.gz file size: $(stat -c%s "$out/Packages.gz") bytes"

done

echo ">>>end write file Packages"

# --- 替换结束 ---


echo ">>>start write file Release"

# Release 文件（关键修复：Components 只保留 main，与 Packages 路径匹配）
cat > "$DIST/Release" <<EOR
Origin: MyTermuxRepo
Label: MyTermuxRepo
Suite: stable
Version: 1.0
Codename: stable
Date: $(date -Ru)
Architectures: $ARCHS
Components: main  # 关键修复！只写 main，因为 Packages 在 main 目录下
# 明确指定 Packages 文件路径格式（可选，但能帮助 apt 识别）
Description: Custom Termux Repository (main component only)
EOR

# 追加校验和（这部分不变，但必须确保能扫描到正确路径的 Packages）
echo ">>>start sha"

# 使用 printf 来正确传递 DIST 变量到子 shell
# 1. 大写 SHA256 段落
echo "SHA256:" >> "$DIST/Release"
find "$DIST" -type f -name "Packages" -o -name "Packages.gz" | sort | \
xargs -I{} sh -c '
    sha=$(sha256sum "$1" | cut -d" " -f1)
    size=$(stat -c%s "$1")
    # 使用 printf 来安全地进行字符串替换
    path=$(printf "%s\n" "$1" | sed "s|^$2/||")
    echo " $sha $size $path"
' sh {} "$DIST" >> "$DIST/Release"

# 2. 大写 SHA1 段落
echo "SHA1:" >> "$DIST/Release"
find "$DIST" -type f -name "Packages" -o -name "Packages.gz" | sort | \
xargs -I{} sh -c '
    sha=$(sha1sum "$1" | cut -d" " -f1)
    size=$(stat -c%s "$1")
    path=$(printf "%s\n" "$1" | sed "s|^$2/||")
    echo " $sha $size $path"
' sh {} "$DIST" >> "$DIST/Release"

echo "Hash: SHA256" >> "$DIST/Release"
# ===== 结束 =====


echo ">>>start gpg"

# 签名（需要时自动）
KEYID=$(gpg --list-secret-keys --keyid-format LONG | awk '/^sec/ {print $2}' | cut -d/ -f2 | head -n1)
[ -n "$KEYID" ] && {
  gpg -abs -u "$KEYID" -o "$DIST/Release.gpg" "$DIST/Release"
  gpg --clearsign -u "$KEYID" -o "$DIST/InRelease" "$DIST/Release"
}
echo ">>>end update.sh"

echo "✅ 索引 & 签名完成"
