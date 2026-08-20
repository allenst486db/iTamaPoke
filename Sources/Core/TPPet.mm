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
- (NSString *)soundOnText   { return [NSString stringWithUTF8String:T(S_SND_ON)]; }
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
