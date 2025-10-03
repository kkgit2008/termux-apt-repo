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
    # 只扫描 ≤20 MiB 的 deb（大块已合并）
    find "$POOL" -name '*.deb' -size -20M | xargs apt-repo | \
      awk -v ARCH="$arch" '
        /^Package:/     {pkg=$2}
        /^Version:/     {ver=$2}
        /^Architecture:/{arc=$2}
        /^$/ && pkg && arc==ARCH {
          print "Package:", pkg
          print "Version:", ver
          print "Architecture:", arc
          print "Filename:", fn
          print "Size:", sz
          print "MD5sum:", md5
          print "SHA1:", sha1
          print "SHA256:", sha256
          print ""
        }
        /^Filename:/    {fn=$2}
        /^Size:/        {sz=$2}
        /^MD5sum:/      {md5=$2}
        /^SHA1:/        {sha1=$2}
        /^SHA256:/      {sha256=$2}' \
    > "$out/Packages"
    gzip -9 -c "$out/Packages" > "$out/Packages.gz"
done

# Release
cat > "$DIST/Release" <<EOR
Origin: TermuxRepo
Label: TermuxRepo
Suite: stable
Version: 1.0
Codename: stable
Date: $(date -Ru)
Architectures: $ARCHS
Components: main bootstrap
EOR
find "$DIST" -name Packages -o -name Packages.gz | sort | \
xargs -I{} sh -c 'echo " $(sha256sum {} | cut -d" " -f1) $(stat -c%s {}) {}"' \
>> "$DIST/Release"

# 签名
KEYID=$(gpg --list-secret-keys --keyid-format LONG | awk '/^sec/ {print $2}' | cut -d/ -f2)
gpg -abs -u "$KEYID" -o "$DIST/Release.gpg" "$DIST/Release"
gpg --clearsign -u "$KEYID" -o "$DIST/InRelease" "$DIST/Release"
echo "✅ 索引 & 签名完成"
