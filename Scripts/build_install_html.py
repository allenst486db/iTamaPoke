#!/usr/bin/env python3
"""One-off build script: assembles docs/INSTALL.html from the mosikdo-guide
template. Companion to build_gameplay_html.py — run by hand when the
install steps or screenshot change."""
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
head = head.replace("<title>모식도 가이드 — 제목을 여기에</title>",
                     "<title>iTamaPoke Install Guide</title>")

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
      <div class="tb-title">설치 가이드 — iTamaPoke v0.8.0</div>
      <button type="button" class="toc-btn" aria-label="목차 토글">
        <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M2 4h12M2 8h12M2 12h8" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>
      </button>
    </div>

    <div class="content">

      <header>
        <p class="eyebrow">INSTALL GUIDE · v0.8.0</p>
        <h1>iTamaPoke 설치 가이드</h1>
        <p class="lede">코딩 지식 없이도 따라올 수 있게 쓴 설치 안내입니다. 세 가지 경로 중 본인 상황에 맞는 걸 고르세요.</p>
      </header>

      <section>
        <div class="sec-head"><span class="sec-num">1</span><p class="kicker">Which Path</p></div>
        <h2>어느 경로로 가야 하나요</h2>
        <div class="cards">
          <div class="cd"><div class="t">경로 A · 무료</div><div class="d">Sideloadly/AltStore로 사이드로딩. 7일마다 재서명 필요. 애플워치 앱은 없음.</div></div>
          <div class="cd"><div class="t">경로 B · 유료</div><div class="d">Apple Developer 계정($99/년)으로 서명 — 재서명 걱정 없음, 애플워치도 가능.</div></div>
          <div class="cd"><div class="t">경로 C · Xcode 빌드</div><div class="d">맥 + Xcode 필요. 스프라이트를 빌드에 바로 넣을 수 있고, 애플워치 연결이 가장 안정적.</div></div>
          <div class="cd"><div class="t">경로 D · 브라우저 빌드</div><div class="d">iOS/워치 앱과 별개인 웹 버전. 목적은 본인 폰/태블릿에 앱으로 설치하는 것 — 네이티브 셸로 감싸서, 공개 배포는 안 함.</div></div>
        </div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">2</span><p class="kicker">Path A</p></div>
        <h2>경로 A — 무료 설치</h2>
        <ol class="pts" style="list-style:decimal;padding-left:1.2rem">
        </ol>
        <div class="method">
          <div class="m-head"><span class="m-badge">1</span><h3 style="margin:0">앱 파일 다운로드</h3></div>
          <p class="m-desc">GitHub Releases에서 <code>.ipa</code> 파일을 받습니다. 워치 없이 아이폰만 쓸 거면 iPhone-only 파일로 충분합니다.</p>
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge">2</span><h3 style="margin:0">사이드로딩 도구 설치</h3></div>
          <p class="m-desc">Sideloadly(Mac/Windows) 또는 AltStore 중 하나를 맥/PC에 설치합니다.</p>
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge">3</span><h3 style="margin:0">서명하고 설치</h3></div>
          <p class="m-desc">Apple ID로 로그인해서 <code>.ipa</code>를 아이폰에 설치합니다.</p>
        </div>
        <div class="method">
          <div class="m-head"><span class="m-badge">4</span><h3 style="margin:0">아이폰에서 신뢰</h3></div>
          <p class="m-desc">설정 → 일반 → VPN 및 기기 관리에서 본인 Apple ID 프로파일을 신뢰 처리합니다.</p>
        </div>
        <div class="note warn"><span class="lbl">7일마다</span><p>무료 계정 서명은 7일마다 만료됩니다 — Sideloadly/AltServer로 재서명해야 계속 쓸 수 있습니다.</p></div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">3</span><p class="kicker">Creature Art · Dex · Cries</p></div>
        <h2>스프라이트 · 도감 설명문 · 울음소리 넣기</h2>
        <p>앱은 <strong>Pokémon 아트/텍스트/음원을 하나도 담지 않은 채</strong> 설치됩니다 — 라이선스 때문에 각자 받아서 넣는 구조입니다. 세 가지 다 같은 <code>mons</code> 폴더에 들어갑니다.</p>
        <ol style="padding-left:1.2rem;color:var(--ink-2);font-size:.94rem;line-height:1.7">
          <li>아이폰 <strong>파일</strong> 앱 → <strong>내 iPhone → iTamaPoke</strong> 안에 <code>mons</code> 폴더를 만듭니다.</li>
          <li>스프라이트(<code>.bin</code>), 도감 설명문(<code>dex_entries_&lt;언어&gt;.txt</code>), 울음소리(<code>psnd&lt;번호&gt;.m4a</code>)를 그 폴더에 넣습니다.</li>
          <li>앱을 완전히 종료했다가 다시 엽니다.</li>
        </ol>
        <div class="note ok"><span class="lbl">Xcode로 빌드한다면</span><p><code>Scripts/fetch_assets.sh</code> 한 번으로 스프라이트·이로치·울음소리를 전부 받아 빌드에 바로 포함시킬 수 있습니다(아래 경로 C 참고).</p></div>

        {shot("dex-detail.png", "Pokedex detail confirming art, dex entry and cry are installed", "정상 설치됐을 때 도감 상세화면 — 초상화·타입·울음소리 재생 버튼이 전부 나옵니다.")}
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">4</span><p class="kicker">Path C</p></div>
        <h2>경로 C — Xcode로 직접 빌드</h2>
        <p>이미 맥에 Xcode가 있고 터미널 명령 몇 줄이 부담 없다면 가장 확실한 경로입니다. 애플워치 연동도 이 경로가 가장 안정적입니다.</p>

        <div class="termwin">
          <div class="termbar"><span class="dots"></span><span class="tt">Terminal</span></div>
          <pre class="term"><span class="c"># 저장소 클론</span>
<span class="k">git</span> clone --recurse-submodules &lt;저장소 URL&gt;
<span class="k">cd</span> iTamaPoke
<span class="k">brew</span> install xcodegen ffmpeg

<span class="c"># 스프라이트 + 이로치 + 울음소리, 전체 종</span>
<span class="k">Scripts/fetch_assets.sh</span>

<span class="k">xcodegen</span> generate
<span class="k">open</span> TamaPoke.xcodeproj</pre>
        </div>

        <div class="note info"><span class="lbl">에셋 없이도 빌드는 됨</span><p>위 <code>fetch_assets.sh</code> 단계를 건너뛰고 빌드해도 앱은 정상 실행됩니다 — 스프라이트/도감 설명문/울음소리가 빠진 채로 시작할 뿐이고, 나중에 파일 앱으로 넣거나 다시 스크립트를 돌리면 됩니다.</p></div>

        <p>Xcode에서: <strong>TamaPoke</strong> 타겟 → Signing &amp; Capabilities → Automatically manage signing 켜기 → 본인 Apple ID를 팀으로 선택. <strong>TamaPokeWatch</strong>도 동일하게. 아이폰을 연결하고 실행 대상으로 고른 뒤 ⌘R.</p>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">5</span><p class="kicker">Path D</p></div>
        <h2>경로 D — 브라우저 빌드, 본인 폰/태블릿에 설치</h2>
        <p><code>browser_ver/</code>는 같은 게임 로직을 WebAssembly로 컴파일해서 웹페이지에서 돌리는 완전히 별도의 빌드입니다. iOS/워치 앱과 세이브 데이터를 공유하지 않고, <strong>공개 배포하지 않습니다</strong>(<a href="../LICENSE">LICENSE</a> 참고). <strong>이 경로의 목적은 본인 iPhone/iPad나 안드로이드 기기에 실제 앱으로 설치하는 것</strong>이지 컴퓨터 브라우저에서만 쓰는 게 아닙니다 — 딱 한 번 컴퓨터에서 빌드해야 하는 건 맞지만(iOS 셸은 Mac, 안드로이드는 아무 OS나), 그 결과물은 이후 폰 안에서만 온전히 실행됩니다.</p>

        <div class="method">
          <div class="m-head"><span class="m-badge">1</span><h3 style="margin:0">웹 코어 빌드 (컴퓨터에서, 한 번만)</h3></div>
          <div class="termwin">
            <div class="termbar"><span class="dots"></span><span class="tt">Terminal</span></div>
            <pre class="term"><span class="c"># Emscripten SDK가 필요합니다 (한 번만)</span>
<span class="k">git</span> clone --depth 1 https://github.com/emscripten-core/emsdk.git
<span class="k">cd</span> emsdk &amp;&amp; ./emsdk install latest &amp;&amp; ./emsdk activate latest
<span class="k">source</span> ./emsdk_env.sh
<span class="k">cd</span> /path/to/iTamaPoke

<span class="c"># 코어 빌드 -&gt; browser_ver/web/tp_core.{{js,wasm}}</span>
<span class="k">browser_ver/build.sh</span></pre>
          </div>
          <p style="font-size:.9rem;color:var(--ink-2)"><code>emsdk</code>는 Python 3.10+가 필요합니다 — 시스템 Python이 더 오래됐다면 <a href="https://github.com/astral-sh/python-build-standalone">astral-sh/python-build-standalone</a>의 이식용 빌드로 <code>emsdk.py</code>만 실행하면 됩니다(그 뒤로는 Emscripten 자체 Python을 씁니다).</p>
        </div>

        <div class="method">
          <div class="m-head"><span class="m-badge">2</span><h3 style="margin:0">폰에 올리기 — 네이티브 셸</h3></div>
          <p class="m-desc"><code>browser_ver/native/</code>에 다 준비돼 있습니다. <strong>iOS/iPadOS</strong>: Xcode에서 <code>TamaPoke.xcodeproj</code> 열기 → File → New → Target… → iOS App → <code>browser_ver/native/ios/WebShellApp.swift</code>와 그 폴더의 <code>Info.plist</code>를 새 타깃에 드래그 → <code>browser_ver/web</code> 폴더 전체를 <strong>폴더 참조로</strong>(파란 폴더 아이콘, 그룹 아님) 드래그 → 연결된 본인 iPhone/iPad에서 빌드·실행(본체 앱과 동일). <strong>안드로이드</strong>: <code>browser_ver/native/android/</code>를 Android Studio에서 바로 열기 → <code>browser_ver/web/</code>을 <code>app/src/main/assets/web/</code>에 복사 → 연결된 본인 폰에서 실행. 둘 다 서버 없이 로컬 파일만 읽습니다. 자세한 절차는 <code>browser_ver/native/README.md</code>.</p>
          <div class="note ok"><span class="lbl">여기까지 하면</span><p>폰에 앱으로 설치된 상태입니다. 아래 스프라이트·도감 설명문은 컴퓨터 브라우저에서든 설치된 앱 안에서든 똑같이, 한 번씩만 직접 골라 넣으면 됩니다.</p></div>
        </div>

        <div class="method">
          <div class="m-head"><span class="m-badge">3</span><h3 style="margin:0">컴퓨터에서 미리 보기 (선택, 이 경로의 목적은 아님)</h3></div>
          <div class="termwin">
            <div class="termbar"><span class="dots"></span><span class="tt">Terminal</span></div>
            <pre class="term"><span class="c"># 로컬 서버로 열기 (file://는 안 됨 — WASM 스트리밍 로드 때문)</span>
<span class="k">cd</span> browser_ver/web &amp;&amp; python3 -m http.server 8123
<span class="c"># 그 다음 컴퓨터 브라우저에서 http://localhost:8123</span></pre>
          </div>
        </div>

        <div class="method">
          <div class="m-head"><span class="m-badge">4</span><h3 style="margin:0">스프라이트 넣기 (자세히)</h3></div>
          <p class="m-desc">iOS처럼 파일 앱에 넣는 게 아니라, <strong>앱 화면 안에서 직접 파일을 고릅니다.</strong></p>
          <ol style="padding-left:1.2rem;color:var(--ink-2);font-size:.92rem;line-height:1.7">
            <li>아무 컴퓨터에서 <code>Scripts/fetch_sprites.sh</code>로 <code>.bin</code> 파일들을 받습니다 — Path C의 <code>fetch_assets.sh</code>와 같은 스크립트, 결과물도 동일한 <code>p&lt;도감번호&gt;.bin</code>/<code>ps&lt;도감번호&gt;.bin</code>(이로치) 파일들입니다.</li>
            <li>그 파일들을 실제로 앱을 쓸 기기로 옮깁니다 — 같은 컴퓨터면 이미 거기 있는 거고, 2단계에서 만든 네이티브 셸이 깔린 폰이라면 AirDrop·케이블·클라우드 드라이브 등 파일 옮기는 아무 방법이나 쓰면 됩니다(경로 A의 5단계에서 iOS 앱에 스프라이트 넣는 것과 같은 원리).</li>
            <li>앱 화면 우측 상단의 <strong>"Load sprites…"</strong> 버튼을 누릅니다.</li>
            <li>파일 선택 창에서 받아둔 <code>.bin</code> 파일들을 <strong>전부 다중 선택</strong>해서 엽니다 — 폴더째 드래그가 아니라 파일 여러 개를 직접 골라야 합니다(iOS Safari가 폴더 선택을 불안정하게 지원해서 일부러 이 방식을 씀).</li>
            <li>고른 파일은 그 기기의 <strong>IndexedDB</strong>(로컬 저장소)에 저장되고, 다음에 열 때도 그대로 남아 있습니다 — 매번 다시 고를 필요 없습니다.</li>
            <li>다른 파일을 다시 고르면 같은 도감번호 파일은 덮어씌워집니다. 별도로 지울 필요 없이 새로 고르기만 하면 됩니다.</li>
          </ol>
          <div class="note ok"><span class="lbl">기기 갈아탈 때</span><p>브라우저를 바꾸거나(사파리→크롬), 시크릿/프라이빗 모드로 열거나, 사이트 데이터를 지우면 IndexedDB도 같이 비워집니다 — 그때는 "Load sprites…"로 다시 골라주면 됩니다. <code>.bin</code> 파일 자체는 원래 있던 곳에 그대로 있으니 다시 고르기만 하면 되고, 인터넷 어디로도 업로드되지 않습니다.</p></div>
        </div>

        <div class="method">
          <div class="m-head"><span class="m-badge">5</span><h3 style="margin:0">도감 설명문 넣기 (선택)</h3></div>
          <p class="m-desc"><code>Scripts/fetch_dex_entries.sh</code>로 받은 <code>dex_entries_&lt;언어&gt;.txt</code> 파일을, 화면의 <strong>"Load dex text…"</strong> 버튼으로 똑같이 다중 선택해서 넣습니다. 도감 상세화면 두 번째 페이지(점 두 개 중 오른쪽)에 나타납니다.</p>
        </div>

        <div class="note warn"><span class="lbl">iOS/워치 앱과는 별개</span><p>세이브 데이터, 스프라이트, 도감 설명문 전부 iOS 앱과 공유되지 않습니다 — 완전히 독립된 빌드입니다. 게임 로직(수치·확률·진화 조건 등)은 동일한 C++ 코드를 그대로 컴파일한 것이라 100% 같습니다.</p></div>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">6</span><p class="kicker">Asset Script Options</p></div>
        <h2><code>fetch_assets.sh</code> 옵션</h2>
        <div class="termwin">
          <div class="termbar"><span class="dots"></span><span class="tt">Terminal</span></div>
          <pre class="term"><span class="c"># 전체 종, 전체 에셋(기본값)</span>
<span class="k">Scripts/fetch_assets.sh</span>

<span class="c"># 특정 종만(예: 1, 4, 7번)</span>
<span class="k">Scripts/fetch_assets.sh</span> 1 4 7

<span class="c"># 울음소리만</span>
<span class="k">Scripts/fetch_assets.sh</span> --only sound

<span class="c"># 일반 스프라이트 + 이로치만, 25번(피카츄)만</span>
<span class="k">Scripts/fetch_assets.sh</span> --only sprites,shiny 25 25</pre>
        </div>
        <p style="font-size:.9rem;color:var(--ink-2)">내부적으로 <code>fetch_sprites.sh</code>(일반) · <code>pack_normal_sprites.py</code>(2·3세대 일반) · <code>pack_shiny_sprites.py</code>(이로치) · <code>fetch_cries.sh</code>(울음소리, <code>ffmpeg</code> 필요)를 필요한 것만 골라 호출하는 얇은 래퍼입니다.</p>
      </section>

      <section>
        <div class="sec-head"><span class="sec-num">7</span><p class="kicker">Troubleshooting</p></div>
        <h2>막히는 부분</h2>
        <div class="check">
          <div class="ck"><span class="box">!</span><div><strong>도감 화면이 텅 비어있다</strong> — <code>thumbs.bin</code>이 <code>mons</code> 폴더에 없는 경우입니다. 스프라이트와 같이 받아지는 파일이니 빠뜨리지 않았는지 확인하세요.</div></div>
          <div class="ck"><span class="box">!</span><div><strong>울음소리 재생 버튼이 안 보인다</strong> — 그 종의 <code>psnd&lt;번호&gt;.m4a</code>가 없는 상태입니다. 파일이 없으면 버튼 자체가 숨겨지는 게 정상 동작입니다.</div></div>
          <div class="ck"><span class="box">!</span><div><strong>시뮬레이터/기기에서 소리가 안 들린다</strong> — 설정 화면의 소리 모드가 OFF는 아닌지, 기기 자체 볼륨이 음소거는 아닌지 먼저 확인하세요.</div></div>
          <div class="ck"><span class="box">!</span><div><strong>울음소리 받아오기가 <code>ffmpeg</code> 오류로 멈춘다</strong> — <code>brew install ffmpeg</code>로 설치 후 다시 실행하세요. PokéAPI가 내려주는 <code>.ogg</code>를 iOS가 재생 가능한 <code>.m4a</code>로 변환하는 데 필요합니다.</div></div>
        </div>
      </section>

      <footer>
        작성 기준: iTamaPoke v0.8.0. 한국어 원본 문서: <a href="INSTALL.ko.md">INSTALL.ko.md</a>. 게임 조작법은 <a href="GAMEPLAY.html">게임 설명서</a> 참고.
      </footer>

    </div>
  </div>
  </div>
</div>
'''

script_start = tpl.index("<script>")
script = tpl[script_start:]

out = head + CONTENT + "\n" + script

with open(os.path.join(DOCS, "INSTALL.html"), "w", encoding="utf-8") as f:
    f.write(out)

print("wrote", os.path.join(DOCS, "INSTALL.html"), len(out), "bytes")
