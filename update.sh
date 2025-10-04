#!/data/data/com.termux/files/usr/bin/sh

echo ">>>start update.sh"

set -e
POOL="pool"
DIST="dists/stable"
ARCHS="aarch64 arm i686 x86_64"

rm -rf "$DIST"
mkdir -p "$DIST"/{main,bootstrap}

echo ">>>start write file Packages"

# 修正：使用一个更健壮的 awk 脚本来生成 Packages 文件
# 它会在每个包信息块之间自动添加空行
for arch in $ARCHS; do
    out="$DIST/main/binary-$arch"
    mkdir -p "$out"
    
    # 使用 apt-repo 生成完整的 Packages 流
    # 然后用 awk 按架构过滤，并确保包之间有空行
    apt-repo "$POOL" | awk -v arch="$arch" '
        BEGIN { in_package = 0; found_arch = 0 }
        
        # 当遇到一个新包的开始 (Package: 行)
        $1 == "Package:" {
            # 如果我们之前正在处理一个包，并且它的架构匹配，那么在新包前打印一个空行
            if (in_package && found_arch) {
                print ""
            }
            in_package = 1      # 标记我们进入了一个新包
            found_arch = 0      # 重置架构匹配标志
        }
        
        # 当在一个包内，检查 Architecture 字段
        in_package && $1 == "Architecture:" && $2 == arch {
            found_arch = 1      # 标记当前包的架构匹配
        }
        
        # 如果当前包的架构已匹配，打印所有行
        found_arch {
            print
        }
        
        # 处理文件末尾的情况，确保最后一个包后也有一个空行
        END {
            if (found_arch) {
                print ""
            }
        }
    ' > "$out/Packages"
    
    gzip -9 -c "$out/Packages" > "$out/Packages.gz"
done

echo ">>>start write file Release"

# Release 文件
cat > "$DIST/Release" <<EOR
Origin: MyTermuxRepo
Label: MyTermuxRepo
Suite: stable
Version: 1.0
Codename: stable
Date: $(date -Ru)
Architectures: $ARCHS
Components: main bootstrap
EOR

echo ">>>start sha"

# 追加校验和
# 1. 大写 SHA256 段落（新 apt 必须）
echo "SHA256:" >> "$DIST/Release"
find "$DIST" -name Packages -o -name Packages.gz | sort | \
xargs -I{} sh -c 'echo " $(sha256sum {} | cut -d" " -f1) $(stat -c%s {}) {}"' \
>> "$DIST/Release"

# 2. 大写 SHA1 段落（旧 Termux apt 只认 SHA1）
echo "SHA1:" >> "$DIST/Release"
find "$DIST" -name Packages -o -name Packages.gz | sort | \
xargs -I{} sh -c 'echo " $(sha1sum {} | cut -d" " -f1) $(stat -c%s {}) {}"' \
>> "$DIST/Release"

# 3. 旧 apt 兼容头部（已做，保留）
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
