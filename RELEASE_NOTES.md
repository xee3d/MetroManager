# MetroManager v1.1.0 - 릴리즈 노트

## 🎉 새로운 기능 업데이트

**릴리즈 날짜**: 2024년 12월  
**버전**: v1.1.0  
**플랫폼**: macOS 13.0+  
**아키텍처**: Apple Silicon (ARM64) / Intel (x86_64)

---

## 🚀 주요 개선사항

### 🔍 **Expo 프로젝트 감지 정확도 대폭 향상**
- **expo.json** 파일 존재 확인 추가
- **app.config.mjs** 파일 지원 추가
- **@expo/cli**, **expo-router**, **expo-constants**, **expo-status-bar** 의존성 확인
- **.expo** 디렉토리 존재 확인
- **metro.config.js** 내용에서 expo 키워드 확인
- **package.json**의 name 필드에서 expo 확인
- **app.json**에서 name과 slug 조합 확인
- React Native CLI로 잘못 인식되던 Expo 프로젝트 문제 해결

### 🎯 **Metro 단축키 시스템 완전 개편**
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

### 🎨 **UI/UX 개선**
- 직관적인 단축키 버튼 UI 추가
- Expo 프로젝트 타입별 조건부 단축키 표시
- 아이콘과 색상으로 기능 구분
- 3줄 레이아웃으로 깔끔한 정리

---

## 🛠️ 기술적 개선사항

### **프로젝트 타입 감지 로직 강화**
- 다중 파일 기반 감지 시스템
- JSON 파싱 오류 처리 개선
- 의존성 기반 감지 정확도 향상
- 파일 내용 분석을 통한 추가 검증

### **단축키 처리 시스템**
- 사용자 입력 기반 명령 처리
- 프로젝트 타입별 명령 분기
- 실시간 명령 실행 및 피드백
- 오류 처리 및 로깅 개선

---

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

---

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

---

## 🔧 시스템 요구사항

- **macOS**: 13.0 (Ventura) 이상
- **아키텍처**: Apple Silicon (M1/M2/M3) 또는 Intel (x86_64)
- **Node.js**: 16.0 이상 (Metro 실행용)
- **패키지 매니저**: npm, yarn, 또는 pnpm

---

## 🐛 해결된 이슈

- ✅ Expo 프로젝트가 React Native CLI로 잘못 인식되는 문제
- ✅ Metro 단축키가 작동하지 않는 문제
- ✅ 프로젝트 타입 감지 정확도 문제
- ✅ 사용자 입력 처리 부재 문제

---

## 🔮 향후 계획

- [ ] 다크 모드 지원
- [ ] 프로젝트 템플릿 기능
- [ ] 팀 협업 기능
- [ ] 플러그인 시스템
- [ ] 웹 대시보드 연동
- [ ] 키보드 단축키 지원 (Cmd+R, Cmd+I 등)

---

## 📝 라이선스

개인 및 상업적 사용 가능

---

## 🤝 기여

버그 리포트 및 기능 제안을 환영합니다!

- **이슈 리포트**: GitHub Issues
- **기능 제안**: GitHub Discussions
- **코드 기여**: Pull Request

---

## 🙏 감사의 말

React Native 개발자 커뮤니티의 피드백과 지원에 감사드립니다.

---

**MetroManager v1.1.0** - React Native 개발을 더욱 편리하게! 🚀

*Expo 프로젝트 감지 정확도와 단축키 기능이 대폭 개선되었습니다.*




