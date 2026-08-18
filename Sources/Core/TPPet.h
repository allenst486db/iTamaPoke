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

+ (instancetype)shared;

/// Loads NVS-equivalent state and applies elapsed wall-clock time. Call once.
- (void)begin;
/// Advances animation timers and the one-minute game tick. Call every frame.
- (void)update;
/// Re-applies wall-clock drift (foregrounding after a long background stretch).
- (void)syncClock;
/// Writes deferred state to disk. Call on backgrounding.
- (void)flushSave;

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
@property (nonatomic, readonly) uint8_t bond;
@property (nonatomic, readonly) uint16_t medals;

// --- presentation strings ----------------------------------------------
// Composed here rather than in Swift: i18n.h's StrId enum is only visible on
// this side, so mirroring the ids in Swift would drift silently on a submodule
// bump. The Swift layer just draws whatever these return.
@property (nonatomic, readonly, copy) NSString *statusMessage;    ///< upstream statusMsg()
@property (nonatomic, readonly, copy) NSString *eggMessage;       ///< upstream eggMsg()
@property (nonatomic, readonly, copy) NSString *headerName;       ///< "*PIKACHU Lv.7"
@property (nonatomic, readonly, copy) NSString *pokedexLine;      ///< "POKEDEX 12/151"
@property (nonatomic, readonly, copy, nullable) NSString *eggRarityLabel;  ///< nil when common
@property (nonatomic, readonly, copy) NSString *ceremonyMessage;

// --- decision gates (a button appears; the player taps it) -------------
@property (nonatomic, readonly) BOOL wantsEvolveButton;
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

- (void)chooseStarter:(int16_t)dex;
- (void)evolve;
- (void)declineEvolve;
- (void)startFarewell;
- (void)declineFarewell;
- (void)releasePet;            ///< long-press "let it go" (ARC reserves `release`)
- (void)renamePet:(NSString *)name;
- (void)factoryReset;

- (BOOL)isRegistered:(int16_t)dex;
- (BOOL)isShinyRegistered:(int16_t)dex;

@end

// --- static tables -----------------------------------------------------
/// Species name, UI accent (RGB565) and background biome from the generated dex.
FOUNDATION_EXPORT NSString *TPDexName(int16_t dex);
FOUNDATION_EXPORT uint16_t TPDexAccent(int16_t dex);
FOUNDATION_EXPORT uint8_t TPDexBiome(int16_t dex);
FOUNDATION_EXPORT int16_t TPStarterDex(NSInteger slot);   ///< slot 0..2

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
