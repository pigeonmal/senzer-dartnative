#include <jni.h>

#include "mmkv_ffi.h"

extern "C" JNIEXPORT void JNICALL
Java_com_senzer_mmkv_SenzerMmkvBridge_nativeSetDefaultRootPath(
    JNIEnv* env, jclass, jstring path) noexcept {
  if (env == nullptr || path == nullptr) return;
  const char* chars = env->GetStringUTFChars(path, nullptr);
  if (chars == nullptr) return;
  const auto length = static_cast<size_t>(env->GetStringUTFLength(path));
  DNMMKVSetDefaultRootPath(reinterpret_cast<const uint8_t*>(chars), length);
  env->ReleaseStringUTFChars(path, chars);
}

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  JNIEnv* env = nullptr;
  if (vm == nullptr || vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}
