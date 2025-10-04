#!/data/data/com.termux/files/usr/bin/sh
echo ">>>start update.sh"

set -e
POOL="pool"
DIST="dists/stable"
#ARCHS="aarch64 arm i686 x86_64"
ARCHS="aarch64"

rm -rf "$DIST"
mkdir -p "$DIST"/{main,bootstrap}

echo ">>>start write file Packages"

# --- 开始使用最终、最终修正版的逻辑 ---

# 1. 首先，为所有架构生成一个临时的、完整的 Packages 文件
#    我们把它放在 DIST 目录下，命名为 Packages.all
echo "  Generating temporary full Packages file..."
../../../files/usr/bin/apt-repo "$POOL" > "$DIST/Packages.all"

# 2. 然后，为每个指定的架构，从完整文件中筛选并生成对应的 Packages 文件
for arch in $ARCHS; do
    out="$DIST/main/binary-$arch"
    mkdir -p "$out"
    echo "  Processing architecture: $arch"

    # 使用 awk 从完整文件中提取指定架构的包信息块
    # 这是一个专门处理 Debian Packages 格式的健壮 awk 脚本
    awk -v arch="$arch" '
        BEGIN { in_block = 0; print_block = 0 }

        # 当遇到一个空行时，说明一个包信息块结束了
        /^$/ {
            if (in_block) {
                in_block = 0
                if (print_block) {
                    print ""  # 打印一个空行来分隔包
                }
                print_block = 0
            }
            next
        }

        # 对于非空行，我们处于一个包信息块中
        { in_block = 1 }

        # 检查当前块的 Architecture 字段
        $1 == "Architecture:" && $2 == arch {
            print_block = 1
        }

        # 如果标记为需要打印，则打印当前行
        print_block {
            print $0
        }
    ' "$DIST/Packages.all" > "$out/Packages"

    # 压缩生成 Packages.gz
    gzip -9 -c "$out/Packages" > "$out/Packages.gz"

    echo "  - Packages file size: $(stat -c%s "$out/Packages") bytes"
    echo "  - Packages.gz file size: $(stat -c%s "$out/Packages.gz") bytes"
done

# 清理临时文件
rm "$DIST/Packages.all"

# --- 最终、最终修正版逻辑结束 ---

echo ">>>end write file Packages"

echo ">>>start write file Release"

# Release 文件（关键修复：Components 只保留 main，与你的 Packages 路径匹配）
cat > "$DIST/Release" <<EOR
Origin: MyTermuxRepo
Label: MyTermuxRepo
Suite: stable
Version: 1.0
Codename: stable
Date: $(date -Ru)
Architectures: $ARCHS
Components: main
Description: Custom Termux Repository (main component only)
EOR

echo ">>>start sha"

echo "SHA256:" >> "$DIST/Release"
find "$DIST" -type f -name "Packages" -o -name "Packages.gz" | sort | \
xargs -I{} sh -c '
    sha=$(sha256sum "$1" | cut -d" " -f1)
    size=$(stat -c%s "$1")
    path=$(printf "%s\n" "$1" | sed "s|^$2/||")
    echo " $sha $size $path"
' sh {} "$DIST" >> "$DIST/Release"

echo "SHA1:" >> "$DIST/Release"
find "$DIST" -type f -name "Packages" -o -name "Packages.gz" | sort | \
xargs -I{} sh -c '
    sha=$(sha1sum "$1" | cut -d" " -f1)
    size=$(stat -c%s "$1")
    path=$(printf "%s\n" "$1" | sed "s|^$2/||")
    echo " $sha $size $path"
' sh {} "$DIST" >> "$DIST/Release"

echo "Hash: SHA256" >> "$DIST/Release"

echo ">>>start gpg"

KEYID=$(gpg --list-secret-keys --keyid-format LONG | awk '/^sec/ {print $2}' | cut -d/ -f2 | head -n1)
[ -n "$KEYID" ] && {
  gpg -abs -u "$KEYID" -o "$DIST/Release.gpg" "$DIST/Release"
  gpg --clearsign -u "$KEYID" -o "$DIST/InRelease" "$DIST/Release"
}
echo ">>>end update.sh"

echo "✅ 索引 & 签名完成"
