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

// The one live game state. Upstream keeps a file-scope `Pet pet;` in the .ino
// and every subsystem reaches for it; mirroring that keeps the port honest.
static Pet gPet;

// Upstream defines the starter trio in the .ino, not in a header.
static const int16_t kStarterDex[3] = { 1, 4, 7 };  // Bulbasaur / Charmander / Squirtle

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
  const char *base = gPet.nick[0] ? gPet.nick : DEX_TBL[gPet.speciesId].name;
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
  const char *nm = gPet.nick[0] ? gPet.nick : DEX_TBL[gPet.speciesId].name;
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
  return [NSString stringWithUTF8String:TPDexEntry(gPet.speciesId)->name];
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
- (uint8_t)nextDexGoal     { return gPet.nextDexGoal(); }
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

// Rebuilt on every call rather than cached: the box is small (<=151 entries)
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
- (NSString *)filterCaughtText { return [NSString stringWithUTF8String:T(S_CAUGHT_MARK)]; }

// Type names/colours aren't in the string table (upstream keeps them as a
// raw per-language array inside TamaPoke.ino, which isn't vendored) --
// English-only here, same simplification the existing speciesName/DEX_TBL
// name already makes regardless of the active language.
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

// --- minigame / training ------------------------------------------------
- (uint16_t)gameHigh      { return gPet.gameHi; }
- (uint16_t)strengthHigh  { return gPet.strHi; }
- (NSString *)newRecordText { return [NSString stringWithUTF8String:T(S_NEW_RECORD)]; }
- (NSString *)hitFastText   { return [NSString stringWithUTF8String:T(S_HIT_FAST)]; }

static NSString *TPFormatted(StrId id, unsigned v) {
  char out[40];
  snprintf(out, sizeof(out), T(id), v);
  return [NSString stringWithUTF8String:out];
}

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
  snprintf(out, sizeof(out), T(S_RELEASE_FMT), TPDexEntry(gPet.speciesId)->name);
  return [NSString stringWithUTF8String:out];
}

- (NSString *)yesText   { return [NSString stringWithUTF8String:T(S_YES)]; }
- (NSString *)noText    { return [NSString stringWithUTF8String:T(S_NO)]; }
- (NSString *)nameLabel     { return [NSString stringWithUTF8String:T(S_NAME)]; }
- (NSString *)settingsTitle { return [NSString stringWithUTF8String:T(S_SET_TIME)]; }
// The fork replaced the base's on/off S_SND_ON with a multi-level SoundMode
// (S_SND_FULL/MED/LOW/OFF); this app only has a binary switch, so FULL is
// the "on" label.
- (NSString *)soundOnText   { return [NSString stringWithUTF8String:T(S_SND_FULL)]; }
- (NSString *)soundOffText  { return [NSString stringWithUTF8String:T(S_SND_OFF)]; }


@end

// --- static tables -----------------------------------------------------
static const DexEntry *TPDexEntry(int16_t dex) {
  if (dex < 0 || dex > DEX_COUNT) dex = 0;
  return &DEX_TBL[dex];
}

NSString *TPDexName(int16_t dex) {
  return [NSString stringWithUTF8String:TPDexEntry(dex)->name];
}

uint16_t TPDexAccent(int16_t dex) { return TPDexEntry(dex)->accent; }
uint8_t  TPDexBiome(int16_t dex)  { return TPDexEntry(dex)->biome; }

int16_t TPStarterDex(NSInteger slot) {
  return (slot >= 0 && slot < 3) ? kStarterDex[slot] : kStarterDex[0];
}

NSString *TPString(uint8_t strId) {
  if (strId >= STR_COUNT) return @"";
  return [NSString stringWithUTF8String:T((StrId)strId)];
}

void TPSetLanguage(uint8_t lang) {
  if (lang < LANG_COUNT) setLang((Lang)lang);
}

uint8_t TPLanguage(void) { return (uint8_t)gLang; }

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
