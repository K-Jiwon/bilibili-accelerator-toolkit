#!/bin/zsh
# 双击即可安装（Finder 里双击 .command 文件）
cd "$(dirname "$0")" || exit 1
./install.sh
echo ""
echo "按回车键关闭这个窗口…"
read -r _
