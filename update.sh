#!/data/data/com.termux/files/usr/bin/sh
set -e
POOL="pool"
DIST="dists/stable"
ARCHS="aarch64 arm i686 x86_64"

rm -rf "$DIST"
mkdir -p "$DIST"/{main,bootstrap}

for arch in $ARCHS; do
    out="$DIST/main/binary-$arch"
    mkdir -p "$out"
    apt-repo "$POOL" | grep -E "^(Package|Version|Architecture|Filename|Size|MD5sum|SHA1|SHA256):" | \
    awk -v arch="$arch" '$1=="Architecture:" && $2==arch {flag=1; print; next}
                        flag && /^[A-Z]/              {print}
                        flag && /^$/                   {print; flag=0}' \
    > "$out/Packages"
    gzip -9 -c "$out/Packages" > "$out/Packages.gz"
done

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

# 追加校验和
find "$DIST" -name Packages -o -name Packages.gz | sort | \
xargs -I{} sh -c 'echo " $(sha256sum {} | cut -d" " -f1) $(stat -c%s {}) {}"' \
>> "$DIST/Release"

# 签名（需要时自动）
KEYID=$(gpg --list-secret-keys --keyid-format LONG | awk '/^sec/ {print $2}' | cut -d/ -f2 | head -n1)
[ -n "$KEYID" ] && {
  gpg -abs -u "$KEYID" -o "$DIST/Release.gpg" "$DIST/Release"
  gpg --clearsign -u "$KEYID" -o "$DIST/InRelease" "$DIST/Release"
}
echo "✅ 索引 & 签名完成"
