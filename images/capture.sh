#!/bin/bash
# MacShortcutBall 真实截图指引
# 前提：已打开 MacShortcutBall.app，悬浮球可见
#
# 方式一（推荐，手动精准）：用 ⇧⌘4 框选目标区域，保存到 images/ 对应文件名
# 方式二（命令行区域截图）：screencapture -R<x,y,w,h> images/demo-ball.png
#
# 请把以下 4 张截图保存到 images/ 目录：
echo "请截取并保存到 images/："
echo "  demo-ball.png     屏幕右侧悬浮球常态"
echo "  demo-search.png   点球后搜索面板，输入「截屏」命中多条"
echo "  demo-online.png   输入本地没有的词，显示「在线搜索 Mac 快捷键」"
echo "  demo-menubar.png  菜单栏放大镜图标 + 右键悬浮球菜单"
echo ""
echo "导出后，把 README.md 中『截图演示』里的 .svg 改成对应的 .png 即可。"
