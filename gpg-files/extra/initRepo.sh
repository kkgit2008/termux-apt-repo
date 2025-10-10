#!/data/data/com.itsaky.androidide/files/usr/bin/sh
set -e
# 注释掉官方默认源
sed -i 's/^[^#].*termux\.org/#&/' "$PREFIX/etc/apt/sources.list"
echo "deb [trusted=yes] https://github.com/kkgit2008/termux-apt-repo/raw/main/gpg-files stable main" > "$PREFIX/etc/apt/sources.list.d/androide-repo.list"
#pkg update
echo "✅ 完成，可安装：pkg install <包名>"
