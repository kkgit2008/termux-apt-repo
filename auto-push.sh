#!/data/data/com.termux/files/usr/bin/sh
while ! git push origin main --force-with-lease; do
  echo ">>> 连接中断，10 秒后重试 ..."
  sleep 10
done
