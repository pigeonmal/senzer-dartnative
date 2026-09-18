#import <Foundation/Foundation.h>

#include <cstring>

#include "cpp/mmkv_ffi.h"

/// Called by DartNative's generated registrant on iOS. The path is resolved
/// from the host application's sandbox and never contains Senzer app data.
extern "C" DNMMKV_EXPORT void DNMMKVInitializeDefaultPath(void) {
  @autoreleasepool {
    NSArray<NSString *> *directories = NSSearchPathForDirectoriesInDomains(
        NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *library = directories.firstObject;
    if (library.length == 0) return;
    NSString *path = [library stringByAppendingPathComponent:@"mmkv"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    const char *utf8 = path.UTF8String;
    if (utf8 == nullptr) return;
    DNMMKVSetDefaultRootPath(reinterpret_cast<const uint8_t *>(utf8), strlen(utf8));
  }
}
