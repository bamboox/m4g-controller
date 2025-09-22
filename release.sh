#!/bin/bash

# Android 4G 远程控制应用发布脚本
# 由 Qoder 完成

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的输出
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [ $# -eq 0 ]; then
    print_error "请提供版本号作为参数"
    echo "用法: $0 <版本号>"
    echo "示例: $0 v1.0.0"
    exit 1
fi

VERSION=$1

# 检查版本号格式
if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "版本号格式不正确，应为 vX.Y.Z 格式"
    echo "示例: v1.0.0"
    exit 1
fi

print_info "开始发布版本: $VERSION"

# 检查是否有未提交的更改
if ! git diff-index --quiet HEAD --; then
    print_warning "检测到未提交的更改"
    read -p "是否继续？ [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消发布"
        exit 0
    fi
fi

# 更新版本信息
print_info "更新版本信息..."

# 从版本号提取数字
VERSION_NAME=${VERSION#v}  # 移除 v 前缀
VERSION_CODE=$(echo $VERSION_NAME | sed 's/\.//g')  # 移除点号作为版本代码

# 更新 build.gradle.kts 中的版本信息
sed -i.bak "s/versionCode = [0-9]*/versionCode = ${VERSION_CODE}/" app/build.gradle.kts
sed -i.bak "s/versionName = \"[^\"]*\"/versionName = \"${VERSION_NAME}\"/" app/build.gradle.kts

print_success "版本信息已更新为 ${VERSION_NAME} (${VERSION_CODE})"

# 清理并构建
print_info "清理项目..."
./gradlew clean

print_info "构建 APK..."
./gradlew assembleDebug assembleRelease

# 检查构建结果
if [ ! -f "app/build/outputs/apk/release/app-release.apk" ]; then
    print_error "Release APK 构建失败"
    exit 1
fi

if [ ! -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    print_error "Debug APK 构建失败"
    exit 1
fi

print_success "APK 构建完成"

# 提交更改
print_info "提交版本更改..."
git add app/build.gradle.kts
git commit -m "chore: bump version to $VERSION" || true

# 创建并推送标签
print_info "创建 Git 标签..."
git tag -a $VERSION -m "Release $VERSION

## 🚀 功能特性
- 通过MQTT协议远程控制Android设备4G网络
- 无需root权限，使用Shizuku和无障碍服务
- 支持自动重连和状态监控

## 📦 下载文件
- app-release.apk: 正式版本，推荐生产环境使用
- app-debug.apk: 调试版本，用于开发测试

## 📋 安装要求
- Android 7.0+ (API 24)
- 需要开启无障碍服务权限
- 建议安装Shizuku以获得更好的权限管理"

print_info "推送标签到远程仓库..."
git push origin $VERSION

print_success "标签 $VERSION 已推送，GitHub Actions 将自动构建并创建 Release"

# 显示构建输出信息
print_info "构建输出文件："
echo "  Debug APK:   app/build/outputs/apk/debug/app-debug.apk"
echo "  Release APK: app/build/outputs/apk/release/app-release.apk"

print_info "请访问 GitHub Actions 页面查看构建进度："
echo "  https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\([^/]*\/[^/]*\)\.git/\1/')/actions"

print_success "发布流程完成！"