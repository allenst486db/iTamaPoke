#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Objective-C facade over battle.h/battle.cpp and the wild-encounter-prompt
// logic that drives them, both translated from ShadowEnemyx/TamaPoke
// ("TamaPoke — Expanded") rather than from the upstream/ submodule --
// see upstream-expanded/README.md. Same deliberately-thin philosophy as
// TPPet: only what the SwiftUI layer currently draws or calls.
//
// One process-wide battle, same as TPPet's one process-wide Pet.

@interface TPBattle : NSObject

@property (class, nonatomic, readonly) TPBattle *shared;

/// battle.cpp's battleTypeEffectPct, for the Type quiz's distractor filter
/// (100 = neutral, above = super-effective). Types are dex.h's TYPE_* ids.
+ (uint8_t)typeEffectPct:(uint8_t)attackType
               defender1:(uint8_t)defendType1
               defender2:(uint8_t)defendType2;

// --- wild encounter prompt (idle screen) ---------------------------------
/// Call once per tick with whether the idle screen is actually showing (no
/// other modal open) -- mirrors the fork's mainScreenReadyForWild(), which
/// lives in the view layer here rather than in this facade.
- (void)maybeOfferWildEncounterIfEligible:(BOOL)mainScreenReady;
@property (nonatomic, readonly) BOOL wildPromptActive;
@property (nonatomic, readonly, copy) NSString *wildPromptLine;    ///< "PIKACHU Lv.12"
@property (nonatomic, readonly, copy) NSString *wildQuestionText;
@property (nonatomic, readonly, copy) NSString *fightText;
@property (nonatomic, readonly, copy) NSString *laterText;
- (void)dismissWildPrompt;   ///< "later"
- (void)acceptWildPrompt;    ///< "fight" -- starts the battle with the prompted wild

// --- lifecycle ------------------------------------------------------------
@property (nonatomic, readonly) BOOL canStart;   ///< canStartWildBattle: not egg/sleeping/ceremony
- (void)start;                                    ///< random wild, for the Battle idle-menu button
- (void)close;
@property (nonatomic, readonly) BOOL isOpen;

// --- in-battle state --------------------------------------------------
@property (nonatomic, readonly) BOOL resolved;
@property (nonatomic, readonly) int16_t wildDex;
@property (nonatomic, readonly) uint8_t wildLevel;
@property (nonatomic, readonly) BOOL wildAlreadyCaught;   ///< small pokeball marker by the HP bar
@property (nonatomic, readonly) uint16_t playerHp;
@property (nonatomic, readonly) uint16_t playerMaxHp;
@property (nonatomic, readonly) uint16_t enemyHp;
@property (nonatomic, readonly) uint16_t enemyMaxHp;
@property (nonatomic, readonly) uint8_t restUsesLeft;
@property (nonatomic, readonly) BOOL attackMenuOpen;
@property (nonatomic, readonly, copy) NSString *roundLabel;      ///< "R3"
@property (nonatomic, readonly, copy) NSString *battleMessage;   ///< last turn's result text, "" before the first
@property (nonatomic, readonly) uint16_t lastEnemyDamage;        ///< 0 when nothing to show under the message

// text (composed here for the same reason as TPPet: StrId stays private to
// the Objective-C++ side)
@property (nonatomic, readonly, copy) NSString *titleText;
@property (nonatomic, readonly, copy) NSString *playerLabel;     ///< "NAME Lv.N"
@property (nonatomic, readonly, copy) NSString *enemyLabel;
@property (nonatomic, readonly, copy) NSString *runText;
@property (nonatomic, readonly, copy) NSString *attackText;
@property (nonatomic, readonly, copy) NSString *dodgeText;
@property (nonatomic, readonly, copy) NSString *restText;        ///< "REST N"
@property (nonatomic, readonly, copy) NSString *quickAttackText;
@property (nonatomic, readonly, copy) NSString *heavyAttackText;

// --- actions (mid-battle) --------------------------------------------------
- (void)openAttackMenu;
- (void)closeAttackMenu;
- (void)performQuickAttack;
- (void)performHeavyAttack;
- (void)performDodge;
- (void)performRest;

// --- resolved screen --------------------------------------------------
@property (nonatomic, readonly) BOOL playerWon;
@property (nonatomic, readonly, copy) NSString *resultText;      ///< WIN / LOSS
@property (nonatomic, readonly, copy) NSString *roundsLine;
@property (nonatomic, readonly, copy) NSString *damageLine;
@property (nonatomic, readonly, copy) NSString *rewardLine;      ///< "" when nothing was gained
@property (nonatomic, readonly) BOOL catchOffered;
@property (nonatomic, readonly) BOOL catchDone;
@property (nonatomic, readonly) BOOL catchTried;
@property (nonatomic, readonly) BOOL catchSuccess;
@property (nonatomic, readonly) BOOL respectCatch;               ///< close-loss "it respects you" catch, not a post-win one
@property (nonatomic, readonly, copy) NSString *closeChanceText; ///< shown only when respectCatch && offered && !done
@property (nonatomic, readonly, copy) NSString *catchWildText;
@property (nonatomic, readonly, copy) NSString *leaveWildText;
@property (nonatomic, readonly, copy) NSString *okText;
@property (nonatomic, readonly, copy) NSString *caughtOkText;
@property (nonatomic, readonly, copy) NSString *escapedText;
- (void)tryCatch;
- (void)leaveWild;

@end

NS_ASSUME_NONNULL_END
