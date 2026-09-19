# 성경 앱 APK 빌드 메뉴얼

이 폴의 파일들로 APK를 만드는 방법을 설명합니다.

---

## 1. 폴 구성 (현재 상태)

```
C:\Temp\workspace\Bible_app\
├── bible_app\          ← ★ 앱 소스 (이것만 있으면 빌드 가능)
│   ├── lib\            ← Dart 소스 코드
│   ├── assets\         ← 성경/주석/찬송가/사전 데이터 (빌드에 포함됨)
│   ├── android\        ← Android 빌드 설정 + 서명 키스토어
│   └── pubspec.yaml    ← 프로젝트 설정
├── data\               ← 성경/주석 원본 데이터 (백업용, 빌드에는 불필요)
├── icon\               ← 앱 아이콘 원본 (백업용)
├── .git\               ← 소스 버전 이력 (복구용)
└── APK_BUILD_MANUAL.md ← 이 파일
```

> `bible_app\BUILD_MANUAL.md`는 이전 PC(다른 사용자 환경)에서 작성된 파일이라
> 경로가 다릅니다. 이 메뉴얼을 기준으로 하세요.

---

## 2. 필요한 프로그램

| 프로그램 | 이 PC의 위치 | 확인 방법 |
|---|---|---|
| Flutter SDK | `C:\Utils\flutter` | `C:\Utils\flutter\bin\flutter.bat --version` |
| Java (JDK) | Flutter 연동용으로 설치된 것 사용 | 빌드 시 자동 사용 |
| Android SDK | Flutter에 설정된 것 사용 | `flutter doctor` |

Flutter 설치를 확인하려면 Git Bash(또는 명령 프롬프트)에서:

```bash
C:/Utils/flutter/bin/flutter.bat doctor
```

---

## 3. APK 빌드 절차

### 3-1. Git Bash를 열고 프로젝트 폴로 이동

```bash
cd /c/Temp/workspace/Bible_app/bible_app
```

### 3-2. 빌드 실행

```bash
export PATH="$PATH:/c/Windows/System32/WindowsPowerShell/v1.0"
/c/Utils/flutter/bin/flutter.bat build apk --release --android-skip-build-dependency-validation
```

> - `--android-skip-build-dependency-validation` 플래그는 **꼭 필요**합니다.
>   이 프로젝트는 Gradle/AGP 버전 조합 때문에 Flutter의 버전 검사를 우회해야 합니다.
> - 첫 빌드는 4~8분, 이후 변경분만 다시 빌드하면 2~4분 걸립니다.

### 3-3. 결과물 확인

빌드 성공 메시지:
```
√ Built build\app\outputs\flutter-apk\app-release.apk
```

생성된 APK:
```
C:\Temp\workspace\Bible_app\bible_app\build\app\outputs\flutter-apk\app-release.apk
```

이 APK를 폰으로 옮겨 설치하거나, 작업 폴 루트로 복사해 보관합니다.

---

## 4. 서명(Keystore) 정보

릴리즈 APK는 이미 서명 설정이 되어 있습니다.

| 항목 | 값 |
|---|---|
| 키스토어 파일 | `bible_app\android\app\bible_release.jks` |
| Key alias | `bible_release` |
| storePassword / keyPassword | `bible2026keystore` |
| 패키지명 (applicationId) | `kr.juchoi.holybible` |

> 같은 키스토어로 빌드해야 앱 업데이트(덮어쓰기 설치)가 가능합니다.
> 이 파일이나 비밀번호를 바꾸면 기존 설치자가 업데이트할 수 없게 되므로 그대로 유지하세요.

---

## 5. 소스를 잘못 지웠을 때 복구 (.git 활용)

소스 폴 `bible_app`이 깨지거나 파일을 잘못 지운 경우, `.git`의 이력에서 복구할 수 있습니다.

```bash
cd /c/Temp/workspace/Bible_app

# 마지막 커밋 상태로 되돌리기 (수정분은 사라짐)
git checkout -- bible_app

# 특정 파일만 복구
git checkout -- bible_app/lib/models/verse.dart

# 저장된 커밋 목록 보기
git log --oneline
```

---

## 6. 코드를 수정한 뒤 다시 빌드할 때

1. 소스를 저장한 뒤 3-2의 빌드 명령을 그대로 다시 실행하면 됩니다.
2. `pubspec.yaml`을 건드렸다면(패키지 추가/제거) 먼저:
   ```bash
   /c/Utils/flutter/bin/flutter.bat pub get
   ```
3. 빌드가 이상하게 실패하면 초기화 후 재빌드:
   ```bash
   /c/Utils/flutter/bin/flutter.bat clean
   ```
   (clean 후에는 첫 빌드처럼 시간이 더 걸립니다)

---

## 7. 폰에 설치하는 방법

1. USB로 폰을 연결하고 폰에서 **개발자 옵션 → USB 디버깅**을 켭니다.
2. 또는 APK 파일을 폰으로 복사(카톡/이메일/USB)한 뒤, 폰에서 파일을 열어 설치합니다.
   (설치 시 "출처를 알 수 없는 앱 설치" 허용 필요)
3. 패키지명이 `kr.juchoi.holybible`이므로, 이전 버전(다른 패키지명) 앱과는 별개의 앱으로 설치됩니다.

---

## 8. 문제 해결

| 증상 | 해결 |
|---|---|
| `flutter 명령을 찾을 수 없음` | 경로를 `C:\Utils\flutter\bin\flutter.bat` 전체로 지정 |
| PowerShell 관련 오류 | `export PATH="$PATH:/c/Windows/System32/WindowsPowerShell/v1.0"` 실행 후 재시도 |
| Gradle 메모리 오류 | 이미 `android\gradle.properties`에 `-Xmx4g` 설정됨 |
| 빌드는 됐는데 변경 내용이 반영 안 됨 | `flutter clean` 후 재빌드 |
| 로그의 `kotlin metadata 'e:'` 줄 | 무시필도 없는 경고. 빌드 결과에 영향 없음 |
