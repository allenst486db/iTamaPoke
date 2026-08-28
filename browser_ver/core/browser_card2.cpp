// Daily goals / Box / Expedition (stat card pages 2/3/7) and the training
// sack minigame -- a plain-C++ port of the matching TPPet.mm accessors.
// All read/act on the one Pet browser_glue.cpp owns, via the same
// tp_battle_pet() accessor browser_battle.cpp uses.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <string>

#include <emscripten.h>

#include "pet.h"
#include "dex.h"
#include "i18n.h"
#include "dayphase.h"

extern Pet &tp_battle_pet(); // browser_glue.cpp

namespace {
uint32_t nowEpoch() { return (uint32_t)std::time(nullptr); }

StrId expItemStrId(int i) {
  switch (i) {
    case 0: return S_ITEM_SNACK;
    case 1: return S_ITEM_ENERGY;
    case 2: return S_ITEM_CARE;
    default: return S_ITEM_TRAIN;
  }
}

// Box sort mode: 0 dex order, 1 by type, 2 raised-first. Client-side only,
// same as TPPet.mm's gBoxSort -- everything else reads the live Pet.
int gBoxSort = 0;

// Cached sorted dex list -- rebuilt lazily (gBoxCacheN < 0) rather than on
// every tp_box_dex_at call (one per visible row, every frame the box
// screen is open). Invalidated by tp_box_invalidate() below whenever the
// box could have changed: a catch, or cycling sort.
int16_t gBoxCache[DEX_COUNT];
int gBoxCacheN = -1;

bool boxComesBefore(Pet &pet, int16_t a, int16_t b) {
  if (gBoxSort == 1) {
    const DexEntry &da = DEX_TBL[a], &db = DEX_TBL[b];
    if (da.type1 != db.type1) return da.type1 < db.type1;
    if (da.type2 != db.type2) return da.type2 < db.type2;
  } else if (gBoxSort == 2) {
    bool ra = pet.isRegistered(a), rb = pet.isRegistered(b);
    if (ra != rb) return ra;
  }
  return a < b;
}

uint16_t boxBuildList(Pet &pet, int16_t *out) {
  uint16_t n = 0;
  for (int16_t dex = 1; dex <= DEX_COUNT; dex++) if (pet.isCaught(dex)) out[n++] = dex;
  for (uint16_t i = 1; i < n; i++) {
    int16_t v = out[i];
    int j = (int)i - 1;
    while (j >= 0 && boxComesBefore(pet, v, out[j])) { out[j + 1] = out[j]; j--; }
    out[j + 1] = v;
  }
  return n;
}
} // namespace

extern "C" {

// --- Daily goals ---------------------------------------------------------

EMSCRIPTEN_KEEPALIVE const char *tp_daily_title() { return T(S_DAILY); }
EMSCRIPTEN_KEEPALIVE
const char *tp_day_phase_label() {
  Pet &pet = tp_battle_pet();
  uint8_t phase = dayPhaseFromHour(sceneHourFromEpoch(pet.lastSeenEpoch));
  StrId id = phase == 0 ? S_MORNING : phase == 2 ? S_EVENING : phase == 3 ? S_NIGHT : S_DAY;
  return T(id);
}
EMSCRIPTEN_KEEPALIVE int tp_daily_goal_count() { return DAILY_GOAL_COUNT; }
EMSCRIPTEN_KEEPALIVE const char *tp_done_text() { return T(S_DONE); }
EMSCRIPTEN_KEEPALIVE void tp_ensure_daily_goals() { tp_battle_pet().ensureDailyGoals(); }
EMSCRIPTEN_KEEPALIVE
int tp_daily_goal_complete(int i) {
  Pet &pet = tp_battle_pet();
  return (i >= 0 && i < DAILY_GOAL_COUNT && pet.dailyGoalComplete((uint8_t)i)) ? 1 : 0;
}
EMSCRIPTEN_KEEPALIVE
const char *tp_daily_goal_label(int i) {
  Pet &pet = tp_battle_pet();
  if (i < 0 || i >= DAILY_GOAL_COUNT) return "";
  switch (pet.dailyGoalType[i]) {
    case DAILY_GOAL_PLAY: return T(S_GOAL_PLAY);
    case DAILY_GOAL_BATTLE: return T(S_GOAL_BATTLE);
    case DAILY_GOAL_CATCH: return T(S_GOAL_CATCH);
    case DAILY_GOAL_MEMO: return T(S_GOAL_MEMO);
    default: return T(S_GOAL_CARE);
  }
}
EMSCRIPTEN_KEEPALIVE
int tp_daily_goal_kind(int i) {
  Pet &pet = tp_battle_pet();
  if (i < 0 || i >= DAILY_GOAL_COUNT) return 0;
  switch (pet.dailyGoalType[i]) {
    case DAILY_GOAL_PLAY: return 1;
    case DAILY_GOAL_BATTLE: return 2;
    case DAILY_GOAL_CATCH: return 3;
    case DAILY_GOAL_MEMO: return 4;
    default: return 0;
  }
}
EMSCRIPTEN_KEEPALIVE
int tp_daily_goal_progress(int i) {
  Pet &pet = tp_battle_pet();
  if (i < 0 || i >= DAILY_GOAL_COUNT) return 0;
  uint8_t target = pet.dailyGoalTarget(pet.dailyGoalType[i]);
  uint8_t p = pet.dailyGoalProgress[i];
  return p > target ? target : p;
}
EMSCRIPTEN_KEEPALIVE
int tp_daily_goal_target(int i) {
  Pet &pet = tp_battle_pet();
  if (i < 0 || i >= DAILY_GOAL_COUNT) return 0;
  return pet.dailyGoalTarget(pet.dailyGoalType[i]);
}
EMSCRIPTEN_KEEPALIVE
const char *tp_daily_reward_line() {
  static std::string out;
  Pet &pet = tp_battle_pet();
  int done = 0;
  for (int i = 0; i < DAILY_GOAL_COUNT; i++) if (pet.dailyGoalComplete((uint8_t)i)) done++;
  char buf[24];
  snprintf(buf, sizeof(buf), "%s %d/%d", T(S_REWARD), done, DAILY_GOAL_COUNT);
  out = buf;
  return out.c_str();
}

// --- Box -------------------------------------------------------------

EMSCRIPTEN_KEEPALIVE const char *tp_box_title() { return T(S_BOX); }
EMSCRIPTEN_KEEPALIVE
const char *tp_caught_count_line() {
  static std::string out;
  char buf[24];
  snprintf(buf, sizeof(buf), T(S_CAUGHT_COUNT_FMT), tp_battle_pet().caughtCount());
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE
const char *tp_known_count_line() {
  static std::string out;
  char buf[24];
  snprintf(buf, sizeof(buf), T(S_KNOWN_FMT), tp_battle_pet().knownDexCount());
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE
const char *tp_dex_goal_line() {
  static std::string out;
  char buf[24];
  snprintf(buf, sizeof(buf), T(S_DEX_GOAL_FMT), tp_battle_pet().nextDexGoal());
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_no_catches_text() { return T(S_NO_CATCHES); }
EMSCRIPTEN_KEEPALIVE const char *tp_raised_mark_text() { return T(S_RAISED_MARK); }
EMSCRIPTEN_KEEPALIVE
const char *tp_box_sort_label() {
  return gBoxSort == 1 ? T(S_SORT_TYPE) : gBoxSort == 2 ? T(S_SORT_RAISED) : T(S_SORT_DEX);
}
EMSCRIPTEN_KEEPALIVE void tp_cycle_box_sort() { gBoxSort = (gBoxSort + 1) % 3; gBoxCacheN = -1; }
EMSCRIPTEN_KEEPALIVE void tp_box_invalidate() { gBoxCacheN = -1; }
EMSCRIPTEN_KEEPALIVE
const char *tp_page_line(int page, int count) {
  static std::string out;
  char buf[16];
  snprintf(buf, sizeof(buf), T(S_PAGE_FMT), page, count);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE
int tp_box_page_count(int rows) {
  int pages = (tp_battle_pet().caughtCount() + rows - 1) / rows;
  return pages > 0 ? pages : 1;
}
EMSCRIPTEN_KEEPALIVE
int tp_box_dex_at(int index) {
  if (gBoxCacheN < 0) gBoxCacheN = (int)boxBuildList(tp_battle_pet(), gBoxCache);
  return (index >= 0 && index < gBoxCacheN) ? gBoxCache[index] : -1;
}

// --- Expedition ------------------------------------------------------

static const uint8_t kExpMinutes[3] = { 15, 30, 60 };

EMSCRIPTEN_KEEPALIVE const char *tp_expedition_title() { return T(S_EXPEDITION); }
EMSCRIPTEN_KEEPALIVE int tp_expedition_ready() { return tp_battle_pet().expeditionReady(nowEpoch()) ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_expedition_active() { return tp_battle_pet().expeditionActive(nowEpoch()) ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_found_line() {
  static std::string out;
  char buf[40];
  snprintf(buf, sizeof(buf), T(S_FOUND_ITEM_FMT), T(expItemStrId(tp_battle_pet().expeditionRewardItem)));
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_expedition_claim_text() { return T(S_EXP_CLAIM); }
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_back_in_line() {
  static std::string out;
  Pet &pet = tp_battle_pet();
  uint32_t now = nowEpoch();
  uint32_t left = (pet.expeditionEndEpoch > now ? pet.expeditionEndEpoch - now + 59UL : 0) / 60UL;
  char buf[32];
  snprintf(buf, sizeof(buf), T(S_EXP_IN_FMT), (unsigned)left);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_expedition_wait_text() { return T(S_WAIT); }
EMSCRIPTEN_KEEPALIVE const char *tp_expedition_inventory_full_text() { return T(S_INV_FULL); }
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_need_energy_text() {
  static std::string out;
  char buf[32];
  snprintf(buf, sizeof(buf), T(S_NEED_ENE_FMT), 12);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE int tp_expedition_inventory_full() { return tp_battle_pet().expeditionInventoryFull() ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_duration_label(int i) {
  static const StrId ids[3] = { S_EXP_15, S_EXP_30, S_EXP_60 };
  return (i >= 0 && i <= 2) ? T(ids[i]) : "";
}
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_cost_label(int i) {
  static std::string out;
  if (i < 0 || i > 2) return "";
  char buf[16];
  snprintf(buf, sizeof(buf), "-%u ENE", Pet::expeditionEnergyCost(kExpMinutes[i]));
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE
int tp_expedition_can_start(int i) {
  if (i < 0 || i > 2) return 0;
  return tp_battle_pet().canStartExpedition(kExpMinutes[i], nowEpoch()) ? 1 : 0;
}
EMSCRIPTEN_KEEPALIVE void tp_claim_expedition() { tp_battle_pet().claimExpedition(nowEpoch()); }
EMSCRIPTEN_KEEPALIVE
void tp_start_expedition(int i) {
  if (i < 0 || i > 2) return;
  tp_battle_pet().startExpedition(kExpMinutes[i], nowEpoch(), (uint8_t)(std::rand() % 100),
                                   (uint8_t)(std::rand() % 3));
}
EMSCRIPTEN_KEEPALIVE const char *tp_inventory_title() { return T(S_INVENTORY); }
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_item_label(int i) { return (i >= 0 && i <= 3) ? T(expItemStrId(i)) : ""; }
EMSCRIPTEN_KEEPALIVE
int tp_expedition_item_count(int i) {
  return (i >= 0 && i <= 3) ? tp_battle_pet().itemCounts[i] : 0;
}
EMSCRIPTEN_KEEPALIVE
int tp_expedition_item_color(int i) {
  switch (i) {
    case 0: return 0xED07; case 1: return 0x4C98; case 2: return 0x5DCD;
    case 3: return 0xEA87; default: return 0x8C4D;
  }
}
EMSCRIPTEN_KEEPALIVE
void tp_use_expedition_item(int i) {
  Pet &pet = tp_battle_pet();
  if (i < 0 || i > 2 || pet.itemCounts[i] == 0) return;
  pet.useExpeditionItem((ExpeditionItem)i);
}
EMSCRIPTEN_KEEPALIVE const char *tp_train_choice_title() { return T(S_ITEM_TRAIN); }
EMSCRIPTEN_KEEPALIVE
const char *tp_train_stat_label(int i) {
  static const StrId ids[3] = { S_TRAIN_ATK, S_TRAIN_DEF, S_TRAIN_SPE };
  return (i >= 0 && i <= 2) ? T(ids[i]) : "";
}
namespace {
uint8_t trainStatValue(Pet &pet, int i) {
  switch (i) { case 0: return pet.trAtk; case 1: return pet.trDef; case 2: return pet.trSpe; default: return 0; }
}
} // namespace
EMSCRIPTEN_KEEPALIVE
int tp_train_stat_usable(int i) { return trainStatValue(tp_battle_pet(), i) < 100 ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE const char *tp_train_maxed_text() { return T(S_ITEM_MAXED); }
EMSCRIPTEN_KEEPALIVE
void tp_use_train_item(int statIndex) {
  Pet &pet = tp_battle_pet();
  if (statIndex < 0 || statIndex > 2 || pet.itemCounts[EXP_ITEM_TRAIN] == 0) return;
  pet.useExpeditionItem(EXP_ITEM_TRAIN, (int8_t)statIndex);
}
EMSCRIPTEN_KEEPALIVE
int tp_expedition_hud_state() {
  switch (tp_battle_pet().expeditionHudState(nowEpoch())) {
    case EXP_HUD_ACTIVE: return 1;
    case EXP_HUD_READY: return 2;
    case EXP_HUD_BAG: return 3;
    default: return 0;
  }
}
EMSCRIPTEN_KEEPALIVE
const char *tp_expedition_hud_label() {
  static std::string out;
  Pet &pet = tp_battle_pet();
  int state = tp_expedition_hud_state();
  char buf[24];
  if (state == 1) {
    uint32_t now = nowEpoch();
    uint32_t left = (pet.expeditionEndEpoch > now ? pet.expeditionEndEpoch - now + 59UL : 0) / 60UL;
    snprintf(buf, sizeof(buf), "%s %lum", T(S_EXP_HUD_TOUR), (unsigned long)left);
    out = buf;
  } else if (state == 2) {
    out = T(S_EXP_READY);
  } else if (state == 3) {
    snprintf(buf, sizeof(buf), "%s x%u", T(S_EXP_HUD_BAG), pet.expeditionItemCount());
    out = buf;
  } else {
    out = "";
  }
  return out.c_str();
}

// --- Training sack minigame --------------------------------------------

namespace { bool gSackRunning = false; uint32_t gSackUntil = 0; uint16_t gSackHits = 0;
  uint32_t gSackOverUntil = 0; uint8_t gSackGain = 0; int gSackNewHigh = 0; }

EMSCRIPTEN_KEEPALIVE
void tp_sack_start(uint32_t nowMs) {
  gSackHits = 0; gSackGain = 0; gSackNewHigh = 0;
  gSackOverUntil = 0; gSackUntil = nowMs + 10000; gSackRunning = true;
}
EMSCRIPTEN_KEEPALIVE int tp_sack_hits() { return gSackHits; }
EMSCRIPTEN_KEEPALIVE int tp_sack_over_until_reached(uint32_t nowMs) { return gSackOverUntil != 0 && nowMs >= gSackOverUntil; }
EMSCRIPTEN_KEEPALIVE int tp_sack_is_over() { return gSackOverUntil != 0; }
EMSCRIPTEN_KEEPALIVE int tp_sack_gain() { return gSackGain; }
EMSCRIPTEN_KEEPALIVE int tp_sack_new_high() { return gSackNewHigh; }
EMSCRIPTEN_KEEPALIVE int tp_strength_high2() { return tp_battle_pet().strHi; }

EMSCRIPTEN_KEEPALIVE
void tp_sack_step(uint32_t nowMs) {
  if (!gSackRunning || gSackOverUntil != 0) return;
  if (nowMs >= gSackUntil) {
    Pet &pet = tp_battle_pet();
    int prevHigh = pet.strHi;
    gSackGain = pet.trainStrength(gSackHits);
    gSackNewHigh = gSackHits > prevHigh ? 1 : 0;
    gSackOverUntil = nowMs + 4000;
  }
}
EMSCRIPTEN_KEEPALIVE
void tp_sack_tap(uint32_t nowMs) {
  if (!gSackRunning || gSackOverUntil != 0 || nowMs >= gSackUntil) return;
  gSackHits++;
}
EMSCRIPTEN_KEEPALIVE const char *tp_hits_line() {
  static std::string out; char buf[24]; snprintf(buf, sizeof(buf), T(S_HITS_FMT), gSackHits);
  out = buf; return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_strength_gain_line() {
  static std::string out; char buf[24]; snprintf(buf, sizeof(buf), T(S_STR_GAIN_FMT), gSackGain);
  out = buf; return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_new_record_text() { return T(S_NEW_RECORD); }
EMSCRIPTEN_KEEPALIVE const char *tp_record_line(int record) {
  static std::string out; char buf[24]; snprintf(buf, sizeof(buf), T(S_RECORD_FMT), record);
  out = buf; return out.c_str();
}

} // extern "C"
