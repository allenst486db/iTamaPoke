//
// The presentation-string section below (statusMessage, eggMessage, headerName,
// pokedexLine, eggRarityLabel) and the starter table are translated from
// TamaPoke by Quique Tortosa, MIT licensed:
// https://github.com/socquique/TamaPoke (TamaPoke.ino). See LICENSE.
//

#import "TPPet.h"
#include "pet.h"
#include "dex.h"
#include "i18n.h"
#include "dayphase.h"
#include "battle.h"   // BattleReward only, here -- the actual runtime lives in TPBattle.mm

// The one live game state. Upstream keeps a file-scope `Pet pet;` in the .ino
// and every subsystem reaches for it; mirroring that keeps the port honest.
static Pet gPet;

// Upstream defines its starters in the .ino, not in a header, and offers the
// three gen-1 ones. With the dex extended to gen 1-3 this build offers each
// generation's trio, in dex order. The picker shows exactly one trio per page
// (see PetScreen's starterRowsPerPage), so this order is also the page order:
// gen 1, gen 2, gen 3. Keep it a multiple of three, or a page ends up short.
static const int16_t kStarterDex[] = {
    1,  // Bulbasaur
    4,  // Charmander
    7,  // Squirtle
  152,  // Chikorita
  155,  // Cyndaquil
  158,  // Totodile
  252,  // Treecko
  255,  // Torchic
  258,  // Mudkip
};
static const NSInteger kStarterCount = sizeof(kStarterDex) / sizeof(kStarterDex[0]);

extern "C" void TPSetSfxHook(void (*hook)(uint8_t));
static void (^gSfxBlock)(uint8_t) = nil;
static void TPSfxTrampoline(uint8_t id) { if (gSfxBlock) gSfxBlock(id); }

static uint32_t TPNowEpoch(void) {
  return (uint32_t)[[NSDate date] timeIntervalSince1970];
}

// Defined with the static tables below, but the card's presentation strings
// need it from inside the class body.
static const DexEntry *TPDexEntry(int16_t dex);

@implementation TPPet

+ (instancetype)shared {
  static TPPet *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [[TPPet alloc] init]; });
  return shared;
}

- (void)begin {
  loadLang();
  gPet.begin();
  // The firmware reads its RTC here. On iOS the system clock plays that role,
  // which is what makes offline progression work identically.
  gPet.syncClock(TPNowEpoch());
}

// `Pet::begin` re-reads the store when its "init" key is already set, which is
// exactly the reload path — no separate entry point needed on the C++ side.
- (void)reload {
  gPet.begin();
  gPet.syncClock(TPNowEpoch());
}

- (void)update      { gPet.update(millis()); }
- (void)syncClock   { gPet.syncClock(TPNowEpoch()); }
- (void)flushSave   { gPet.flushSave(); }

// --- needs -------------------------------------------------------------
- (uint8_t)fullness { return gPet.fullness; }
- (uint8_t)joy      { return gPet.joy; }
- (uint8_t)energy   { return gPet.energy; }
- (uint8_t)hygiene  { return gPet.hygiene; }
- (uint8_t)poops    { return gPet.poops; }
- (uint8_t)weight   { return gPet.weight; }

// --- identity ----------------------------------------------------------
- (int16_t)speciesId     { return gPet.speciesId; }
- (int16_t)prevSpeciesId { return gPet.prevSpeciesId; }
- (BOOL)shiny            { return gPet.shiny; }
- (BOOL)isEgg            { return gPet.isEgg(); }
- (uint8_t)level         { return gPet.level(); }
- (uint32_t)ageMinutes   { return gPet.ageMinutes; }
- (uint32_t)lastSeenEpoch { return gPet.lastSeenEpoch; }

- (NSString *)nick {
  return gPet.nick[0] ? [NSString stringWithUTF8String:gPet.nick] : @"";
}

// --- state -------------------------------------------------------------
- (BOOL)sleeping        { return gPet.sleeping; }
- (TPMood)mood          { return (TPMood)gPet.mood(); }
- (BOOL)eating          { return gPet.eating(); }
- (BOOL)showHeart       { return gPet.showHeart(); }
- (BOOL)evolvingNow     { return gPet.evolving(); }
- (float)evolveProgress { return gPet.evolveT(); }
- (TPCeremony)ceremony  { return (TPCeremony)gPet.ceremony; }
- (float)ceremonyProgress { return gPet.ceremonyT(); }
- (BOOL)savePending     { return gPet.savePending(); }

// --- egg / dex ---------------------------------------------------------
- (uint8_t)eggCracks        { return gPet.eggCracks(); }
- (uint8_t)eggRarity        { return gPet.eggRarity(); }
- (uint16_t)registeredCount { return gPet.registeredCount(); }
- (BOOL)awaitingStarter     { return gPet.awaitingStarter(); }

// --- retention ---------------------------------------------------------
- (uint16_t)streak { return gPet.streak; }
- (uint8_t)bond    { return gPet.bond; }
- (uint16_t)medals { return gPet.medals; }

// --- decision gates ----------------------------------------------------
- (BOOL)wantsEvolveButton   { return gPet.wantEvolveButton(); }
- (BOOL)canEvolveNow        { return gPet.canEvolveNow(); }
- (BOOL)wantsFarewellButton { return gPet.wantFarewellButton(); }
- (BOOL)canRunawayNow       { return gPet.canRunawayNow(); }

// --- actions -----------------------------------------------------------
- (void)feedBerry:(uint8_t)color { gPet.feedBerry(color); }
- (void)feedCandy   { gPet.feedCandy(); }
- (void)playWithPet { gPet.play(); }
- (void)toggleLight { gPet.toggleLight(); }
- (void)clean       { gPet.clean(); }
- (void)caress      { gPet.caress(); }
- (void)eggTap      { gPet.eggTap(); }
- (BOOL)lovesBerry:(uint8_t)color { return gPet.lovesBerry(color); }
- (void)playResult:(uint8_t)score { gPet.playResult(score); }
- (uint8_t)trainStrength:(uint16_t)hits { return gPet.trainStrength(hits); }
- (uint8_t)applyCatchResult:(uint8_t)score { return gPet.applyCatchResult(score); }

- (NSString *)applyBattleWinWithDex:(int16_t)dex closeWin:(BOOL)closeWin {
  BattleReward reward = gPet.applyBattleWin(dex, closeWin);
  if (reward.amount == 0) return @"";
  StrId fmt = S_SPD_GAIN_FMT;
  if (reward.stat == BATTLE_REWARD_ATK) fmt = S_ATK_GAIN_FMT;
  else if (reward.stat == BATTLE_REWARD_DEF) fmt = S_DEF_GAIN_FMT;
  char out[24];
  snprintf(out, sizeof(out), T(fmt), reward.amount);
  return [NSString stringWithUTF8String:out];
}
- (void)applyBattleLoss { gPet.applyBattleLoss(); }
- (uint8_t)catchChanceForWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel
                        petLevel:(uint8_t)petLevel closeWin:(BOOL)closeWin {
  return gPet.catchChanceForWild(dex, wildLevel, petLevel, closeWin);
}
- (uint8_t)respectCatchChanceForWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel
                               petLevel:(uint8_t)petLevel {
  return gPet.respectCatchChanceForWild(dex, wildLevel, petLevel);
}
- (BOOL)tryCatchWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel petLevel:(uint8_t)petLevel
               closeWin:(BOOL)closeWin luckRoll:(uint8_t)luckRoll {
  return gPet.tryCatchWild(dex, wildLevel, petLevel, closeWin, luckRoll);
}
- (BOOL)tryRespectCatchWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel
                       petLevel:(uint8_t)petLevel luckRoll:(uint8_t)luckRoll {
  return gPet.tryRespectCatchWild(dex, wildLevel, petLevel, luckRoll);
}

- (void)chooseStarter:(int16_t)dex { gPet.chooseStarter(dex); }
- (void)evolve          { gPet.evolve(); }
- (void)declineEvolve   { gPet.declineEvolve(); }
- (void)startFarewell   { gPet.startFarewell(); }
- (void)declineFarewell { gPet.declineFarewell(); }
- (void)startRunaway    { gPet.startRunaway(); }
- (void)releasePet      { gPet.release(); }
- (void)factoryReset    { gPet.factoryReset(); }

- (void)renamePet:(NSString *)name {
  gPet.rename(name.length ? name.UTF8String : "");
}

- (NSInteger)nickCapacity { return (NSInteger)sizeof(gPet.nick) - 1; }

- (BOOL)isRegistered:(int16_t)dex      { return gPet.isRegistered(dex); }
- (BOOL)isShinyRegistered:(int16_t)dex { return gPet.isShinyRegistered(dex); }

// --- presentation strings ----------------------------------------------
// Ports of the .ino's statusMsg() / eggMsg() and the snprintf call sites that
// build the header. The bath line is omitted until the bath scene is ported.

- (NSString *)statusMessage {
  StrId id;
  if (gPet.evolving())            id = S_EVOLVING;
  else if (gPet.sleeping)         return @"Zzz...";
  else if (gPet.eating())         id = S_EATING;
  else if (gPet.showHeart())      id = S_LIKES;
  else if (gPet.fullness < 25)    id = S_HUNGRY;
  else if (gPet.hygiene < 25)     id = S_NEEDS_BATH;
  else if (gPet.energy < 25)      id = S_EXHAUSTED;
  else if (gPet.joy < 25)         id = S_SAD;
  else if (gPet.weight > 60)      id = S_CHUBBY;
  else if (gPet.shiny && gPet.ageMinutes < 15) id = S_IS_SHINY;
  else                            id = S_HAPPY;
  return [NSString stringWithUTF8String:T(id)];
}

- (NSString *)eggMessage {
  StrId id = gPet.eggCracks() == 0 ? S_EGG_TOUCH
           : gPet.eggCracks() == 1 ? S_EGG_MOVES
                                   : S_EGG_ALMOST;
  return [NSString stringWithUTF8String:T(id)];
}

- (NSString *)headerName {
  if (gPet.isEgg()) return [NSString stringWithUTF8String:T(S_EGG_HDR)];
  const char *base = gPet.nick[0] ? gPet.nick : dexName(gPet.speciesId);
  char out[40];
  snprintf(out, sizeof(out), T(S_NAME_FMT), gPet.shiny ? "*" : "", base, gPet.level());
  return [NSString stringWithUTF8String:out];
}

- (NSString *)pokedexLine {
  char out[32];
  snprintf(out, sizeof(out), T(S_POKEDEX_FMT), gPet.registeredCount());
  return [NSString stringWithUTF8String:out];
}

- (NSString *)eggRarityLabel {
  uint8_t r = gPet.eggRarity();
  if (r < R_RARO) return nil;
  return [NSString stringWithUTF8String:T(r == R_LEGENDARIO ? S_EGG_LEGEND : S_EGG_RARE)];
}

- (NSString *)ceremonyMessage {
  StrId id = gPet.ceremony == CER_FAREWELL ? S_FAREWELL
           : gPet.ceremony == CER_RUNAWAY  ? S_RUNAWAY
                                           : S_GOODBYE;
  return [NSString stringWithUTF8String:T(id)];
}

// --- decision prompts --------------------------------------------------
// The two CTA strings take the creature's name, so they are composed with the
// same nick-or-dex-name rule drawEvolveButton/drawFarewellButton use upstream.
static NSString *TPNamedPrompt(StrId id) {
  const char *nm = gPet.nick[0] ? gPet.nick : dexName(gPet.speciesId);
  char out[64];
  snprintf(out, sizeof(out), T(id), nm);
  return [NSString stringWithUTF8String:out];
}

- (NSString *)evolveButtonText   { return [NSString stringWithUTF8String:T(S_EVO_TAP)]; }
- (NSString *)farewellButtonText { return TPNamedPrompt(S_FAREWELL_BTN); }
- (NSString *)runawayButtonText  { return TPNamedPrompt(S_RUNAWAY_BTN); }
- (NSString *)evolveQuestion     { return [NSString stringWithUTF8String:T(S_EVO_Q)]; }
- (NSString *)evolveKeepText     { return [NSString stringWithUTF8String:T(S_EVO_KEEP)]; }
- (NSString *)farewellQuestion   { return [NSString stringWithUTF8String:T(S_FAR_Q)]; }
- (NSString *)farewellGoText     { return [NSString stringWithUTF8String:T(S_FAR_GO)]; }
- (NSString *)farewellStayText   { return [NSString stringWithUTF8String:T(S_FAR_STAY)]; }
- (NSString *)galleryBackText    { return [NSString stringWithUTF8String:T(S_DETAIL_BACK)]; }

// --- stat card ---------------------------------------------------------
- (uint16_t)bestStreak       { return gPet.bestStreak; }
- (uint16_t)atkStat          { return gPet.atkStat(); }
- (uint16_t)defStat          { return gPet.defStat(); }
- (uint16_t)speStat          { return gPet.speStat(); }
- (uint8_t)careMistakes      { return gPet.careMistakes; }
- (uint8_t)minutesIntoLevel  { return gPet.ageMinutes % MINUTES_PER_LEVEL; }
- (uint16_t)minutesPerLevel  { return MINUTES_PER_LEVEL; }
- (BOOL)showMedal            { return gPet.showMedal(); }
- (BOOL)showMilestone        { return gPet.showMilestone(); }
- (NSInteger)medalCount      { return MED_COUNT; }

- (BOOL)hasMedalAtIndex:(NSInteger)i {
  if (i < 0 || i >= MED_COUNT) return NO;
  return gPet.hasMedal(1 << i);
}

- (NSString *)medalDescriptionAtIndex:(NSInteger)i {
  if (i < 0 || i >= MED_COUNT) return @"";
  return [NSString stringWithUTF8String:medalDesc((int)i)];
}

- (NSString *)newMedalName {
  if (!gPet.showMedal()) return nil;
  for (int i = 0; i < MED_COUNT; i++)
    if (gPet.newMedal & (1 << i)) return [NSString stringWithUTF8String:medalName(i)];
  return nil;
}

- (NSString *)speciesName {
  return [NSString stringWithUTF8String:dexName(gPet.speciesId)];
}

- (NSString *)streakLine {
  char out[40];
  snprintf(out, sizeof(out), T(S_STREAK_FMT), gPet.streak, gPet.bestStreak);
  return [NSString stringWithUTF8String:out];
}

- (NSString *)infoLine {
  const char *berry = !gPet.berryKnown      ? T(S_BERRY_UNK)
                    : gPet.lovesBerry(0)    ? T(S_BERRY_RED)
                    : gPet.lovesBerry(1)    ? T(S_BERRY_BLUE)
                                            : T(S_BERRY_GREEN);
  char out[64];
  snprintf(out, sizeof(out), T(S_INFO_FMT), berry, (unsigned long)(gPet.ageMinutes / 1440));
  return [NSString stringWithUTF8String:out];
}

- (NSString *)renameHint     { return [NSString stringWithUTF8String:T(S_RENAME_HINT)]; }
- (NSString *)backHint       { return [NSString stringWithUTF8String:T(S_BACK)]; }
- (NSString *)bondLabel      { return [NSString stringWithUTF8String:T(S_VIN)]; }
- (NSString *)battleTitle    { return [NSString stringWithUTF8String:T(S_BATTLE)]; }
- (NSString *)battleRecordLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_WL_FMT), gPet.battleWins, gPet.battleLosses);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)battleStreakLine {
  char out[18];
  snprintf(out, sizeof(out), T(S_BSTREAK_FMT), gPet.battleStreak);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)battleBestLine {
  char out[16];
  snprintf(out, sizeof(out), T(S_BBEST_FMT), gPet.bestBattleStreak);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)wildBattleText { return [NSString stringWithUTF8String:T(S_WILD_BATTLE)]; }
- (NSString *)catchTitleText { return [NSString stringWithUTF8String:T(S_CATCH_TITLE)]; }
- (NSString *)playTitleText { return [NSString stringWithUTF8String:T(S_PLAY)]; }
- (NSString *)progressTitle  { return [NSString stringWithUTF8String:T(S_PROGRESS)]; }
- (NSString *)trainButtonText{ return [NSString stringWithUTF8String:T(S_TRAIN_STR)]; }
- (NSString *)medalBannerTitle { return [NSString stringWithUTF8String:T(S_MEDAL_BANNER)]; }
- (NSString *)milestoneTitle { return [NSString stringWithUTF8String:T(S_GREAT)]; }

- (NSString *)milestoneLine {
  char out[32];
  snprintf(out, sizeof(out), T(S_STREAK_DAYS_FMT), gPet.streak);
  return [NSString stringWithUTF8String:out];
}

- (NSString *)statLabel:(NSInteger)index {
  StrId ids[4] = { S_STAT_ATK, S_STAT_DEF, S_STAT_SPE, S_STAT_WGT };
  if (index < 0 || index > 3) return @"";
  return [NSString stringWithUTF8String:T(ids[index])];
}

- (NSString *)medalsLine {
  int got = 0;
  for (int i = 0; i < MED_COUNT; i++)
    if (gPet.hasMedal(1 << i)) got++;
  char out[32];
  snprintf(out, sizeof(out), T(S_MEDALS_FMT), got, MED_COUNT);
  return [NSString stringWithUTF8String:out];
}

- (NSString *)levelLine {
  char out[16];
  snprintf(out, sizeof(out), T(S_LVL_FMT), gPet.level());
  return [NSString stringWithUTF8String:out];
}

- (NSString *)nextLevelLine {
  uint8_t into = gPet.ageMinutes % MINUTES_PER_LEVEL;
  char out[40];
  snprintf(out, sizeof(out), T(S_NEXT_LVL_FMT), MINUTES_PER_LEVEL - into, gPet.level() + 1);
  return [NSString stringWithUTF8String:out];
}

- (NSString *)evolutionLabel { return [NSString stringWithUTF8String:T(S_EVO_LABEL)]; }

// Mirrors renderCardProgress's branch, which also decides the colour; the kind
// is returned separately so the Swift side does not re-derive the same rules.
- (NSString *)evolutionStatus {
  const DexEntry *d = TPDexEntry(gPet.speciesId);
  if (d->evolvesTo == 0) return [NSString stringWithUTF8String:T(S_FINAL_FORM)];
  int needed = d->evolveLevel + gPet.careMistakes;
  if (gPet.level() >= needed) {
    return [NSString stringWithUTF8String:T(gPet.lowestStat() >= 40 ? S_EVO_READY : S_EVO_BLOCKED)];
  }
  char out[40];
  snprintf(out, sizeof(out), T(S_EVO_IN_FMT), needed - gPet.level());
  return [NSString stringWithUTF8String:out];
}

- (uint8_t)evolutionStatusKind {
  const DexEntry *d = TPDexEntry(gPet.speciesId);
  if (d->evolvesTo == 0) return 0;
  int needed = d->evolveLevel + gPet.careMistakes;
  if (gPet.level() < needed) return 0;
  return gPet.lowestStat() >= 40 ? 1 : 2;
}

- (NSString *)mistakesLine {
  char out[32];
  snprintf(out, sizeof(out), T(S_MISTAKES_FMT), gPet.careMistakes);
  return [NSString stringWithUTF8String:out];
}

// --- personality / daily / box (ShadowEnemyx/TamaPoke "Expanded" fork) --
// See upstream-expanded/README.md. Colour/label logic below mirrors
// renderCardPersonality / renderCardDaily / renderCardBox / renderGallery's
// filter row in that fork's TamaPoke.ino, which isn't vendored itself (only
// the Pet class and string table are) -- these are the Swift-facing
// equivalents of that drawing code, not a straight port of it.

static StrId TPPersonalityNameId(PetPersonality p) {
  switch (p) {
    case PERS_PLAYFUL: return S_PERS_PLAYFUL;
    case PERS_BRAVE:   return S_PERS_BRAVE;
    case PERS_CALM:    return S_PERS_CALM;
    case PERS_LAZY:    return S_PERS_LAZY;
    default:           return S_PERS_BALANCED;
  }
}
static StrId TPPersonalityHintId(PetPersonality p) {
  switch (p) {
    case PERS_PLAYFUL: return S_PERS_PLAYFUL_HINT;
    case PERS_BRAVE:   return S_PERS_BRAVE_HINT;
    case PERS_CALM:    return S_PERS_CALM_HINT;
    case PERS_LAZY:    return S_PERS_LAZY_HINT;
    default:           return S_PERS_BALANCED_HINT;
  }
}
- (NSInteger)personalityKind { return (NSInteger)gPet.personality(); }
- (NSString *)personalityTitle { return [NSString stringWithUTF8String:T(S_PERSONALITY)]; }
- (NSString *)personalityName {
  return [NSString stringWithUTF8String:T(TPPersonalityNameId(gPet.personality()))];
}
- (NSString *)personalityHint {
  return [NSString stringWithUTF8String:T(TPPersonalityHintId(gPet.personality()))];
}
- (NSString *)personalityAgeLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_AGE_DAYS_FMT), (unsigned long)(gPet.ageMinutes / 1440));
  return [NSString stringWithUTF8String:out];
}
- (NSString *)recordsTitle      { return [NSString stringWithUTF8String:T(S_RECORDS)]; }
- (NSString *)ballRecordLabel   { return [NSString stringWithUTF8String:T(S_GAME_BALL)]; }
- (NSString *)catchRecordLabel  { return [NSString stringWithUTF8String:T(S_GAME_CATCH)]; }
- (NSString *)memoRecordLabel   { return [NSString stringWithUTF8String:T(S_GAME_MEMO)]; }
- (NSString *)cleanRecordLabel  { return [NSString stringWithUTF8String:T(S_GAME_CLEAN)]; }
- (NSString *)typeRecordLabel   { return [NSString stringWithUTF8String:T(S_GAME_TYPE)]; }
- (uint16_t)catchHigh    { return gPet.catchHi; }
- (uint16_t)memoHigh     { return gPet.memoHi; }
- (uint16_t)cleanHigh    { return gPet.cleanHi; }
- (uint16_t)typeHigh     { return gPet.typeHi; }
- (uint16_t)bestBattleStreak { return gPet.bestBattleStreak; }

static NSString *TPFormatted(StrId id, unsigned v) {
  char out[40];
  snprintf(out, sizeof(out), T(id), v);
  return [NSString stringWithUTF8String:out];
}

- (uint8_t)applyMemoResult:(uint8_t)rounds { return gPet.applyMemoResult(rounds); }
- (uint8_t)applyCleanResult:(uint8_t)score { return gPet.applyCleanResult(score); }
- (uint8_t)applyTypeResult:(uint8_t)score  { return gPet.applyTypeResult(score); }
- (NSString *)memoWatchText { return [NSString stringWithUTF8String:T(S_MEMO_WATCH)]; }
- (NSString *)memoWrongText { return [NSString stringWithUTF8String:T(S_MEMO_WRONG)]; }
- (NSString *)memoTurnLine:(NSInteger)input of:(NSInteger)len {
  char out[28];
  snprintf(out, sizeof(out), T(S_MEMO_TURN_FMT), (unsigned)input, (unsigned)len);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)roundLine:(NSInteger)round { return TPFormatted(S_ROUND_FMT, (uint16_t)round); }
- (NSString *)cleanTitleText { return [NSString stringWithUTF8String:T(S_CLEAN_TITLE)]; }
- (NSString *)typeTitleText  { return [NSString stringWithUTF8String:T(S_TYPE_TITLE)]; }
- (NSString *)defGainLine:(uint8_t)gain { return TPFormatted(S_DEF_GAIN_FMT, gain); }
- (NSString *)hygGainLine:(uint8_t)gain { return TPFormatted(S_HYG_GAIN_FMT, gain); }
- (NSString *)atkGainLine:(uint8_t)gain { return TPFormatted(S_ATK_GAIN_FMT, gain); }

- (uint8_t)collectionFrame { return gPet.collectionFrame; }
- (uint8_t)unlockedCollectionFrameCount { return gPet.unlockedCollectionFrameCount(); }
- (BOOL)setCollectionFrame:(uint8_t)frame {
  bool changed = gPet.setCollectionFrame(frame);
  if (changed) gPet.flushSave();
  return changed;
}
- (NSString *)collectionTitle { return [NSString stringWithUTF8String:T(S_COLLECTION)]; }
- (NSString *)collectionRankName {
  return [NSString stringWithUTF8String:T((StrId)(S_RANK_TRAINER + gPet.collectionRank()))];
}
- (NSString *)knownLine { return TPFormatted(S_KNOWN_FMT, gPet.knownDexCount()); }
- (NSString *)frameLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_FRAME_FMT), gPet.collectionFrame + 1,
           gPet.unlockedCollectionFrameCount());
  return [NSString stringWithUTF8String:out];
}

- (NSString *)soundModeLabel:(NSInteger)mode {
  StrId ids[3] = { S_SND_OFF, S_SND_VIB, S_SND_FULL };
  return [NSString stringWithUTF8String:T(ids[mode >= 0 && mode <= 2 ? mode : 0])];
}

- (NSString *)dailyTitle { return [NSString stringWithUTF8String:T(S_DAILY)]; }
// Port of the fork's currentDayPhase()/sceneHour() -- both live in
// TamaPoke.ino (not vendored), built from dayphase.h helpers that are.
static uint8_t TPCurrentDayPhase() {
  return dayPhaseFromHour(sceneHourFromEpoch(gPet.lastSeenEpoch));
}
- (NSString *)dayPhaseLabel {
  StrId id;
  switch (TPCurrentDayPhase()) {
    case 0:  id = S_MORNING; break;
    case 2:  id = S_EVENING; break;
    case 3:  id = S_NIGHT;   break;
    default: id = S_DAY;     break;
  }
  return [NSString stringWithUTF8String:T(id)];
}
- (NSInteger)dailyGoalCount { return DAILY_GOAL_COUNT; }
- (NSString *)doneText { return [NSString stringWithUTF8String:T(S_DONE)]; }
- (NSString *)dailyRewardLine {
  NSUInteger done = 0;
  for (NSInteger i = 0; i < DAILY_GOAL_COUNT; i++)
    if ([self dailyGoalCompleteAtIndex:i]) done++;
  char out[24];
  snprintf(out, sizeof(out), "%s %u/%u", T(S_REWARD), (unsigned)done, DAILY_GOAL_COUNT);
  return [NSString stringWithUTF8String:out];
}
- (void)ensureDailyGoals { gPet.ensureDailyGoals(); }
- (NSString *)dailyGoalLabelAtIndex:(NSInteger)i {
  if (i < 0 || i >= DAILY_GOAL_COUNT) return @"";
  StrId id;
  switch (gPet.dailyGoalType[i]) {
    case DAILY_GOAL_PLAY:   id = S_GOAL_PLAY;   break;
    case DAILY_GOAL_BATTLE: id = S_GOAL_BATTLE; break;
    case DAILY_GOAL_CATCH:  id = S_GOAL_CATCH;  break;
    case DAILY_GOAL_MEMO:   id = S_GOAL_MEMO;   break;
    default:                id = S_GOAL_CARE;   break;
  }
  return [NSString stringWithUTF8String:T(id)];
}
- (NSUInteger)dailyGoalProgressAtIndex:(NSInteger)i {
  if (i < 0 || i >= DAILY_GOAL_COUNT) return 0;
  uint8_t target = gPet.dailyGoalTarget(gPet.dailyGoalType[i]);
  uint8_t p = gPet.dailyGoalProgress[i];
  return p > target ? target : p;
}
- (NSUInteger)dailyGoalTargetAtIndex:(NSInteger)i {
  if (i < 0 || i >= DAILY_GOAL_COUNT) return 0;
  return gPet.dailyGoalTarget(gPet.dailyGoalType[i]);
}
- (BOOL)dailyGoalCompleteAtIndex:(NSInteger)i {
  if (i < 0 || i >= DAILY_GOAL_COUNT) return NO;
  return gPet.dailyGoalComplete((uint8_t)i);
}
- (NSInteger)dailyGoalKindAtIndex:(NSInteger)i {
  if (i < 0 || i >= DAILY_GOAL_COUNT) return 0;
  switch (gPet.dailyGoalType[i]) {
    case DAILY_GOAL_PLAY:   return 1;
    case DAILY_GOAL_BATTLE: return 2;
    case DAILY_GOAL_CATCH:  return 3;
    case DAILY_GOAL_MEMO:   return 4;
    default:                return 0;  // care
  }
}

- (NSString *)boxTitle { return [NSString stringWithUTF8String:T(S_BOX)]; }
- (uint16_t)caughtCount    { return gPet.caughtCount(); }
- (uint16_t)knownDexCount  { return gPet.knownDexCount(); }
- (uint16_t)nextDexGoal    { return gPet.nextDexGoal(); }
- (NSString *)caughtCountLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_CAUGHT_COUNT_FMT), gPet.caughtCount());
  return [NSString stringWithUTF8String:out];
}
- (NSString *)knownCountLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_KNOWN_FMT), gPet.knownDexCount());
  return [NSString stringWithUTF8String:out];
}
- (NSString *)dexGoalLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_DEX_GOAL_FMT), gPet.nextDexGoal());
  return [NSString stringWithUTF8String:out];
}
- (NSString *)noCatchesText  { return [NSString stringWithUTF8String:T(S_NO_CATCHES)]; }
- (NSString *)raisedMarkText { return [NSString stringWithUTF8String:T(S_RAISED_MARK)]; }

// 0 dex order, 1 by type, 2 raised-first. Only sort mode kept client-side --
// everything else reads straight off the live Pet each call.
static NSInteger gBoxSort = 0;
- (NSString *)boxSortLabel {
  if (gBoxSort == 1) return [NSString stringWithUTF8String:T(S_SORT_TYPE)];
  if (gBoxSort == 2) return [NSString stringWithUTF8String:T(S_SORT_RAISED)];
  return [NSString stringWithUTF8String:T(S_SORT_DEX)];
}
- (void)cycleBoxSort { gBoxSort = (gBoxSort + 1) % 3; }

- (NSString *)pageLineForPage:(NSInteger)page count:(NSInteger)count {
  char out[16];
  snprintf(out, sizeof(out), T(S_PAGE_FMT), (int)page, (int)count);
  return [NSString stringWithUTF8String:out];
}

static bool TPBoxComesBefore(int16_t a, int16_t b) {
  if (gBoxSort == 1) {
    const DexEntry &da = DEX_TBL[a], &db = DEX_TBL[b];
    if (da.type1 != db.type1) return da.type1 < db.type1;
    if (da.type2 != db.type2) return da.type2 < db.type2;
  } else if (gBoxSort == 2) {
    bool ra = gPet.isRegistered(a), rb = gPet.isRegistered(b);
    if (ra != rb) return ra;
  }
  return a < b;
}

// Rebuilt on every call rather than cached: the box is small (<=DEX_COUNT entries)
// and this only runs while the Box page is on screen.
static uint16_t TPBoxBuildList(int16_t *out) {
  uint16_t n = 0;
  for (int16_t dex = 1; dex <= DEX_COUNT; dex++)
    if (gPet.isCaught(dex)) out[n++] = dex;
  for (uint16_t i = 1; i < n; i++) {
    int16_t v = out[i];
    int j = (int)i - 1;
    while (j >= 0 && TPBoxComesBefore(v, out[j])) { out[j + 1] = out[j]; j--; }
    out[j + 1] = v;
  }
  return n;
}
- (NSInteger)boxPageCountWithRowsPerPage:(NSInteger)rows {
  NSInteger pages = (gPet.caughtCount() + rows - 1) / rows;
  return pages > 0 ? pages : 1;
}
- (int16_t)boxDexAtIndex:(NSInteger)index {
  int16_t list[DEX_COUNT];
  uint16_t n = TPBoxBuildList(list);
  return (index >= 0 && index < n) ? list[index] : -1;
}
- (BOOL)isCaught:(int16_t)dex { return gPet.isCaught(dex); }

- (NSString *)raisedCaughtLine {
  char out[24];
  snprintf(out, sizeof(out), T(S_RAISED_CAUGHT_FMT), gPet.registeredCount(), gPet.caughtCount());
  return [NSString stringWithUTF8String:out];
}
- (NSString *)filterAllText    { return [NSString stringWithUTF8String:T(S_FILTER_ALL)]; }
- (NSString *)caughtMarkText { return [NSString stringWithUTF8String:T(S_CAUGHT_MARK)]; }

// Type names/colours aren't in the string table (upstream keeps them as a
// raw per-language array inside TamaPoke.ino, which isn't vendored) --
// deliberately English-only in every language, confirmed rather than left
// as a gap: unlike speciesName below (which used to make this same
// simplification by accident -- see kor_patch/FEASIBILITY.ko.md -- until
// that turned out to be a real bug, not a design choice).
static const char *const kTypeNames[19] = {
  "", "NORMAL", "FIRE", "WATER", "ELEC", "GRASS", "ICE", "FIGHT", "POISON",
  "GROUND", "FLY", "PSY", "BUG", "ROCK", "GHOST", "DRAGON", "DARK", "STEEL", "FAIRY"
};
static uint16_t TPTypeColor(uint8_t type) {
  switch (type) {
    case TYPE_FIRE: return 0xEA87;     case TYPE_WATER: return 0x4C98;
    case TYPE_ELECTRIC: return 0xBCA1; case TYPE_GRASS: return 0x3C49;
    case TYPE_ICE: return 0x5D99;      case TYPE_FIGHTING: return 0xA2A5;
    case TYPE_POISON: return 0x8A73;   case TYPE_GROUND: return 0xB447;
    case TYPE_FLYING: return 0x8D7F;   case TYPE_PSYCHIC: return 0xD28F;
    case TYPE_BUG: return 0x7CC4;      case TYPE_ROCK: return 0x9407;
    case TYPE_GHOST: return 0x6B33;    case TYPE_DRAGON: return 0x5A5F;
    case TYPE_DARK: return 0x5ACB;     case TYPE_STEEL: return 0xA534;
    case TYPE_FAIRY: return 0xF3B7;    default: return 0x8C4D;
  }
}
- (NSString *)typeTextForDex:(int16_t)dex {
  const DexEntry *d = TPDexEntry(dex);
  if (d->type1 >= 19) return @"";
  if (d->type2 == TYPE_NONE || d->type2 >= 19)
    return [NSString stringWithUTF8String:kTypeNames[d->type1]];
  char out[24];
  snprintf(out, sizeof(out), "%s %s", kTypeNames[d->type1], kTypeNames[d->type2]);
  return [NSString stringWithUTF8String:out];
}
- (uint16_t)typeColorForDex:(int16_t)dex {
  const DexEntry *d = TPDexEntry(dex);
  return TPTypeColor(d->type1);
}
- (uint8_t)type1ForDex:(int16_t)dex {
  const DexEntry *d = TPDexEntry(dex);
  return d->type1 < 19 ? d->type1 : (uint8_t)TYPE_NONE;
}
- (uint8_t)type2ForDex:(int16_t)dex {
  const DexEntry *d = TPDexEntry(dex);
  return d->type2 < 19 ? d->type2 : (uint8_t)TYPE_NONE;
}
- (NSString *)typeNameForType:(uint8_t)type {
  return [NSString stringWithUTF8String:type < 19 ? kTypeNames[type] : ""];
}
- (uint16_t)typeColorForType:(uint8_t)type { return TPTypeColor(type); }

// --- expedition -----------------------------------------------------------
// The fork's expeditionNowEpoch() falls back from a real RTC chip to
// lastSeenEpoch; there's no RTC chip here at all, so this always uses the
// same wall-clock source syncClock() already does (TPNowEpoch(), declared
// above this file's -syncClock).
static uint32_t TPExpeditionNowEpoch() { return TPNowEpoch(); }

static StrId TPExpItemStrId(NSInteger i) {
  switch (i) {
    case 0: return S_ITEM_SNACK;
    case 1: return S_ITEM_ENERGY;
    case 2: return S_ITEM_CARE;
    default: return S_ITEM_TRAIN;
  }
}

- (NSString *)expeditionTitle { return [NSString stringWithUTF8String:T(S_EXPEDITION)]; }
- (BOOL)expeditionReady  { return gPet.expeditionReady(TPExpeditionNowEpoch()); }
- (BOOL)expeditionActive { return gPet.expeditionActive(TPExpeditionNowEpoch()); }

- (NSString *)expeditionFoundLine {
  char out[40];
  const char *item = T(TPExpItemStrId(gPet.expeditionRewardItem));
  snprintf(out, sizeof(out), T(S_FOUND_ITEM_FMT), item);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)expeditionClaimText { return [NSString stringWithUTF8String:T(S_EXP_CLAIM)]; }

- (NSString *)expeditionBackInLine {
  uint32_t now = TPExpeditionNowEpoch();
  uint32_t left = (gPet.expeditionEndEpoch > now ? gPet.expeditionEndEpoch - now + 59UL : 0) / 60UL;
  char out[32];
  snprintf(out, sizeof(out), T(S_EXP_IN_FMT), (unsigned)left);
  return [NSString stringWithUTF8String:out];
}
- (NSString *)expeditionWaitText { return [NSString stringWithUTF8String:T(S_WAIT)]; }
- (NSString *)expeditionInventoryFullText { return [NSString stringWithUTF8String:T(S_INV_FULL)]; }
- (NSString *)expeditionNeedEnergyText {
  char out[32];
  snprintf(out, sizeof(out), T(S_NEED_ENE_FMT), 12);
  return [NSString stringWithUTF8String:out];
}
- (BOOL)expeditionInventoryFull { return gPet.expeditionInventoryFull(); }

static const uint8_t kExpMinutes[3] = { 15, 30, 60 };
- (NSString *)expeditionDurationLabel:(NSInteger)i {
  if (i < 0 || i > 2) return @"";
  StrId ids[3] = { S_EXP_15, S_EXP_30, S_EXP_60 };
  return [NSString stringWithUTF8String:T(ids[i])];
}
- (NSString *)expeditionCostLabel:(NSInteger)i {
  if (i < 0 || i > 2) return @"";
  char out[16];
  snprintf(out, sizeof(out), "-%u ENE", Pet::expeditionEnergyCost(kExpMinutes[i]));
  return [NSString stringWithUTF8String:out];
}
- (BOOL)expeditionCanStart:(NSInteger)i {
  if (i < 0 || i > 2) return NO;
  return gPet.canStartExpedition(kExpMinutes[i], TPExpeditionNowEpoch());
}
- (void)claimExpedition {
  ExpeditionItem item = gPet.claimExpedition(TPExpeditionNowEpoch());
  (void)item;  // sound/feedback handled in Swift from the return value's side effect (count changed)
}
- (void)startExpedition:(NSInteger)i {
  if (i < 0 || i > 2) return;
  gPet.startExpedition(kExpMinutes[i], TPExpeditionNowEpoch(),
                       (uint8_t)arc4random_uniform(100), (uint8_t)arc4random_uniform(3));
}

- (NSString *)inventoryTitle { return [NSString stringWithUTF8String:T(S_INVENTORY)]; }
- (NSString *)expeditionItemLabel:(NSInteger)i {
  if (i < 0 || i > 3) return @"";
  return [NSString stringWithUTF8String:T(TPExpItemStrId(i))];
}
- (NSUInteger)expeditionItemCount:(NSInteger)i {
  if (i < 0 || i > 3) return 0;
  return gPet.itemCounts[i];
}
// RGB565 literals matching this file's other UI_BAR_* colour choices
// (0x5DCD ok/green, 0xED07 warn/yellow, 0xEA87 bad/red -- see
// Sources/Shared/TPGraphics.swift's UI enum, which these are kept in sync
// with by hand since this file can't import Swift).
- (uint16_t)expeditionItemColor:(NSInteger)i {
  switch (i) {
    case 0: return 0xED07;  // warn: snack
    case 1: return 0x4C98;  // energy
    case 2: return 0x5DCD;  // ok: care
    case 3: return 0xEA87;  // bad: train
    default: return 0x8C4D;
  }
}
- (void)useExpeditionItem:(NSInteger)i {
  if (i < 0 || i > 2) return;  // 3 (train) goes through -useTrainItem: instead
  if (gPet.itemCounts[i] == 0) return;
  gPet.useExpeditionItem((ExpeditionItem)i);
}

- (NSString *)trainChoiceTitle { return [NSString stringWithUTF8String:T(S_ITEM_TRAIN)]; }
- (NSString *)trainStatLabel:(NSInteger)i {
  if (i < 0 || i > 2) return @"";
  StrId ids[3] = { S_TRAIN_ATK, S_TRAIN_DEF, S_TRAIN_SPE };
  return [NSString stringWithUTF8String:T(ids[i])];
}
- (uint8_t)trainStatValue:(NSInteger)i {
  switch (i) {
    case 0: return gPet.trAtk;
    case 1: return gPet.trDef;
    case 2: return gPet.trSpe;
    default: return 0;
  }
}
- (BOOL)trainStatUsable:(NSInteger)i { return [self trainStatValue:i] < 100; }
- (NSString *)trainMaxedText { return [NSString stringWithUTF8String:T(S_ITEM_MAXED)]; }
- (void)useTrainItem:(NSInteger)statIndex {
  if (statIndex < 0 || statIndex > 2) return;
  if (gPet.itemCounts[EXP_ITEM_TRAIN] == 0) return;
  gPet.useExpeditionItem(EXP_ITEM_TRAIN, (int8_t)statIndex);
}

- (NSInteger)expeditionHudState {
  switch (gPet.expeditionHudState(TPExpeditionNowEpoch())) {
    case EXP_HUD_ACTIVE: return 1;
    case EXP_HUD_READY:  return 2;
    case EXP_HUD_BAG:    return 3;
    default:              return 0;
  }
}
- (NSString *)expeditionHudLabel {
  NSInteger state = self.expeditionHudState;
  if (state == 1) {
    char out[24];
    uint32_t now = TPExpeditionNowEpoch();
    uint32_t left = (gPet.expeditionEndEpoch > now ? gPet.expeditionEndEpoch - now + 59UL : 0) / 60UL;
    snprintf(out, sizeof(out), "%s %lum", T(S_EXP_HUD_TOUR), (unsigned long)left);
    return [NSString stringWithUTF8String:out];
  }
  if (state == 2) return [NSString stringWithUTF8String:T(S_EXP_READY)];
  if (state == 3) {
    char out[20];
    snprintf(out, sizeof(out), "%s x%u", T(S_EXP_HUD_BAG), gPet.expeditionItemCount());
    return [NSString stringWithUTF8String:out];
  }
  return @"";
}

// --- minigame / training ------------------------------------------------
- (uint16_t)gameHigh      { return gPet.gameHi; }
- (uint16_t)strengthHigh  { return gPet.strHi; }
- (NSString *)newRecordText { return [NSString stringWithUTF8String:T(S_NEW_RECORD)]; }
- (NSString *)hitFastText   { return [NSString stringWithUTF8String:T(S_HIT_FAST)]; }

- (NSString *)scoreLine:(uint16_t)score        { return TPFormatted(S_SCORE_FMT, score); }
- (NSString *)recordLine:(uint16_t)record      { return TPFormatted(S_RECORD_FMT, record); }
- (NSString *)shortRecordLine:(uint16_t)record { return TPFormatted(S_REC_FMT, record); }
- (NSString *)hitsLine:(uint16_t)hits          { return TPFormatted(S_HITS_FMT, hits); }
- (NSString *)strengthGainLine:(uint8_t)gain   { return TPFormatted(S_STR_GAIN_FMT, gain); }

- (NSString *)playResultMessage:(uint16_t)score {
  return [NSString stringWithUTF8String:T(score >= 10 ? S_GREAT_JOY : S_PLUS_JOY)];
}

// --- release dialog -----------------------------------------------------
- (NSString *)releaseQuestion {
  char out[48];
  snprintf(out, sizeof(out), T(S_RELEASE_FMT), dexName(gPet.speciesId));
  return [NSString stringWithUTF8String:out];
}

- (NSString *)yesText   { return [NSString stringWithUTF8String:T(S_YES)]; }
- (NSString *)noText    { return [NSString stringWithUTF8String:T(S_NO)]; }
- (NSString *)nameLabel     { return [NSString stringWithUTF8String:T(S_NAME)]; }
- (NSString *)settingsTitle { return [NSString stringWithUTF8String:T(S_SET_TIME)]; }

@end

// --- static tables -----------------------------------------------------
static const DexEntry *TPDexEntry(int16_t dex) {
  if (dex < 0 || dex > DEX_COUNT) dex = 0;
  return &DEX_TBL[dex];
}

int16_t TPDexCount(void) { return DEX_COUNT; }

NSString *TPDexName(int16_t dex) {
  // dexName(dex) reads DEX_NAMES[gLang][dex] -- the actually-localized table.
  // TPDexEntry(dex)->name is DEX_TBL's single, always-English name (battle
  // logic/species data only, never meant to reach the UI) -- using it here
  // was a real bug: every screen that shows a species name (header, gallery,
  // box, starter picker) stayed English regardless of the selected language,
  // including for the two languages (FR/DE) whose DEX_NAMES rows have always
  // carried real localized names.
  return [NSString stringWithUTF8String:dexName(dex)];
}

uint16_t TPDexAccent(int16_t dex) { return TPDexEntry(dex)->accent; }
uint8_t  TPDexBiome(int16_t dex)  { return TPDexEntry(dex)->biome; }

NSInteger TPStarterCount(void) { return kStarterCount; }

int16_t TPStarterDex(NSInteger slot) {
  return (slot >= 0 && slot < kStarterCount) ? kStarterDex[slot] : kStarterDex[0];
}

NSString *TPString(uint8_t strId) {
  if (strId >= STR_COUNT) return @"";
  return [NSString stringWithUTF8String:T((StrId)strId)];
}

// `lang` here is the settings picker's 8-slot UI index, not the raw `Lang`
// enum: 0-5 are the plain languages, 6 is "KR" (full Korean: gLang=LANG_KO),
// 7 is "kr" (species names + dex chrome only, in Korean, with everything
// else staying in English -- see gDexNamesKorean in i18n.h/.cpp). Folding
// the mapping in here keeps the Swift call sites unaware of the split.
void TPSetLanguage(uint8_t lang) {
  if (lang <= 5) {
    setDexNamesKorean(false);
    setLang((Lang)lang);
  } else if (lang == 6) {
    setDexNamesKorean(true);
    setLang(LANG_KO);
  } else if (lang == 7) {
    setDexNamesKorean(true);
    setLang(LANG_EN);
  }
}

uint8_t TPLanguage(void) {
  if (gLang == LANG_KO) return 6;
  if (gDexNamesKorean) return 7;
  return (uint8_t)gLang;
}

void TPSetSfxHandler(void (^handler)(uint8_t)) {
  gSfxBlock = [handler copy];
  TPSetSfxHook(handler ? TPSfxTrampoline : NULL);
}

NSString *TPBarLabel(NSInteger index) {
  StrId id;
  switch (index) {
    case 0:  id = S_BAR_FOOD; break;
    case 1:  id = S_BAR_JOY;  break;
    case 2:  id = S_BAR_ENE;  break;
    default: id = S_BAR_HYG;  break;
  }
  return [NSString stringWithUTF8String:T(id)];
}

NSString *TPChooseStarterTitle(void) {
  return [NSString stringWithUTF8String:T(S_CHOOSE_STARTER)];
}

NSArray<NSString *> *TPNoSpritesLines(void) {
  return @[ [NSString stringWithUTF8String:T(S_NO_SPRITES)],
            [NSString stringWithUTF8String:T(S_LOAD_SPRITES)] ];
}
