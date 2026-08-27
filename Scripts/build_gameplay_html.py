#!/usr/bin/env python3
"""One-off build script: assembles docs/GAMEPLAY.html from the mosikdo-guide
template plus the screenshots in docs/img/. Not part of the app; run by hand
whenever the guide's screenshots or copy change, then delete or keep as-is."""
import base64
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
IMG = os.path.join(DOCS, "img")
TEMPLATE = os.path.expanduser("~/.claude/skills/mosikdo-guide/assets/template.html")


def b64(name):
    with open(os.path.join(IMG, name), "rb") as f:
        return base64.b64encode(f.read()).decode()


def shot(name, alt, caption):
    return f'''<figure><img src="data:image/png;base64,{b64(name)}" alt="{alt}" style="display:block;max-width:220px;margin:0 auto;border-radius:10px;border:.5px solid var(--line)"><figcaption>{caption}</figcaption></figure>'''


with open(TEMPLATE, encoding="utf-8") as f:
    tpl = f.read()

head, rest = tpl.split('<div class="desktop">', 1)
_, tail = rest.rsplit("</script>", 1)
head = head.replace("<title>모식도 가이드 — 제목을 여기에</title>",
                     "<title>iTamaPoke Gameplay Guide</title>")

CONTENT = f'''
<div class="desktop">
  <div id="tocBackdrop" class="toc-backdrop"></div>
  <div class="layout">
  <aside id="tocPanel" class="toc-panel" aria-label="문서 목차">
    <div class="toc-head">
      <span class="toc-title">목차</span>
      <button type="button" class="toc-close" aria-label="목차 닫기">✕</button>
    </div>
    <div id="tocList" class="toc-list"></div>
  </aside>
  <div class="window">

    <div class="titlebar">
      <div class="traffic"><i class="r"></i><i class="y"></i><i class="g"></i></div>
      <div class="tb-title">게임 설명서 — iTamaPoke v0.7.1</div>
      <button type="button" class="toc-btn" aria-label="목차 토글">
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M2 4h12M2 8h12M2 12h8" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
      </button>
    </div>

    <div class="content">

      <header>
        <p class="eyebrow">GAMEPLAY GUIDE · v0.7.1</p>
        <h1>iTamaPoke 게임 설명서</h1>
        <p class="lede">화면 캡쳐는 전부 <strong>영어(EN) 모드</strong>에서, 도감에 <strong>피카츄</strong>를 등록해서 찍었습니다. 실제 조작감은 한글 모드에서도 동일합니다.</p>
      </header>

      <section>
        <div class="sec-head"><span class="sec-num">1</span><p class="kicker">Getting Started</p></div>
        <h2>캐릭터 얻기</h2>
        <p>앱을 처음 실행하면 캐릭터가 없는 상태입니다 — 화면을 탭해서 <strong>스타터를 고르거나</strong>, 이미 게임을 진행 중이라면 알을 부화시킵니다. 알의 <strong>희귀도</strong>(종은 아님)는 부화 전에 미리 표시되며, 더 희귀한 알일수록 초기 스탯 굴림이 좋을 확률이 높지만, 어떤 알이든 결국 부화하면 이후 성장 방식은 동일합니다.</p>
        <div class="note info"><span class="lbl">스타터</span><p>1~3세대 스타터 9종 중에서 직접 고릅니다 — 한 페이지에 한 세대씩(3마리). 스타터 선택 화면에도 언어 전환 핀이 있어서, 캐릭터를 얻기 전에도 원하는 언어로 바꿀 수 있습니다.</p></div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">2</span><p class="kicker">Idle Screen</p></div>
        <h2>대기 화면</h2>
        <p>캐릭터는 실제 기기 시간에 맞춰 낮/밤이 바뀌는 하늘 아래에서 혼자 돌아다닙니다. 계속 붙잡고 있어야 하는 게임이 아니라, 가끔 들여다보도록 설계되어 있습니다.</p>

        {shot("idle.png", "Idle screen showing PIKACHU", "대기 화면 — 이름/레벨, 상태 메시지, FOOD/JOY/ENE/HYG 네 게이지, 하단 네 버튼(먹이·놀기·잠자기·씻기).")}

        <ul class="pts">
          <li><strong>위로 스와이프</strong> — 8페이지짜리 스탯 카드</li>
          <li><strong>왼쪽으로 스와이프</strong> — 도감: 키우거나 본 적 있는 모든 종을 썸네일 격자로 표시, 전체/키운 것/잡은 것 필터 가능</li>
          <li><strong>아래로 스와이프</strong> — 설정(언어, 소리, 시간)</li>
          <li><strong>캐릭터 탭</strong> — 짧은 반응</li>
          <li><strong>캐릭터 길게 누르기</strong> — 떠나보낼지 묻는 창 ("작별" 참고)</li>
          <li><strong>먹이 아이콘 탭</strong> — 먹이 메뉴(열매/사탕)</li>
          <li><strong>화면 위쪽 칩</strong> — 원정 진행 중/보상 가능 시 등장, 탭하면 원정 페이지로 이동</li>
          <li><strong>"야생 배틀?" 알림</strong> — 깨어있고 별다른 일이 없을 때 가끔 저절로 뜸</li>
        </ul>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">3</span><p class="kicker">Care</p></div>
        <h2>먹이·목욕·훈련</h2>
        <div class="cards">
          <div class="cd"><div class="t">🍎 먹이 주기</div><div class="d">열매(배고픔 회복, 색은 장식)와 사탕(효과 크고 훈련 스탯도 소폭 상승) 두 종류. 과식·소식 둘 다 역효과 — 게이지는 목표 범위입니다.</div></div>
          <div class="cd"><div class="t">🛁 목욕과 청소</div><div class="d">방치하면 지저분해지고(응가 아이콘), 탭해서 치울 수 있습니다. 심하면 실제 목욕 연출(원본 하드웨어와 동일한 거품 연출)이 필요해집니다.</div></div>
          <div class="cd"><div class="t">💪 훈련 자루</div><div class="d">놀기 메뉴가 아니라 스탯 카드의 배틀 페이지에서 진입. 타이밍 맞춰 타격 — 배틀에서 쓰는 전투 스탯을 올려줍니다.</div></div>
        </div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">4</span><p class="kicker">Minigames</p></div>
        <h2>미니게임 5종</h2>
        <p>먹이 줄의 놀기 아이콘을 탭하면 5개 미니게임 타일이 뜹니다. 전부 짧고 반복 가능한 세션 — 붙잡고 오래 하는 게임이 아닙니다.</p>

        {shot("play-menu.png", "Play menu with five minigame tiles", "놀기 메뉴 — BALL / CATCH / MEMO / CLEAN / TYPE, 타일을 탭해서 시작.")}

        <div class="method">
          <div class="m-head"><span class="m-badge">BALL</span></div>
          <p class="m-desc">타이밍 맞춰 잡기/튕기기 게임. 행복도와 유대감 상승.</p>
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge alt">CATCH</span><span class="m-pill ok">Expanded 포크</span></div>
          <p class="m-desc">시간이 다 되거나 인내심이 바닥나기 전에 움직이는 타겟을 탭. 잘못 탭해도 놓친 것과 동일 처리.</p>
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge alt">MEMO</span><span class="m-pill ok">Expanded 포크</span></div>
          <p class="m-desc">맞힐 때마다 한 단계씩 길어지는 사이먼 게임 방식 패드 순서 맞히기. 라운드가 끝나면 다음 시연 전에 잠깐 정지해서 "내 차례였는지 시연인지" 헷갈리지 않게 합니다.</p>
          {shot("memo-game.png", "MEMO minigame with four colour pads", "MEMO — 패드 4개, ROUND/BEST 카운터, 진행 상태 문구.")}
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge alt">CLEAN</span><span class="m-pill ok">Expanded 포크</span></div>
          <p class="m-desc">계속 새로 생기는 먼지를 세 번 놓치거나 시간이 다 되기 전에 닦아내기.</p>
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge alt">TYPE</span><span class="m-pill ok">Expanded 포크</span></div>
          <p class="m-desc">시간 내에 화면에 나온 타입을 이기는 타입 셋 중 정답을 고르는 상성 퀴즈. 1~3세대 전체 18타입(악/강철/페어리 포함) 커버.</p>
        </div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">5</span><p class="kicker">Battle · Expedition</p></div>
        <h2>배틀과 원정</h2>
        <p class="kicker" style="margin-top:0">Expanded 포크에서 포팅</p>
        <p>캐릭터가 깨어있고 대기 상태일 때 "야생 배틀?" 알림이 가끔 저절로 뜹니다 — 싸우거나 나중으로 넘길 수 있고, 스탯 카드의 배틀 페이지에서 언제든 직접 시작할 수도 있습니다.</p>
        <ul class="pts">
          <li><strong>공격(ATTACK)</strong> — 약공격(약한 데미지, 더 많이 흘림) / 강공격(세게, 더 노출) 선택</li>
          <li><strong>회피(DODGE)</strong> — 완전 회피 확률, 성공 시 다음 공격 카운터 보너스</li>
          <li><strong>휴식(REST)</strong> — HP 크게 회복 + 데미지 일부 경감, 배틀당 최대 2회</li>
        </ul>
        <p>본가와 동일한 18개 타입 상성이 데미지에 그대로 반영됩니다. 이기면 방금 이긴 상대를 잡을 기회가 주어지고, 승패와 무관하게 박스/도감에는 "잡음"으로 기록됩니다.</p>
        <div class="note plain"><span class="lbl">원정</span><p>캐릭터를 15/30/60분짜리 시간제 여행으로 보내 에너지를 소모하고, 길게 보낼수록 좋은 보상 확률이 올라갑니다. 보상은 간식·영양제·케어 키트·훈련 토큰 4종 중 하나로 원정 페이지의 인벤토리에 쌓입니다.</p></div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">6</span><p class="kicker">Stat Card · 8 Pages</p></div>
        <h2>스탯 카드</h2>
        <p>대기 화면에서 위로 스와이프한 뒤, 좌우로 스와이프해서 8페이지를 넘깁니다.</p>

        {shot("statcard-profile.png", "Stat card profile page for PIKACHU", "스탯 카드 1페이지(프로필) — 이름, 레벨, 배고픔/행복도/청결도. 이름을 탭하면 이름변경 키보드가 열립니다.")}

        <div class="table-wrap"><table>
          <thead><tr><th>#</th><th>페이지</th><th>내용</th></tr></thead>
          <tbody>
            <tr><th>1</th><td>프로필</td><td>이름, 레벨, 배고픔/행복도/청결도 막대</td></tr>
            <tr><th>2</th><td>성격 <span class="m-pill ok" style="margin-left:.3em">Expanded</span></td><td>돌본 방식으로 정해지는 성향, 나이, 미니게임 개인 최고 기록</td></tr>
            <tr><th>3</th><td>데일리 목표 <span class="m-pill ok" style="margin-left:.3em">Expanded</span></td><td>매일 새로 굴리는 목표 3개, 전부 달성 시 보너스</td></tr>
            <tr><th>4</th><td>박스 <span class="m-pill ok" style="margin-left:.3em">Expanded</span></td><td>배틀에서 잡은 야생 개체 목록, 정렬 가능</td></tr>
            <tr><th>5</th><td>배틀</td><td>전투 스탯, 승/패 기록, 야생 배틀·훈련 자루 버튼</td></tr>
            <tr><th>6</th><td>메달</td><td>이정표 달성 배지, 방금 받은 메달은 축하 연출</td></tr>
            <tr><th>7</th><td>진행도</td><td>스트릭, 유대감, 지금까지 키운 모든 캐릭터 누적 메달 수</td></tr>
            <tr><th>8</th><td>원정 <span class="m-pill ok" style="margin-left:.3em">Expanded</span></td><td>원정 시작/보상 수령/아이템 인벤토리</td></tr>
          </tbody>
        </table></div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">7</span><p class="kicker">Pokedex · Cries</p></div>
        <h2>도감, 도감 설명문, 울음소리</h2>
        <p>대기 화면에서 왼쪽으로 스와이프하면 도감 그리드가 열립니다. 전체(ALL) / 키운 것(RAISED) / 잡은 것(CAUGHT) 세 필터로 좁혀볼 수 있습니다.</p>

        {shot("dex-list.png", "Pokedex grid filtered to RAISED", "도감 그리드 — RAISED 필터로 좁힌 상태(이 예시에서는 BULBASAUR와 PIKACHU).")}

        <p>종을 탭하면 2페이지짜리 상세 화면이 열립니다.</p>

        {shot("dex-pikachu.png", "Pokedex detail for PIKACHU with cry button", "도감 상세 1페이지 — 번호/이름/타입 칩, 초상화, 울음소리 재생 버튼, RAISED/CAUGHT 표시. 두 번째 페이지는 도감 설명문.")}

        <div class="note info"><span class="lbl">울음소리 재생</span><p>초상화 아래 캡슐 버튼을 탭하면 짧은 울음소리가 재생되며, 게이지가 도감 마스트헤드와 같은 빨간색으로 차오릅니다. 사운드 파일이 없는 종은 버튼 자체가 안 보입니다. 재생은 <strong>설정의 소리 모드</strong>를 그대로 따르므로, 소리를 꺼두면 울음소리도 재생되지 않습니다.</p></div>
        <div class="note plain"><span class="lbl">도감 설명문</span><p>2페이지에는 실제 게임 도감 문구가 뜹니다 — 스프라이트·울음소리와 마찬가지로 저장소에는 포함돼 있지 않고, 직접 받아와서 <code>Files → On My iPhone → iTamaPoke → mons</code>에 넣거나 Xcode 빌드 시 스크립트로 받아옵니다. 설치 방법은 <a href="INSTALL.html">설치 가이드</a> 참고.</p></div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">8</span><p class="kicker">Evolution · Farewell</p></div>
        <h2>진화와 작별</h2>
        <p>진화 조건(레벨 및 스탯/유대감 기준)을 충족하면 스탯 카드에 진화 버튼이 나타납니다. 항상 선택 사항이며, 거절해도 다음 레벨업 때 계속 물어볼 뿐입니다. 1세대 6종은 세대를 넘어 진화합니다(골뱃→크로뱃, 럭키→해피너스는 레벨 25 / 롱스톤→강철톤, 시드라→킹드라, 스라크→핫삼, 폴리곤→폴리곤2는 레벨 40).</p>
        <p>캐릭터를 길게 누르면 확인을 묻고, 짧은 작별 연출을 재생한 뒤 스타터/알 선택 화면으로 돌아갑니다 — 누적 메달 수와 최고 연속 기록은 계속 이어집니다.</p>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">9</span><p class="kicker">Language · Sound</p></div>
        <h2>언어와 사운드 설정</h2>
        <p>대기 화면에서 아래로 스와이프하면 설정 화면이 열립니다: 시간대/시각, 소리 모드, 언어.</p>

        {shot("settings.png", "Settings screen with SND ALL and EN language pill", "설정 화면 — SET TIME, 소리 모드(SND ALL/MED/LOW/OFF 순환), 언어 핀(8단계: ES/EN/FR/DE/IT/PT/KR/kr).")}

        <ul class="pts">
          <li><strong>소리 버튼</strong> — 단순 켜기/끄기가 아니라 4단계(전체/중간/최소/끔)를 순환. 켜져 있는 동안은 햅틱도 함께 울립니다.</li>
          <li><strong>언어 핀</strong> — ES/EN/FR/DE/IT/PT 6개 언어에 더해, <strong>KR</strong>(UI 전체 한글화)과 <strong>kr</strong>(포켓몬 이름·도감만 한글, 나머지 UI는 영어) 두 가지 한글 모드까지 8단계.</li>
        </ul>
        <p>모든 효과음(탭, 먹기, 진화, 메달, 배틀 타격 등)은 녹음이 아니라 원본 하드웨어처럼 실시간 합성한 칩튠 사운드입니다. 도감의 울음소리만 예외적으로 실제 음원 파일을 재생합니다 — 위 "도감" 섹션 참고.</p>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">10</span><p class="kicker">Numbers</p></div>
        <h2>실제 수치</h2>
        <p style="font-size:.9rem;color:var(--ink-2)">게임 코드(수정하지 않은 원본)에 있는 정확한 숫자입니다.</p>

        <div class="note info"><span class="lbl">레벨업</span><p>실제 1시간마다 레벨 +1 — 순수 시간 기준. 앱을 꺼놔도 시간은 흐르고(최대 2주까지 따라잡음), 다시 열면 그동안의 변화가 한 번에 반영됩니다.</p></div>

        <div class="table-wrap"><table>
          <thead><tr><th>스탯</th><th>분당 감소</th><th>추가 감소</th></tr></thead>
          <tbody>
            <tr><th>FOOD</th><td>−2</td><td></td></tr>
            <tr><th>ENE</th><td>−1</td><td>과체중이면 −1 추가</td></tr>
            <tr><th>HYG</th><td>−1</td><td>눈에 보이는 응가당 −4</td></tr>
            <tr><th>JOY</th><td>−1</td><td>FOOD&lt;30이면 −2, HYG&lt;30이면 −2</td></tr>
          </tbody>
        </table></div>
        <p style="margin-top:.9rem">스탯이 10 이하면 <strong>관리 실패</strong>(진화 1레벨 지연 + 유대감 하락). 이로치 확률은 기본 1/48, 스트릭·유대감이 높으면 최대 약 1/8까지, 작별 직후엔 잠깐 두 배.</p>
      </section>

      <footer>
        작성 기준: iTamaPoke v0.7.1. 원작 게임 로직은 <a href="https://github.com/socquique/TamaPoke">socquique/TamaPoke</a>, 성격·데일리·박스·미니게임 4종·배틀·원정은 <a href="https://github.com/ShadowEnemyx/TamaPoke">ShadowEnemyx/TamaPoke ("Expanded")</a> 포크에서 포팅. 한국어 원본 문서: <a href="GAMEPLAY.ko.md">GAMEPLAY.ko.md</a>.
      </footer>

    </div>
  </div>
  </div>
</div>
'''

script_start = tpl.index("<script>")
script = tpl[script_start:]

out = head + CONTENT + "\n" + script

with open(os.path.join(DOCS, "GAMEPLAY.html"), "w", encoding="utf-8") as f:
    f.write(out)

print("wrote", os.path.join(DOCS, "GAMEPLAY.html"), len(out), "bytes")
