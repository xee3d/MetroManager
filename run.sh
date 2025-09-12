#!/bin/bash

# MetroManager 실행 스크립트
# 개발용 빌드 후 앱을 실행합니다.

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

print_step "MetroManager를 빌드하고 실행합니다..."

# 기존 빌드 정리
print_step "기존 빌드 정리 중..."
rm -rf build

# Debug 빌드
print_step "Debug 빌드 시작..."
xcodebuild \
    -project MetroManager.xcodeproj \
    -scheme MetroManager \
    -configuration Debug \
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

print_success "앱을 실행합니다: $APP_FILE"
open "$APP_FILE"

print_success "🎉 MetroManager가 실행되었습니다!"

