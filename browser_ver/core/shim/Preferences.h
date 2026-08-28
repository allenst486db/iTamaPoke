// Browser/WASM stand-in for ESP32's Preferences (NVS key-value store),
// covering the get*/put* surface upstream-expanded/*.cpp actually calls
// (begin/end/clear/isKey, bool/char/short/uint/ushort/bytes/string).
//
// Real Preferences persists to flash itself; this one is a plain in-memory
// map for the game-tick duration, and relies on the JS side to survive a
// reload -- browser_glue.cpp exports tp_export_state()/tp_import_state()
// (JSON) around it, called from IndexedDB on save/load. Same shape as the
// iOS build's own NSUserDefaults-backed shim in Sources/Core/TPPet.mm,
// just serialized differently since there is no NSUserDefaults here.
#pragma once

#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <variant>
#include <vector>

class Preferences {
public:
  bool begin(const char *ns, bool readOnly = false) { (void)ns; (void)readOnly; return true; }
  void end() {}
  void clear() { store().clear(); }
  bool isKey(const char *key) { return store().count(key) != 0; }

  bool putBool(const char *key, bool value)   { store()[key] = value; return true; }
  bool getBool(const char *key, bool def = false) {
    auto it = store().find(key);
    if (it == store().end() || !std::holds_alternative<bool>(it->second)) return def;
    return std::get<bool>(it->second);
  }

  size_t putUChar(const char *key, uint8_t value) { store()[key] = (int64_t)value; return 1; }
  uint8_t getUChar(const char *key, uint8_t def = 0) { return (uint8_t)getInt(key, def); }

  size_t putChar(const char *key, int8_t value) { store()[key] = (int64_t)value; return 1; }
  int8_t getChar(const char *key, int8_t def = 0) { return (int8_t)getInt(key, def); }

  size_t putShort(const char *key, int16_t value) { store()[key] = (int64_t)value; return 2; }
  int16_t getShort(const char *key, int16_t def = 0) { return (int16_t)getInt(key, def); }

  size_t putUShort(const char *key, uint16_t value) { store()[key] = (int64_t)value; return 2; }
  uint16_t getUShort(const char *key, uint16_t def = 0) { return (uint16_t)getInt(key, def); }

  size_t putUInt(const char *key, uint32_t value) { store()[key] = (int64_t)value; return 4; }
  uint32_t getUInt(const char *key, uint32_t def = 0) { return (uint32_t)getInt(key, def); }

  size_t putString(const char *key, const char *value) { store()[key] = std::string(value); return std::strlen(value); }
  size_t getString(const char *key, char *out, size_t maxLen) {
    auto it = store().find(key);
    std::string v = (it != store().end() && std::holds_alternative<std::string>(it->second))
        ? std::get<std::string>(it->second) : std::string();
    size_t n = v.size() < maxLen - 1 ? v.size() : maxLen - 1;
    std::memcpy(out, v.data(), n);
    out[n] = '\0';
    return n;
  }

  size_t putBytes(const char *key, const void *value, size_t len) {
    const uint8_t *p = static_cast<const uint8_t *>(value);
    store()[key] = std::vector<uint8_t>(p, p + len);
    return len;
  }
  size_t getBytes(const char *key, void *out, size_t maxLen) {
    auto it = store().find(key);
    if (it == store().end() || !std::holds_alternative<std::vector<uint8_t>>(it->second)) return 0;
    const auto &v = std::get<std::vector<uint8_t>>(it->second);
    size_t n = v.size() < maxLen ? v.size() : maxLen;
    std::memcpy(out, v.data(), n);
    return n;
  }

  using Value = std::variant<bool, int64_t, std::string, std::vector<uint8_t>>;

  // One shared table for the whole process, like NVS's single flash
  // partition -- every Preferences instance in upstream-expanded (there is
  // only ever the one, "tamapoke") already assumed this via ESP32's own
  // Preferences being backed by one real NVS namespace. Public so
  // browser_glue.cpp's export/import (JSON <-> IndexedDB) can walk it
  // directly rather than needing a get-every-known-key round trip.
  static std::map<std::string, Value> &store() {
    static std::map<std::string, Value> s;
    return s;
  }

private:
  int64_t getInt(const char *key, int64_t def) {
    auto it = store().find(key);
    if (it == store().end() || !std::holds_alternative<int64_t>(it->second)) return def;
    return std::get<int64_t>(it->second);
  }
};
