#!/bin/bash

# MetroManager 릴리즈 빌드 스크립트
# macOS용 배포용 앱을 빌드합니다.

set -e

echo "🚀 MetroManager 릴리즈 빌드를 시작합니다..."

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

# Xcode 버전 확인
print_step "Xcode 버전 확인 중..."
XCODE_VERSION=$(xcodebuild -version | head -n 1)
print_success "Xcode 버전: $XCODE_VERSION"

# 빌드 디렉토리 생성
BUILD_DIR="build"
RELEASE_DIR="release"
print_step "빌드 디렉토리 정리 중..."
rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

# 릴리즈 빌드
print_step "릴리즈 빌드 시작..."
xcodebuild \
    -project MetroManager.xcodeproj \
    -scheme MetroManager \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -archivePath "$BUILD_DIR/MetroManager.xcarchive" \
    archive

if [ $? -eq 0 ]; then
    print_success "아카이브 생성 완료"
else
    print_error "아카이브 생성 실패"
    exit 1
fi

# 앱 내보내기
print_step "앱 내보내기 중..."
xcodebuild \
    -exportArchive \
    -archivePath "$BUILD_DIR/MetroManager.xcarchive" \
    -exportPath "$RELEASE_DIR" \
    -exportOptionsPlist exportOptions.plist

if [ $? -eq 0 ]; then
    print_success "앱 내보내기 완료"
else
    print_error "앱 내보내기 실패"
    exit 1
fi

# 앱 파일 찾기
APP_FILE=$(find "$RELEASE_DIR" -name "*.app" -type d | head -n 1)
if [ -z "$APP_FILE" ]; then
    print_error "앱 파일을 찾을 수 없습니다."
    exit 1
fi

# 앱 크기 확인
APP_SIZE=$(du -sh "$APP_FILE" | cut -f1)
print_success "앱 크기: $APP_SIZE"

# 앱 정보 출력
print_step "앱 정보:"
echo "  - 경로: $APP_FILE"
echo "  - 크기: $APP_SIZE"
echo "  - 아키텍처: $(file "$APP_FILE/Contents/MacOS/MetroManager" | grep -o 'x86_64\|arm64')"

# 코드 서명 확인
print_step "코드 서명 확인 중..."
if codesign -dv "$APP_FILE" 2>&1 | grep -q "signed"; then
    print_success "코드 서명 확인됨"
else
    print_warning "코드 서명되지 않음 (개발용 빌드)"
fi

# 최종 정리
print_step "빌드 정리 중..."
rm -rf "$BUILD_DIR"

print_success "🎉 MetroManager 릴리즈 빌드가 완료되었습니다!"
echo ""
echo "📦 배포 파일: $APP_FILE"
echo "📋 릴리즈 노트: RELEASE_NOTES.md"
echo ""
echo "🚀 앱을 실행하려면:"
echo "   open \"$APP_FILE\""





