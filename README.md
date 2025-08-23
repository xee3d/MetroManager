# MetroManager

React Native/Expo Metro 서버를 관리하는 macOS 네이티브 앱입니다.

## 🚀 주요 기능

### 📱 **Metro 서버 관리**
- **Expo** 및 **React Native CLI** 프로젝트 자동 감지 (정확도 대폭 향상)
- 포트 충돌 자동 해결 (8081 → 8082, 8083...)
- Metro 서버 시작/중지/재시작
- 실시간 로그 모니터링

### 🎯 **Metro 단축키 시스템**
- **기본 단축키** (모든 프로젝트):
  - `r` - 앱 리로드
  - `i` - iOS 시뮬레이터에서 앱 실행
  - `a` - Android 에뮬레이터에서 앱 실행
  - `d` - 개발자 메뉴 열기
  - `j` - 디버그 모드 토글
  - `m` - 메뉴 열기

- **Expo 전용 단축키** (Expo 프로젝트에서만 표시):
  - `w` - 웹 브라우저에서 앱 실행
  - `c` - 캐시 및 로그 정리
  - `s` - Expo Go로 앱 전송
  - `t` - 터널 모드로 연결
  - `l` - LAN 모드로 연결
  - `o` - localhost 모드로 연결
  - `u` - URL 정보 표시
  - `h` - 도움말 표시
  - `v` - 버전 정보 표시
  - `q` - Expo 서버 종료

### 🔍 **외부 프로세스 감지**
- 다른 터미널에서 실행 중인 Metro 서버 자동 감지
- 포트 스캔을 통한 활성 서버 탐지
- 프로젝트 이름과 경로 자동 추출
- "좀비" 프로세스 자동 정리

### 🎨 **사용자 경험**
- 직관적인 SwiftUI 인터페이스
- 프로젝트별 상세 정보 표시
- 터미널 통합 (기존 창에 새 탭으로 열기)
- 콘솔 텍스트 크기 조절
- 성능 최적화 (30초 간격 백그라운드 모니터링)
- Expo 프로젝트 타입별 조건부 UI 표시

## 📦 설치 및 실행

### 🎯 **배포용 앱 실행**
```bash
# 앱 다운로드 후 실행
open MetroManager-Release.app
```

### 🔧 **개발용 빌드**
```bash
# 프로젝트 클론
git clone <repository-url>
cd MetroManager

# Xcode로 빌드
xcodebuild -project MetroManager.xcodeproj -scheme MetroManager -configuration Debug build

# 앱 실행
open /Users/ethanchoi/Library/Developer/Xcode/DerivedData/MetroManager-*/Build/Products/Debug/MetroManager.app
```

## 🛠️ 시스템 요구사항

- **macOS**: 13.0 이상
- **아키텍처**: Apple Silicon (ARM64) / Intel (x86_64)
- **의존성**: Node.js, npm/yarn/pnpm (Metro 실행용)

## 📋 사용법

### 1. **프로젝트 추가**
- "프로젝트 추가" 버튼 클릭
- 프로젝트 경로 선택
- Expo 또는 React Native CLI 자동 감지 (정확도 향상)

### 2. **Metro 서버 시작**
- 프로젝트 선택 후 "시작" 버튼 클릭
- 포트 충돌 시 자동으로 다른 포트 사용
- 실시간 로그 확인 가능

### 3. **단축키 사용**
- 프로젝트가 실행 중일 때 단축키 버튼들 표시
- Expo 프로젝트인 경우 추가 단축키 버튼들 표시
- 원하는 기능의 버튼 클릭하여 실행

### 4. **외부 프로세스 감지**
- 돋보기 버튼으로 실행 중인 Metro 서버 감지
- 쓰레기통 버튼으로 죽은 프로세스 정리

### 5. **터미널 연동**
- 터미널 버튼으로 프로젝트 디렉토리 열기
- 기존 터미널 창에 새 탭으로 열림

## 🔧 기술 스택

- **언어**: Swift 5
- **UI 프레임워크**: SwiftUI
- **아키텍처**: MVVM (ObservableObject)
- **빌드 도구**: Xcode 16
- **타겟**: macOS 13.0+

## 📊 성능 최적화

- **백그라운드 모니터링**: 30초 간격 (시스템 부하 최소화)
- **외부 프로세스 스캔**: 필요시에만 실행
- **메모리 사용량**: < 1MB
- **앱 크기**: ~988KB

## 🎨 앱 아이콘

Claude 코드 스타일의 도트 텍스트 형식 아이콘 사용

## 📝 라이선스

개인 및 상업적 사용 가능

## 🤝 기여

버그 리포트 및 기능 제안 환영합니다!

---

**MetroManager v1.1.0** - React Native 개발을 더욱 편리하게! 🚀

*Expo 프로젝트 감지 정확도와 단축키 기능이 대폭 개선되었습니다.*
