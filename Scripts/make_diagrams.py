#!/usr/bin/env python3
"""Draws the docs' diagrams as SVG, in English and Korean.

These used to be Mermaid blocks. Mermaid renders on GitHub, but its default
look is generic and it gives no control over palette, spacing or emphasis --
next to the game's own screenshots it read as a different project. These are
hand-laid-out instead, in the game's own colours (see Sources/Shared/
TPGraphics.swift's UI enum) with a monospaced face to match its UI.

Written as a generator rather than twelve hand-edited files so the English
and Korean versions can never drift apart in layout, and so a palette or
spacing change is one edit rather than twelve.

Each SVG paints its own background, so it looks the same in GitHub's light
and dark themes rather than leaving dark text on a dark page.

    python3 Scripts/make_diagrams.py        # writes docs/img/diagram-*.svg
"""

import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "docs" / "img"

# --- palette ---------------------------------------------------------------
# The game's UI colours, converted from the RGB565 constants it draws with.
BG      = "#faf5ea"   # UI.bgDay
EDGE    = "#e6dcc8"
INK     = "#2b3550"   # UI.ink
MUTED   = "#8a93a6"   # UI.track
GREEN   = "#4fb06a"   # UI.barOK
BLUE    = "#4a90d9"
RED     = "#e05c5c"   # UI.barBad
AMBER   = "#e2a33d"   # UI.barWarn
VIOLET  = "#8b7bd8"
WHITE   = "#ffffff"

MONO = ("ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,"
        "'Apple SD Gothic Neo','Malgun Gothic','Noto Sans KR',monospace")
SANS = ("-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,"
        "'Apple SD Gothic Neo','Malgun Gothic','Noto Sans KR',sans-serif")


def esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.parts = []

    # -- primitives ---------------------------------------------------------
    def rect(self, x, y, w, h, r=12, fill=WHITE, stroke=None, sw=2, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
            f'fill="{fill}"{s}{d}/>')

    def text(self, x, y, s, size=14, fill=INK, weight="normal", anchor="middle",
             font=MONO, opacity=1):
        o = f' opacity="{opacity}"' if opacity != 1 else ""
        self.parts.append(
            f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}"'
            f'{o}>{esc(s)}</text>')

    def line(self, x1, y1, x2, y2, stroke=MUTED, sw=2, dash=None, arrow=True):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        a = ' marker-end="url(#ah)"' if arrow else ""
        self.parts.append(
            f'<path d="M{x1} {y1} L{x2} {y2}" fill="none" stroke="{stroke}" '
            f'stroke-width="{sw}" stroke-linecap="round"{d}{a}/>')

    def elbow(self, x1, y1, x2, y2, stroke=MUTED, sw=2, dash=None, arrow=True):
        """Right-angled connector: down from the source, across, into the target."""
        my = (y1 + y2) / 2
        d = f' stroke-dasharray="{dash}"' if dash else ""
        a = ' marker-end="url(#ah)"' if arrow else ""
        self.parts.append(
            f'<path d="M{x1} {y1} L{x1} {my} L{x2} {my} L{x2} {y2}" fill="none" '
            f'stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" '
            f'stroke-linecap="round"{d}{a}/>')

    # -- composites ---------------------------------------------------------
    def card(self, x, y, w, h, lines, accent=INK, fill=WHITE, star=False,
             muted_from=1, size=14, dash=None):
        """A node: coloured left bar, title line, then dimmer detail lines."""
        self.rect(x, y, w, h, 12, fill, accent, 2, dash)
        self.parts.append(
            f'<path d="M{x+1} {y+13} L{x+1} {y+h-13}" stroke="{accent}" '
            f'stroke-width="5" stroke-linecap="round"/>')
        n = len(lines)
        step = 19 if size >= 14 else 17
        top = y + h / 2 - (n - 1) * step / 2 + size / 3
        for i, ln in enumerate(lines):
            self.text(x + w / 2 + 4, top + i * step, ln,
                      size=size if i < muted_from else size - 2,
                      fill=INK if i < muted_from else MUTED,
                      weight="bold" if i < muted_from else "normal")
        if star:
            self.parts.append(
                f'<circle cx="{x + w - 15}" cy="{y + 15}" r="11" fill="{accent}"/>')
            self.text(x + w - 15, y + 20, "★", size=13, fill=WHITE, weight="bold")

    def diamond(self, cx, cy, w, h, lines, accent=INK):
        self.parts.append(
            f'<path d="M{cx} {cy-h/2} L{cx+w/2} {cy} L{cx} {cy+h/2} L{cx-w/2} {cy} Z" '
            f'fill="{WHITE}" stroke="{accent}" stroke-width="2" stroke-linejoin="round"/>')
        n = len(lines)
        top = cy - (n - 1) * 17 / 2 + 5
        for i, ln in enumerate(lines):
            self.text(cx, top + i * 17, ln, size=13, weight="bold")

    def label(self, x, y, s, size=12, fill=MUTED, anchor="middle"):
        """Edge label on a small plate, so it stays readable over a line."""
        wid = max(len(s) * (size * 0.62), 20) + 12
        self.rect(x - wid / 2, y - size + 1, wid, size + 8, 5, BG, None, 0)
        self.text(x, y + 4, s, size=size, fill=fill, anchor=anchor, font=SANS)

    def title(self, x, y, s):
        self.text(x, y, s, size=13, fill=MUTED, weight="bold", anchor="start",
                  font=SANS)

    def svg(self):
        body = "\n  ".join(self.parts)
        return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" role="img">
  <defs>
    <marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7"
            markerHeight="7" orient="auto-start-reverse">
      <path d="M0 1 L9 5 L0 9 z" fill="{MUTED}"/>
    </marker>
  </defs>
  <rect x="0" y="0" width="{self.w}" height="{self.h}" rx="18" fill="{BG}" stroke="{EDGE}" stroke-width="2"/>
  {body}
</svg>
"""


def write(name, canvas):
    p = OUT / f"{name}.svg"
    p.write_text(canvas.svg(), encoding="utf-8")
    print(f"wrote {p.relative_to(OUT.parent.parent)}  ({canvas.w}x{canvas.h})")


# --- diagram 1: overview (README) -----------------------------------------
def overview(t):
    c = Canvas(880, 330)
    c.title(24, 30, t["title"])
    # left: your fork
    c.rect(24, 48, 250, 200, 14, "#fffdf7", EDGE, 2, "6 5")
    c.text(149, 72, t["fork_group"], size=12, fill=MUTED, weight="bold", font=SANS)
    c.card(44, 88, 210, 58, [t["fork"], t["fork_sub"]], VIOLET)
    c.card(44, 166, 210, 58, [t["build"], t["build_sub"]], VIOLET)
    c.line(149, 146, 149, 160)
    # outputs
    c.card(350, 60, 216, 62, [t["web"], t["web_sub"]], GREEN, star=True)
    c.card(350, 140, 216, 62, [t["apk"], t["apk_sub"]], BLUE)
    c.card(350, 220, 216, 62, [t["ipa"], t["ipa_sub"]], MUTED, dash="5 4")
    # fan out from the right edge of the fork group, not from inside it
    for y in (91, 171, 251):
        c.elbow(278, 195, 346, y)
    # assets, feeding all three from the right
    c.card(632, 108, 224, 92,
           [t["mons"], t["mons_1"], t["mons_2"], t["mons_3"]], AMBER,
           fill="#fdf6e6")
    for y in (91, 171, 251):
        c.line(628, 154, 572, y)
    c.text(440, 312, t["foot"], size=12, fill=MUTED, font=SANS)
    return c


# --- diagram 2: which path (INSTALL) --------------------------------------
def paths(t):
    c = Canvas(880, 452)
    c.title(24, 30, t["title"])
    c.diamond(180, 100, 250, 92, [t["q1"], t["q1b"]], INK)
    c.card(620, 64, 230, 72, [t["b"], t["b1"], t["b2"]], BLUE)
    c.line(305, 92, 616, 96)
    c.label(460, 84, t["yes"])
    c.diamond(180, 274, 250, 92, [t["q2"], t["q2b"]], INK)
    c.line(180, 146, 180, 226)
    c.label(180, 188, t["no"])
    c.card(408, 168, 210, 78, [t["d"], t["d1"], t["d2"]], GREEN, star=True)
    c.card(408, 264, 210, 62, [t["a"], t["a1"]], AMBER)
    c.card(408, 344, 210, 62, [t["c"], t["c1"]], VIOLET)
    c.line(306, 262, 404, 207)
    c.line(306, 274, 404, 295)
    c.line(306, 288, 404, 375)
    # sits beside the recommended card rather than floating above it
    c.text(636, 213, t["best"], size=13, fill=GREEN, weight="bold",
           anchor="start", font=SANS)
    # notes go under the diamonds, where nothing else is
    c.text(40, 384, t["note"], size=12, fill=MUTED, anchor="start", font=SANS)
    c.text(40, 406, t["note2"], size=12, fill=MUTED, anchor="start", font=SANS)
    return c


# --- diagram 3: Path D flow ------------------------------------------------
def pathd(t):
    c = Canvas(880, 250)
    c.title(24, 30, t["title"])
    steps = [(t["s1"], t["s1b"], VIOLET), (t["s2"], t["s2b"], VIOLET),
             (t["s3"], t["s3b"], BLUE)]
    for i, (a, b, col) in enumerate(steps):
        x = 24 + i * 292
        c.card(x, 52, 254, 66, [f"{i+1}. {a}", b], col)
        if i < 2:
            c.line(x + 258, 85, x + 288, 85)
    steps2 = [(t["s4"], t["s4b"], BLUE), (t["s5"], t["s5b"], AMBER),
              (t["s6"], t["s6b"], GREEN)]
    for i, (a, b, col) in enumerate(steps2):
        x = 24 + i * 292
        c.card(x, 152, 254, 66, [f"{i+4}. {a}", b], col)
        if i < 2:
            c.line(x + 258, 185, x + 288, 185)
    # No wrap connector between the rows: drawn as a bracket it reads as a
    # rule across the whole diagram. The numbering carries the order.
    return c


# --- diagram 4: where things are stored ------------------------------------
def storage(t):
    c = Canvas(880, 340)
    c.title(24, 30, t["title"])
    c.rect(24, 46, 402, 268, 16, "#fffdf7", EDGE, 2, "6 5")
    c.text(225, 70, t["phone"], size=12, fill=MUTED, weight="bold", font=SANS)
    c.card(44, 86, 362, 76, [t["icon"], t["icon_1"], t["icon_2"]], GREEN, star=True)
    c.card(44, 196, 362, 76, [t["tab"], t["tab_1"], t["tab_2"]], RED, dash="6 4")
    c.parts.append(
        f'<path d="M225 168 L225 190" stroke="{RED}" stroke-width="2" '
        f'stroke-dasharray="4 5"/>')
    c.label(225, 182, t["never"], fill=RED)
    c.card(536, 100, 320, 140,
           [t["files"], t["f1"], t["f2"], t["f3"], t["f4"]], AMBER,
           fill="#fdf6e6")
    # in: files picked from the folder; out: the save exported back to it
    c.line(532, 126, 414, 112)
    c.label(478, 98, t["load"], size=11)
    c.line(414, 146, 532, 196)
    c.label(478, 186, t["save"], size=11)
    c.text(440, 330, t["foot"], size=12, fill=MUTED, font=SANS)
    return c


# --- diagram 5: Apple Watch / developer account ----------------------------
def watch(t):
    c = Canvas(880, 330)
    c.title(24, 30, t["title"])
    c.diamond(150, 110, 240, 88, [t["q"], t["qb"]], INK)
    c.card(336, 62, 280, 78, [t["reg"], t["reg1"], t["reg2"]], BLUE)
    c.card(644, 70, 212, 62, [t["ok"], t["ok1"]], GREEN)
    c.line(272, 92, 332, 96)
    c.label(302, 74, t["paid"], size=11, fill=BLUE)
    c.line(620, 101, 640, 101)
    c.card(336, 178, 280, 78, [t["free"], t["free1"], t["free2"]], AMBER)
    c.line(272, 126, 332, 200)
    c.label(300, 152, t["nopaid"], size=11, fill=AMBER)
    c.card(336, 272, 306, 56, [t["never"], t["never2"]], RED, dash="6 4")
    c.line(272, 140, 332, 296)
    c.text(646, 190, t["note"], size=12, fill=MUTED, anchor="start", font=SANS)
    c.text(646, 212, t["note2"], size=12, fill=MUTED, anchor="start", font=SANS)
    c.text(646, 234, t["note3"], size=12, fill=MUTED, anchor="start", font=SANS)
    return c


# --- diagram 6: Path A flow ------------------------------------------------
def patha(t):
    c = Canvas(880, 250)
    c.title(24, 30, t["title"])
    row1 = [(t["s1"], t["s1b"]), (t["s2"], t["s2b"]), (t["s3"], t["s3b"])]
    for i, (a, b) in enumerate(row1):
        x = 24 + i * 292
        c.card(x, 52, 254, 66, [f"{i+1}. {a}", b], AMBER)
        if i < 2:
            c.line(x + 258, 85, x + 288, 85)
    row2 = [(t["s4"], t["s4b"]), (t["s5"], t["s5b"]), (t["s6"], t["s6b"])]
    for i, (a, b) in enumerate(row2):
        x = 24 + i * 292
        col = RED if i == 2 else AMBER
        c.card(x, 152, 254, 66, [f"{i+4}. {a}", b], col)
        if i < 2:
            c.line(x + 258, 185, x + 288, 185)
    return c


EN = {
    "overview": dict(
        title="HOW A COPY GETS BUILT",
        fork_group="YOUR FORK  (once)",
        fork="Fork", fork_sub="your own copy on GitHub",
        build="Build workflow", build_sub="GitHub compiles it for you",
        web="Web app", web_sub="iPhone · iPad · desktop",
        apk="Android .apk", apk_sub="install and play",
        ipa="iOS .ipa", ipa_sub="paths A / B / C · signing",
        mons="mons folder", mons_1="sprites · cries · dex text",
        mons_2="you supply them", mons_3="never hosted, never shipped",
        foot="No creature art is in the repository or in anything published."),
    "paths": dict(
        title="WHICH PATH SHOULD I TAKE?",
        q1="Paid Apple Developer", q1b="account?",
        yes="yes", no="no  (most people)",
        b="Path B", b1="signed .ipa", b2="no re-signing for a year",
        q2="What do you", q2b="want?",
        d="Path D", d1="web app / Android", d2="no Mac, never expires",
        a="Path A", a1="free sideloading, 7 days",
        c="Path C", c1="build in Xcode, Watch too",
        best="start here",
        note="Every path installs without creature art —",
        note2="you add it yourself afterwards."),
    "pathd": dict(
        title="PATH D, END TO END",
        s1="Fork", s1b="your own copy on GitHub",
        s2="Enable Pages", s2b="Settings → Pages → Actions",
        s3="Run the workflow", s3b="Build (browser), about 5 min",
        s4="Your own link", s4b="username.github.io/iTamaPoke",
        s5="Install on the phone", s5b="Add to Home Screen, or the APK",
        s6="Load the mons folder", s6b="then it plays offline"),
    "storage": dict(
        title="WHERE THINGS ARE KEPT",
        phone="ON THE PHONE",
        icon="Home-screen icon", icon_1="the app: save + sprites + cries",
        icon_2="load your files here",
        tab="The same link in a browser tab",
        tab_1="a separate app as far as storage goes",
        tab_2="its own save, its own sprites",
        never="never shared",
        files="Files › On My iPhone › mons",
        f1="p001.bin … sprites", f2="psnd001.m4a … cries",
        f3="dex_entries_ko.txt … dex text",
        f4="iTamaPoke-save.tpsave … backup",
        load="Load sprites…", save="Save file…",
        foot="Loaded files live in the app, not in the folder — the folder is only where you pick them from."),
    "watch": dict(
        title="APPLE WATCH: WHAT DECIDES IT",
        q="Want it on the", qb="Apple Watch?",
        paid="paid account", nopaid="free Apple ID",
        reg="Register the devices", reg1="UDIDs in the developer portal",
        reg2="or connect each to Xcode once",
        ok="Path B or C", ok1="no re-signing for a year",
        free="Path C only", free1="Xcode registers them for you",
        free2="⌘R again every 7 days",
        never="Path A can't reach the Watch",
        never2="sideloading cannot sign the watch app",
        note="A signed build installs only on devices",
        note2="whose UDID is in its profile — and the",
        note3="workflow cannot register them for you."),
    "patha": dict(
        title="PATH A, END TO END",
        s1="Download the .ipa", s1b="Actions → Build (unsigned)",
        s2="Install the tool", s2b="Sideloadly or AltStore",
        s3="Sign and install", s3b="with your own Apple ID",
        s4="Trust the developer", s4b="Settings → General → VPN & Device",
        s5="Add the mons folder", s5b="Files → On My iPhone → iTamaPoke",
        s6="Renew every 7 days", s6b="free Apple IDs expire"),
}

KO = {
    "overview": dict(
        title="사본이 만들어지는 과정",
        fork_group="내 fork  (한 번만)",
        fork="Fork", fork_sub="GitHub에 내 사본 만들기",
        build="Build 워크플로", build_sub="GitHub가 대신 빌드",
        web="웹앱", web_sub="아이폰 · 아이패드 · 데스크톱",
        apk="안드로이드 .apk", apk_sub="설치해서 바로 플레이",
        ipa="iOS .ipa", ipa_sub="경로 A / B / C · 서명 필요",
        mons="mons 폴더", mons_1="스프라이트 · 울음소리 · 도감문",
        mons_2="본인이 직접 준비", mons_3="호스팅도 배포도 하지 않음",
        foot="캐릭터 그림은 저장소에도, 배포되는 어떤 결과물에도 들어 있지 않습니다."),
    "paths": dict(
        title="어느 경로로 가야 하나요?",
        q1="유료 Apple Developer", q1b="계정이 있나요?",
        yes="있음", no="없음  (대부분)",
        b="경로 B", b1="서명된 .ipa", b2="1년간 재서명 불필요",
        q2="무엇을", q2b="원하나요?",
        d="경로 D", d1="웹앱 / 안드로이드", d2="Mac 불필요, 만료 없음",
        a="경로 A", a1="무료 사이드로딩, 7일",
        c="경로 C", c1="Xcode 빌드, 워치까지",
        best="처음이라면 이것",
        note="어느 경로든 캐릭터 그림 없이 설치되고,",
        note2="그림은 설치 후 직접 넣습니다."),
    "pathd": dict(
        title="경로 D 전체 흐름",
        s1="Fork", s1b="GitHub에 내 사본 만들기",
        s2="Pages 켜기", s2b="Settings → Pages → Actions",
        s3="워크플로 실행", s3b="Build (browser), 약 5분",
        s4="내 링크 생성", s4b="내아이디.github.io/iTamaPoke",
        s5="폰에 설치", s5b="홈 화면에 추가, 또는 APK",
        s6="mons 폴더 넣기", s6b="이후 오프라인으로 플레이"),
    "storage": dict(
        title="무엇이 어디에 저장되나",
        phone="폰 안",
        icon="홈 화면 아이콘", icon_1="앱 본체: 세이브 + 스프라이트 + 울음소리",
        icon_2="파일은 여기서 넣습니다",
        tab="같은 링크를 브라우저 탭으로 연 것",
        tab_1="저장 공간 기준으로는 별개의 앱",
        tab_2="세이브도 스프라이트도 따로",
        never="서로 공유 안 됨",
        files="파일 › 나의 iPhone › mons",
        f1="p001.bin … 스프라이트", f2="psnd001.m4a … 울음소리",
        f3="dex_entries_ko.txt … 도감 설명문",
        f4="iTamaPoke-save.tpsave … 백업",
        load="Load sprites…", save="Save file…",
        foot="넣은 파일은 폴더가 아니라 앱 안에 저장됩니다. 폴더는 고르는 출처일 뿐입니다."),
    "watch": dict(
        title="애플워치: 무엇이 갈리는가",
        q="애플워치에도", qb="넣고 싶다",
        paid="유료 계정", nopaid="무료 Apple ID",
        reg="기기를 먼저 등록", reg1="포털에 아이폰·워치 UDID 등록",
        reg2="또는 Xcode에 한 번씩 연결",
        ok="경로 B 또는 C", ok1="1년간 재서명 불필요",
        free="경로 C만 가능", free1="Xcode가 개인 팀에 자동 등록",
        free2="7일마다 ⌘R 다시",
        never="경로 A는 워치에 못 넣음",
        never2="사이드로딩은 워치 앱을 서명하지 못함",
        note="서명된 빌드는 프로파일에 UDID가 든",
        note2="기기에만 설치됩니다. 워크플로는 기기를",
        note3="대신 등록해 주지 못합니다."),
    "patha": dict(
        title="경로 A 전체 흐름",
        s1=".ipa 다운로드", s1b="Actions → Build (unsigned)",
        s2="도구 설치", s2b="Sideloadly 또는 AltStore",
        s3="서명하고 설치", s3b="본인 Apple ID로",
        s4="개발자 신뢰", s4b="설정 → 일반 → VPN 및 기기 관리",
        s5="mons 폴더 넣기", s5b="파일 → 나의 iPhone → iTamaPoke",
        s6="7일마다 갱신", s6b="무료 Apple ID는 만료됨"),
}

BUILDERS = {"overview": overview, "paths": paths, "pathd": pathd,
            "storage": storage, "watch": watch, "patha": patha}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in BUILDERS.items():
        write(f"diagram-{name}", build(EN[name]))
        write(f"diagram-{name}.ko", build(KO[name]))
