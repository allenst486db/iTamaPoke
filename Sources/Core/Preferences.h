#pragma once
//
// Arduino ESP32 `Preferences` (NVS key/value store) reimplemented on top of
// NSUserDefaults. Header stays pure C++ so pet.cpp compiles as C++; the
// implementation lives in Preferences.mm.
//
#include <stdint.h>
#include <stddef.h>

class Preferences {
public:
  bool begin(const char *name, bool readOnly = false);
  void end();
  bool clear();
  bool remove(const char *key);
  bool isKey(const char *key);

  size_t putChar(const char *key, int8_t v);
  size_t putUChar(const char *key, uint8_t v);
  size_t putShort(const char *key, int16_t v);
  size_t putUShort(const char *key, uint16_t v);
  size_t putInt(const char *key, int32_t v);
  size_t putUInt(const char *key, uint32_t v);
  size_t putBool(const char *key, bool v);
  size_t putString(const char *key, const char *v);
  size_t putBytes(const char *key, const void *v, size_t len);

  int8_t getChar(const char *key, int8_t def = 0);
  uint8_t getUChar(const char *key, uint8_t def = 0);
  int16_t getShort(const char *key, int16_t def = 0);
  uint16_t getUShort(const char *key, uint16_t def = 0);
  int32_t getInt(const char *key, int32_t def = 0);
  uint32_t getUInt(const char *key, uint32_t def = 0);
  bool getBool(const char *key, bool def = false);
  size_t getString(const char *key, char *value, size_t maxLen);
  size_t getBytes(const char *key, void *buf, size_t maxLen);

private:
  char _ns[24] = "tamapoke";
};
