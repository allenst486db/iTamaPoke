#import <Foundation/Foundation.h>
#include "audio.h"   // upstream/audio.h -- declarations only, no ESP32 deps

// The firmware drives an ES8311 codec over I2S. There is no such chip here, so
// the effect IDs are forwarded to Swift, where TPAudio re-synthesises upstream's
// square waves through AVAudioEngine.
static void (*gSfxHook)(uint8_t) = NULL;
static bool gEnabled = true;

extern "C" void TPSetSfxHook(void (*hook)(uint8_t)) { gSfxHook = hook; }

void audioBegin(void) {}
void sfxPlay(uint8_t id) { if (gEnabled && gSfxHook) gSfxHook(id); }
void audioSetEnabled(bool on) { gEnabled = on; }
bool audioEnabled(void) { return gEnabled; }
