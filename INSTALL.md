# MetroManager 설치 가이드

## 🚀 빠른 시작

### 1. 앱 다운로드
최신 릴리즈를 [GitHub Releases](https://github.com/your-username/MetroManager/releases)에서 다운로드하세요.

### 2. 앱 설치
```bash
# 다운로드한 앱을 Applications 폴더로 이동
mv ~/Downloads/MetroManager.app /Applications/

# 또는 Finder에서 드래그 앤 드롭
```

### 3. 앱 실행
```bash
# 터미널에서 실행
open /Applications/MetroManager.app

# 또는 Applications 폴더에서 더블클릭
```

## 🔧 시스템 요구사항

- **macOS**: 13.0 (Ventura) 이상
- **아키텍처**: Apple Silicon (M1/M2/M3) 또는 Intel (x86_64)
- **Node.js**: 16.0 이상 (Metro 실행용)
- **패키지 매니저**: npm, yarn, 또는 pnpm

## 📋 사전 준비

### Node.js 설치 확인
```bash
node --version
npm --version
```

### React Native 개발 환경 설정
MetroManager는 기존 React Native 프로젝트와 함께 사용됩니다.

## 🛠️ 문제 해결

### 앱이 실행되지 않는 경우
1. **보안 설정 확인**
   - 시스템 환경설정 > 보안 및 개인 정보 보호
   - "확인 없이 열기" 허용

2. **권한 확인**
   ```bash
   # 앱에 실행 권한 부여
   chmod +x /Applications/MetroManager.app/Contents/MacOS/MetroManager
   ```

### Metro 서버가 시작되지 않는 경우
1. **Node.js 버전 확인**
   ```bash
   node --version  # 16.0 이상 필요
   ```

2. **프로젝트 의존성 설치**
   ```bash
   cd your-react-native-project
   npm install
   # 또는
   yarn install
   ```

3. **포트 충돌 확인**
   ```bash
   # 8081 포트 사용 중인 프로세스 확인
   lsof -i :8081
   ```

## 🔄 업데이트

### 자동 업데이트
현재 버전에서는 자동 업데이트 기능이 지원되지 않습니다.

### 수동 업데이트
1. 기존 앱 삭제
2. 새 버전 다운로드
3. 새 앱 설치

## 📞 지원

문제가 발생하거나 도움이 필요한 경우:
- [GitHub Issues](https://github.com/your-username/MetroManager/issues)
- [GitHub Discussions](https://github.com/your-username/MetroManager/discussions)

## 📝 라이선스

이 앱은 개인 및 상업적 사용이 가능합니다.

---

**MetroManager** - React Native 개발을 더욱 편리하게! 🚀







