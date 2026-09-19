#include "mmkv_ffi.h"

#if defined(__APPLE__)
#include <MMKVCore/MMKV.h>
#include <MMKVCore/MMBuffer.h>
#else
#include <MMKV/MMKV.h>
#include <MMKV/MMBuffer.h>
#endif

#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <mutex>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

#if !defined(MMKV_APPLE)
using NativeMMKV = ::MMKV;
using NativeMMKVConfig = ::MMKVConfig;
constexpr auto kNativeSingleProcess = ::MMKV_SINGLE_PROCESS;
constexpr auto kNativeMultiProcess = ::MMKV_MULTI_PROCESS;
constexpr auto kNativeReadOnly = ::MMKV_READ_ONLY;
constexpr auto kNativeLogNone = ::MMKVLogNone;
constexpr auto kNativeDiscardOnError = ::OnErrorDiscard;
constexpr auto kNativeRecoverOnError = ::OnErrorRecover;
#else
using NativeMMKV = mmkv::MMKV;
using NativeMMKVConfig = mmkv::MMKVConfig;
constexpr auto kNativeSingleProcess = mmkv::MMKV_SINGLE_PROCESS;
constexpr auto kNativeMultiProcess = mmkv::MMKV_MULTI_PROCESS;
constexpr auto kNativeReadOnly = mmkv::MMKV_READ_ONLY;
constexpr auto kNativeLogNone = mmkv::MMKVLogNone;
constexpr auto kNativeDiscardOnError = mmkv::OnErrorDiscard;
constexpr auto kNativeRecoverOnError = mmkv::OnErrorRecover;
#endif

constexpr int32_t kOk = 0;
constexpr int32_t kMissing = 1;
constexpr int32_t kWrongType = 2;
constexpr int32_t kOkAscii = 3;
constexpr int32_t kInvalidArgument = -1;
constexpr int32_t kIoError = -2;
constexpr int32_t kReadOnly = -3;
constexpr int32_t kBufferTooSmall = -4;

inline bool isAsciiFast(const char* data, size_t len) noexcept {
  const auto* ptr = reinterpret_cast<const uint8_t*>(data);
  while (len >= sizeof(uint64_t)) {
    uint64_t word;
    std::memcpy(&word, ptr, sizeof(uint64_t));
    if ((word & 0x8080808080808080ULL) != 0) return false;
    ptr += sizeof(uint64_t);
    len -= sizeof(uint64_t);
  }
  while (len > 0) {
    if ((*ptr & 0x80) != 0) return false;
    ptr++;
    len--;
  }
  return true;
}

thread_local std::string g_last_error;
void setError(const char* message) { g_last_error = message == nullptr ? "" : message; }

// DartNative's synchronous FFI calls run to completion before the next call on
// an isolate. Reuse the decode buffer on that native thread so string reads do
// not allocate a temporary std::string for every operation. The buffer is
// thread-local rather than attached to a shared MMKV instance, preserving the
// native engine's ability to serve multiple isolates concurrently.
thread_local std::string g_string_scratch;
thread_local mmkv::MMBuffer g_buffer_scratch;

constexpr size_t kScratchShrinkThreshold = 64 * 1024; // 64 KB

inline void recycleStringScratch() noexcept {
  g_string_scratch.clear();
  if (g_string_scratch.capacity() > kScratchShrinkThreshold) {
    g_string_scratch.shrink_to_fit();
  }
}

inline void recycleBufferScratch() noexcept {
  if (g_buffer_scratch.length() > kScratchShrinkThreshold) {
    g_buffer_scratch = mmkv::MMBuffer();
  }
}

struct SharedInstance {
  std::string key;
  NativeMMKV* value = nullptr;
  size_t references = 0;
};

struct Handle {
  SharedInstance* shared = nullptr;
};

std::mutex g_instances_mutex;
std::unordered_map<std::string, SharedInstance*> g_instances;

void wipe(std::string& value) noexcept {
  volatile char* bytes = value.empty() ? nullptr : value.data();
  for (size_t index = 0; bytes != nullptr && index < value.size(); ++index) {
    bytes[index] = 0;
  }
  value.clear();
}

struct WipeOnExit {
  std::string& value;
  ~WipeOnExit() { wipe(value); }
};

std::string toString(const uint8_t* value, size_t length) {
  if (length == 0) return {};
  if (value == nullptr) throw std::invalid_argument("null pointer with non-zero length");
  return std::string(reinterpret_cast<const char*>(value), length);
}

std::string_view toView(const uint8_t* value, size_t length) {
  if (length == 0) return {};
  if (value == nullptr) throw std::invalid_argument("null pointer with non-zero length");
  return {reinterpret_cast<const char*>(value), length};
}

std::string instanceKey(const std::string& id, const std::string& root) {
  const auto effective_root = root.empty() ? NativeMMKV::getRootDir() : root;
  if (effective_root.empty()) return std::string("\0", 1) + id;
  // If already an absolute normalized path (standard on mobile), avoid filesystem syscalls
  if (effective_root.front() == '/' && effective_root.find("/.") == std::string::npos) {
    return effective_root + '\0' + id;
  }
  std::error_code error;
  const auto normalized = std::filesystem::absolute(effective_root, error).lexically_normal().string();
  return (error ? effective_root : normalized) + '\0' + id;
}

bool validId(const std::string& id) {
  if (id.empty() || id == "." || id == ".." || id.find('/') != std::string::npos ||
      id.find('\\') != std::string::npos) {
    return false;
  }
  for (const auto byte : id) {
    const auto value = static_cast<unsigned char>(byte);
    if (value < 0x20 || value == 0x7f) return false;
  }
  return true;
}

bool validRootPath(const std::string& path) {
  for (const auto byte : path) {
    const auto value = static_cast<unsigned char>(byte);
    if (value < 0x20 || value == 0x7f) return false;
  }
  return true;
}

bool validKey(std::string_view key) {
  if (key.empty() || key.find('\0') != std::string_view::npos) {
    setError("key must not be empty or contain a NUL character.");
    return false;
  }
  return true;
}

NativeMMKV* value(DNMMKVHandle handle) {
  auto* typed = static_cast<Handle*>(handle);
  if (typed == nullptr || typed->shared == nullptr || typed->shared->value == nullptr) return nullptr;
  return typed->shared->value;
}

template <typename Function>
int32_t guarded(Function&& function) noexcept {
  try {
    return function();
  } catch (const std::exception& error) {
    setError(error.what());
    return kIoError;
  } catch (...) {
    setError("Unknown MMKV native error.");
    return kIoError;
  }
}

int32_t copyOut(const void* value, size_t size, uint8_t** output, size_t* output_size) {
  if (output == nullptr || output_size == nullptr) return kInvalidArgument;
  auto* result = static_cast<uint8_t*>(std::malloc(size == 0 ? 1 : size));
  if (result == nullptr) return kIoError;
  if (size != 0) {
    if (value == nullptr) {
      std::free(result);
      return kInvalidArgument;
    }
    std::memcpy(result, value, size);
  }
  *output = result;
  *output_size = size;
  return kOk;
}

int32_t copyInto(const void* value, size_t size, uint8_t* output, size_t capacity,
                 size_t* output_size) {
  if (output_size == nullptr) return kInvalidArgument;
  *output_size = size;
  if (size > capacity) return kBufferTooSmall;
  if (size != 0 && (output == nullptr || value == nullptr)) return kInvalidArgument;
  if (size != 0) std::memcpy(output, value, size);
  return kOk;
}

template <typename T>
int32_t copyOut(const T& value, uint8_t** output, size_t* output_size) {
  return copyOut(value.data(), value.size(), output, output_size);
}

int32_t writeFailure(const NativeMMKV* instance) {
  return instance != nullptr && instance->isReadOnly() ? kReadOnly : kIoError;
}

inline int32_t getKeyStatus(bool gotValue) noexcept {
  return gotValue ? kOk : kMissing;
}

bool ensureInitialized(const std::string& root) {
  if (!NativeMMKV::getRootDir().empty()) return true;
  if (root.empty()) return false;
  NativeMMKV::initializeMMKV(root, kNativeLogNone);
  return !NativeMMKV::getRootDir().empty();
}

NativeMMKV* createInstance(const std::string& id, const std::string& root,
                           const std::string& encryption_key, int32_t encryption_type,
                           int32_t mode, bool read_only, bool compare_before_set,
                           int32_t recovery_strategy) {
  if (!validId(id)) {
    setError("id must be a non-empty filename-safe value.");
    return nullptr;
  }
  if (!validRootPath(root)) {
    setError("root path contains an unsafe control character.");
    return nullptr;
  }
  if (!ensureInitialized(root)) {
    setError("MMKV has not been initialized with a default root path.");
    return nullptr;
  }
  if (encryption_type < 0 || encryption_type > 2) {
    setError("encryptionType must be 0, AES-128 (1), or AES-256 (2).");
    return nullptr;
  }
  if (encryption_key.empty() && encryption_type != 0) {
    setError("encryptionType cannot be set without an encryption key.");
    return nullptr;
  }
  if (!encryption_key.empty() && encryption_type == 0) {
    setError("an encryption key requires AES-128 or AES-256.");
    return nullptr;
  }
  const size_t max_key_length = encryption_type == 2 ? 32 : 16;
  if (!encryption_key.empty() && encryption_key.size() != max_key_length) {
    setError(encryption_type == 2 ? "AES-256 encryption keys must be exactly 32 bytes."
                                 : "AES-128 encryption keys must be exactly 16 bytes.");
    return nullptr;
  }
  if (recovery_strategy < 0 || recovery_strategy > 2) {
    setError("recoveryStrategy must be 0, discard-on-error (1), or recover-on-error (2).");
    return nullptr;
  }

  NativeMMKVConfig config;
  config.mode = mode == 1 ? kNativeMultiProcess : kNativeSingleProcess;
  if (read_only) config.mode = config.mode | kNativeReadOnly;
  config.aes256 = encryption_type == 2;
  config.cryptKey = encryption_key.empty() ? nullptr : &encryption_key;
  config.rootPath = root.empty() ? nullptr : &root;
  config.enableCompareBeforeSet = compare_before_set;
  if (recovery_strategy == 1) config.recover = kNativeDiscardOnError;
  if (recovery_strategy == 2) config.recover = kNativeRecoverOnError;
  return NativeMMKV::mmkvWithID(id, config);
}

}  // namespace

DNMMKVHandle DNMMKVCreate(const uint8_t* id, size_t id_len, const uint8_t* root_path,
                          size_t root_path_len, const uint8_t* encryption_key, size_t encryption_key_len,
                          int32_t encryption_type, int32_t mode, int32_t read_only,
                          int32_t compare_before_set, int32_t recovery_strategy) {
  setError("");
  try {
    const auto id_string = toString(id, id_len);
    const auto root_string = toString(root_path, root_path_len);
    auto key_string = toString(encryption_key, encryption_key_len);
    WipeOnExit wipe_key(key_string);
    if (!validId(id_string)) {
      setError("id must be a non-empty filename-safe value.");
      return nullptr;
    }
    if (!validRootPath(root_string)) {
      setError("root path contains an unsafe control character.");
      return nullptr;
    }
    if (!ensureInitialized(root_string)) return nullptr;
    std::lock_guard lock(g_instances_mutex);
    const auto key = instanceKey(id_string, root_string);
    if (auto found = g_instances.find(key); found != g_instances.end()) {
      found->second->references++;
      return new Handle{found->second};
    }
    auto* native = createInstance(id_string, root_string, key_string, encryption_type, mode,
                                   read_only != 0, compare_before_set != 0, recovery_strategy);
    if (native == nullptr) return nullptr;
    auto* shared = new SharedInstance{key, native, 1};
    g_instances.emplace(key, shared);
    return new Handle{shared};
  } catch (const std::exception& error) {
    setError(error.what());
    return nullptr;
  } catch (...) {
    setError("Unknown MMKV create error.");
    return nullptr;
  }
}

void DNMMKVDestroy(DNMMKVHandle handle) {
  auto* typed = static_cast<Handle*>(handle);
  if (typed == nullptr) return;
  std::lock_guard lock(g_instances_mutex);
  if (typed->shared != nullptr && typed->shared->references > 0) {
    typed->shared->references--;
    if (typed->shared->references == 0) {
      if (typed->shared->value != nullptr) typed->shared->value->close();
      g_instances.erase(typed->shared->key);
      delete typed->shared;
    }
  }
  delete typed;
}

int32_t DNMMKVSetString(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                        const uint8_t* input, size_t input_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    return instance->set(toView(input, input_len), key_view) ? kOk : writeFailure(instance);
  });
}

int32_t DNMMKVSetBoolean(DNMMKVHandle handle, const uint8_t* key, size_t key_len, int32_t input) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || (input != 0 && input != 1)) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    return instance->set(input != 0, key_view) ? kOk : writeFailure(instance);
  });
}

int32_t DNMMKVSetNumber(DNMMKVHandle handle, const uint8_t* key, size_t key_len, double input) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    return instance->set(input, key_view) ? kOk : writeFailure(instance);
  });
}

int32_t DNMMKVSetInt64(DNMMKVHandle handle, const uint8_t* key, size_t key_len, int64_t input) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    return instance->set(input, key_view) ? kOk : writeFailure(instance);
  });
}

int32_t DNMMKVSetBuffer(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                        const uint8_t* input, size_t input_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || (input_len != 0 && input == nullptr)) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    // MMKV copies the bytes into its mmap record synchronously. Borrow the
    // caller-owned scratch buffer for this call to avoid an intermediate
    // malloc+memcpy; this is the same zero-copy handoff used by RN MMKV.
    mmkv::MMBuffer buffer(const_cast<uint8_t*>(input), input_len, mmkv::MMBufferNoCopy);
    return instance->set(std::move(buffer), key_view) ? kOk : writeFailure(instance);
  });
}

int32_t DNMMKVGetString(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                        uint8_t** output, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    recycleStringScratch();
    const auto status = getKeyStatus(instance->getString(key_view, g_string_scratch, true));
    const auto is_ascii = (status == kOk && isAsciiFast(g_string_scratch.data(), g_string_scratch.size()));
    const auto result = status == kOk ? copyOut(g_string_scratch, output, output_len) : status;
    recycleStringScratch();
    return (result == kOk && is_ascii) ? kOkAscii : result;
  });
}

int32_t DNMMKVGetBoolean(DNMMKVHandle handle, const uint8_t* key, size_t key_len, int32_t* output) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    bool has_value = false;
    const auto result = instance->getBool(key_view, false, &has_value);
    const auto status = getKeyStatus(has_value);
    if (status == kOk) *output = result ? 1 : 0;
    return status;
  });
}

int32_t DNMMKVGetNumber(DNMMKVHandle handle, const uint8_t* key, size_t key_len, double* output) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    bool has_value = false;
    const auto result = instance->getDouble(key_view, 0.0, &has_value);
    const auto status = getKeyStatus(has_value);
    if (status == kOk) *output = result;
    return status;
  });
}

int32_t DNMMKVGetInt64(DNMMKVHandle handle, const uint8_t* key, size_t key_len, int64_t* output) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    bool has_value = false;
    const auto result = instance->getInt64(key_view, 0, &has_value);
    const auto status = getKeyStatus(has_value);
    if (status == kOk) *output = result;
    return status;
  });
}

int32_t DNMMKVGetBuffer(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                        uint8_t** output, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    mmkv::MMBuffer result;
    const auto got_value = instance->getBytes(key_view, result);
    const auto status = getKeyStatus(got_value);
    if (status != kOk) return status;
    return copyOut(result.getPtr(), result.length(), output, output_len);
  });
}

int32_t DNMMKVGetStringInto(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                            uint8_t* output, size_t output_capacity, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    recycleStringScratch();
    const auto status = getKeyStatus(instance->getString(key_view, g_string_scratch, true));
    const auto result = status == kOk
               ? copyInto(g_string_scratch.data(), g_string_scratch.size(), output, output_capacity,
                          output_len)
               : status;
    recycleStringScratch();
    return result;
  });
}

int32_t DNMMKVGetBufferInto(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                            uint8_t* output, size_t output_capacity, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    mmkv::MMBuffer result;
    const auto status = getKeyStatus(instance->getBytes(key_view, result));
    if (status != kOk) return status;
    return copyInto(result.getPtr(), result.length(), output, output_capacity, output_len);
  });
}

int32_t DNMMKVGetStringView(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                            const uint8_t** output, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    recycleBufferScratch();
    const auto got_value = instance->getBytes(key_view, g_buffer_scratch);
    const auto status = getKeyStatus(got_value);
    if (status != kOk) {
      *output = nullptr;
      *output_len = 0;
      return status;
    }
    const auto* ptr = reinterpret_cast<const char*>(g_buffer_scratch.getPtr());
    const auto len = g_buffer_scratch.length();
    *output = reinterpret_cast<const uint8_t*>(ptr);
    *output_len = len;
    return isAsciiFast(ptr, len) ? kOkAscii : kOk;
  });
}

int32_t DNMMKVGetBufferView(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                            const uint8_t** output, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    recycleBufferScratch();
    const auto got_value = instance->getBytes(key_view, g_buffer_scratch);
    const auto status = getKeyStatus(got_value);
    if (status != kOk) {
      *output = nullptr;
      *output_len = 0;
      return status;
    }
    *output = reinterpret_cast<const uint8_t*>(g_buffer_scratch.getPtr());
    *output_len = g_buffer_scratch.length();
    return kOk;
  });
}

int32_t DNMMKVContains(DNMMKVHandle handle, const uint8_t* key, size_t key_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    return instance->containsKey(key_view) ? 1 : 0;
  });
}

int32_t DNMMKVGetKeyCount(DNMMKVHandle handle, size_t* count) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || count == nullptr) return kInvalidArgument;
    *count = instance->count();
    return kOk;
  });
}

int32_t DNMMKVGetKeyAt(DNMMKVHandle handle, size_t index, uint8_t** output, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto keys = instance->allKeys();
    if (index >= keys.size()) return kMissing;
    return copyOut(keys[index], output, output_len);
  });
}

int32_t DNMMKVGetAllKeys(DNMMKVHandle handle, uint8_t** output, size_t* output_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || output == nullptr || output_len == nullptr) return kInvalidArgument;
    const auto keys = instance->allKeys();
    size_t total = 0;
    for (const auto& key : keys) {
      if (key.size() > SIZE_MAX - sizeof(uint64_t) ||
          total > SIZE_MAX - sizeof(uint64_t) - key.size()) {
        return kIoError;
      }
      total += sizeof(uint64_t) + key.size();
    }
    auto* result = static_cast<uint8_t*>(std::malloc(total == 0 ? 1 : total));
    if (result == nullptr) return kIoError;
    auto* cursor = result;
    for (const auto& key : keys) {
      const auto length = static_cast<uint64_t>(key.size());
      std::memcpy(cursor, &length, sizeof(length));
      cursor += sizeof(length);
      if (!key.empty()) {
        std::memcpy(cursor, key.data(), key.size());
        cursor += key.size();
      }
    }
    *output = result;
    *output_len = total;
    return kOk;
  });
}

int32_t DNMMKVRemove(DNMMKVHandle handle, const uint8_t* key, size_t key_len, int32_t* removed) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr || removed == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    if (instance->isReadOnly()) {
      *removed = 0;
      return kOk;
    }
    *removed = instance->removeValueForKey(key_view) ? 1 : 0;
    return kOk;
  });
}

int32_t DNMMKVClearAll(DNMMKVHandle handle) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    if (instance->isReadOnly()) return kOk;
    instance->clearAll();
    return kOk;
  });
}

int32_t DNMMKVTrim(DNMMKVHandle handle) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    if (instance->isReadOnly()) return kOk;
    instance->trim();
    instance->clearMemoryCache();
    return kOk;
  });
}

int32_t DNMMKVImportAll(DNMMKVHandle destination, DNMMKVHandle source, size_t* imported) {
  return guarded([&] {
    auto* target = value(destination);
    auto* origin = value(source);
    if (target == nullptr || origin == nullptr || imported == nullptr) return kInvalidArgument;
    if (target == origin) {
      *imported = 0;
      return kOk;
    }
    if (target->isReadOnly()) {
      *imported = 0;
      return kOk;
    }
    *imported = target->importFrom(origin);
    return kOk;
  });
}

uint64_t DNMMKVByteSize(DNMMKVHandle handle) {
  auto* instance = value(handle);
  return instance == nullptr ? 0 : static_cast<uint64_t>(instance->actualSize());
}

uint64_t DNMMKVLength(DNMMKVHandle handle) {
  auto* instance = value(handle);
  return instance == nullptr ? 0 : static_cast<uint64_t>(instance->count());
}

int32_t DNMMKVIsReadOnly(DNMMKVHandle handle) {
  auto* instance = value(handle);
  return instance == nullptr ? kInvalidArgument : (instance->isReadOnly() ? 1 : 0);
}

int32_t DNMMKVIsEncrypted(DNMMKVHandle handle) {
  auto* instance = value(handle);
  return instance == nullptr ? kInvalidArgument : (instance->isEncryptionEnabled() ? 1 : 0);
}

int32_t DNMMKVCheckContentChanged(DNMMKVHandle handle) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    instance->checkContentChanged();
    return kOk;
  });
}

int32_t DNMMKVClearMemoryCache(DNMMKVHandle handle) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    instance->clearMemoryCache();
    return kOk;
  });
}

int32_t DNMMKVRecrypt(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                      int32_t encryption_type) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    if (instance->isReadOnly()) return kReadOnly;
    auto key_string = toString(key, key_len);
    WipeOnExit wipe_key(key_string);
    if (key_string.empty()) {
      if (encryption_type != 0) return kInvalidArgument;
      const auto result = instance->reKey("") ? kOk : kIoError;
      return result;
    }
    if (encryption_type != 1 && encryption_type != 2) {
      return kInvalidArgument;
    }
    const size_t max_key_length = encryption_type == 2 ? 32 : 16;
    if (key_string.size() != max_key_length) {
      return kInvalidArgument;
    }
    const auto result = instance->reKey(key_string, encryption_type == 2) ? kOk : kIoError;
    return result;
  });
}

int32_t DNMMKVExists(const uint8_t* id, size_t id_len, const uint8_t* root_path,
                    size_t root_path_len) {
  return guarded([&] {
    const auto id_string = toString(id, id_len);
    const auto root_string = toString(root_path, root_path_len);
    if (!validId(id_string)) return kInvalidArgument;
    if (!validRootPath(root_string)) return kInvalidArgument;
    if (!ensureInitialized(root_string)) return kInvalidArgument;
    return NativeMMKV::checkExist(id_string, root_string.empty() ? nullptr : &root_string) ? 1 : 0;
  });
}

int32_t DNMMKVDelete(const uint8_t* id, size_t id_len, const uint8_t* root_path,
                    size_t root_path_len) {
  return guarded([&] {
    const auto id_string = toString(id, id_len);
    const auto root_string = toString(root_path, root_path_len);
    if (!validId(id_string)) return kInvalidArgument;
    if (!validRootPath(root_string)) return kInvalidArgument;
    if (!ensureInitialized(root_string)) return kInvalidArgument;
    std::lock_guard lock(g_instances_mutex);
    const auto key = instanceKey(id_string, root_string);
    if (auto found = g_instances.find(key); found != g_instances.end()) {
      if (found->second->value != nullptr) found->second->value->close();
      found->second->value = nullptr;
      g_instances.erase(found);
    }
    return NativeMMKV::removeStorage(id_string, root_string.empty() ? nullptr : &root_string) ? 1 : 0;
  });
}

int32_t DNMMKVSetDefaultRootPath(const uint8_t* path, size_t path_len) {
  return guarded([&] {
    const auto root = toString(path, path_len);
    if (root.empty() || !validRootPath(root)) return kInvalidArgument;
    NativeMMKV::initializeMMKV(root, kNativeLogNone);
    return kOk;
  });
}

const char* DNMMKVLastError(void) { return g_last_error.c_str(); }

void DNMMKVFree(void* pointer) { std::free(pointer); }

int32_t DNMMKVProfileNoop(DNMMKVHandle, const uint8_t*, size_t, const uint8_t*, size_t) {
  return kOk;
}

int32_t DNMMKVProfileValidate(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                              const uint8_t* val, size_t val_len) {
  return guarded([&] {
    auto* instance = value(handle);
    if (instance == nullptr) return kInvalidArgument;
    const auto key_view = toView(key, key_len);
    if (!validKey(key_view)) return kInvalidArgument;
    static_cast<void>(toView(val, val_len));
    return kOk;
  });
}
