# Free vs. paid Apple account — what actually differs

[한국어는 아래](#한국어)

This project supports both, on purpose. Nothing here is a workaround; it's
just what Apple's provisioning system allows for each account type.

| | Free Apple ID | Paid Apple Developer Program ($99/yr) |
|---|---|---|
| Cost | $0 | $99/year |
| Which CI workflow | [`build.yml`](../.github/workflows/build.yml) → sign yourself after | [`build-signed.yml`](../.github/workflows/build-signed.yml) → installs as-is |
| Signing | interactive only — a tool (Xcode, AltStore, Sideloadly) signs on your device with your Apple ID, CI cannot do this step | CI signs it directly via an App Store Connect API key |
| App expiry | **7 days**, then it stops launching until re-signed | **1 year** |
| Re-signing while it's running | AltStore/SideStore can auto-renew over Wi-Fi if the signing app/PC stays reachable; Sideloadly needs you to redo it by hand | not needed until the yearly renewal |
| Simultaneous sideloaded apps | 3 at a time, shared across everything you've sideloaded with that Apple ID | no such limit |
| Apple Watch app | often dropped by sideloading tools (AltStore never installs it; Sideloadly frequently drops it) — reliable only via Xcode's own install | installs and stays, same as any other signed app |
| TestFlight | not available (needs the paid program) | available, but this project deliberately doesn't use it — see [README "Legal"](../README.md#legal): this app cannot pass App Store review (no rights to the character art), and TestFlight submission goes through that same review |
| Device registration | not required — free provisioning covers whatever you plug in | your device UDID must be registered in the Developer portal before a build signed for it will install |
| What CI needs from you | nothing | 4 repository secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` — see the signed workflow's own comments |

**Bottom line:** a free Apple ID gets you the exact same app, it just needs
re-signing every 7 days and is more likely to lose the watch companion along
the way. If you only care about the iPhone app and don't mind AltStore's
auto-renew running in the background, free is genuinely fine long-term.

---

## 한국어

이 프로젝트는 무료 계정과 유료 계정 둘 다 지원하도록 만들어졌습니다. 아래
내용은 우회 기법이 아니라, Apple의 프로비저닝 시스템이 계정 종류별로 원래
허용하는 범위입니다.

| | 무료 Apple ID | 유료 Apple Developer Program ($99/년) |
|---|---|---|
| 비용 | $0 | 연 $99 |
| 사용할 CI 워크플로우 | [`build.yml`](../.github/workflows/build.yml) → 이후 직접 서명 | [`build-signed.yml`](../.github/workflows/build-signed.yml) → 바로 설치 가능 |
| 서명 방식 | 대화형(인터랙티브)만 가능 — Xcode/AltStore/Sideloadly 같은 도구가 내 기기에서 내 Apple ID로 서명. CI는 이 단계를 대신할 수 없음 | CI가 App Store Connect API 키로 직접 서명 |
| 앱 만료 | **7일** 후 재서명 전까지 실행 안 됨 | **1년** |
| 실행 중 자동 재서명 | AltStore/SideStore는 서명용 앱/PC가 같은 와이파이에 있으면 자동 갱신 가능. Sideloadly는 수동으로 다시 해야 함 | 연 단위 갱신 전까지 불필요 |
| 동시 사이드로드 앱 개수 | 같은 Apple ID로 사이드로드한 전체 앱 합쳐서 3개 | 제한 없음 |
| 애플워치 앱 | 사이드로딩 도구에서 자주 누락됨(AltStore는 아예 설치 안 함, Sideloadly는 종종 빠뜨림) — Xcode로 직접 설치해야 확실함 | 다른 서명 앱과 동일하게 정상 설치·유지 |
| TestFlight | 불가(유료 프로그램 필요) | 가능하지만 이 프로젝트는 일부러 사용하지 않음 — [README "Legal"](../README.md#legal) 참고: 캐릭터 아트에 대한 권리가 없어서 앱스토어 심사를 통과할 수 없고, TestFlight 제출도 같은 심사를 거침 |
| 기기 등록 | 불필요 — 무료 프로비저닝은 연결한 기기를 그대로 커버 | 빌드를 설치하기 전에 개발자 포털에 기기 UDID를 미리 등록해야 함 |
| CI에 필요한 준비물 | 없음 | 리포지토리 시크릿 4개: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` — 서명 빌드 워크플로우 파일 내 주석 참고 |

**결론:** 무료 Apple ID로도 완전히 동일한 앱을 쓸 수 있습니다. 다만 7일마다
재서명이 필요하고, 그 과정에서 워치 앱이 빠질 가능성이 더 높을 뿐입니다.
아이폰 앱만 신경 쓰고 AltStore 자동 갱신을 백그라운드에서 계속 돌려도 괜찮다면
무료 계정만으로도 장기적으로 충분합니다.
