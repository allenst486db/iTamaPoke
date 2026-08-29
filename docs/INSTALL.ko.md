# 설치 가이드 (코딩 지식 불필요)

[English](INSTALL.md) · 스크린샷과 함께 보려면 [설치 가이드(HTML)](INSTALL.html)

파일을 다운로드하고 단계를 따라할 수 있다는 것 외엔 아무것도 필요 없습니다.
설명 없이 나오는 용어는 처음 등장할 때 바로 설명합니다.

> ⚠️ **시작 전에:** 이건 혼자 만든 취미 포팅 프로젝트이지, 완성된 상용
> 앱이 아닙니다. 아래 무료 계정 설치 경로는 아직 검증 중이고, 특히
> 애플워치 쪽에서 버그가 있을 수 있습니다. 뭔가 안 되면 사용자 잘못이
> 아닐 가능성이 큽니다.

## 어느 경로로 가야 하나요?

```
유료 Apple Developer 계정($99/년)이 있나요?
│
├─ 없음(대부분) ────────────────────────────► 경로 A: 무료 설치
│                                              (Mac 또는 Windows, 약 15분)
│
└─ 있음 ───────────────────────────────────► 경로 B: 서명된 설치
                                               (Mac 또는 Windows, 약 10분,
                                               재서명 영구히 불필요)
```

**경로 C**도 있습니다 — Xcode로 직접 빌드하는 방법인데, 이미 Xcode가 설치된
Mac이 있고 스프라이트를 설치 후 추가하는 대신 빌드에 바로 내장하고 싶을
때만 관련 있습니다. **경로 D**는 iOS/워치 앱과 완전히 별개인 **브라우저
빌드**(`browser_ver/`)입니다 — 같은 게임 로직을 웹페이지(또는 그걸 감싼
얇은 네이티브 앱)에서 돌립니다.

---

## 경로 A — 무료 설치 (Sideloadly 또는 AltStore)

**Mac과 Windows 둘 다** 가능합니다. 필요한 것: 아이폰, USB 케이블(최초
한 번), 무료 Apple ID(앱스토어 쓰실 때 쓰는 것과 같은 종류 — 유료 계정
아님).

### 1. 앱 파일 다운로드

1. 이 저장소 페이지를 브라우저로 열고 위쪽의 **Actions** 탭을 클릭합니다.
2. 왼쪽에서 **Build (unsigned)**를 클릭합니다.
3. 목록 맨 위의 가장 최근 실행을 클릭합니다 — 초록색 체크 ✅가 있어야
   합니다.
4. 아래로 스크롤하면 **Artifacts** 아래 파일이 두 개 있습니다.
   **`TamaPoke-unsigned-nowatch-ipa`**(아이폰 전용)를 다운로드하세요.
   `.zip`으로 받아지니 압축을 풀면 `TamaPoke-unsigned-nowatch.ipa` 파일이
   나옵니다. 이게 앱 파일이고, 아직 내 폰용으로 서명은 안 된 상태입니다
   (아래에서 설명).

   > `TamaPoke-unsigned-withwatch-ipa`는 무시하세요. 애플워치용 앱까지
   > 같이 들어있는 버전을 참고용으로 남겨둔 것인데, 무료 Apple ID는
   > 임베드된 두 번째 watchOS 앱까지 프로비저닝할 수 없어서 AltStore는
   > 이 파일 자체를 설치 거부하고, Sideloadly는 아이폰 앱만 설치하고
   > 워치 부분은 조용히 빠뜨립니다. 유료 개발자 계정 없이 워치에 넣고
   > 싶다면 사이드로딩 대신 아래 **경로 C**(Xcode로 워치와 직접 연결해
   > 빌드)를 이용하세요.

### 2. 사이드로딩 도구 설치

인터넷에서 받은 `.ipa`는 아직 본인 Apple 계정으로 서명되어 있지 않아서
iOS가 바로 설치해주지 않습니다. **사이드로딩 도구**가 본인의 무료 Apple
ID로 먼저 서명해줍니다. 둘 중 하나를 고르세요:

- **[AltStore](https://altstore.io)** — 앱이 자동으로 계속 갱신되길
  원하면 추천(5단계 참고). Windows, Mac 둘 다 지원.
- **[Sideloadly](https://sideloadly.io)** — 한 번 설치는 더 간단하지만
  7일마다 손으로 갱신해야 함. 마찬가지로 Windows, Mac 둘 다 지원.

둘 다 무료이고 이런 용도로 널리 쓰이는 정식 제3자 도구입니다 — 각자의
공식 홈페이지에서 설치하세요.

### 3. 서명하고 설치하기

**Sideloadly 사용 시:**
1. 아이폰을 USB로 컴퓨터에 연결하고 Sideloadly를 엽니다.
2. `TamaPoke-unsigned-nowatch.ipa`를 Sideloadly 창으로 드래그합니다.
3. Apple ID 이메일을 입력란에 씁니다.
4. **Start**를 클릭합니다. 중간에 Apple ID 비밀번호를 물어보는데, 이건
   Apple 서버로 직접 전달되어 서명하는 용도이지 저희나 다른 누구에게
   가는 게 아닙니다.
5. 끝날 때까지 기다립니다. 홈 화면에 앱이 생깁니다.

**AltStore 사용 시:**
1. 컴퓨터에 **AltServer**를 설치하고(altstore.io) 안내를 따라갑니다 —
   최초 1회 아이폰을 연결해서 AltStore 앱을 설치해줍니다.
2. 아이폰과 컴퓨터가 **같은 Wi-Fi**에 있는지 확인합니다.
3. 아이폰에서 **AltStore** 앱 → **My Apps** → **+** 버튼 →
   `TamaPoke-unsigned-nowatch.ipa` 선택.
4. Apple ID를 물어보면 입력합니다. 설치될 때까지 기다립니다.

### 4. 아이폰에서 신뢰하기

처음 열려고 하면 iOS가 "개발자를 신뢰할 수 없음"이라고 거부합니다. 한 번만
고치면 됩니다:

**설정 → 일반 → VPN 및 기기 관리** → "개발자 앱" 아래 항목(본인 Apple ID
이름이 붙어 있음) 탭 → **신뢰**.

이제 앱이 정상적으로 열립니다.

### 5. 캐릭터 아트 추가하기

앱은 포켓몬 스프라이트 없이 설치됩니다 — [메인 README에서 이유
설명](../README.md#스프라이트). 이렇게 추가하세요:

1. 컴퓨터에서 [github.com/socquique/TamaPoke](https://github.com/socquique/TamaPoke)로
   이동 → 초록색 **Code** 버튼 → **Download ZIP**.
2. 압축을 풀고 안에서 `tools/sdcard/mons` 폴더를 찾습니다 — 캐릭터별
   `.bin` 파일들과 `thumbs.bin`이라는 파일이 들어있습니다.
3. 그 `mons` 폴더를 아이폰으로 옮깁니다 — AirDrop(Mac), 본인에게
   이메일로 보내기, 클라우드 드라이브 앱 등 뭐든 상관없습니다. 아이폰의
   **파일** 앱이 접근할 수 있는 곳에만 도착하면 됩니다.
4. 아이폰에서 **파일** 앱 → **내 iPhone** → **iTamaPoke**를 엽니다.
5. 그 안에 정확히 `mons`라는 이름의 새 폴더를 만듭니다(옮긴 파일이 이미
   `mons` 폴더째로 왔다면, 빈 폴더를 새로 만드는 대신 그 폴더를 통째로
   옮기면 됩니다).
6. `.bin` 파일들을 복사해 넣습니다 — 전체 종을 다 넣어도 되고, 용량을
   아끼려면 일부만 넣어도 됩니다. **`thumbs.bin`도 꼭 포함하세요** — 이게
   없으면 도감 화면이 텅 비어 보입니다.
7. iTamaPoke 앱을 완전히 종료(앱 전환기에서 위로 스와이프)했다가 다시
   엽니다. 이제 플레이스홀더 대신 캐릭터가 보여야 합니다.

도감 설명문과 울음소리도 넣고 싶다면 같은 `mons` 폴더 안에 넣으면 됩니다 —
[README "도감 설명문"](../README.ko.md#도감-설명문), [README
"울음소리"](../README.ko.md#울음소리) 참고. 울음소리는 받아올 때 컴퓨터에
`ffmpeg`가 필요합니다(`brew install ffmpeg`) — 아이폰 쪽에는 필요 없습니다.

이 `.ipa`에는 애플워치 앱이 아예 들어있지 않습니다 — 1단계의 안내 참고.
유료 개발자 계정 없이 애플워치에도 넣고 싶다면 사이드로딩 대신 아래 경로
C(Xcode로 워치와 직접 연결해 빌드)를 이용하세요 — 무료 계정에서는 워치로
가는 사이드로딩 경로 자체가 없습니다.

### 6. 계속 작동하게 유지하기 (7일마다)

무료 Apple ID로 서명된 앱은 **7일**이 지나면 실행이 멈춥니다 — 이건 앱의
버그가 아니라 Apple의 무료 계정 제한입니다.

- **AltStore 사용자:** 컴퓨터에서 AltServer를 계속 켜두고, 가끔 아이폰을
  같은 Wi-Fi에 연결해두면 자동으로 갱신됩니다.
- **Sideloadly 사용자:** 일주일에 한 번 3단계를 손으로 반복하세요. 저장
  데이터는 이 과정에서 영향받지 않습니다.

무료 Apple ID는 이런 식으로 사이드로드한 앱을 동시에 **3개까지만** 설치할
수 있습니다.

---

## 경로 B — 서명된 설치 (유료 Apple Developer 계정)

이미 연 $99를 내는 Apple Developer 계정이 있다면, 사이드로딩 도구 없이
바로 설치되고 1년 동안 재서명이 필요 없습니다.

> 본인이 직접 fork한 저장소가 아니라면, 먼저 `project.yml`의
> `PRODUCT_BUNDLE_IDENTIFIER`를 `com.allenst486db.itamapoke`가 아닌
> 본인만의 고유한 값으로 바꾸세요 — 이미 다른 사람 계정에 등록된
> 식별자는 Apple 서버가 서명을 거부합니다.

1. 이 저장소의 **Settings → Secrets and variables → Actions**에서 시크릿
   4개를 등록합니다 — 각 값을 정확히 어디서 가져오는지는
   [`.github/workflows/build-signed.yml`](../.github/workflows/build-signed.yml)
   맨 위 주석을 참고하세요.
2. **Actions** 탭 → **Build (signed)** → **Run workflow**.
3. 완료되면(초록색 체크) 경로 A의 1단계와 같은 방식으로
   `TamaPoke-signed-ipa`를 다운로드합니다.
4. Apple Configurator나 Xcode의 Devices 창으로 설치합니다 — 이미 등록된
   기기용으로 서명되어 있어서 사이드로딩 도구가 필요 없습니다.
5. 경로 A의 5단계와 동일하게 스프라이트를 추가합니다.

이 경로는 애플워치 앱도 정상 설치되고, 1년 동안 만료되지 않습니다.

---

## 경로 C — Xcode로 직접 빌드 (Mac만 가능)

이미 Xcode가 설치된 Mac이 있고 터미널에 명령어 몇 개 입력하는 게 괜찮은
분들을 위한 방법입니다. 애플워치만큼은 이 방법이 가장 확실하고, 스프라이트를
설치 후 추가하는 대신 빌드에 바로 내장할 수 있습니다.

본인이 직접 fork한 저장소가 아니라면, `project.yml`의
`PRODUCT_BUNDLE_IDENTIFIER`를 `com.allenst486db.itamapoke`가 아닌 값으로
먼저 바꾸세요(위 경로 B와 같은 이유입니다).

```bash
git clone --recurse-submodules https://github.com/allenst486db/iTamaPoke
cd iTamaPoke
brew install xcodegen
Scripts/fetch_sprites.sh all      # "all" 대신 도감 번호 몇 개만 써도 됨
xcodegen generate
open TamaPoke.xcodeproj
```

위 스크립트 없이 그냥 빌드해도 됩니다 — 스프라이트·도감 설명문·울음소리
없이 시작할 뿐이고, 나중에 언제든 추가할 수 있습니다([README
"스프라이트"](../README.ko.md#스프라이트), ["도감
설명문"](../README.ko.md#도감-설명문), ["울음소리"](../README.ko.md#울음소리)
참고). `Scripts/fetch_assets.sh`는 스프라이트·이로치·울음소리를 스크립트
하나하나 따로 실행하지 않고 한 번에 받아옵니다 — 울음소리는 먼저 `ffmpeg`
설치가 필요합니다(`brew install ffmpeg`).

Xcode에서: **TamaPoke** 타겟 선택 → *Signing & Capabilities* → *Automatically
manage signing* 켜기 → 본인 Apple ID를 팀으로 선택. **TamaPokeWatch**도
동일하게. 그런 다음 아이폰을 연결하고 실행 대상으로 선택한 뒤 ⌘R. 워치는
**TamaPokeWatch** 스킴과 본인 애플워치로 대상 바꿔서 반복.

iOS 16+ / watchOS 9+ 모두 **개발자 모드**를 한 번 켜야 합니다: 설정 → 개인정보
보호 및 보안 → 개발자 모드 → 켜기, 재시작. 워치는 별도 토글입니다.

여기서도 무료 Apple ID는 7일 후 만료되니 ⌘R을 다시 누르면 됩니다.

### 앱 아이콘

기본으로 작은 마스코트 아이콘이 포함되어 있습니다(메인 README 참고). 본인
이미지를 쓰려면:

```bash
Scripts/fetch_app_icon.sh path/to/icon.png   # 정사각형, 가급적 1024x1024
xcodegen generate
```

---

## 경로 D — 브라우저 빌드, 본인 폰/태블릿에 설치

`browser_ver/`는 같은 C++ 게임 로직을 WebAssembly로 컴파일해서 웹페이지에서
돌립니다 — App Store도, 사이드로딩도, 7일 만료도 없습니다. iOS 앱과 세이브
데이터·스프라이트·도감 설명문을 공유하지 않는 완전히 별도의 빌드입니다.
**이 경로의 목적은 본인 iPhone/iPad나 안드로이드 기기에 실제 앱으로 설치하는
것**이지, 컴퓨터 브라우저에서만 돌리는 게 아닙니다 — 딱 한 번 컴퓨터에서
빌드해야 하는 건 맞지만(iOS 셸은 Mac, 안드로이드는 아무 OS나), 그 결과물은
이후 폰 안에서만 온전히 실행됩니다.

### 준비: 먼저 이 저장소를 clone하세요

아직 하지 않았다면(경로 C를 따라갔거나 처음 시작하는 경우) 저장소를 clone하세요:

```bash
git clone --recurse-submodules https://github.com/allenst486db/iTamaPoke
cd iTamaPoke
```

아래 단계의 경로는 모두 iTamaPoke 폴더 기준입니다. 경로 C를 이미 따라갔다면 이 부분을
건너뛰고 바로 1단계로 가셔도 됩니다.

### 1. 웹 코어 빌드 (컴퓨터에서, 한 번만)

```bash
# 최초 1회: Emscripten SDK 설치
# (iTamaPoke 폴더 밖 어디든 설치하세요)
git clone --depth 1 https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh

# iTamaPoke 저장소 폴더로 돌아가기
cd /path/to/iTamaPoke

# 코어 빌드 -> browser_ver/web/tp_core.{js,wasm}
bash browser_ver/build.sh
```

`emsdk`는 Python 3.10+가 필요합니다 — 시스템 Python이 더 오래됐다면
[astral-sh/python-build-standalone](https://github.com/astral-sh/python-build-standalone)의
이식용 빌드로 `emsdk.py`만 실행하면 됩니다(그 이후로는 Emscripten 자체
번들 Python을 씁니다).

### 2. 폰에 올리기: 브라우저 탭이 아니라 네이티브 셸

`browser_ver/native/`에 다 준비돼 있습니다 — Xcode 새 타깃에 넣는
**WKWebView**(iOS/iPadOS) 셸과, 바로 열 수 있는 **WebView**(안드로이드)
Gradle 프로젝트. 둘 다 `browser_ver/web/`을 앱 안에 로컬 파일로 번들해서
읽습니다 — 서버 없음, 네트워크 권한 없음, 설치 끝나면 컴퓨터에 남는 것도
없습니다. 자세한 절차는 `browser_ver/native/README.md`, 요약하면:

- **iOS/iPadOS**: 루트 폴더의 `TamaPoke.xcodeproj`는 git clone에 포함되어 있습니다.
  Xcode에서 이 파일을 열기 → File → New → Target… → iOS App → 
  `browser_ver/native/ios/WebShellApp.swift`와 이 폴더의 `Info.plist`를 새 타깃에 드래그 → 
  `browser_ver/web` 폴더 전체를 **폴더 참조로**(파란 폴더 아이콘, 그룹 아님) 드래그 → 
  연결된 본인 iPhone/iPad에서 빌드 및 실행 (본체 앱과 동일한 방식).
- **안드로이드**: `browser_ver/native/android/`를 Android Studio에서 바로
  열기 → `browser_ver/web/`을 `app/src/main/assets/web/`에 복사 → 연결된
  본인 폰에서 실행.

여기까지 하면 폰에 앱으로 설치된 상태입니다. 아래(스프라이트, 도감
설명문)는 컴퓨터 브라우저에서든 설치된 앱 안에서든 똑같이, 한 번씩만
직접 골라 넣으면 됩니다.

### 컴퓨터에서 미리 보기 (선택사항, 이 경로의 목적은 아님)

네이티브 셸로 감싸기 전에 그냥 눌러보고 싶다면:

```bash
# 로컬 서버로 열기 (file://는 안 됨 — WASM 로드에 실제 origin이 필요)
cd browser_ver/web && python3 -m http.server 8123
# 그 다음 컴퓨터 브라우저에서 http://localhost:8123 열기
```

### 스프라이트 넣기 (자세히)

브라우저 빌드에는 파일 앱이 없습니다 — 대신 **페이지 안에서 직접 파일을
고릅니다**:

1. 아무 컴퓨터에서 `Scripts/fetch_sprites.sh`(경로 C와 같은 스크립트)로
   `.bin` 파일을 받습니다 — 종마다 하나씩, `p<도감번호>.bin`(일반)과
   `ps<도감번호>.bin`(이로치).
2. 그 `.bin` 파일들을 실제로 앱을 쓸 기기로 옮깁니다. 같은 컴퓨터라면
   이미 거기 있는 거고, 위 2단계에서 만든 네이티브 셸이 깔린 폰이라면
   AirDrop·케이블·클라우드 드라이브 등 파일 옮기는 아무 방법이나 쓰면
   됩니다 — 경로 A의 5단계에서 iOS 앱에 스프라이트 넣는 것과 같은
   원리입니다.
3. 앱에서 **"Load sprites…"** 버튼을 누릅니다.
4. 파일 선택 창에서 **원하는 `.bin` 파일 전부를 한 번에 다중 선택**합니다 —
   폴더째 끌어놓는 게 아닙니다. (일부러 폴더 선택을 안 씁니다: iOS
   Safari의 폴더 선택이 불안정해서, 모든 플랫폼에서 똑같이 다중 파일
   선택 방식을 씁니다.)
4. 고른 파일은 **이 브라우저 자체의 IndexedDB**(이 브라우저·이 기기에
   묶인 로컬 저장소)에 저장되고, 새로고침해도 그대로 남습니다 — 브라우저당
   한 번만 고르면 됩니다.
5. 이미 넣은 종의 파일을 다시 고르면 그냥 덮어씌워집니다 — 따로 지울
   필요 없습니다.

브라우저를 바꾸거나(사파리→크롬), 시크릿/프라이빗 창을 쓰거나, 이 사이트의
데이터를 지우면 그 IndexedDB도 같이 비워집니다 — 그럴 때는 "Load
sprites…"를 다시 누르면 됩니다. `.bin` 파일 자체는 어느 경우든 컴퓨터에
그대로 남아 있고, 어디로도 업로드되지 않습니다.

### 도감 설명문 넣기 (선택)

같은 방식으로 버튼 하나 더 있습니다: `Scripts/fetch_dex_entries.sh`로
`dex_entries_<언어>.txt`를 받은 뒤 **"Load dex text…"**를 눌러 다중
선택합니다. 도감 상세화면 두 번째 페이지(오른쪽 점)에 나타납니다.

---

## 막히는 부분

**"설치할 수 없음" / 설치가 조용히 실패함.** 무료 Apple ID는 동시에
사이드로드 앱 3개까지만 허용합니다 — 다른 앱으로 이미 한도를 채우지
않았는지 확인하세요.

**앱이 열리자마자 바로 닫힘.** 보통 경로 A의 4단계(개발자 신뢰)를 안 한
경우입니다.

**캐릭터 없이 플레이스홀더만 보임.** 스프라이트 파일 위치가 잘못됐을 수
있습니다 — 폴더 이름이 정확히 `mons`인지, 앱의 파일 폴더 바로 안에 있는지,
파일 추가 후 앱을 완전히 재시작했는지 확인하세요.

**도감 화면이 텅 빔.** `thumbs.bin`이 빠진 경우입니다 — 151개 넘는 파일
사이에서 이거 하나만 빠뜨리기 쉽습니다.

**애플워치가 한참 기다려도 플레이스홀더만 보임.** 워치 앱을 직접 열어서
화면을 잠깐 켜두세요 — 워치를 실제로 보고 있지 않으면 폰에서 온 파일 전달이
지연될 수 있는데, 이건 이 앱만의 문제가 아니라 Apple의 폰-워치 파일 전송
방식 자체의 특성입니다.

**그 외 뭔가 이상함.** 실제로 있을 수 있는 일입니다 — 이 문서 맨 위의
경고를 참고하세요. 무엇을 보셨는지 이 저장소에 이슈로 남겨주셔도 좋습니다.
