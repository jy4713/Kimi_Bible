# 성경 앱 빌드 메뉴얼 (Kimi_Bible)

이 저장소(github.com/jy4713/Kimi_Bible)를 체크아웃받아 **Android APK**와 **웹 페이지**를 만드는 방법과, 빌드 전에 미리 준비해야 할 것들을 정리한 문서입니다.

> **메뉴얼 유지 규칙**: 앱 소스, 번들 데이터(assets), 빌드 설정을 바꾸는 작업(패키지 업데이트 요청 포함)을 할 때마다 이 문서도 함께 갱신합니다.

---

## 1. 미리 준비할 것 (Prerequisites)

| 항목 | 버전/설명 |
|---|---|
| Git | 아무 최신 버전 |
| Flutter SDK | **stable 채널, 3.47.x 권장** (개발 당시 3.47.4 / Dart 3.13.3). pubspec 기준 최소 `>=3.3.0 <4.0.0` |
| Android Studio | 최신 stable + **Android SDK + Platform-Tools** 설치 (APK 빌드용) |
| Java (JDK) | Android Studio 내장 JDK 사용 가능 (Gradle이 자동 감지) |
| Google Chrome | 웹 빌드/테스트용 (`flutter run -d chrome`) |
| 디스크 여유 | 약 1 GB (에셋 258 MB + 빌드 산출물) / 클론 시간 다소 소요 |

### Flutter 설치 후 확인
```bash
flutter doctor
# Android toolchain / Chrome 이 체크되어 있으면 OK
```

### (Windows 전용) PowerShell 경로
Gradle가 PowerShell을 찾지 못해 빌드가 실패하면 Git Bash 등에서 PATH를 추가:
```bash
export PATH="$PATH:/c/Windows/System32/WindowsPowerShell/v1.0"
```

---

## 2. 체크아웃 & 초기 설정

```bash
git clone https://github.com/jy4713/Kimi_Bible.git
cd Kimi_Bible/bible_app
flutter pub get
```

- 저장소 루트의 `bible_app/` 폴 더가 프로젝트 루트입니다.
- 에셋(성경 DB 등 약 258 MB)이 git에 포함되어 있어 클론에 시간이 걸립니다.
- APK 빌드에 필요 없는 것들(build/, .dart_tool/, windows/ 등)은 `.gitignore`로 제외되어 있어 클론 직후 바로 빌드 가능합니다.

---

## 3. Android APK 만들기

```bash
cd Kimi_Bible/bible_app
flutter build apk --release --android-skip-build-dependency-validation
```

- 산출물: `bible_app/build/app/outputs/flutter-apk/app-release.apk` (약 195 MB)
- `--android-skip-build-dependency-validation`: 프로젝트 플러그인 버전 조합에 대한 경고 검사를 걸러주는 플래그. **그대로 사용하세요** (없으면 빌드가 막힐 수 있음).
- 첫 빌드는 Gradle 다운로드/컴파일로 **5~10분** 걸리고, 이후는 3~5분 정도입니다.
- 설치: APK를 기기로 옮겨 설치하거나 `adb install app-release.apk`
- 앱 ID: `kr.juchoi.holybible` (android/app/build.gradle.kts)

### 설치판은 새 앱으로 인식되나요?
앱 ID(`applicationId`)와 서명 키가 같으면 **덮어쓰기(업데이트) 설치**됩니다. 완전 새 앱으로 인식되게 하려면 `android/app/build.gradle.kts`의 `applicationId`를 바꾸세요.

---

## 4. 웹 페이지 만들기

```bash
cd Kimi_Bible/bible_app
flutter build web --release
```

- 산출물: `bible_app/build/web/` — 이 폴 더 통째를 정적 웹 서버(호스팅)에 올리면 됩니다.
- 로컬에서 바로 확인: `flutter run -d chrome` (또는 `flutter run -d web-server` 후 브라우저 접속)
- 웹에서는 SQLite가 WASM(`web/sqlite3.wasm`, `web/sqflite_sw.js`)으로 동작하며, 성경 DB는 첫 실행 시 브라우저 저장소로 복사됩니다.
- **서버 설치·배포(nginx, wasm MIME 설정, 캐시 초기화 등)는 [WEB_DEPLOY_MANUAL.md](WEB_DEPLOY_MANUAL.md) 참고**

---

## 5. 번들 데이터 교체 / 추가 (패키지 업데이트 시)

빌드에 포함되는 데이터는 모두 `bible_app/assets/` 아래입니다:

| 폴 더 | 파일 | 용도 |
|---|---|---|
| `assets/bible/` | `*.bdb` (일반), `*.sdb` (Strong's 번호 포함) | 성경 본문 |
| `assets/hymn/` | `*.hdb` (+ 같은 이름의 `*.cmp` 악보 zip) | 찬송가/교독문 |
| `assets/commentary/` | `*.cdb` | 주석 |
| `assets/dic/` | `*.dct` | 원어 사전 |

**새 파일을 추가할 때 반드시 2가지를 함께 수정:**

1. **`pubspec.yaml`** — `flutter:` → `assets:` 목록에 파일 경로 추가
2. **`lib/models/source_info.dart`** — `kBuiltInBibles` / `kBuiltInHymns` / `kBuiltInCommentaries` 목록에 `SourceInfo(...)` 항목 추가
   - 찬송가: `isReading: false` (기본값, 생략 가능)
   - 교독문: **`isReading: true`** 반드시 표시 → 찬송가와 별개 메뉴/설정으로 분리됨
   - 찬송가는 `companionAssetPath: 'assets/hymn/xxx.cmp'`로 악보 묶음 지정

그 후 `flutter build apk ...`로 재빌드하면 됩니다. (이 절의 절차가 바뀌면 이 메뉴얼도 함께 수정합니다.)

---

## 6. 버전/이름 변경

| 변경 항목 | 위치 |
|---|---|
| 앱 버전 | `pubspec.yaml`의 `version:` |
| 앱 ID (패키지명) | `android/app/build.gradle.kts`의 `applicationId` |
| 앱 이름 (설치 시 표시) | `android/app/src/main/AndroidManifest.xml`의 `android:label` |
| 아이콘 | `android/app/src/main/res/mipmap-*/` |

---

## 7. 트러블슈팅

| 증상 | 해결 |
|---|---|
| `powershell` 관련 Gradle 오류 | 1절의 PowerShell PATH 추가 |
| 빌드가 버전 검사에서 멈춤 | `--android-skip-build-dependency-validation` 플래그 확인 |
| 앱 업데이트 후 데이터가 옛것 | 앱은 assets를 기기 저장소에 한 번 복사해 쓰는데, 크기가 바뀐 에셋은 자동으로 갱신됨. 이상 시 앱 삭제 후 재설치 |
| `flutter` 명령 인식 안 됨 | Flutter SDK의 `bin` 폴 더를 PATH에 등록 |
| **웹에서** `DatabaseException(getDatabasesPath is null)` 또는 `TypeError: null is not a subtype of type 'bool'` | 웹 DB 워커(`sqflite_sw.js`)나 `sqlite3.wasm`이 서버에 없거나(404) 캐시된 오류 상태. ① nginx 루트에 두 파일이 있는지 확인 (`curl -I http://서버/sqlite3.wasm` → 200 필요) ② `build/web/` **전체를** 비우고 다시 업로드 (일부만 올리면 버전이 섞임) ③ 브라우저 서비스 워커 캐시 초기화: Ctrl+Shift+R, 안 되면 DevTools → Application → Service Workers → Unregister 후 재접속 |

---

최종 수정: 2026-09-20 (WEB_DEPLOY_MANUAL.md 신규 추가 — nginx 배포·wasm MIME·서비스워커 캐시 안내, 웹 섹션에 링크)
