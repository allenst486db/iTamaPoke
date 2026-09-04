#include "hangul.h"

#include <string>

// Standard Unicode Hangul composition: a syllable is
//   0xAC00 + (cho * 21 + jung) * 28 + jong
// with the three indices ordered as in the Unicode tables. Everything below
// is bookkeeping to turn key presses into those three numbers.

namespace {

// Per-jamo facts the automaton needs. For a consonant: its index as an
// initial (cho) and as a final (jong, 0 when it cannot be one -- ㄸ, ㅃ, ㅉ
// never close a syllable). For a vowel: its index as a medial (jung).
struct JamoInfo {
  uint16_t compat;   // U+31xx standalone form, for key caps and lone jamo
  int8_t cho;
  int8_t jong;
  int8_t jung;
};

const JamoInfo kJamo[TPH_JAMO_COUNT] = {
  // consonants
  { 0x3131,  0,  1, -1 },  // ㄱ
  { 0x3132,  1,  2, -1 },  // ㄲ
  { 0x3134,  2,  4, -1 },  // ㄴ
  { 0x3137,  3,  7, -1 },  // ㄷ
  { 0x3138,  4,  0, -1 },  // ㄸ
  { 0x3139,  5,  8, -1 },  // ㄹ
  { 0x3141,  6, 16, -1 },  // ㅁ
  { 0x3142,  7, 17, -1 },  // ㅂ
  { 0x3143,  8,  0, -1 },  // ㅃ
  { 0x3145,  9, 19, -1 },  // ㅅ
  { 0x3146, 10, 20, -1 },  // ㅆ
  { 0x3147, 11, 21, -1 },  // ㅇ
  { 0x3148, 12, 22, -1 },  // ㅈ
  { 0x3149, 13,  0, -1 },  // ㅉ
  { 0x314A, 14, 23, -1 },  // ㅊ
  { 0x314B, 15, 24, -1 },  // ㅋ
  { 0x314C, 16, 25, -1 },  // ㅌ
  { 0x314D, 17, 26, -1 },  // ㅍ
  { 0x314E, 18, 27, -1 },  // ㅎ
  // vowels
  { 0x314F, -1, -1,  0 },  // ㅏ
  { 0x3150, -1, -1,  1 },  // ㅐ
  { 0x3151, -1, -1,  2 },  // ㅑ
  { 0x3152, -1, -1,  3 },  // ㅒ
  { 0x3153, -1, -1,  4 },  // ㅓ
  { 0x3154, -1, -1,  5 },  // ㅔ
  { 0x3155, -1, -1,  6 },  // ㅕ
  { 0x3156, -1, -1,  7 },  // ㅖ
  { 0x3157, -1, -1,  8 },  // ㅗ
  { 0x3158, -1, -1,  9 },  // ㅘ
  { 0x3159, -1, -1, 10 },  // ㅙ
  { 0x315A, -1, -1, 11 },  // ㅚ
  { 0x315B, -1, -1, 12 },  // ㅛ
  { 0x315C, -1, -1, 13 },  // ㅜ
  { 0x315D, -1, -1, 14 },  // ㅝ
  { 0x315E, -1, -1, 15 },  // ㅞ
  { 0x315F, -1, -1, 16 },  // ㅟ
  { 0x3160, -1, -1, 17 },  // ㅠ
  { 0x3161, -1, -1, 18 },  // ㅡ
  { 0x3162, -1, -1, 19 },  // ㅢ
  { 0x3163, -1, -1, 20 },  // ㅣ
};

// Vowels that merge when typed in sequence (ㅗ then ㅏ is ㅘ). Also covers
// ㅏ+ㅣ=ㅐ and friends, so the ㅐ/ㅔ keys are a convenience rather than the
// only way to reach them.
struct Pair { int8_t a, b, out; };
const Pair kVowelMerge[] = {
  {  8,  0,  9 },  // ㅗ ㅏ ㅘ
  {  8,  1, 10 },  // ㅗ ㅐ ㅙ
  {  8, 20, 11 },  // ㅗ ㅣ ㅚ
  { 13,  4, 14 },  // ㅜ ㅓ ㅝ
  { 13,  5, 15 },  // ㅜ ㅔ ㅞ
  { 13, 20, 16 },  // ㅜ ㅣ ㅟ
  { 18, 20, 19 },  // ㅡ ㅣ ㅢ
  {  0, 20,  1 },  // ㅏ ㅣ ㅐ
  {  2, 20,  3 },  // ㅑ ㅣ ㅒ
  {  4, 20,  5 },  // ㅓ ㅣ ㅔ
  {  6, 20,  7 },  // ㅕ ㅣ ㅖ
};

// Finals that merge the same way (ㄹ then ㄱ closes as ㄺ).
const Pair kJongMerge[] = {
  {  1, 19,  3 },  // ㄱ ㅅ ㄳ
  {  4, 22,  5 },  // ㄴ ㅈ ㄵ
  {  4, 27,  6 },  // ㄴ ㅎ ㄶ
  {  8,  1,  9 },  // ㄹ ㄱ ㄺ
  {  8, 16, 10 },  // ㄹ ㅁ ㄻ
  {  8, 17, 11 },  // ㄹ ㅂ ㄼ
  {  8, 19, 12 },  // ㄹ ㅅ ㄽ
  {  8, 25, 13 },  // ㄹ ㅌ ㄾ
  {  8, 26, 14 },  // ㄹ ㅍ ㄿ
  {  8, 27, 15 },  // ㄹ ㅎ ㅀ
  { 17, 19, 18 },  // ㅂ ㅅ ㅄ
};

// A final's index as an initial, for the moment a following vowel steals it
// (간 + ㅏ becomes 가나). Index is the jong value; -1 means "cannot move",
// which only applies to the empty final.
const int8_t kJongToCho[28] = {
  -1,  0,  1, -1,  2, -1, -1,  3,  5, -1, -1, -1, -1, -1,
  -1, -1,  6,  7, -1,  9, 10, 11, 12, 14, 15, 16, 17, 18,
};

// Compound finals split back into (what stays, what moves).
struct Split { int8_t whole, stays, moves_cho; };
const Split kJongSplit[] = {
  {  3,  1,  9 },  // ㄳ -> ㄱ + ㅅ
  {  5,  4, 12 },  // ㄵ -> ㄴ + ㅈ
  {  6,  4, 18 },  // ㄶ -> ㄴ + ㅎ
  {  9,  8,  0 },  // ㄺ -> ㄹ + ㄱ
  { 10,  8,  6 },  // ㄻ -> ㄹ + ㅁ
  { 11,  8,  7 },  // ㄼ -> ㄹ + ㅂ
  { 12,  8,  9 },  // ㄽ -> ㄹ + ㅅ
  { 13,  8, 16 },  // ㄾ -> ㄹ + ㅌ
  { 14,  8, 17 },  // ㄿ -> ㄹ + ㅍ
  { 15,  8, 18 },  // ㅀ -> ㄹ + ㅎ
  { 18, 17,  9 },  // ㅄ -> ㅂ + ㅅ
};

std::string gCommitted;    // everything already settled
int gCho = -1, gJung = -1, gJong = 0;
std::string gText;         // cache for tph_text()
std::string gJamoText;     // cache for tph_jamo_utf8()

void appendUtf8(std::string &out, uint32_t cp) {
  if (cp < 0x80) {
    out += (char)cp;
  } else if (cp < 0x800) {
    out += (char)(0xC0 | (cp >> 6));
    out += (char)(0x80 | (cp & 0x3F));
  } else {
    out += (char)(0xE0 | (cp >> 12));
    out += (char)(0x80 | ((cp >> 6) & 0x3F));
    out += (char)(0x80 | (cp & 0x3F));
  }
}

// The syllable (or lone jamo) currently being composed.
std::string current() {
  std::string out;
  if (gCho >= 0 && gJung >= 0) {
    appendUtf8(out, 0xAC00 + (uint32_t)(gCho * 21 + gJung) * 28 + gJong);
  } else if (gCho >= 0) {
    for (int i = 0; i < TPH_CONS_COUNT; i++)
      if (kJamo[i].cho == gCho) { appendUtf8(out, kJamo[i].compat); break; }
  } else if (gJung >= 0) {
    for (int i = TPH_VOWEL_FIRST; i < TPH_JAMO_COUNT; i++)
      if (kJamo[i].jung == gJung) { appendUtf8(out, kJamo[i].compat); break; }
  }
  return out;
}

void commit() {
  gCommitted += current();
  gCho = -1; gJung = -1; gJong = 0;
}

int mergeVowel(int a, int b) {
  for (const Pair &p : kVowelMerge) if (p.a == a && p.b == b) return p.out;
  return -1;
}
int mergeJong(int a, int b) {
  for (const Pair &p : kJongMerge) if (p.a == a && p.b == b) return p.out;
  return -1;
}
const Split *splitJong(int whole) {
  for (const Split &s : kJongSplit) if (s.whole == whole) return &s;
  return nullptr;
}
// A compound vowel reduced by one keystroke, for backspace.
int unmergeVowel(int v) {
  for (const Pair &p : kVowelMerge) if (p.out == v) return p.a;
  return -1;
}

void dropLastChar(std::string &s) {
  if (s.empty()) return;
  size_t i = s.size() - 1;
  while (i > 0 && ((unsigned char)s[i] & 0xC0) == 0x80) i--;
  s.erase(i);
}

} // namespace

extern "C" {

void tph_reset(void) {
  gCommitted.clear();
  gCho = -1; gJung = -1; gJong = 0;
}

void tph_set(const char *text) {
  tph_reset();
  if (text) gCommitted = text;
}

int tph_press_jamo(int jamo) {
  if (jamo < 0 || jamo >= TPH_JAMO_COUNT) return 0;
  const JamoInfo &j = kJamo[jamo];

  if (j.jung >= 0) {                       // vowel
    if (gCho < 0 && gJung < 0) {
      gJung = j.jung;
    } else if (gCho < 0) {                 // lone vowel already showing
      int m = mergeVowel(gJung, j.jung);
      if (m >= 0) { gJung = m; }
      else { commit(); gJung = j.jung; }
    } else if (gJung < 0) {
      gJung = j.jung;
    } else if (gJong == 0) {
      int m = mergeVowel(gJung, j.jung);
      if (m >= 0) { gJung = m; }
      else { commit(); gJung = j.jung; }
    } else {
      // The final belongs to this vowel's syllable instead: 간 + ㅏ = 가나.
      const Split *s = splitJong(gJong);
      int movedCho;
      if (s) { movedCho = s->moves_cho; gJong = s->stays; }
      else { movedCho = kJongToCho[gJong]; gJong = 0; }
      commit();
      gCho = movedCho; gJung = j.jung; gJong = 0;
    }
    return 1;
  }

  // consonant
  if (gCho < 0 && gJung < 0) {
    gCho = j.cho;
  } else if (gJung < 0) {                  // two initials in a row
    commit();
    gCho = j.cho;
  } else if (gCho < 0) {                   // lone vowel, then a consonant
    commit();
    gCho = j.cho;
  } else if (gJong == 0) {
    if (j.jong > 0) gJong = j.jong;
    else { commit(); gCho = j.cho; }
  } else {
    int m = j.jong > 0 ? mergeJong(gJong, j.jong) : -1;
    if (m >= 0) gJong = m;
    else { commit(); gCho = j.cho; }
  }
  return 1;
}

int tph_press_ascii(char c) {
  commit();
  gCommitted += c;
  return 1;
}

int tph_backspace(void) {
  if (gJong > 0) {
    const Split *s = splitJong(gJong);
    gJong = s ? s->stays : 0;
  } else if (gJung >= 0) {
    int u = unmergeVowel(gJung);
    gJung = u >= 0 ? u : -1;
  } else if (gCho >= 0) {
    gCho = -1;
  } else if (!gCommitted.empty()) {
    dropLastChar(gCommitted);
  } else {
    return 0;
  }
  return 1;
}

const char *tph_text(void) {
  gText = gCommitted + current();
  return gText.c_str();
}

int tph_byte_len(void) {
  return (int)(gCommitted.size() + current().size());
}

int tph_char_len(void) {
  std::string s = gCommitted + current();
  int n = 0;
  for (char ch : s) if (((unsigned char)ch & 0xC0) != 0x80) n++;
  return n;
}

const char *tph_jamo_utf8(int jamo) {
  gJamoText.clear();
  if (jamo >= 0 && jamo < TPH_JAMO_COUNT) appendUtf8(gJamoText, kJamo[jamo].compat);
  return gJamoText.c_str();
}

int tph_composing(void) { return (gCho >= 0 || gJung >= 0) ? 1 : 0; }

} // extern "C"
