#import <Foundation/Foundation.h>
#include <string.h>
#include "Preferences.h"

// Keys are namespaced "<ns>/<key>" so several Preferences instances (pet state,
// i18n language) can share one NSUserDefaults suite without colliding.
static NSString *TPKey(const char *ns, const char *key) {
  return [NSString stringWithFormat:@"%s/%s", ns, key];
}

bool Preferences::begin(const char *name, bool) {
  strncpy(_ns, name ? name : "tamapoke", sizeof(_ns) - 1);
  _ns[sizeof(_ns) - 1] = 0;
  return true;
}

void Preferences::end() {
  [[NSUserDefaults standardUserDefaults] synchronize];
}

bool Preferences::clear() {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  NSString *prefix = [NSString stringWithFormat:@"%s/", _ns];
  for (NSString *k in [[d dictionaryRepresentation] allKeys]) {
    if ([k hasPrefix:prefix]) [d removeObjectForKey:k];
  }
  return true;
}

bool Preferences::remove(const char *key) {
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:TPKey(_ns, key)];
  return true;
}

bool Preferences::isKey(const char *key) {
  return [[NSUserDefaults standardUserDefaults] objectForKey:TPKey(_ns, key)] != nil;
}

// --- scalars -----------------------------------------------------------
// NSUserDefaults stores every integer as NSInteger; the getters re-narrow.
static size_t TPPutInt(const char *ns, const char *key, long long v, size_t sz) {
  [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)v forKey:TPKey(ns, key)];
  return sz;
}

static long long TPGetInt(const char *ns, const char *key, long long def) {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  NSNumber *n = [d objectForKey:TPKey(ns, key)];
  return n ? (long long)[n integerValue] : def;
}

size_t Preferences::putChar(const char *k, int8_t v)    { return TPPutInt(_ns, k, v, 1); }
size_t Preferences::putUChar(const char *k, uint8_t v)  { return TPPutInt(_ns, k, v, 1); }
size_t Preferences::putShort(const char *k, int16_t v)  { return TPPutInt(_ns, k, v, 2); }
size_t Preferences::putUShort(const char *k, uint16_t v){ return TPPutInt(_ns, k, v, 2); }
size_t Preferences::putInt(const char *k, int32_t v)    { return TPPutInt(_ns, k, v, 4); }
size_t Preferences::putUInt(const char *k, uint32_t v)  { return TPPutInt(_ns, k, v, 4); }

size_t Preferences::putBool(const char *k, bool v) {
  [[NSUserDefaults standardUserDefaults] setBool:v forKey:TPKey(_ns, k)];
  return 1;
}

int8_t   Preferences::getChar(const char *k, int8_t d)    { return (int8_t)TPGetInt(_ns, k, d); }
uint8_t  Preferences::getUChar(const char *k, uint8_t d)  { return (uint8_t)TPGetInt(_ns, k, d); }
int16_t  Preferences::getShort(const char *k, int16_t d)  { return (int16_t)TPGetInt(_ns, k, d); }
uint16_t Preferences::getUShort(const char *k, uint16_t d){ return (uint16_t)TPGetInt(_ns, k, d); }
int32_t  Preferences::getInt(const char *k, int32_t d)    { return (int32_t)TPGetInt(_ns, k, d); }
uint32_t Preferences::getUInt(const char *k, uint32_t d)  { return (uint32_t)TPGetInt(_ns, k, d); }

bool Preferences::getBool(const char *k, bool def) {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  NSNumber *n = [d objectForKey:TPKey(_ns, k)];
  return n ? [n boolValue] : def;
}

// --- strings and blobs -------------------------------------------------
size_t Preferences::putString(const char *key, const char *v) {
  NSString *s = [NSString stringWithUTF8String:(v ? v : "")];
  [[NSUserDefaults standardUserDefaults] setObject:s forKey:TPKey(_ns, key)];
  return strlen(v ? v : "");
}

size_t Preferences::getString(const char *key, char *value, size_t maxLen) {
  if (!value || maxLen == 0) return 0;
  value[0] = 0;
  NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:TPKey(_ns, key)];
  if (!s) return 0;
  strncpy(value, [s UTF8String], maxLen - 1);
  value[maxLen - 1] = 0;
  return strlen(value);
}

size_t Preferences::putBytes(const char *key, const void *v, size_t len) {
  NSData *data = [NSData dataWithBytes:v length:len];
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:TPKey(_ns, key)];
  return len;
}

size_t Preferences::getBytes(const char *key, void *buf, size_t maxLen) {
  NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:TPKey(_ns, key)];
  if (!data) return 0;
  size_t n = data.length < maxLen ? data.length : maxLen;
  memcpy(buf, data.bytes, n);
  return n;
}
