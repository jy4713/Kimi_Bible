# 웹 서버 배포 메뉴얼 (nginx)

`flutter build web`으로 만든 결과물을 **Ubuntu + nginx 서버**에 올려 성경 앱을 웹으로 서비스하는 방법입니다.
APK/웹 **빌드** 방법은 [BUILD_MANUAL.md](BUILD_MANUAL.md)를 참고하세요. 이 문서는 **서버 설치·배포** 전용입니다.

> **메뉴얼 유지 규칙**: 배포 절차나 서버 설정 관련 변경이 있을 때마다 이 문서도 함께 갱신합니다.

---

## 1. 대상 환경

| 항목 | 설명 |
|---|---|
| 서버 OS | Ubuntu 20.04/22.04 등 (테스트 환경: Ubuntu + nginx 1.18) |
| 공인 IP | 사용자가 브라우저로 접속할 IP (예: `http://168.107.53.70/`) |
| 웹 루트 | 기본 `/var/www/html` (이 문서 기준) |

클론드 서버(AWS 등)라면 **보안 그룹 인바운드 80번 포트 허용**이 되어 있어야 외부 접속이 됩니다.

---

## 2. nginx 설치 & 기동 (서버에서)

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable --now nginx
```

설치 확인: 브라우저에서 `http://서버IP/` 접속 → nginx 기본 페이지가 보이면 OK

---

## 3. 웹 빌드 (Flutter가 있는 PC에서)

```bash
git clone https://github.com/jy4713/Kimi_Bible.git
cd Kimi_Bible/bible_app
flutter pub get
flutter build web --release
```

- 결과물: `bible_app/build/web/` 폴 더
- `--release`를 빼고 `flutter build web`만 쳐도 동일합니다 (기본값이 release)

---

## 4. 서버에 업로드 — **반드시 폴 더 전체를**

`build/web/` 안쪽 파일 **전체**를 서버의 `/var/www/html/`에 올립니다.
**일부 파일만 올리면 버전이 섞여서 이상한 오류가 납니다.** 재배포 시에는 기존 파일을 먼저 지우고 통째로 교체하세요.

### Linux / Mac (rsync 권장 — 삭제+전송 한 번에)
```bash
rsync -av --delete build/web/ ubuntu@서버IP:/var/www/html/
```

### Windows
- **pscp** (PuTTY 설치 시 제공): `pscp -r build/web/* ubuntu@서버IP:/var/www/html/`
- 또는 **FileZilla/WinSCP**로 `build/web/` 내용 전체를 `/var/www/html/`에 업로드 (기존 파일 삭제 후)

### 권한 문제가 나면 (403 등)
```bash
# 서버에서
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

---

## 5. ★ wasm MIME 설정 (필수 — 안 하면 성경이 안 열림)

**이 단계를 빠뜨리는 것이 웹 배포 실패의 가장 흔한 원인입니다.**

앱의 SQLite는 브라우저에서 WebAssembly(`sqlite3.wasm`)로 동작하는데, nginx 기본 설정(1.18 등)은 `.wasm`의 MIME 타입을 모릅니다.
그러면 `application/octet-stream`으로 응답해서 **브라우저가 wasm 로드를 거부**하고, 성경/주석/교독문 전부 빈 화면이 됩니다.

```bash
# /etc/nginx/mime.types에 wasm 등록 (이미 있으면 자동으로 건드리지 않음)
grep -q wasm /etc/nginx/mime.types || sudo sed -i '/text\/html html htm;/a\    application/wasm wasm;' /etc/nginx/mime.types

# 설정 적용
sudo nginx -t && sudo nginx -s reload
```

---

## 6. 배포 확인 (서버에서)

```bash
# 세 개 모두 확인하세요
curl -I http://서버IP/ | grep -i "HTTP/"                          # → HTTP/1.1 200 OK
curl -I http://서버IP/sqlite3.wasm | grep -i content-type         # → application/wasm  ← 필수!
curl -I http://서버IP/sqflite_sw.js | grep -i content-type        # → javascript 계열
```

`sqlite3.wasm`이 `application/octet-stream`으로 나오면 **5절의 MIME 설정이 안 된 것**입니다.

---

## 7. 브라우저에서 확인할 때 주의

- **첫 로딩은 느릴 수 있습니다** — 성경 DB를 브라우저 저장소(IndexedDB)로 복사하는 시간이 필요합니다. 두 번째부터는 빠릅니다.
- 재배포 후에도 예전 화면이 남아 있으면 **서비스 워커 캐시** 때문입니다:
  1. 페이지에서 **F12** → **Application** 탭
  2. **Service Workers** → **Unregister** 클릭
  3. **Storage** → **Clear site data** 클릭
  4. 접속 (또는 **Ctrl+Shift+R**)

---

## 8. 재배포 절차 (앱 업데이트 시)

1. PC에서: `git pull` → `flutter build web --release`
2. 서버에 `build/web/` **전체를** 다시 올리기 (기존 파일 삭제 후)
3. **5절의 MIME 설정은 서버에 한 번만 하면 됩니다** (nginx 설정이 유지되므로 생략 가능)
4. 브라우저: Ctrl+Shift+R → 안 되면 서비스 워커 Unregister (7절)

---

## 9. 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| `DatabaseException(getDatabasesPath is null)` 또는 `TypeError: null is not a subtype of type 'bool'` | 웹 DB 워커 초기화 실패 | ① `sqlite3.wasm` / `sqflite_sw.js`가 서버에 있는지 (`curl -I`로 200 확인) ② 5절 MIME 설정 확인 ③ 7절 캐시 초기화 |
| 페이지는 뜨는데 성경 본문이 안 나옴 | 위와 동일 | 위 절차대로 확인 후 F12 → Console 탭의 빨간 에러 확인 |
| 외부에서 접속이 안 됨 (타임아웃) | 방화벽/보안 그룹 | `sudo ufw allow 80/tcp` / 클라우드 보안 그룹 인바운드 80 허용 |
| 403 Forbidden | 웹 루트 권한 | 4절 권한 명령 실행 |
| 404 Not Found | 파일 경로/업로드 누락 | `build/web/` **전체**가 `/var/www/html/` 아래에 있는지 확인 (특히 `index.html`, `main.dart.js`) |

---

최종 수정: 2026-09-20 (최초 작성 — nginx wasm MIME 설정, 서비스 워커 캐시 주의 포함)
