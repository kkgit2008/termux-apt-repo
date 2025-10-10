#!/data/data/com.termux/files/usr/bin/bash

# 检查 _redirects 文件是否存在
if [ ! -f "_redirects" ]; then
    echo "Error: _redirects file not found!"
    exit 1
fi

# 读取 _redirects 文件，逐行生成 HTML 重定向文件
while IFS=' ' read -r source_path target_url status_code; do
    # 跳过空行和注释行
    if [[ -z "$source_path" || "$source_path" == "#"* ]]; then
        continue
    fi

    # 构造 HTML 文件路径（去掉源路径的前缀，在本地创建对应目录）
    # 例如：/raw/main/gpg-files/glib.deb → raw/main/gpg-files/glib.deb.html
    html_file="${source_path:1}.html"  # 去掉开头的 "/"，添加 ".html" 后缀
    html_dir=$(dirname "$html_file")   # 获取目录路径（如 raw/main/gpg-files）

    # 创建目录（若不存在）
    mkdir -p "$html_dir"

    # 生成 HTML 重定向文件（3秒自动跳转，兼容所有浏览器）
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Refresh" content="0; URL='$target_url'" />
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Redirecting...</title>
</head>
<body>
    Redirecting to <a href="$target_url">$target_url</a>...
</body>
</html>
EOF

    echo "Generated: $html_file → $target_url"
done < "_redirects"

echo "All redirect HTML files generated successfully!"
