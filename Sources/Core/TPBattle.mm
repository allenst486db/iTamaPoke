//
// Translated from ShadowEnemyx/TamaPoke ("TamaPoke — Expanded"), a separate
// community fork -- not from the upstream/ submodule. See
// upstream-expanded/README.md. Covers TamaPoke.ino's wild-encounter-prompt
// and battle-screen logic (maybeOfferWildEncounter, startBattleWith,
// finishBattle, performBattleAction, battleTap, renderBattle), which aren't
// vendored themselves (only battle.h/battle.cpp, the pure combat engine,
// and pet.h/pet.cpp are) -- this file is the Swift-facing reimplementation
// of that .ino code, not a line-for-line port of it.
//

#import "TPBattle.h"
#import "TPPet.h"
#include "battle.h"
#include "dex.h"
#include "i18n.h"
#include "dayphase.h"
#include "audio.h"

// Small, deliberate duplication of TPPet.mm's own file-local day-phase and
// petBattleStats() helpers -- both are two or three lines translated
// straight from the .ino, and sharing them isn't worth a new header only
// this pair of files would use.
static uint8_t TPBattleDayPhase() {
  return dayPhaseFromHour(sceneHourFromEpoch(TPPet.shared.lastSeenEpoch));
}

static BattleStats TPBattlePlayerStats() {
  TPPet *pet = TPPet.shared;
  BattleStats stats = {};
  stats.level = pet.level;
  stats.atk = pet.atkStat;
  stats.def = pet.defStat;
  stats.spe = pet.speStat;
  stats.hp = 0;
  if (!pet.isEgg && pet.speciesId >= 1 && pet.speciesId <= DEX_COUNT) {
    const DexEntry &d = DEX_TBL[pet.speciesId];
    stats.type1 = d.type1;
    stats.type2 = d.type2;
  }
  return stats;
}

@implementation TPBattle {
  // wild encounter prompt (idle screen)
  BOOL _wildPromptActive;
  int16_t _wildPromptDex;
  uint8_t _wildPromptLevel;
  uint32_t _wildPromptUntilMs;
  uint32_t _nextWildEligibleMs;
  uint32_t _lastWildCheckMs;

  // battle
  BOOL _open;
  BOOL _resolved;
  int16_t _dex;
  uint8_t _level;
  BattleStats _player;
  BattleStats _enemy;
  BattleRuntime _run;
  BattleTurnResult _turn;
  BOOL _attackMenuOpen;
  char _message[28];
  BOOL _lowHpWarned;

  BOOL _catchOffered, _catchTried, _catchDone, _catchSuccess, _respectCatch;
  uint8_t _catchChance;
  NSString *_rewardLineCache;
}

+ (TPBattle *)shared {
  static TPBattle *s = [TPBattle new];
  return s;
}

+ (uint8_t)typeEffectPct:(uint8_t)attackType
               defender1:(uint8_t)defendType1
               defender2:(uint8_t)defendType2 {
  return battleTypeEffectPct(attackType, defendType1, defendType2);
}

// Upstream's WILD_COOLDOWN_MS/WILD_PROMPT_MS/WILD_CHECK_MS, in the same
// millis() units TPPet's -update runs on.
static const uint32_t kWildCooldownMs = 20UL * 60UL * 1000UL;
static const uint32_t kWildPromptMs = 20000UL;
static const uint32_t kWildCheckMs = 60000UL;

static uint32_t TPNowMs(void) {
  return (uint32_t)([[NSProcessInfo processInfo] systemUptime] * 1000.0);
}

#pragma mark - Wild encounter prompt

- (void)maybeOfferWildEncounterIfEligible:(BOOL)mainScreenReady {
  uint32_t now = TPNowMs();
  if (_nextWildEligibleMs == 0) {
    _nextWildEligibleMs = now + kWildCooldownMs;
    return;
  }
  if (_wildPromptActive) return;
  if (now - _lastWildCheckMs < kWildCheckMs) return;
  _lastWildCheckMs = now;
  if ((int32_t)(now - _nextWildEligibleMs) < 0) return;
  if (!mainScreenReady) return;

  TPPet *pet = TPPet.shared;
  uint8_t phase = TPBattleDayPhase();
  int16_t cand = pickWildSpecies((uint8_t)arc4random_uniform(100), phase);
  uint8_t chance = (phase == 3) ? 4 : (phase == 0 ? 7 : 8);
  if (phase == 3 && cand >= 1 && cand <= DEX_COUNT) {
    const DexEntry &d = DEX_TBL[cand];
    if (d.type1 == TYPE_GHOST || d.type2 == TYPE_GHOST ||
        d.type1 == TYPE_POISON || d.type2 == TYPE_POISON) chance = 8;
  }
  if ((uint8_t)arc4random_uniform(100) >= chance) return;

  _wildPromptDex = cand;
  _wildPromptLevel = wildLevelFor(pet.level, (uint8_t)arc4random_uniform(100));
  _wildPromptActive = YES;
  _wildPromptUntilMs = now + kWildPromptMs;
  _nextWildEligibleMs = now + kWildCooldownMs;
}

- (BOOL)wildPromptActive {
  if (_wildPromptActive && (int32_t)(TPNowMs() - _wildPromptUntilMs) >= 0) {
    _wildPromptActive = NO;
  }
  return _wildPromptActive;
}
- (NSString *)wildPromptLine {
  char out[28];
  snprintf(out, sizeof(out), "%s Lv.%u", TPDexName(_wildPromptDex).UTF8String, _wildPromptLevel);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)wildQuestionText { return [NSString stringWithUTF8String:T(S_WILD_Q)]; }
- (NSString *)fightText { return [NSString stringWithUTF8String:T(S_FIGHT)]; }
- (NSString *)laterText { return [NSString stringWithUTF8String:T(S_LATER)]; }
- (void)dismissWildPrompt { _wildPromptActive = NO; }
- (void)acceptWildPrompt {
  int16_t dex = _wildPromptDex;
  uint8_t level = _wildPromptLevel;
  _wildPromptActive = NO;
  [self startWithDex:dex level:level];
}

#pragma mark - Lifecycle

- (BOOL)canStart {
  TPPet *pet = TPPet.shared;
  return canStartWildBattle(pet.isEgg, pet.sleeping, (uint8_t)pet.ceremony);
}

- (void)start { [self startWithDex:0 level:0]; }

- (void)startWithDex:(int16_t)forcedDex level:(uint8_t)forcedLevel {
  if (!self.canStart) return;
  _wildPromptActive = NO;
  _nextWildEligibleMs = TPNowMs() + kWildCooldownMs;

  TPPet *pet = TPPet.shared;
  uint8_t phase = TPBattleDayPhase();
  if (forcedDex >= 1 && forcedDex <= DEX_COUNT) {
    _dex = forcedDex;
    _level = forcedLevel ? forcedLevel : wildLevelFor(pet.level, (uint8_t)arc4random_uniform(100));
  } else {
    _dex = pickWildSpecies((uint8_t)arc4random_uniform(100), phase);
    _level = wildLevelFor(pet.level, (uint8_t)arc4random_uniform(100));
  }
  _player = TPBattlePlayerStats();
  _enemy = wildBattleStats(_dex, _level);
  _enemy.hp = 0;
  _run = beginBattleRuntime(_player, _enemy);
  _turn = BattleTurnResult{};
  _message[0] = 0;
  _attackMenuOpen = NO;
  _lowHpWarned = NO;
  _catchOffered = _catchTried = _catchDone = _catchSuccess = _respectCatch = NO;
  _catchChance = 0;
  _resolved = NO;
  _open = YES;
}

- (void)close {
  _open = NO;
  _resolved = NO;
  _attackMenuOpen = NO;
  _catchOffered = _catchTried = _catchDone = _catchSuccess = _respectCatch = NO;
  _catchChance = 0;
}

- (BOOL)isOpen { return _open; }
- (BOOL)resolved { return _resolved; }
- (int16_t)wildDex { return _dex; }
- (uint8_t)wildLevel { return _level; }
- (BOOL)wildAlreadyCaught { return [TPPet.shared isCaught:_dex]; }
- (uint16_t)playerHp { return _run.playerHp; }
- (uint16_t)playerMaxHp { return _run.playerMaxHp; }
- (uint16_t)enemyHp { return _run.enemyHp; }
- (uint16_t)enemyMaxHp { return _run.enemyMaxHp; }
- (uint8_t)restUsesLeft { return _run.restUsesLeft; }
- (BOOL)attackMenuOpen { return _attackMenuOpen; }
- (NSString *)roundLabel {
  char out[14];
  snprintf(out, sizeof(out), T(S_ROUND_SHORT_FMT), _run.round + 1);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)battleMessage { return [NSString stringWithUTF8String:_message]; }
- (uint16_t)lastEnemyDamage { return _turn.enemyDamage; }

- (NSString *)titleText { return [NSString stringWithUTF8String:T(S_WILD_BATTLE)]; }
- (NSString *)playerLabel {
  TPPet *pet = TPPet.shared;
  NSString *name = pet.nick.length ? pet.nick : pet.speciesName;
  char out[28];
  snprintf(out, sizeof(out), "%s Lv.%u", name.UTF8String, _player.level);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)enemyLabel {
  char out[28];
  snprintf(out, sizeof(out), "%s Lv.%u", TPDexName(_dex).UTF8String, _level);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)runText { return [NSString stringWithUTF8String:T(S_RUN_BATTLE)]; }
- (NSString *)attackText { return [NSString stringWithUTF8String:T(S_ATTACK)]; }
- (NSString *)dodgeText { return [NSString stringWithUTF8String:T(S_DODGE)]; }
- (NSString *)restText {
  char out[18];
  snprintf(out, sizeof(out), "%s %u", T(S_REST), _run.restUsesLeft);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)quickAttackText { return [NSString stringWithUTF8String:T(S_QUICK_ATTACK)]; }
- (NSString *)heavyAttackText { return [NSString stringWithUTF8String:T(S_HEAVY_ATTACK)]; }

#pragma mark - Actions

- (void)openAttackMenu { _attackMenuOpen = YES; }
- (void)closeAttackMenu { _attackMenuOpen = NO; }
- (void)performQuickAttack { [self performAction:BATTLE_ATTACK_QUICK]; }
- (void)performHeavyAttack { [self performAction:BATTLE_ATTACK_HEAVY]; }
- (void)performDodge { [self performAction:BATTLE_DODGE]; }
- (void)performRest { [self performAction:BATTLE_REST]; }

- (void)performAction:(BattleAction)action {
  if (_resolved) return;
  _attackMenuOpen = NO;
  _turn = stepBattle(_run, action, (uint8_t)arc4random_uniform(100));

  if (_turn.restFailed) {
    snprintf(_message, sizeof(_message), "%s", T(S_NO_REST));
  } else if (_turn.counterReady) {
    snprintf(_message, sizeof(_message), "%s", T(S_COUNTER_READY));
  } else if (_turn.playerRested) {
    char heal[18];
    snprintf(heal, sizeof(heal), T(S_RESTED_FMT), _turn.playerHeal);
    snprintf(_message, sizeof(_message), "%s %s", heal, T(S_GUARD));
  } else if (_turn.playerDamage > 0) {
    if (_turn.playerTypePct > 100) snprintf(_message, sizeof(_message), "%s %u", T(S_EFFECTIVE), _turn.playerDamage);
    else if (_turn.playerTypePct < 100) snprintf(_message, sizeof(_message), "%s %u", T(S_NOT_EFFECTIVE), _turn.playerDamage);
    else snprintf(_message, sizeof(_message), T(S_HIT_FMT), _turn.playerDamage);
  } else if (_turn.enemyDodged) {
    snprintf(_message, sizeof(_message), "%s", T(S_ENEMY_DODGED));
  } else if (_turn.playerDodged) {
    snprintf(_message, sizeof(_message), "%s", T(S_DODGED));
  } else {
    snprintf(_message, sizeof(_message), "%s", T(S_MISSED));
  }

  if (_turn.battleEnded) {
    [self finish];
    return;
  }
  if (!_lowHpWarned && _run.playerHp > 0 && _run.playerHp <= _run.playerMaxHp * 3 / 10) {
    _lowHpWarned = YES;
    sfxPlay(SFX_LOW_HP);
  }
  if (_turn.restFailed) sfxPlay(SFX_DENY);
  else if (_turn.counterReady) sfxPlay(SFX_COUNTER);
  else if (_turn.playerRested) sfxPlay(SFX_REST);
  else if (action == BATTLE_ATTACK_QUICK) sfxPlay(SFX_ATTACK_QUICK);
  else if (action == BATTLE_ATTACK_HEAVY) sfxPlay(SFX_ATTACK_HEAVY);
  else if (_turn.playerDamage > 0 && _turn.playerTypePct > 100) sfxPlay(SFX_EFFECTIVE);
  else if (_turn.playerDamage > 0 && _turn.playerTypePct < 100) sfxPlay(SFX_WEAK_HIT);
  else if (_turn.enemyDamage > 0) sfxPlay(SFX_ENEMY_HIT);
  else sfxPlay(_turn.playerDamage > 0 ? SFX_PLAY : SFX_TAP);
}

- (void)finish {
  if (_resolved) return;
  _resolved = YES;
  TPPet *pet = TPPet.shared;
  if (_turn.playerWon) {
    BOOL closeWin = _run.playerHp <= _run.playerMaxHp / 3;
    _rewardLineCache = [pet applyBattleWinWithDex:_dex closeWin:closeWin];
    _catchOffered = YES;
    _respectCatch = NO;
    _catchChance = [pet catchChanceForWildDex:_dex wildLevel:_level petLevel:_player.level closeWin:closeWin];
    sfxPlay(SFX_BATTLE_WIN);
  } else {
    _rewardLineCache = @"";
    [pet applyBattleLoss];
    BOOL closeLoss = _run.enemyHp > 0 && (uint32_t)_run.enemyHp * 100UL <= (uint32_t)_run.enemyMaxHp * 30UL;
    _catchChance = closeLoss ? [pet respectCatchChanceForWildDex:_dex wildLevel:_level petLevel:_player.level] : 0;
    _catchOffered = _catchChance > 0;
    _respectCatch = _catchOffered;
    sfxPlay(SFX_BATTLE_LOSS);
  }
}

#pragma mark - Resolved screen

- (BOOL)playerWon { return _turn.playerWon; }
- (NSString *)resultText { return [NSString stringWithUTF8String:T(_turn.playerWon ? S_WIN : S_LOSS)]; }
- (NSString *)roundsLine {
  char out[20];
  snprintf(out, sizeof(out), T(S_ROUNDS_FMT), _run.round);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)damageLine {
  char out[28];
  snprintf(out, sizeof(out), T(S_DAMAGE_FMT), _run.playerDamageTotal, _run.enemyDamageTotal);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)rewardLine { return _rewardLineCache ?: @""; }
- (BOOL)catchOffered { return _catchOffered; }
- (BOOL)catchDone { return _catchDone; }
- (BOOL)catchTried { return _catchTried; }
- (BOOL)catchSuccess { return _catchSuccess; }
- (BOOL)respectCatch { return _respectCatch; }
- (NSString *)closeChanceText {
  return (_respectCatch && _catchOffered && !_catchDone)
    ? [NSString stringWithUTF8String:T(S_CLOSE_CHANCE)] : @"";
}
- (NSString *)catchWildText { return [NSString stringWithUTF8String:T(S_CATCH_WILD)]; }
- (NSString *)leaveWildText { return [NSString stringWithUTF8String:T(S_LEAVE_WILD)]; }
- (NSString *)okText { return [NSString stringWithUTF8String:T(S_OK)]; }
- (NSString *)caughtOkText { return [NSString stringWithUTF8String:T(S_CAUGHT_OK)]; }
- (NSString *)escapedText { return [NSString stringWithUTF8String:T(S_ESCAPED)]; }

- (void)tryCatch {
  if (!_catchOffered || _catchDone) return;
  TPPet *pet = TPPet.shared;
  BOOL closeWin = _run.playerHp <= _run.playerMaxHp / 3;
  _catchTried = YES;
  _catchDone = YES;
  uint8_t luck = (uint8_t)arc4random_uniform(100);
  if (_respectCatch) {
    _catchSuccess = [pet tryRespectCatchWildDex:_dex wildLevel:_level petLevel:_player.level luckRoll:luck];
  } else {
    _catchSuccess = [pet tryCatchWildDex:_dex wildLevel:_level petLevel:_player.level closeWin:closeWin luckRoll:luck];
  }
  sfxPlay(_catchSuccess ? SFX_CATCH_OK : SFX_CATCH_FAIL);
}
- (void)leaveWild {
  _catchDone = YES;
  _catchTried = NO;
  sfxPlay(SFX_TAP);
}

@end
