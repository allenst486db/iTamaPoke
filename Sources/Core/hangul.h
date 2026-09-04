// Hangul input for the rename keyboard, shared by the iOS/watchOS app and
// the browser build.
//
// Upstream's firmware draws with an ASCII bitmap font, so naming a creature
// has always been A-Z only -- see socquique/TamaPoke#5, where that font is
// exactly why Korean was turned down. Both of this port's renderers use a
// real system/canvas font instead, so the only thing still missing was a
// way to *type* Hangul. This is that: a plain 2-set (두벌식) composition
// automaton over an on-screen jamo grid.
//
// Deliberately not Chunjiin (천지인, the 12-key feature-phone layout that
// kky3013-oss/TamaPoke-KR implements): with 466px of screen there is room
// for every jamo as its own key, which needs no multi-tap timing and no
// disambiguation, and reads faster for anyone who has used a computer
// keyboard.
//
// Lives in plain C++ with a C ABI, compiled into both builds from this one
// file (project.yml pulls in all of Sources/Core; browser_ver/build.sh
// names it explicitly), so the two keyboards can never drift apart.

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Jamo ids the keyboards press. Consonants and vowels share one space; the
// keyboard layouts below index into it, and so does tph_jamo_utf8().
enum {
  TPH_CONS_FIRST = 0,
  TPH_G = 0, TPH_GG, TPH_N, TPH_D, TPH_DD, TPH_R, TPH_M, TPH_B, TPH_BB,
  TPH_S, TPH_SS, TPH_NG, TPH_J, TPH_JJ, TPH_CH, TPH_K, TPH_T, TPH_P, TPH_H,
  TPH_CONS_COUNT,                       // 19

  TPH_VOWEL_FIRST = TPH_CONS_COUNT,
  TPH_A = TPH_VOWEL_FIRST, TPH_AE, TPH_YA, TPH_YAE, TPH_EO, TPH_E, TPH_YEO,
  TPH_YE, TPH_O, TPH_WA, TPH_WAE, TPH_OE, TPH_YO, TPH_U, TPH_WO, TPH_WE,
  TPH_WI, TPH_YU, TPH_EU, TPH_UI, TPH_I,
  TPH_JAMO_COUNT                        // 19 + 21 = 40
};

// Clears the draft (both the committed text and the syllable in progress).
void tph_reset(void);

// Replaces the draft with `text`, with nothing left composing -- used when
// the keyboard opens on an existing nickname, and when switching between
// the Korean and English layouts.
void tph_set(const char *text);

// One key press. `jamo` is one of the ids above; anything out of range is
// ignored. Returns 1 if the draft changed.
int tph_press_jamo(int jamo);

// A plain ASCII key (the English layout, and "." / "-"). Any syllable in
// progress is committed first, exactly as a real IME does.
int tph_press_ascii(char c);

// Deletes one jamo from the syllable in progress, or one character from the
// committed text when nothing is composing -- so backspace undoes typing
// step by step rather than dropping a whole syllable at once.
int tph_backspace(void);

// The draft as UTF-8, including the syllable still being composed. Valid
// until the next call that changes it.
const char *tph_text(void);

// Byte length of tph_text(), which is what has to fit Pet::nick.
int tph_byte_len(void);

// Character (not byte) count, for the "name is getting long" checks the
// keyboards do.
int tph_char_len(void);

// The standalone form of a jamo, for drawing the key caps. Static storage,
// valid until the next call.
const char *tph_jamo_utf8(int jamo);

// Whether a syllable is mid-composition, so the caller can underline the
// last character the way an IME does.
int tph_composing(void);

#ifdef __cplusplus
}
#endif
