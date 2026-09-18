Pod::Spec.new do |s|
  s.name = 'senzer_mmkv'
  s.version = '0.1.0'
  s.summary = 'Synchronous C++ MMKV-compatible storage for DartNative'
  s.description = 'A public, app-agnostic native key-value store with a stable C FFI ABI.'
  s.homepage = 'https://github.com/pigeonmal/senzer-dartnative'
  s.license = { :type => 'MIT', :file => '../LICENSE' }
  s.author = { 'DartNative Contributors' => 'https://github.com/pigeonmal/senzer-dartnative' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/cpp/*.h'
  # Xcode 27 SDKs used by DartNative require iOS 15 as the minimum target.
  s.platform = :ios, '15.0'
  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  # Tencent MMKVCore supplies the mmap-backed C++ engine, AES-128/AES-256
  # encryption, CRC recovery, and multi-process locking.
  s.dependency 'MMKVCore', '2.4.2'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    # The FFI bridge is on every synchronous read/write path. Keep the
    # release bridge at -O3; MMKVCore remains owned by its own pod target.
    'GCC_OPTIMIZATION_LEVEL[config=Debug]' => '3',
    'GCC_OPTIMIZATION_LEVEL[config=Release]' => '3',
    'DEFINES_MODULE' => 'YES',
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'NO',
  }
end
