# TamaPoke for iPhone / Apple Watch

**[English README](README.md)**

[socquique/TamaPoke](https://github.com/socquique/TamaPoke) — Waveshare
ESP32-S3 원형 AMOLED 보드용, 1세대 포켓몬풍 다마고치 펌웨어 — 를 iOS/watchOS로
개인 빌드용으로 포팅한 프로젝트입니다.

> **개인 이용만 가능. 재배포·앱스토어 등록 불가 — 캐릭터를 다른 것으로 바꾼
> 리스킨 버전도 동일하게 재배포 불가.**
> 뭔가 하기 전에 먼저 [라이선스](#라이선스)를 읽어주세요.

처음이신가요? [게임 방법](docs/GAMEPLAY.ko.md) 문서는 게임 자체를 설명합니다
(이 문서는 포팅 부분만 다룹니다). [무료 vs 유료 Apple 계정](docs/DEV_ACCOUNT.md)
문서는 아래 두 빌드 경로가 정확히 어떻게 다른지 정리해 둡니다.

---

## 라이선스

이 저장소에는 **포켓몬 에셋도, 스프라이트도 없습니다.** 소스 코드만 있습니다:

| 항목 | 위치 | 라이선스 |
|---|---|---|
| 원본 펌웨어 게임 로직 (`pet.cpp`, `dex.h`, `i18n.cpp`) | `upstream/` 서브모듈 — 커밋 참조만, 파일 복사 없음 | MIT © Quique Tortosa, 원저장소 자체 조건 |
| 렌더러, 레이아웃, UI 팔레트, 상태 문자열 — 원본 C++를 **번역** | `Sources/Shared/`, `Sources/Core/TPPet.mm` | 이 저장소의 [LICENSE](LICENSE) (아래 참고) |
| 셰임(shim), ObjC 브리지 구조, CI, 빌드 스크립트 — 이 포팅 고유 | `Sources/Core/`, `.github/`, `Scripts/` | 이 저장소의 [LICENSE](LICENSE) |
| 기본 앱 아이콘 (제3자 IP 없는 범용 마스코트) | `Resources/DefaultAppIcon.png` | 이 저장소의 [LICENSE](LICENSE) |
| 포켓몬 이름, 디자인, 종 데이터 | **이 저장소에 없음** | © Nintendo / Game Freak / The Pokémon Company |
| 스프라이트 | **이 저장소에 없음**, 사용자별로 받아오는 방식, [스프라이트](#스프라이트) 참고 | [PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab), CC BY-NC 4.0 |

**해도 되는 것:** 빌드해서 *본인 소유* 기기에 설치하는 것, 그리고 본인이 가진
사본을 원하는 대로 수정하는 것 — 캐릭터를 완전히 다른 걸로 바꿔서 혼자 갖고
노는 것도 포함해서요.

**하면 안 되는 것:** 배포 — 앱스토어(Apple 심사 지침 5.2.1은 증빙 가능한 권리를
요구하는데 이게 없습니다), TestFlight, 대체 마켓, 사이드로딩 서비스, 공개
다운로드 링크, 단 한 사람에게라도 빌드를 무료로 넘겨주는 것까지 전부
포함합니다. **이 제한은 캐릭터 아트가 아니라 엔진을 기준으로 따라붙습니다** —
포켓몬을 일반 고양이/강아지 등으로 바꾼 버전이라도 여전히 이 저장소의
파생물이고 동일하게 제한됩니다. 리스킨은 빠져나갈 구멍이 아닙니다 — 구속력
있는 문구는 [LICENSE](LICENSE) 3항을 참고하세요. 무료/비상업적이라는 점은
포켓몬 저작권에 대해서도, 이 저장소 자체 조건에 대해서도 법적 방어가 되지
않습니다. 받아온 스프라이트를 커밋하지 마세요 — `.gitignore`가 이미
`Resources/mons/`를 막고 있습니다.

정말로 배포 가능한 무언가를 원한다면, 이 포트를 재배포하는 게 아니라
upstream의 MIT 저장소를 직접 기반으로 독자적인 엔진을 새로 만들어야 합니다.
그 경계가 정확히 어디인지는 [LICENSE](LICENSE) 1항을 참고하세요.

전체 저작자 표시와 범위: [NOTICE](NOTICE). 구속력 있는 조건: [LICENSE](LICENSE)
— 표준 오픈소스 라이선스가 아니라 짧은 커스텀 "개인 이용 라이선스"입니다.
길지 않으니 꼭 읽어보세요.

---

## 상태

원작 대비 기능적으로 완성: 펌웨어의 모든 화면과 연출이 포팅되어 있습니다.

**게임:** 원본 C++ 코드가 수정 없이 그대로 실행됩니다 — 스탯 감소, 진화 조건,
알 희귀도 굴림, 스트릭/유대감/메달, 유전자와 오프라인 진행 모두 원본 코드
그대로이지, 재구현한 게 아닙니다.

**화면:** 대기 화면(바이옴 배경, 실시간 하늘, 돌아다니는 캐릭터), 스타터 선택,
알과 부화, 먹이 메뉴, 목욕, 상세 보기가 있는 도감, 4페이지 스탯 카드(프로필,
배틀, 메달, 진행도), 공 미니게임, 훈련 자루, 이름 변경 키보드, 설정, 진화와
작별/가출 결정 및 그 연출까지 전부 포함됩니다.

**진입 방식도 원본 그대로:** 왼쪽 스와이프로 도감, 위로 스와이프로 스탯 카드,
아래로 스와이프로 설정, 캐릭터를 길게 눌러 떠나보낼지 묻기.

**사운드**는 원본 것을 재합성한 겁니다. 펌웨어는 ES8311 코덱에서 게임보이풍
사각파를 생성하는데, 여기엔 그런 칩이 없으니 `Sources/Shared/TPAudio.swift`가
동일한 파형(원본의 음표 테이블, 16kHz 샘플레이트, 진폭, 클릭 방지 램프)을
직접 만들어 `AVAudioEngine`으로 재생하고, 햅틱도 함께 울립니다. 설정의 토글
하나로 둘 다 전환됩니다.

> 오디오 세션이 `.ambient`라서 효과음이 지금 듣고 있는 다른 소리와 섞이고,
> 무음 스위치도 따릅니다. 무음 상태의 폰은 소리는 안 나도 햅틱은 그대로
> 울립니다.

의도적으로 원본과 다르게 만든 부분 하나: 폰은 ESP32가 아니라서, **시계 화면에
시계가 없습니다.** 시/분 다이얼이 있는 이유는 원래 펌웨어가 자기가 몇 시인지
모르고 하늘 연출이 거기 의존하기 때문인데, iOS는 시간을 이미 알고 있고,
게임에 손으로 시간을 맞추게 했더니 정확히 그것 때문에 하늘이 9시간 빨리
돌아버리는 문제가 생겼습니다. 그 화면의 나머지 기능(언어, 소리)은 그대로
포팅되어 있습니다.

---

## 포팅 방식

펌웨어는 고정된 **466×466** 프레임버퍼에 그림을 그립니다. 이 좌표 공간은
`Sources/Shared/TPGraphics.swift`에 그대로 보존되어 있고, SwiftUI `Canvas`가
스케일 변환 하나만 적용합니다. 그 결과 두 가지가 성립합니다:

- `drawScene`, `drawBars`, `drawButtons` 등은 **한 줄 한 줄 그대로** 포팅됩니다
  — `CX - strlen(s) * 6` 같은 중앙 정렬 계산도 그대로 맞습니다.
- 아이폰과 애플워치는 이 스케일 계수만 다릅니다. 별도 레이아웃이 없습니다.

C++ 게임 로직은 **다시 작성하지 않았습니다.** `upstream/pet.cpp`와
`upstream/i18n.cpp`는 두 개의 셰임 헤더에 대해 그대로 컴파일됩니다:

| 셰임 | 대체하는 것 | 실제 구현 |
|---|---|---|
| `Sources/Core/Arduino.h` | `millis()`, `random()`, `min/max`, `Serial` | `mach_absolute_time`, `arc4random` |
| `Sources/Core/Preferences.h` | ESP32 NVS 키/값 저장소 | `NSUserDefaults` |
| `Sources/Core/AudioStub.mm` | ES8311 코덱 + I2S 톤 신디사이저 | Swift로의 콜백 (햅틱) |

`Sources/Core/TPPet.mm`은 C++ `Pet`을 감싸는 일부러 얇게 만든 Objective-C++
파사드입니다. 문자열 조합은 Swift가 아니라 여기서 이루어지는데, `i18n.h`의
`StrId` enum이 이쪽에서만 보이기 때문입니다 — Swift 쪽에 id를 따로 복제해두면
서브모듈이 갱신될 때 조용히 어긋날 수 있습니다.

**원본 펌웨어는 전원이 꺼져 있어도 RTC로 시간을 계속 유지**하고, 부팅 시 최대
2주치 경과 시뮬레이션을 한 번에 따라잡습니다. 이 설계는 iOS의 포그라운드
진입과 정확히 대응되고, 그래서 이 포팅 버전은 백그라운드 실행이 전혀
필요하지 않습니다.

---

## 빌드

두 가지 워크플로우가 있습니다. 어느 쪽을 쓸 수 있는지는 전적으로 어떤 Apple
계정을 갖고 있는지에 달려 있습니다 — CI는 유료 멤버십은 서명할 수 있지만
무료 Apple ID는 서명할 수 없고, 이건 우회할 방법이 없습니다.

| | [Build (unsigned)](.github/workflows/build.yml) | [Build (signed)](.github/workflows/build-signed.yml) |
|---|---|---|
| Apple 계정 | 무료 Apple ID | 유료 Developer Program ($99/년) |
| 실행 시점 | 매 push + 수동 실행 | 수동 실행만 |
| 준비물 | 없음 | 리포지토리 시크릿 4개 |
| 결과물 | 직접 재서명해야 하는 `.ipa` | 바로 설치되는 `.ipa` |
| 만료 | 7일 | 1년 |
| 애플워치 | 설치 과정에서 보통 빠짐 | 정상 서명되어 빠질 이유가 없음 |
| Mac 필요 여부 | 불필요 | 불필요 |

### Build (unsigned) — 무료 Apple ID

Push하면 Actions 탭에 `TamaPoke-unsigned-ipa` 아티팩트가 생성됩니다. 기기에
설치하는 과정에서 서명하세요 ([설치](#설치) 참고).

### Build (signed) — 유료 Developer Program

**Settings → Secrets and variables → Actions**에 아래를 등록하세요:

| 시크릿 | 어디서 얻는지 |
|---|---|
| `APPLE_TEAM_ID` | Developer 포털 → Membership, 10자리 |
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations |
| `ASC_ISSUER_ID` | 같은 페이지, UUID 형식 |
| `ASC_PRIVATE_KEY` | `AuthKey_*.p8` 파일 전체 내용, `BEGIN`/`END` 줄 포함 |

이 API 키는 **App Manager** 권한이 필요합니다 — App ID와 프로비저닝 프로파일을
필요할 때마다 생성하기 때문입니다. 기기 등록까지는 해주지 않으니, 미리 아이폰과
애플워치를 Xcode에 한 번 연결해두세요 — 등록 안 된 기기용으로 서명된 빌드는
아무 데도 설치되지 않습니다.

이후 **Actions → Build (signed) → Run workflow**. 기본 내보내기 방식은
`debugging`이고, 팀 내 다른 사람 기기에 나눠줄 빌드가 필요하면
`release-testing`(구 "ad-hoc")을 선택하세요.

팀 ID는 커밋되지 않고 시크릿에서 읽어오므로, 공개 저장소인 `project.yml`이
깨끗하게 유지됩니다.

> 이 워크플로우는 일부러 TestFlight에 업로드하지 **않습니다.** TestFlight는
> App Store Connect 심사를 거치는데, 이 앱은 통과할 수 없습니다 —
> [라이선스](#라이선스) 참고.

### Mac에서 로컬로

```bash
brew install xcodegen && xcodegen generate && open TamaPoke.xcodeproj
```

`.xcodeproj`는 `project.yml`에서 생성되며 커밋되지 않습니다.

---

## 스프라이트

앱은 기본적으로 **캐릭터 아트 없이** 배포되므로, 별다른 조치가 없으면 원본
펌웨어 자체의 "No sprites" 안내가 캐릭터 자리에 그려집니다. 이 아트는
[PMD SpriteCollab](https://github.com/PMDCollab/SpriteCollab)(CC BY-NC) 유래의
포켓몬 팬아트입니다: 본인 기기에 빌드해서 쓰는 건 괜찮지만, 커밋하거나
재배포하는 건 안 됩니다. `Resources/mons/`가 바로 그 이유로 gitignore되어
있습니다.

upstream 서브모듈에 이미 패킹된 스프라이트가 들어있어서 따로 다운로드할 게
없습니다 — 원하는 종만 복사해오면 됩니다:

```bash
Scripts/fetch_sprites.sh 7        # 도감 번호로 한 종만
Scripts/fetch_sprites.sh 1 4 7    # 스타터 3종
Scripts/fetch_sprites.sh all      # 151종 전체, 약 20MB
xcodegen generate                 # Xcode가 인식하도록
```

파일이 없는 종은 "No sprites" 안내로 대체되므로, 일부만 복사해도 정상 동작
상태입니다 — 다만 복사하지 않은 형태로 진화하면 다시 캐릭터가 사라집니다.
`--shiny`를 붙이면 이로치 변형도 추가되고, 없으면 이로치 캐릭터도 일반 색으로
그려질 뿐 사라지지는 않습니다.

스프라이트는 앱 번들 안 `mons/p<도감번호>.bin`(이로치는 `ps<도감번호>.bin`)에서
원본의 TPK2 포맷으로 읽히며, `Sources/Shared/TPSprite.swift`가 디코딩합니다.
현재 종 하나만 메모리에 상주합니다.

**두 타겟 모두 자체 사본을 갖고 있습니다.** watchOS 앱은 폰 앱의 리소스를 읽을
수 없고, 이 워치 앱은 독립 실행형이라 자체 세트가 필요합니다. 151종 전체(302개
파일)는 번들당 약 40MB라 `.ipa`가 워치 앱까지 포함하면 약 80MB가 됩니다.
완전성보다 용량이 더 중요하다면 실제로 키우는 종만 복사하세요 — 워치 설치가
훨씬 빨라집니다.

> **CI 빌드에는 스프라이트가 전혀 들어가지 않습니다** — 파일 자체가
> 저장소에 없어서, 두 워크플로우 중 어느 쪽에서 나온 `.ipa`든 플레이스홀더만
> 보입니다. 스프라이트를 복사해 넣고 Xcode로 빌드해야 캐릭터가 보입니다.

---

## 저장과 파일 앱

아이폰 앱은 자신의 Documents 폴더를 공개하므로, **파일 → 내 iPhone →
iTamaPoke**에서 `iTamaPoke-save.json`으로 캐릭터가 보이며, 저장할 때마다
다시 쓰여집니다. 백업하려면 이 파일을 밖으로 복사하거나 다른 기기로
옮기세요.

복원하려면 그 폴더에 파일을 `iTamaPoke-import.json`이라는 이름으로 다시
넣고 앱을 여세요. 실행 시 로드된 뒤 `.imported-<시간>`으로 이름이 바뀌어서,
재시작해도 자기도 모르게 캐릭터가 롤백되는 일이 없습니다 — 같은 이유로
내보낸 파일이 스스로 다시 불러와지는 일도 없습니다. **가져오기는 그 기기의
캐릭터를 대체합니다.** 폴더 안 `README.txt`도 같은 내용을 설명하므로, 이 문서
없이도 파일 앱만으로 흐름을 알 수 있습니다.

이 문서는 손으로 나열한 필드 목록이 아니라 `Pet::save`가 쓰는 것과 동일한
`tamapoke/` `UserDefaults` 네임스페이스 전체이므로, 서브모듈 업데이트로 필드가
추가돼도 백업에서 조용히 빠지는 일이 없습니다. 형식이 잘못된 파일은 아무것도
쓰기 전에 거부됩니다. 스프라이트는 이 저장 데이터에 포함되지 않고, 앱 번들에서
옵니다.

워치 앱은 자체 저장 데이터를 따로 갖고 있고 파일 폴더가 없습니다.

---

## 앱 아이콘

스프라이트와 달리, 이건 기본적으로 실제 아이콘이 포함되어 배포됩니다:
`Resources/DefaultAppIcon.png`는 이 프로젝트를 위해 새로 그린 작은 범용
마스코트로(포켓몬도, 제3자 아트도 아님) git에 커밋되어 있습니다.
`project.yml`을 통해 두 타겟에 연결된 빌드 단계 스크립트
`Scripts/ensure_app_icon.sh`가, 아무것도 지정되어 있지 않을 때(새로 clone한
직후나 모든 CI 빌드 포함) 자동으로 이 기본 이미지를 각 에셋 카탈로그에
복사합니다. 아이콘 하나를 갖기 위해 따로 할 일이 없습니다.

본인 이미지(포켓몬 콜라주든 뭐든 — 제3자 IP라면 스프라이트와 동일한 주의사항
적용)를 쓰고 싶다면:

```bash
Scripts/fetch_app_icon.sh path/to/icon.png   # 정사각형, 가급적 1024x1024
xcodegen generate
```

**이 스크립트를 실행하는 것이 곧 아이콘을 바꾸는 행위입니다** — 두 에셋
카탈로그의 `AppIcon.png`를 덮어쓰고, `ensure_app_icon.sh`는 파일이 *없을
때만* 채워 넣으므로 방금 설정한 걸 다시 덮어쓰지 않습니다. 커스텀
`AppIcon.png` 파일은 스프라이트와 같은 이유로 gitignore된 채로 남아있습니다
(본인 기기에 빌드하는 건 괜찮지만 커밋·재배포는 안 됨); 범용 기본 이미지만
git에 추적됩니다.

두 타겟 모두 어떤 아이콘을 쓰든 각자 사본이 필요합니다 — watchOS 앱은 폰 앱의
에셋 카탈로그를 읽을 수 없습니다. 각 카탈로그는 Xcode의 "single size" 앱
아이콘(1024×1024, `idiom: universal`)을 사용하므로, iOS/watchOS에 실제로
필요한 더 작은 사이즈들은 전부 그 파일 하나에서 빌드 시점에 자동 생성됩니다 —
따로 만들 게 없고, 알파 채널이 있는 이미지도 상관없습니다. 두 플랫폼 모두
자기 방식대로 둥근 모서리를 씌우기 때문입니다.

> **CI 빌드는 항상 기본 아이콘으로 나갑니다.** 커스텀 아이콘은 절대 아닙니다
> — 커스텀 `AppIcon.png`는 `fetch_app_icon.sh`를 실행한 그 컴퓨터에만
> 존재하고, CI의 체크아웃에는 없습니다.

---

## 설치

첫 빌드 전에, 본인이 `com.allenst486db.itamapoke`의 소유자가 아니라면
`project.yml`의 `PRODUCT_BUNDLE_IDENTIFIER`를 바꾸세요 — 다른 개발자가 이미
쓰고 있는 식별자는 프로비저닝이 거부합니다.

> ⚠️ **애플워치에 설치하는 게 가장 어려운 부분입니다.** 사이드로딩 도구는
> 내장된 워치 앱을 잘 처리하지 못합니다 — AltStore는 아예 설치하지 않고,
> Sideloadly는 종종 빠뜨립니다. 두 CI 워크플로우 모두 워치 앱이 번들에
> 없으면 **빌드 자체가 실패**하도록 되어 있으므로, 초록불이면 워치 앱이 실제로
> 포함된 것이고, *설치* 과정에서 유지되는지는 도구에 달려 있습니다. 워치 앱이
> 필요하면 Xcode로 설치하세요.

### Xcode로 — 어떤 Apple ID로도 되고, 워치까지 확실한 유일한 방법

Mac이 필요합니다. 무료 Apple ID도 여기서는 잘 됩니다: CI가 못 하는 대화형
로그인을 Xcode가 대신 해주는 것뿐입니다.

1. **두 기기 모두 개발자 모드 켜기** (iOS 16+ / watchOS 9+): 설정 → 개인정보
   보호 및 보안 → 개발자 모드 → 켜기, 재시작. 워치는 별도 토글이 있어서
   아이폰에서 켰다고 워치까지 켜지지 않습니다.
2. 프로젝트 생성 후 열기:
   ```bash
   brew install xcodegen && xcodegen generate && open TamaPoke.xcodeproj
   ```
3. **TamaPoke** 타겟 선택 → Signing & Capabilities → *Automatically manage
   signing* 체크 → 본인 팀 선택. **TamaPokeWatch** 타겟도 동일하게. 두 타겟
   모두 같은 팀이어야 합니다.
   > `.xcodeproj`는 생성되는 파일이라 `xcodegen generate`를 돌릴 때마다
   > 초기화됩니다. 재생성 후 팀을 다시 선택하거나, 커맨드라인 빌드라면
   > `xcodebuild`에 `DEVELOPMENT_TEAM=YOURTEAMID`를 넘기세요.
4. USB로 아이폰 연결 후 기기에서 **신뢰** 탭.
5. **TamaPoke** 스킴과 본인 아이폰을 대상으로 선택 → `⌘R`.
6. 최초 실행 시 한 번만: 아이폰 → 설정 → 일반 → VPN 및 기기 관리 → 개발자
   인증서 신뢰. 신뢰하기 전까지 앱이 열리지 않습니다.
7. 워치는 **TamaPokeWatch** 스킴과 본인 애플워치를 대상으로 선택 → `⌘R`.
   워치는 잠금 해제 상태로 충전기에 꽂아두세요 — 첫 설치는 몇 분씩 걸리고
   자주 멈춘 것처럼 보이지만 정상입니다.

케이블을 빼려면 Window → Devices and Simulators에서 *Connect via network*를
체크하세요.

무료 Apple ID는 **7일** 후 앱이 실행되지 않게 되므로 `⌘R`을 다시 실행해
갱신하세요. 유료 멤버십이면 1년입니다.

### 서명된 `.ipa`로 — 유료 Developer Program

*Build (signed)* 실행 결과에서 `TamaPoke-signed-ipa` 아티팩트를 다운로드하세요.
팀에 등록된 기기용으로 이미 서명되어 있어서 재서명 도구가 필요 없습니다:
Xcode → Window → **Devices and Simulators**에서 아이폰을 선택하고 `.ipa`를
*Installed Apps* 목록으로 드래그하면 됩니다 ([Apple Configurator](
https://apps.apple.com/app/apple-configurator/id1037126344)도 가능합니다).

### 서명 안 된 `.ipa`로 — 무료 Apple ID, Mac 없이

1. *Build (unsigned)* 실행 결과에서 `TamaPoke-unsigned-ipa` 아티팩트 다운로드.
2. [AltStore](https://altstore.io)(AltServer는 Windows에서도 동작) 또는
   [Sideloadly](https://sideloadly.io) 설치.
3. 본인 무료 Apple ID로 서명해서 USB나 Wi-Fi로 설치.

무료 계정 제한: 앱은 **7일** 후 만료되어 재서명해야 하고(AltServer는 실행 중일
때 자동 갱신), 무료 Apple ID는 동시에 사이드로드 앱 3개까지 허용합니다.

이 경로로는 워치 앱이 살아남지 못할 가능성이 높습니다 — 위 경고 참고. 아이폰
앱은 어느 쪽이든 영향 없습니다: 워치 타겟이 독립형(`WKRunsIndependentlyOfCompanionApp`)이라
나중에 폰 앱을 다시 설치하지 않고도 Xcode에서 워치만 따로 설치할 수 있습니다.

---

## Upstream

`37ba1c4` (v1.4)에 고정되어 있습니다. upstream 수정사항을 받아오려면:

```bash
git submodule update --remote upstream
```

그런 다음 다시 빌드하세요 — 셰임이 유일한 연결 지점이라 대부분의 upstream
변경은 비용이 들지 않습니다. `pet.h`에 새로운 Arduino 심볼이 추가되면
`Sources/Core/Arduino.h`에 추가하세요; `upstream/`은 직접 수정하지 마세요.
