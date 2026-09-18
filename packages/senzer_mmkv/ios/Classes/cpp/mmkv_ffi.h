#pragma once

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(__GNUC__)
#define DNMMKV_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#else
#define DNMMKV_EXPORT
#endif

typedef void* DNMMKVHandle;

DNMMKV_EXPORT DNMMKVHandle DNMMKVCreate(const uint8_t* id, size_t id_len,
                                        const uint8_t* root_path, size_t root_path_len,
                                        const uint8_t* encryption_key, size_t encryption_key_len,
                                        int32_t encryption_type, int32_t mode, int32_t read_only,
                                        int32_t compare_before_set, int32_t recovery_strategy);
DNMMKV_EXPORT void DNMMKVDestroy(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVSetString(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                      const uint8_t* value, size_t value_len);
DNMMKV_EXPORT int32_t DNMMKVSetBoolean(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                       int32_t value);
DNMMKV_EXPORT int32_t DNMMKVSetNumber(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                      double value);
DNMMKV_EXPORT int32_t DNMMKVSetInt64(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                     int64_t value);
DNMMKV_EXPORT int32_t DNMMKVSetBuffer(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                      const uint8_t* value, size_t value_len);
DNMMKV_EXPORT int32_t DNMMKVGetString(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                      uint8_t** value, size_t* value_len);
DNMMKV_EXPORT int32_t DNMMKVGetBoolean(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                       int32_t* value);
DNMMKV_EXPORT int32_t DNMMKVGetNumber(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                      double* value);
DNMMKV_EXPORT int32_t DNMMKVGetInt64(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                     int64_t* value);
DNMMKV_EXPORT int32_t DNMMKVGetBuffer(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                      uint8_t** value, size_t* value_len);
DNMMKV_EXPORT int32_t DNMMKVContains(DNMMKVHandle handle, const uint8_t* key, size_t key_len);
DNMMKV_EXPORT int32_t DNMMKVGetKeyCount(DNMMKVHandle handle, size_t* count);
DNMMKV_EXPORT int32_t DNMMKVGetKeyAt(DNMMKVHandle handle, size_t index, uint8_t** key,
                                     size_t* key_len);
// Returns a packed sequence of [uint64_t byte length][UTF-8 key] records.
// The caller owns the buffer and releases it with DNMMKVFree.
DNMMKV_EXPORT int32_t DNMMKVGetAllKeys(DNMMKVHandle handle, uint8_t** output,
                                       size_t* output_len);
DNMMKV_EXPORT int32_t DNMMKVRemove(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                   int32_t* removed);
DNMMKV_EXPORT int32_t DNMMKVClearAll(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVTrim(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVImportAll(DNMMKVHandle destination, DNMMKVHandle source,
                                      size_t* imported);
DNMMKV_EXPORT uint64_t DNMMKVByteSize(DNMMKVHandle handle);
DNMMKV_EXPORT uint64_t DNMMKVLength(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVIsReadOnly(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVIsEncrypted(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVCheckContentChanged(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVClearMemoryCache(DNMMKVHandle handle);
DNMMKV_EXPORT int32_t DNMMKVRecrypt(DNMMKVHandle handle, const uint8_t* key, size_t key_len,
                                    int32_t encryption_type);
DNMMKV_EXPORT int32_t DNMMKVExists(const uint8_t* id, size_t id_len, const uint8_t* root_path,
                                   size_t root_path_len);
DNMMKV_EXPORT int32_t DNMMKVDelete(const uint8_t* id, size_t id_len, const uint8_t* root_path,
                                   size_t root_path_len);
DNMMKV_EXPORT int32_t DNMMKVSetDefaultRootPath(const uint8_t* path, size_t path_len);
DNMMKV_EXPORT const char* DNMMKVLastError(void);
DNMMKV_EXPORT void DNMMKVFree(void* pointer);

#if defined(__cplusplus)
}
#endif
