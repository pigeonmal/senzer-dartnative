package com.senzer.mmkv

import android.content.Context
import java.io.File
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Engine-scoped entry point for the pure FFI plugin.
 *
 * Loading the library from the JVM side guarantees JNI_OnLoad runs before Dart
 * opens the FFI symbols. The bridge stores only application-owned path data.
 */
class SenzerMmkvPlugin : FlutterPlugin {
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    SenzerMmkvBridge.initialize(binding.applicationContext)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    SenzerMmkvBridge.detach()
  }
}

internal object SenzerMmkvBridge {
  @Volatile private var applicationContext: Context? = null

  @JvmStatic
  external fun nativeSetDefaultRootPath(path: String)

  @JvmStatic
  fun initialize(context: Context) {
    System.loadLibrary("senzer_mmkv")
    applicationContext = context.applicationContext
    val directory = File(context.applicationContext.filesDir, "mmkv")
    if (!directory.exists()) directory.mkdirs()
    nativeSetDefaultRootPath(directory.absolutePath)
  }

  @JvmStatic
  fun detach() {
    applicationContext = null
  }
}
