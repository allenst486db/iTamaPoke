#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Objective-C facade over the upstream C++ `Pet`.
//
// Deliberately thin: it exposes only what the SwiftUI layer currently draws or
// calls. Grow it alongside the UI rather than mirroring all of pet.h up front.
//
// Each process owns its own Pet, so the iOS app and the Watch app keep separate
// save files today. Cross-device sync is a later problem.

typedef NS_ENUM(NSInteger, TPMood) {
  TPMoodHappy = 0, TPMoodSad, TPMoodEating, TPMoodSleeping
};

typedef NS_ENUM(NSInteger, TPCeremony) {
  TPCeremonyNone = 0, TPCeremonyFarewell, TPCeremonyRunaway, TPCeremonyRelease
};

@interface TPPet : NSObject

// A class property, not a `+shared` class method: the latter imports into Swift
// as `TPPet.shared()`, which silently binds a function value at every call site.
@property (class, nonatomic, readonly) TPPet *shared;

/// Loads NVS-equivalent state and applies elapsed wall-clock time. Call once.
- (void)begin;
/// Advances animation timers and the one-minute game tick. Call every frame.
- (void)update;
/// Re-applies wall-clock drift (foregrounding after a long background stretch).
- (void)syncClock;
/// Writes deferred state to disk. Call on backgrounding.
- (void)flushSave;
/// Re-reads persisted state into the live C++ Pet. Call after something outside
/// the game has rewritten the store — importing a save file, for instance.
- (void)reload;

// --- needs -------------------------------------------------------------
@property (nonatomic, readonly) uint8_t fullness;
@property (nonatomic, readonly) uint8_t joy;
@property (nonatomic, readonly) uint8_t energy;
@property (nonatomic, readonly) uint8_t hygiene;
@property (nonatomic, readonly) uint8_t poops;
@property (nonatomic, readonly) uint8_t weight;

// --- identity ----------------------------------------------------------
@property (nonatomic, readonly) int16_t speciesId;
@property (nonatomic, readonly) int16_t prevSpeciesId;
@property (nonatomic, readonly) BOOL shiny;
@property (nonatomic, readonly) BOOL isEgg;
@property (nonatomic, readonly) uint8_t level;
@property (nonatomic, readonly) uint32_t ageMinutes;
@property (nonatomic, readonly, copy) NSString *nick;
@property (nonatomic, readonly) uint32_t lastSeenEpoch;

// --- state -------------------------------------------------------------
@property (nonatomic, readonly) BOOL sleeping;
@property (nonatomic, readonly) TPMood mood;
@property (nonatomic, readonly) BOOL eating;
@property (nonatomic, readonly) BOOL showHeart;
@property (nonatomic, readonly) BOOL evolvingNow;
@property (nonatomic, readonly) float evolveProgress;
@property (nonatomic, readonly) TPCeremony ceremony;
@property (nonatomic, readonly) float ceremonyProgress;
@property (nonatomic, readonly) BOOL savePending;

// --- egg / dex ---------------------------------------------------------
@property (nonatomic, readonly) uint8_t eggCracks;
@property (nonatomic, readonly) uint8_t eggRarity;
@property (nonatomic, readonly) uint16_t registeredCount;
@property (nonatomic, readonly) BOOL awaitingStarter;

// --- retention ---------------------------------------------------------
@property (nonatomic, readonly) uint16_t streak;
@property (nonatomic, readonly) uint16_t bestStreak;
@property (nonatomic, readonly) uint8_t bond;
@property (nonatomic, readonly) uint16_t medals;
/// A medal or streak milestone was just earned: the idle screen banners it.
@property (nonatomic, readonly) BOOL showMedal;
@property (nonatomic, readonly) BOOL showMilestone;
/// Name of the medal being celebrated, nil when none is.
@property (nonatomic, readonly, copy, nullable) NSString *newMedalName;

// --- personality / daily / box ------------------------------------------
// Ported from ShadowEnemyx/TamaPoke ("TamaPoke — Expanded", a separate
// community fork socquique's own README links to) rather than from the base
// upstream/ submodule -- see upstream-expanded/README.md. Battle/expedition
// fields the fork also added are not exposed here; nothing draws them.
@property (nonatomic, readonly) NSInteger personalityKind;       ///< 0 balanced..4 lazy
@property (nonatomic, readonly, copy) NSString *personalityTitle;
@property (nonatomic, readonly, copy) NSString *personalityName;
@property (nonatomic, readonly, copy) NSString *personalityHint;
// personalityKind above (0..4) doubles as the colour key; Swift maps it to
// UI.barOK/barWarn/barBad plus two colours those constants don't cover.
@property (nonatomic, readonly, copy) NSString *personalityAgeLine;
@property (nonatomic, readonly, copy) NSString *recordsTitle;
@property (nonatomic, readonly, copy) NSString *ballRecordLabel;
@property (nonatomic, readonly, copy) NSString *catchRecordLabel;
@property (nonatomic, readonly, copy) NSString *memoRecordLabel;
@property (nonatomic, readonly, copy) NSString *cleanRecordLabel;
@property (nonatomic, readonly, copy) NSString *typeRecordLabel;
@property (nonatomic, readonly) uint16_t catchHigh;
@property (nonatomic, readonly) uint16_t memoHigh;
@property (nonatomic, readonly) uint16_t cleanHigh;
@property (nonatomic, readonly) uint16_t typeHigh;
@property (nonatomic, readonly) uint16_t bestBattleStreak;

// The fork's memo/clean/type minigame results -- each banks the score into a
// stat the same way applyCatchResult does, and returns the gain for the card.
- (uint8_t)applyMemoResult:(uint8_t)rounds;   ///< pays out DEF
- (uint8_t)applyCleanResult:(uint8_t)score;   ///< pays out hygiene
- (uint8_t)applyTypeResult:(uint8_t)score;    ///< pays out ATK
// Minigame screen strings (fork's renderMemoGame/renderCleanGame/renderTypeGame).
@property (nonatomic, readonly, copy) NSString *memoWatchText;   ///< "Watch..."
@property (nonatomic, readonly, copy) NSString *memoWrongText;   ///< "Wrong!"
- (NSString *)memoTurnLine:(NSInteger)input of:(NSInteger)len;   ///< "Your turn 2/5"
- (NSString *)roundLine:(NSInteger)round;                        ///< "ROUND 3"
@property (nonatomic, readonly, copy) NSString *cleanTitleText;  ///< "CLEAN!"
@property (nonatomic, readonly, copy) NSString *typeTitleText;   ///< "TYPE!"
- (NSString *)defGainLine:(uint8_t)gain;                         ///< "DEF +2"
- (NSString *)hygGainLine:(uint8_t)gain;                         ///< "HYG +4"
- (NSString *)atkGainLine:(uint8_t)gain;                         ///< "ATK +2"
// Battle-type names/colours by TYPE_* id (1 NORMAL .. 18 FAIRY), for the
// Type quiz's cards. Same English-only table typeTextForDex draws from.
- (NSString *)typeNameForType:(uint8_t)type;
- (uint16_t)typeColorForType:(uint8_t)type;

// The fork's collection frames: decorative portrait frames unlocked by dex
// milestones, plus the collector rank shown under the profile portrait.
@property (nonatomic, readonly) uint8_t collectionFrame;
@property (nonatomic, readonly) uint8_t unlockedCollectionFrameCount;
- (BOOL)setCollectionFrame:(uint8_t)frame;
@property (nonatomic, readonly, copy) NSString *collectionTitle; ///< "COLLECTION"
@property (nonatomic, readonly, copy) NSString *collectionRankName;
@property (nonatomic, readonly, copy) NSString *knownLine;       ///< "Known 12"
@property (nonatomic, readonly, copy) NSString *frameLine;       ///< "Frame 1/3"

/// Sound-mode labels by TPSoundMode raw value (0 SILENT, 1 VIBRATE, 2 FULL).
- (NSString *)soundModeLabel:(NSInteger)mode;

@property (nonatomic, readonly, copy) NSString *dailyTitle;
@property (nonatomic, readonly, copy) NSString *dayPhaseLabel;   ///< Morning/Day/Evening/Night
@property (nonatomic, readonly) NSInteger dailyGoalCount;        ///< always 3
@property (nonatomic, readonly, copy) NSString *dailyRewardLine; ///< "REWARD 1/3"
@property (nonatomic, readonly, copy) NSString *doneText;
/// Rotates in a new set of 3 goals once a real day has passed. Safe to call
/// on every frame the Daily page is visible -- a no-op most of the time.
- (void)ensureDailyGoals;
- (NSString *)dailyGoalLabelAtIndex:(NSInteger)i;
- (NSUInteger)dailyGoalProgressAtIndex:(NSInteger)i;
- (NSUInteger)dailyGoalTargetAtIndex:(NSInteger)i;
- (BOOL)dailyGoalCompleteAtIndex:(NSInteger)i;
/// 0 care, 1 play, 2 battle, 3 catch, 4 memo -- Swift maps this to a colour.
- (NSInteger)dailyGoalKindAtIndex:(NSInteger)i;

@property (nonatomic, readonly, copy) NSString *boxTitle;
@property (nonatomic, readonly) uint16_t caughtCount;   ///< wild pokemon caught (separate from raised)
@property (nonatomic, readonly) uint16_t knownDexCount; ///< raised OR caught
@property (nonatomic, readonly) uint16_t nextDexGoal;
@property (nonatomic, readonly, copy) NSString *caughtCountLine;
@property (nonatomic, readonly, copy) NSString *knownCountLine;
@property (nonatomic, readonly, copy) NSString *dexGoalLine;
@property (nonatomic, readonly, copy) NSString *boxSortLabel;
@property (nonatomic, readonly, copy) NSString *noCatchesText;
@property (nonatomic, readonly, copy) NSString *raisedMarkText;
- (NSString *)pageLineForPage:(NSInteger)page count:(NSInteger)count;
- (void)cycleBoxSort;
- (NSInteger)boxPageCountWithRowsPerPage:(NSInteger)rows;
/// -1 when this row is past the end of the (sorted, filtered) caught list.
- (int16_t)boxDexAtIndex:(NSInteger)index;
- (BOOL)isCaught:(int16_t)dex;

// --- Pokedex All/Raised/Caught filter ------------------------------------
@property (nonatomic, readonly, copy) NSString *raisedCaughtLine;  ///< "R:1 C:0"
@property (nonatomic, readonly, copy) NSString *filterAllText;
@property (nonatomic, readonly, copy) NSString *caughtMarkText;

// --- type (Box rows + Pokedex detail) ------------------------------------
- (NSString *)typeTextForDex:(int16_t)dex;   ///< "FIRE" or "FIRE FLY"
- (uint16_t)typeColorForDex:(int16_t)dex;    ///< RGB565, primary type
/// The species' battle types as TYPE_* ids, so a caller that draws them
/// separately can colour each one itself rather than splitting the joined
/// string above. type2 is TYPE_NONE (0) for a single-type species.
- (uint8_t)type1ForDex:(int16_t)dex;
- (uint8_t)type2ForDex:(int16_t)dex;

// --- expedition (ShadowEnemyx fork; see upstream-expanded/README.md) ----
@property (nonatomic, readonly, copy) NSString *expeditionTitle;
@property (nonatomic, readonly) BOOL expeditionReady;    ///< a tour finished, reward waiting
@property (nonatomic, readonly) BOOL expeditionActive;   ///< a tour is currently out
@property (nonatomic, readonly, copy) NSString *expeditionFoundLine;   ///< "Found: Snack"
@property (nonatomic, readonly, copy) NSString *expeditionClaimText;
@property (nonatomic, readonly, copy) NSString *expeditionBackInLine;  ///< "Back in 12m"
@property (nonatomic, readonly, copy) NSString *expeditionWaitText;
@property (nonatomic, readonly, copy) NSString *expeditionInventoryFullText;
@property (nonatomic, readonly, copy) NSString *expeditionNeedEnergyText;
@property (nonatomic, readonly) BOOL expeditionInventoryFull;
- (NSString *)expeditionDurationLabel:(NSInteger)i;   ///< i: 0=15m 1=30m 2=60m
- (NSString *)expeditionCostLabel:(NSInteger)i;       ///< "-N ENE"
- (BOOL)expeditionCanStart:(NSInteger)i;
- (void)claimExpedition;
/// i: 0=15m 1=30m 2=60m. No-ops (silently) if not actually startable --
/// callers should already have checked -expeditionCanStart:.
- (void)startExpedition:(NSInteger)i;

@property (nonatomic, readonly, copy) NSString *inventoryTitle;
- (NSString *)expeditionItemLabel:(NSInteger)i;   ///< i: 0 snack 1 energy 2 care 3 train
- (NSUInteger)expeditionItemCount:(NSInteger)i;
- (uint16_t)expeditionItemColor:(NSInteger)i;      ///< RGB565
/// Uses item i. Train (i==3) opens the stat-choice UI instead (Swift-side
/// state) rather than consuming here -- call -useTrainItem: for that one.
- (void)useExpeditionItem:(NSInteger)i;

@property (nonatomic, readonly, copy) NSString *trainChoiceTitle;
- (NSString *)trainStatLabel:(NSInteger)i;    ///< 0 ATK, 1 DEF, 2 SPE
- (uint8_t)trainStatValue:(NSInteger)i;       ///< 0..100
- (BOOL)trainStatUsable:(NSInteger)i;         ///< value < 100
@property (nonatomic, readonly, copy) NSString *trainMaxedText;
- (void)useTrainItem:(NSInteger)statIndex;

// --- HUD chip (idle screen) ----------------------------------------------
/// 0 hidden, 1 active (tour running), 2 ready (reward waiting), 3 bag (idle
/// with items, tap opens the card).
@property (nonatomic, readonly) NSInteger expeditionHudState;
@property (nonatomic, readonly, copy) NSString *expeditionHudLabel;

// --- stat card ---------------------------------------------------------
@property (nonatomic, readonly) uint16_t atkStat;
@property (nonatomic, readonly) uint16_t defStat;
@property (nonatomic, readonly) uint16_t speStat;
@property (nonatomic, readonly) uint8_t careMistakes;
/// Minutes elapsed into the current level, out of `minutesPerLevel`.
@property (nonatomic, readonly) uint8_t minutesIntoLevel;
@property (nonatomic, readonly) uint16_t minutesPerLevel;
@property (nonatomic, readonly) NSInteger medalCount;
- (BOOL)hasMedalAtIndex:(NSInteger)i;
- (NSString *)medalDescriptionAtIndex:(NSInteger)i;

// --- presentation strings ----------------------------------------------
// Composed here rather than in Swift: i18n.h's StrId enum is only visible on
// this side, so mirroring the ids in Swift would drift silently on a submodule
// bump. The Swift layer just draws whatever these return.
@property (nonatomic, readonly, copy) NSString *statusMessage;    ///< upstream statusMsg()
@property (nonatomic, readonly, copy) NSString *eggMessage;       ///< upstream eggMsg()
@property (nonatomic, readonly, copy) NSString *headerName;       ///< "*PIKACHU Lv.7"
@property (nonatomic, readonly, copy) NSString *pokedexLine;      ///< "POKEDEX 12/386"
@property (nonatomic, readonly, copy, nullable) NSString *eggRarityLabel;  ///< nil when common
@property (nonatomic, readonly, copy) NSString *ceremonyMessage;

// Decision prompts. `%s`-formatted ones are composed here for the same reason
// as the rest: the format strings live behind i18n.h's StrId enum.
@property (nonatomic, readonly, copy) NSString *evolveButtonText;    ///< "EVOLVE!"
@property (nonatomic, readonly, copy) NSString *farewellButtonText;  ///< "<name> wants to tell you..."
@property (nonatomic, readonly, copy) NSString *runawayButtonText;   ///< "<name> feels abandoned..."
@property (nonatomic, readonly, copy) NSString *evolveQuestion;      ///< "Evolve?"
@property (nonatomic, readonly, copy) NSString *evolveKeepText;      ///< "Keep form"
@property (nonatomic, readonly, copy) NSString *farewellQuestion;    ///< "Say goodbye?"
@property (nonatomic, readonly, copy) NSString *farewellGoText;      ///< "Goodbye"
@property (nonatomic, readonly, copy) NSString *farewellStayText;    ///< "Stay together"
@property (nonatomic, readonly, copy) NSString *galleryBackText;    ///< Pokedex detail "Back"

// --- stat card text ----------------------------------------------------
@property (nonatomic, readonly, copy) NSString *speciesName;      ///< dex name, ignoring any nickname
@property (nonatomic, readonly, copy) NSString *streakLine;       ///< "Streak 3 (best 7)"
@property (nonatomic, readonly, copy) NSString *infoLine;         ///< favourite berry + age in days
@property (nonatomic, readonly, copy) NSString *renameHint;
@property (nonatomic, readonly, copy) NSString *backHint;
@property (nonatomic, readonly, copy) NSString *bondLabel;
@property (nonatomic, readonly, copy) NSString *battleTitle;
@property (nonatomic, readonly, copy) NSString *battleRecordLine;   ///< "W12 L3" (ShadowEnemyx fork)
@property (nonatomic, readonly, copy) NSString *battleStreakLine;   ///< "Streak 2"
@property (nonatomic, readonly, copy) NSString *battleBestLine;     ///< "Best 7"
@property (nonatomic, readonly, copy) NSString *wildBattleText;     ///< "WILD BATTLE" button label
@property (nonatomic, readonly, copy) NSString *catchTitleText;     ///< Catch minigame screen title
@property (nonatomic, readonly, copy) NSString *playTitleText;      ///< "PLAY" -- Ball/Catch picker title
@property (nonatomic, readonly, copy) NSString *progressTitle;
@property (nonatomic, readonly, copy) NSString *trainButtonText;
@property (nonatomic, readonly, copy) NSString *medalsLine;       ///< "Medals 3/8"
@property (nonatomic, readonly, copy) NSString *levelLine;        ///< "Lv.7"
@property (nonatomic, readonly, copy) NSString *nextLevelLine;
@property (nonatomic, readonly, copy) NSString *evolutionLabel;
@property (nonatomic, readonly, copy) NSString *evolutionStatus;
/// 0 neutral, 1 ready (green), 2 blocked (red) — upstream colours the line.
@property (nonatomic, readonly) uint8_t evolutionStatusKind;
@property (nonatomic, readonly, copy) NSString *mistakesLine;
@property (nonatomic, readonly, copy) NSString *medalBannerTitle; ///< "NEW MEDAL!"
@property (nonatomic, readonly, copy) NSString *milestoneTitle;   ///< "GREAT!"
@property (nonatomic, readonly, copy) NSString *milestoneLine;    ///< "3 days in a row"
- (NSString *)statLabel:(NSInteger)index;   ///< 0 ATK, 1 DEF, 2 SPE, 3 WGT

// --- minigame / training ------------------------------------------------
@property (nonatomic, readonly) uint16_t gameHigh;   ///< ball minigame record
@property (nonatomic, readonly) uint16_t strengthHigh; ///< sack hit record
@property (nonatomic, readonly, copy) NSString *newRecordText;
@property (nonatomic, readonly, copy) NSString *hitFastText;
- (NSString *)scoreLine:(uint16_t)score;      ///< "Score: 12"
- (NSString *)recordLine:(uint16_t)record;    ///< "Record: 20"
- (NSString *)shortRecordLine:(uint16_t)record; ///< "Rec 20", for the HUD
- (NSString *)hitsLine:(uint16_t)hits;
- (NSString *)strengthGainLine:(uint8_t)gain;
- (NSString *)playResultMessage:(uint16_t)score;  ///< "+joy" or "great!"

// --- release dialog -----------------------------------------------------
@property (nonatomic, readonly, copy) NSString *releaseQuestion;  ///< "Release <name>?"
@property (nonatomic, readonly, copy) NSString *yesText;
@property (nonatomic, readonly, copy) NSString *noText;
@property (nonatomic, readonly, copy) NSString *nameLabel;   ///< rename screen title
@property (nonatomic, readonly, copy) NSString *settingsTitle;

// --- decision gates (a button appears; the player taps it) -------------
@property (nonatomic, readonly) BOOL wantsEvolveButton;
/// Whether tapping "Evolve" right now would actually go through: unlike
/// wantsEvolveButton (level-gated only, so the CTA can appear before the
/// pet is truly ready), this also requires all 4 care stats at 40+ and the
/// pet awake -- the same live check -evolve itself makes.
@property (nonatomic, readonly) BOOL canEvolveNow;
@property (nonatomic, readonly) BOOL wantsFarewellButton;
@property (nonatomic, readonly) BOOL canRunawayNow;

// --- actions -----------------------------------------------------------
- (void)feedBerry:(uint8_t)color;   ///< 0 red, 1 blue, 2 green
- (void)feedCandy;
- (void)playWithPet;
- (void)toggleLight;                ///< sleep / wake
- (void)clean;                      ///< bath: clears poops, hygiene -> 100
- (void)caress;
- (void)eggTap;
- (BOOL)lovesBerry:(uint8_t)color;
- (void)playResult:(uint8_t)score;  ///< minigame reward (trains SPEED)
- (uint8_t)trainStrength:(uint16_t)hits;
/// Catch minigame reward (trains SPEED, same as -playResult: -- upstream's
/// applyCatchResult and playResult both hand out gameGain the same way).
/// Returns the joy/speed gain, like -trainStrength:.
- (uint8_t)applyCatchResult:(uint8_t)score;

// --- battle (used by TPBattle, which owns the actual battle runtime; this
// stays the only thing that touches the live Pet directly) ---------------
/// Reward text (e.g. "+2 ATK"), or "" when nothing was gained.
- (NSString *)applyBattleWinWithDex:(int16_t)dex closeWin:(BOOL)closeWin;
- (void)applyBattleLoss;
- (uint8_t)catchChanceForWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel
                        petLevel:(uint8_t)petLevel closeWin:(BOOL)closeWin;
- (uint8_t)respectCatchChanceForWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel
                               petLevel:(uint8_t)petLevel;
- (BOOL)tryCatchWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel petLevel:(uint8_t)petLevel
               closeWin:(BOOL)closeWin luckRoll:(uint8_t)luckRoll;
- (BOOL)tryRespectCatchWildDex:(int16_t)dex wildLevel:(uint8_t)wildLevel
                       petLevel:(uint8_t)petLevel luckRoll:(uint8_t)luckRoll;

- (void)chooseStarter:(int16_t)dex;
- (void)evolve;
- (void)declineEvolve;
- (void)startFarewell;
- (void)declineFarewell;
- (void)startRunaway;          ///< the neglect ending; no dialog, it just leaves
- (void)releasePet;            ///< long-press "let it go" (ARC reserves `release`)
- (void)renamePet:(NSString *)name;
- (void)factoryReset;

- (BOOL)isRegistered:(int16_t)dex;
- (BOOL)isShinyRegistered:(int16_t)dex;

@end

// --- static tables -----------------------------------------------------
/// Species name, UI accent (RGB565) and background biome from the generated dex.
/// How many species this build's dex holds (DEX_COUNT). Swift pages the
/// gallery off it rather than repeating the number.
FOUNDATION_EXPORT int16_t TPDexCount(void);
FOUNDATION_EXPORT NSString *TPDexName(int16_t dex);
FOUNDATION_EXPORT uint16_t TPDexAccent(int16_t dex);
FOUNDATION_EXPORT uint8_t TPDexBiome(int16_t dex);
/// How many starters the picker offers, and the species in each slot.
FOUNDATION_EXPORT NSInteger TPStarterCount(void);
FOUNDATION_EXPORT int16_t TPStarterDex(NSInteger slot);   ///< slot 0..TPStarterCount()-1

/// Localized UI string by upstream `StrId`. Kept as a raw id so the Swift side
/// stays in lockstep with i18n.h without duplicating the table.
FOUNDATION_EXPORT NSString *TPString(uint8_t strId);
/// Need-bar captions, index 0..3 = FOOD / JOY / ENE / HYG.
FOUNDATION_EXPORT NSString *TPBarLabel(NSInteger index);
FOUNDATION_EXPORT NSString *TPChooseStarterTitle(void);
/// Two-line "load the sprites onto the device" notice, shown where the sprite
/// would be. Mirrors the firmware's behaviour when the SD card has no art.
FOUNDATION_EXPORT NSArray<NSString *> *TPNoSpritesLines(void);
FOUNDATION_EXPORT void TPSetLanguage(uint8_t lang);
FOUNDATION_EXPORT uint8_t TPLanguage(void);

/// Routes firmware sound-effect IDs to a Swift handler.
FOUNDATION_EXPORT void TPSetSfxHandler(void (^_Nullable handler)(uint8_t));

NS_ASSUME_NONNULL_END
