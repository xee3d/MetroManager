#!/bin/bash

# MetroManager 빌드 스크립트
# 릴리즈용 앱을 빌드합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 현재 디렉토리 확인
if [ ! -f "MetroManager.xcodeproj/project.pbxproj" ]; then
    print_error "MetroManager.xcodeproj를 찾을 수 없습니다. 올바른 디렉토리에서 실행해주세요."
    exit 1
fi

print_step "MetroManager 릴리즈 빌드를 시작합니다..."

# 기존 빌드 정리
print_step "기존 빌드 정리 중..."
rm -rf build release

# 릴리즈 빌드
print_step "릴리즈 빌드 시작..."
xcodebuild \
    -project MetroManager.xcodeproj \
    -scheme MetroManager \
    -configuration Release \
    -derivedDataPath build \
    build

if [ $? -eq 0 ]; then
    print_success "빌드 완료"
else
    print_error "빌드 실패"
    exit 1
fi

# 앱 파일 찾기
APP_FILE=$(find build -name "MetroManager.app" -type d | head -n 1)
if [ -z "$APP_FILE" ]; then
    print_error "앱 파일을 찾을 수 없습니다."
    exit 1
fi

# 릴리즈 디렉토리에 복사
print_step "릴리즈 디렉토리에 복사 중..."
mkdir -p release
cp -R "$APP_FILE" release/

# 앱 크기 확인
APP_SIZE=$(du -sh "release/MetroManager.app" | cut -f1)
print_success "앱 크기: $APP_SIZE"

print_success "🎉 MetroManager 릴리즈 빌드가 완료되었습니다!"
echo ""
echo "📦 배포 파일: release/MetroManager.app"
echo "🚀 앱을 실행하려면:"
echo "   open release/MetroManager.app"

