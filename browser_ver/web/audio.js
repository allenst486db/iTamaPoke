// Chip-tune SFX synth, ported from Sources/Shared/TPAudio.swift (itself
// translated from the ShadowEnemyx/TamaPoke ("Expanded") fork's audio.cpp
// -- see upstream-expanded/README.md and the root LICENSE/NOTICE). Same
// note tables, same four waveforms, same 16kHz sample rate and anti-click
// envelope as the Swift port, so effects sound like the iOS build's rather
// than like something invented fresh for the browser -- rendered here with
// the Web Audio API instead of AVAudioEngine.
//
// Browsers refuse to start audio before a user gesture, so nothing plays
// until the visitor taps the mute/unmute control at least once; see
// main.js's wiring of Module.onSfx to playSfx() below.

const WAVE = { square: 0, tri: 1, soft: 2, noise: 3 };

const SQ = (f, ms, v) => ({ f, ms, slide: 0, vol: v, wave: WAVE.square });
const TRI = (f, ms, v) => ({ f, ms, slide: 0, vol: v, wave: WAVE.tri });
const SOFT = (f, ms, v) => ({ f, ms, slide: 0, vol: v, wave: WAVE.soft });
const NS = (ms, v) => ({ f: 0, ms, slide: 0, vol: v, wave: WAVE.noise });
const SL = (f, ms, to, v, w) => ({ f, ms, slide: to - f, vol: v, wave: w });
const SIL = (ms) => ({ f: 0, ms, slide: 0, vol: 0, wave: WAVE.square });

// The fork's SFX[] table, one entry per TPSfx case in order (see
// browser_glue.cpp's sfxPlay -> tp_js_on_sfx -> Module.onSfx call chain,
// which hands ids straight from pet.cpp/battle.cpp in this same order).
const EFFECTS = [
  [SQ(1175, 52, 88)],                                                     // 0 tap
  [SOFT(523, 42, 64), SIL(12), SOFT(659, 50, 70)],                        // 1 eat
  [SL(760, 65, 1080, 92, WAVE.tri), SQ(1397, 55, 86)],                    // 2 play
  [SOFT(1047, 70, 56), SIL(18), SOFT(1319, 105, 68)],                     // 3 heart
  [TRI(523, 70, 60), TRI(659, 70, 64), TRI(784, 95, 68),
   SL(880, 190, 1320, 72, WAVE.tri)],                                     // 4 hatch
  [SL(392, 100, 560, 58, WAVE.tri), SL(523, 100, 740, 62, WAVE.tri),
   SL(659, 110, 960, 66, WAVE.tri), SL(880, 210, 1480, 76, WAVE.soft)],   // 5 evolve
  [TRI(784, 60, 66), SIL(22), TRI(1047, 68, 72), SIL(20),
   SL(1175, 210, 1568, 78, WAVE.tri)],                                    // 6 medal
  [SL(330, 120, 230, 70, WAVE.square), SL(220, 150, 160, 64, WAVE.square)], // 7 deny
  [SOFT(784, 130, 58), SOFT(659, 140, 55), SL(523, 260, 392, 54, WAVE.soft)], // 8 bye
  [TRI(784, 65, 64), TRI(1047, 80, 70), SOFT(1319, 130, 70)],             // 9 level
  [TRI(659, 58, 66), TRI(784, 58, 68), TRI(988, 80, 72),
   SL(1175, 170, 1568, 76, WAVE.tri)],                                    // 10 battleWin
  [SL(392, 140, 330, 66, WAVE.soft), SL(330, 140, 247, 62, WAVE.soft),
   SOFT(196, 220, 56)],                                                   // 11 battleLoss
  [TRI(784, 55, 68), TRI(988, 65, 72), SL(1175, 180, 1568, 78, WAVE.tri)], // 12 catchOK
  [NS(55, 50), SL(523, 80, 392, 64, WAVE.square), SIL(16),
   SL(392, 180, 247, 62, WAVE.soft)],                                     // 13 catchFail
  [TRI(1175, 50, 68), SIL(22), TRI(1568, 70, 74), SOFT(1760, 95, 68)],    // 14 dailyGoal
  [NS(35, 36), TRI(1568, 42, 56), TRI(1976, 62, 60), SIL(18),
   TRI(1760, 56, 54)],                                                    // 15 eventSparkle
  [SL(523, 125, 392, 48, WAVE.soft), SOFT(330, 170, 42)],                 // 16 rest
  [SL(784, 75, 1175, 62, WAVE.tri), SIL(16), SQ(1568, 70, 74), NS(40, 42)], // 17 counter
  [TRI(988, 56, 84), SQ(1319, 62, 90)],                                   // 18 menu
  [TRI(659, 58, 72), TRI(880, 64, 78), SQ(1175, 74, 82)],                 // 19 gameStart
  [SL(820, 42, 520, 72, WAVE.square)],                                    // 20 ballBounce
  [NS(55, 56), SL(360, 110, 210, 68, WAVE.soft)],                         // 21 ballMiss
  [SQ(1047, 54, 68)],                                                     // 22 memoStep
  // Memo pads transposed up an octave from the fork's own 349/523/784/
  // 1047Hz -- see TPAudio.swift's comment: level-matched against a phone
  // speaker's rolloff so all four stay distinguishable by ear.
  [SOFT(698, 82, 135)],                                                   // 23 memoPad0
  [TRI(1047, 82, 105)],                                                   // 24 memoPad1
  [TRI(1568, 82, 96)],                                                    // 25 memoPad2
  [SQ(2093, 82, 72)],                                                     // 26 memoPad3
  [SL(980, 42, 1320, 90, WAVE.tri), SQ(1760, 38, 82)],                    // 27 attackQuick
  [NS(36, 46), SL(330, 74, 700, 92, WAVE.square), SQ(880, 52, 86)],       // 28 attackHeavy
  [SL(300, 70, 190, 82, WAVE.square), NS(38, 44)],                        // 29 enemyHit
  [TRI(988, 48, 82), TRI(1319, 54, 90), SQ(1760, 64, 86)],                // 30 effective
  [SOFT(420, 70, 58), SOFT(360, 90, 50)],                                 // 31 weakHit
  [SL(1047, 46, 1568, 88, WAVE.tri), TRI(1760, 42, 78)],                  // 32 minigameOK
  [NS(42, 52), SL(300, 95, 180, 70, WAVE.soft)],                          // 33 minigameBad
  [SQ(740, 70, 74), SIL(38), SQ(740, 70, 74)],                            // 34 lowHP
  [TRI(523, 52, 64), TRI(659, 62, 70), SL(784, 115, 1047, 72, WAVE.tri)], // 35 expeditionStart
  [TRI(784, 55, 70), TRI(1047, 58, 76), TRI(1319, 65, 78),
   SOFT(1568, 130, 72)],                                                  // 36 expeditionFound
  [SOFT(988, 55, 66), TRI(1319, 70, 74), SL(1568, 115, 1976, 76, WAVE.tri)], // 37 expeditionClaim
  [SOFT(659, 48, 62), SL(784, 95, 1175, 70, WAVE.tri)],                   // 38 itemUse
];

const SAMPLE_RATE = 16000;
const BASE_AMP = 9200 / 32768;
const FULL_GAIN_PCT = 118; // the fork's modeGainPct for FULL, the only tier this ever renders

// The fork's LFSR noise source (nextNoise), stepped per sample.
let noiseState = 0xace1;
function nextNoise() {
  noiseState = (noiseState >> 1) ^ ((noiseState & 1) !== 0 ? 0xb400 : 0);
  return (noiseState & 1) !== 0 ? 1 : -1;
}

// The fork's oscSample: one sample of the chosen waveform.
function oscSample(wave, phase, period, amp) {
  if (wave === WAVE.noise) return nextNoise() * amp;
  if (period <= 1) return 0;
  const p = phase % period;
  if (wave === WAVE.tri) {
    const half = period / 2;
    if (p < half) return -amp + (2 * amp * p) / half;
    return amp - (2 * amp * (p - half)) / (period - half);
  }
  if (wave === WAVE.soft) {
    // A symmetric triangle at 3/4 amplitude -- the fork's mellower voice.
    const half = period / 2;
    const q = p < half ? p : period - p;
    return ((2 * amp * q) / half - amp) * 0.75;
  }
  return p < period / 2 ? amp : -amp;
}

// Port of the fork's playTone run over a whole effect: waveform per note,
// linear frequency slide, a 64-sample attack and 96-sample decay so notes
// don't click, FULL's gain baked into the amplitude.
function renderEffect(id) {
  const notes = EFFECTS[id];
  if (!notes) return null;
  const totalFrames = notes.reduce((s, n) => s + Math.floor((SAMPLE_RATE * n.ms) / 1000), 0);
  if (totalFrames <= 0) return null;

  const out = new Float32Array(totalFrames);
  let w = 0;
  for (const note of notes) {
    const total = Math.floor((SAMPLE_RATE * note.ms) / 1000);
    const amp = (BASE_AMP * note.vol) / 100 * (FULL_GAIN_PCT / 100);
    let phase = 0;
    for (let i = 0; i < total; i++) {
      let s = 0;
      if (note.wave === WAVE.noise || note.f > 0) {
        let curF = note.f;
        if (note.slide !== 0 && total > 1) {
          curF = Math.max(20, note.f + (note.slide * i) / total);
        }
        const period = Math.max(2, curF > 0 ? Math.round(SAMPLE_RATE / curF) : 2);
        s = oscSample(note.wave, phase, period, amp);
        if (i < 64) s *= i / 64;
        else if (i > total - 96) s *= (total - i) / 96;
        phase += 1;
      }
      out[w] = s;
      w += 1;
    }
  }
  return out;
}

// --- Playback --------------------------------------------------------

let audioCtx = null;
let bufferCache = new Map();

// Three-level sound mode, mirroring GameModel.swift's TPSoundMode: SILENT
// mutes both audio and haptic (the Vibration API stand-in for the iOS
// build's UIImpactFeedbackGenerator -- Safari on iOS doesn't implement it
// at all, so VIBRATE is silent-but-inert there, same as a phone with
// System Haptics off would be), VIBRATE only, FULL plays both. Persisted
// under its own key for the same reason GameModel.swift's fix just
// applied: a scheme collision would make one mode read back as another.
const SOUND_SILENT = 0, SOUND_VIBRATE = 1, SOUND_FULL = 2;
let soundMode = SOUND_SILENT; // starts silent -- browsers block audio before a user gesture anyway

function loadSoundMode() {
  // Sound on by default, like the iOS app. The AudioContext itself is
  // still only created on the first tap (browsers require a gesture), so
  // starting in FULL costs nothing and means cries/SFX work from the
  // first tap rather than after a hidden settings toggle.
  const stored = localStorage.getItem("tp_soundmode3");
  const v = stored === null ? SOUND_FULL : parseInt(stored, 10);
  soundMode = v === 0 || v === 1 || v === 2 ? v : SOUND_FULL;
  return soundMode;
}

function setSoundMode(mode) {
  soundMode = mode;
  localStorage.setItem("tp_soundmode3", String(mode));
  if (mode === SOUND_FULL) ensureCtx();
}

function ensureCtx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  if (audioCtx.state === "suspended") audioCtx.resume();
  return audioCtx;
}

function getBuffer(id) {
  if (bufferCache.has(id)) return bufferCache.get(id);
  const samples = renderEffect(id);
  if (!samples) return null;
  const ctx = ensureCtx();
  const buf = ctx.createBuffer(1, samples.length, SAMPLE_RATE);
  buf.copyToChannel(samples, 0);
  bufferCache.set(id, buf);
  return buf;
}

// Ports GameModel.swift's emitSfx: haptic (here, Vibration API) whenever
// the mode isn't SILENT, audio only at FULL -- see the mode comment above.
function playSfx(id) {
  if (soundMode === SOUND_SILENT) return;
  if (navigator.vibrate) navigator.vibrate(15);
  if (soundMode !== SOUND_FULL) return;

  const ctx = ensureCtx();
  const buf = getBuffer(id);
  if (!buf) return;
  const src = ctx.createBufferSource();
  src.buffer = buf;
  src.connect(ctx.destination);
  src.start();
}
