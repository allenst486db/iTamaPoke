// Wild-battle glue: a plain-C++ port of Sources/Core/TPBattle.mm (itself a
// Swift-facing reimplementation of TamaPoke.ino's wild-encounter-prompt and
// battle-screen logic -- ShadowEnemyx/TamaPoke "Expanded", not the
// upstream/ submodule -- see upstream-expanded/README.md). battle.h/
// battle.cpp (the actual combat math) are used unmodified, exactly like
// browser_glue.cpp does for pet.cpp; this file only replaces TPBattle.mm's
// two platform calls -- arc4random_uniform(100) -> std::rand() % 100, and
// NSProcessInfo.systemUptime -> g_millis (already driven by tp_tick in
// browser_glue.cpp) -- everything else mirrors it line for line so the
// wild-encounter odds, cooldowns, and battle math match the iOS build.
#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>

#include <emscripten.h>

#include "pet.h"
#include "dex.h"
#include "i18n.h"
#include "battle.h"
#include "dayphase.h"
#include "audio.h"

extern uint32_t g_millis; // browser_glue.cpp

// The one live Pet instance is browser_glue.cpp's; declared there as a file-
// local, so this file gets its own accessor rather than reaching across.
extern "C" int tp_is_egg();
extern "C" int tp_sleeping();
extern "C" int tp_species_id();
extern "C" int tp_level();

namespace {

inline uint8_t rnd100() { return (uint8_t)(std::rand() % 100); }

BattleStats playerStats() {
  BattleStats s{};
  s.level = (uint8_t)tp_level();
  // pet.h doesn't expose atk/def/speStat() through a C export yet (only
  // needed here) -- computed the same way TPBattlePlayerStats() does, via
  // the real Pet methods, reached through the shared instance below.
  return s;
}

} // namespace

// tp_tick() in browser_glue.cpp owns the one Pet; battle math needs read
// access to it (level/species/stats) and, on win/loss, needs to call its
// apply*/tryCatch* methods -- both cross this same extern rather than
// duplicating a second Pet.
extern Pet &tp_battle_pet();

namespace {

const uint32_t kWildCooldownMs = 20UL * 60UL * 1000UL;
const uint32_t kWildPromptMs = 20000UL;
const uint32_t kWildCheckMs = 60000UL;

// Wild encounter prompt (idle screen)
bool gWildPromptActive = false;
int16_t gWildPromptDex = 0;
uint8_t gWildPromptLevel = 0;
uint32_t gWildPromptUntilMs = 0;
uint32_t gNextWildEligibleMs = 0;
uint32_t gLastWildCheckMs = 0;

// Battle
bool gOpen = false, gResolved = false;
int16_t gDex = 0;
uint8_t gLevel = 0;
BattleStats gPlayer{}, gEnemy{};
BattleRuntime gRun{};
BattleTurnResult gTurn{};
bool gAttackMenuOpen = false;
char gMessage[28] = {0};
bool gLowHpWarned = false;

bool gCatchOffered = false, gCatchTried = false, gCatchDone = false,
     gCatchSuccess = false, gRespectCatch = false;
uint8_t gCatchChance = 0;
std::string gRewardLine;

BattleStats realPlayerStats() {
  Pet &pet = tp_battle_pet();
  BattleStats stats{};
  stats.level = pet.level();
  stats.atk = pet.atkStat();
  stats.def = pet.defStat();
  stats.spe = pet.speStat();
  stats.hp = 0;
  if (!pet.isEgg() && pet.speciesId >= 1 && pet.speciesId <= DEX_COUNT) {
    const DexEntry &d = DEX_TBL[pet.speciesId];
    stats.type1 = d.type1;
    stats.type2 = d.type2;
  }
  return stats;
}

uint8_t dayPhaseNow() {
  return dayPhaseFromEpoch(tp_battle_pet().lastSeenEpoch);
}

void startBattle(int16_t forcedDex, uint8_t forcedLevel) {
  Pet &pet = tp_battle_pet();
  gWildPromptActive = false;
  gNextWildEligibleMs = g_millis + kWildCooldownMs;

  uint8_t phase = dayPhaseNow();
  if (forcedDex >= 1 && forcedDex <= DEX_COUNT) {
    gDex = forcedDex;
    gLevel = forcedLevel ? forcedLevel : wildLevelFor(pet.level(), rnd100());
  } else {
    gDex = pickWildSpecies(rnd100(), phase);
    gLevel = wildLevelFor(pet.level(), rnd100());
  }
  gPlayer = realPlayerStats();
  gEnemy = wildBattleStats(gDex, gLevel);
  gEnemy.hp = 0;
  gRun = beginBattleRuntime(gPlayer, gEnemy);
  gTurn = BattleTurnResult{};
  gMessage[0] = 0;
  gAttackMenuOpen = false;
  gLowHpWarned = false;
  gCatchOffered = gCatchTried = gCatchDone = gCatchSuccess = gRespectCatch = false;
  gCatchChance = 0;
  gResolved = false;
  gOpen = true;
}

void finishBattle() {
  if (gResolved) return;
  gResolved = true;
  Pet &pet = tp_battle_pet();
  if (gTurn.playerWon) {
    bool closeWin = gRun.playerHp <= gRun.playerMaxHp / 3;
    BattleReward reward = pet.applyBattleWin(gDex, closeWin);
    if (reward.amount == 0) {
      gRewardLine = "";
    } else {
      StrId fmt = S_SPD_GAIN_FMT;
      if (reward.stat == BATTLE_REWARD_ATK) fmt = S_ATK_GAIN_FMT;
      else if (reward.stat == BATTLE_REWARD_DEF) fmt = S_DEF_GAIN_FMT;
      char out[24];
      snprintf(out, sizeof(out), T(fmt), reward.amount);
      gRewardLine = out;
    }
    gCatchOffered = true;
    gRespectCatch = false;
    gCatchChance = pet.catchChanceForWild(gDex, gLevel, gPlayer.level, closeWin);
    sfxPlay(SFX_BATTLE_WIN);
  } else {
    gRewardLine = "";
    pet.applyBattleLoss();
    bool closeLoss = gRun.enemyHp > 0 &&
                      (uint32_t)gRun.enemyHp * 100UL <= (uint32_t)gRun.enemyMaxHp * 30UL;
    gCatchChance = closeLoss ? pet.respectCatchChanceForWild(gDex, gLevel, gPlayer.level) : 0;
    gCatchOffered = gCatchChance > 0;
    gRespectCatch = gCatchOffered;
    sfxPlay(SFX_BATTLE_LOSS);
  }
}

} // namespace

extern "C" {

// --- Static localized labels ---------------------------------------------
// Thin T(StrId) wrappers for every fixed label the battle screen and wild
// prompt need -- everything dynamic (round label, message, result lines)
// has its own snprintf-backed export further down.

EMSCRIPTEN_KEEPALIVE const char *tp_battle_wild_question_text() { return T(S_WILD_Q); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_fight_text() { return T(S_FIGHT); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_later_text() { return T(S_LATER); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_title_text() { return T(S_WILD_BATTLE); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_run_text() { return T(S_RUN_BATTLE); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_attack_text() { return T(S_ATTACK); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_dodge_text() { return T(S_DODGE); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_quick_attack_text() { return T(S_QUICK_ATTACK); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_heavy_attack_text() { return T(S_HEAVY_ATTACK); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_catch_wild_text() { return T(S_CATCH_WILD); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_leave_wild_text() { return T(S_LEAVE_WILD); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_ok_text() { return T(S_OK); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_caught_ok_text() { return T(S_CAUGHT_OK); }
EMSCRIPTEN_KEEPALIVE const char *tp_battle_escaped_text() { return T(S_ESCAPED); }

// --- Wild encounter prompt -------------------------------------------

EMSCRIPTEN_KEEPALIVE
void tp_battle_check_wild(int mainScreenReady) {
  uint32_t now = g_millis;
  if (gNextWildEligibleMs == 0) {
    gNextWildEligibleMs = now + kWildCooldownMs;
    return;
  }
  if (gWildPromptActive) return;
  if (now - gLastWildCheckMs < kWildCheckMs) return;
  gLastWildCheckMs = now;
  if ((int32_t)(now - gNextWildEligibleMs) < 0) return;
  if (!mainScreenReady) return;

  Pet &pet = tp_battle_pet();
  uint8_t phase = dayPhaseNow();
  int16_t cand = pickWildSpecies(rnd100(), phase);
  uint8_t chance = (phase == 3) ? 4 : (phase == 0 ? 7 : 8);
  if (phase == 3 && cand >= 1 && cand <= DEX_COUNT) {
    const DexEntry &d = DEX_TBL[cand];
    if (d.type1 == TYPE_GHOST || d.type2 == TYPE_GHOST ||
        d.type1 == TYPE_POISON || d.type2 == TYPE_POISON) chance = 8;
  }
  if (rnd100() >= chance) return;

  gWildPromptDex = cand;
  gWildPromptLevel = wildLevelFor(pet.level(), rnd100());
  gWildPromptActive = true;
  gWildPromptUntilMs = now + kWildPromptMs;
  gNextWildEligibleMs = now + kWildCooldownMs;
}

EMSCRIPTEN_KEEPALIVE
int tp_wild_prompt_active() {
  if (gWildPromptActive && (int32_t)(g_millis - gWildPromptUntilMs) >= 0) {
    gWildPromptActive = false;
  }
  return gWildPromptActive ? 1 : 0;
}
EMSCRIPTEN_KEEPALIVE int tp_wild_prompt_dex() { return gWildPromptDex; }
EMSCRIPTEN_KEEPALIVE int tp_wild_prompt_level() { return gWildPromptLevel; }
EMSCRIPTEN_KEEPALIVE void tp_wild_dismiss() { gWildPromptActive = false; }
EMSCRIPTEN_KEEPALIVE
void tp_wild_accept() {
  int16_t dex = gWildPromptDex;
  uint8_t level = gWildPromptLevel;
  gWildPromptActive = false;
  startBattle(dex, level);
}

// --- Lifecycle ---------------------------------------------------------

EMSCRIPTEN_KEEPALIVE
int tp_battle_can_start() {
  Pet &pet = tp_battle_pet();
  return canStartWildBattle(pet.isEgg(), pet.sleeping, pet.ceremony) ? 1 : 0;
}
EMSCRIPTEN_KEEPALIVE void tp_battle_start() { startBattle(0, 0); }
EMSCRIPTEN_KEEPALIVE
void tp_battle_close() {
  gOpen = false;
  gResolved = false;
  gAttackMenuOpen = false;
  gCatchOffered = gCatchTried = gCatchDone = gCatchSuccess = gRespectCatch = false;
  gCatchChance = 0;
}

EMSCRIPTEN_KEEPALIVE int tp_battle_is_open() { return gOpen ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_resolved() { return gResolved ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_wild_dex() { return gDex; }
EMSCRIPTEN_KEEPALIVE int tp_battle_wild_level() { return gLevel; }
EMSCRIPTEN_KEEPALIVE int tp_battle_wild_already_caught() {
  return tp_battle_pet().isCaught(gDex) ? 1 : 0;
}
EMSCRIPTEN_KEEPALIVE int tp_battle_player_hp() { return gRun.playerHp; }
EMSCRIPTEN_KEEPALIVE int tp_battle_player_max_hp() { return gRun.playerMaxHp; }
EMSCRIPTEN_KEEPALIVE int tp_battle_enemy_hp() { return gRun.enemyHp; }
EMSCRIPTEN_KEEPALIVE int tp_battle_enemy_max_hp() { return gRun.enemyMaxHp; }
EMSCRIPTEN_KEEPALIVE int tp_battle_rest_uses_left() { return gRun.restUsesLeft; }
EMSCRIPTEN_KEEPALIVE int tp_battle_attack_menu_open() { return gAttackMenuOpen ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_last_enemy_damage() { return gTurn.enemyDamage; }
EMSCRIPTEN_KEEPALIVE int tp_battle_player_won() { return gTurn.playerWon ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_round() { return gRun.round; }

EMSCRIPTEN_KEEPALIVE
const char *tp_battle_message() { return gMessage; }

EMSCRIPTEN_KEEPALIVE
const char *tp_battle_round_label() {
  static std::string out;
  char buf[14];
  snprintf(buf, sizeof(buf), T(S_ROUND_SHORT_FMT), gRun.round + 1);
  out = buf;
  return out.c_str();
}

EMSCRIPTEN_KEEPALIVE
const char *tp_battle_player_label() {
  static std::string out;
  Pet &pet = tp_battle_pet();
  const char *name = pet.nick[0] ? pet.nick : dexName(pet.speciesId);
  char buf[28];
  snprintf(buf, sizeof(buf), "%s Lv.%u", name, gPlayer.level);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE
const char *tp_battle_enemy_label() {
  static std::string out;
  char buf[28];
  snprintf(buf, sizeof(buf), "%s Lv.%u", dexName(gDex), gLevel);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_battle_rest_text() {
  static std::string out;
  char buf[18];
  snprintf(buf, sizeof(buf), "%s %u", T(S_REST), gRun.restUsesLeft);
  out = buf;
  return out.c_str();
}

// --- Actions -------------------------------------------------------------

EMSCRIPTEN_KEEPALIVE void tp_battle_open_attack_menu() { gAttackMenuOpen = true; }
EMSCRIPTEN_KEEPALIVE void tp_battle_close_attack_menu() { gAttackMenuOpen = false; }

void performAction(BattleAction action) {
  if (gResolved) return;
  gAttackMenuOpen = false;
  gTurn = stepBattle(gRun, action, rnd100());

  if (gTurn.restFailed) {
    snprintf(gMessage, sizeof(gMessage), "%s", T(S_NO_REST));
  } else if (gTurn.counterReady) {
    snprintf(gMessage, sizeof(gMessage), "%s", T(S_COUNTER_READY));
  } else if (gTurn.playerRested) {
    char heal[18];
    snprintf(heal, sizeof(heal), T(S_RESTED_FMT), gTurn.playerHeal);
    snprintf(gMessage, sizeof(gMessage), "%s %s", heal, T(S_GUARD));
  } else if (gTurn.playerDamage > 0) {
    if (gTurn.playerTypePct > 100) snprintf(gMessage, sizeof(gMessage), "%s %u", T(S_EFFECTIVE), gTurn.playerDamage);
    else if (gTurn.playerTypePct < 100) snprintf(gMessage, sizeof(gMessage), "%s %u", T(S_NOT_EFFECTIVE), gTurn.playerDamage);
    else snprintf(gMessage, sizeof(gMessage), T(S_HIT_FMT), gTurn.playerDamage);
  } else if (gTurn.enemyDodged) {
    snprintf(gMessage, sizeof(gMessage), "%s", T(S_ENEMY_DODGED));
  } else if (gTurn.playerDodged) {
    snprintf(gMessage, sizeof(gMessage), "%s", T(S_DODGED));
  } else {
    snprintf(gMessage, sizeof(gMessage), "%s", T(S_MISSED));
  }

  if (gTurn.battleEnded) {
    finishBattle();
    return;
  }
  if (!gLowHpWarned && gRun.playerHp > 0 && gRun.playerHp <= gRun.playerMaxHp * 3 / 10) {
    gLowHpWarned = true;
    sfxPlay(SFX_LOW_HP);
  }
  if (gTurn.restFailed) sfxPlay(SFX_DENY);
  else if (gTurn.counterReady) sfxPlay(SFX_COUNTER);
  else if (gTurn.playerRested) sfxPlay(SFX_REST);
  else if (action == BATTLE_ATTACK_QUICK) sfxPlay(SFX_ATTACK_QUICK);
  else if (action == BATTLE_ATTACK_HEAVY) sfxPlay(SFX_ATTACK_HEAVY);
  else if (gTurn.playerDamage > 0 && gTurn.playerTypePct > 100) sfxPlay(SFX_EFFECTIVE);
  else if (gTurn.playerDamage > 0 && gTurn.playerTypePct < 100) sfxPlay(SFX_WEAK_HIT);
  else if (gTurn.enemyDamage > 0) sfxPlay(SFX_ENEMY_HIT);
  else sfxPlay(gTurn.playerDamage > 0 ? SFX_PLAY : SFX_TAP);
}

EMSCRIPTEN_KEEPALIVE void tp_battle_quick_attack() { performAction(BATTLE_ATTACK_QUICK); }
EMSCRIPTEN_KEEPALIVE void tp_battle_heavy_attack() { performAction(BATTLE_ATTACK_HEAVY); }
EMSCRIPTEN_KEEPALIVE void tp_battle_dodge() { performAction(BATTLE_DODGE); }
EMSCRIPTEN_KEEPALIVE void tp_battle_rest() { performAction(BATTLE_REST); }

// --- Resolved screen -----------------------------------------------------

EMSCRIPTEN_KEEPALIVE
const char *tp_battle_result_text() { return T(gTurn.playerWon ? S_WIN : S_LOSS); }
EMSCRIPTEN_KEEPALIVE
const char *tp_battle_rounds_line() {
  static std::string out;
  char buf[20];
  snprintf(buf, sizeof(buf), T(S_ROUNDS_FMT), gRun.round);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE
const char *tp_battle_damage_line() {
  static std::string out;
  char buf[28];
  snprintf(buf, sizeof(buf), T(S_DAMAGE_FMT), gRun.playerDamageTotal, gRun.enemyDamageTotal);
  out = buf;
  return out.c_str();
}
EMSCRIPTEN_KEEPALIVE const char *tp_battle_reward_line() { return gRewardLine.c_str(); }
EMSCRIPTEN_KEEPALIVE int tp_battle_catch_offered() { return gCatchOffered ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_catch_done() { return gCatchDone ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_catch_tried() { return gCatchTried ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_catch_success() { return gCatchSuccess ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE int tp_battle_respect_catch() { return gRespectCatch ? 1 : 0; }
EMSCRIPTEN_KEEPALIVE
const char *tp_battle_close_chance_text() {
  return (gRespectCatch && gCatchOffered && !gCatchDone) ? T(S_CLOSE_CHANCE) : "";
}

EMSCRIPTEN_KEEPALIVE
void tp_battle_try_catch() {
  if (!gCatchOffered || gCatchDone) return;
  Pet &pet = tp_battle_pet();
  bool closeWin = gRun.playerHp <= gRun.playerMaxHp / 3;
  gCatchTried = true;
  gCatchDone = true;
  uint8_t luck = rnd100();
  if (gRespectCatch) {
    gCatchSuccess = pet.tryRespectCatchWild(gDex, gLevel, gPlayer.level, luck);
  } else {
    gCatchSuccess = pet.tryCatchWild(gDex, gLevel, gPlayer.level, closeWin, luck);
  }
  sfxPlay(gCatchSuccess ? SFX_CATCH_OK : SFX_CATCH_FAIL);
}
EMSCRIPTEN_KEEPALIVE
void tp_battle_leave_wild() {
  gCatchDone = true;
  gCatchTried = false;
  sfxPlay(SFX_TAP);
}

} // extern "C"
