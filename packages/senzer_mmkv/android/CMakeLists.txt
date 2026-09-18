cmake_minimum_required(VERSION 3.22.1)
project(senzer_mmkv LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(senzer_mmkv_ffi OBJECT
  ../ios/Classes/cpp/mmkv_ffi.cpp
)

add_library(senzer_mmkv_jni OBJECT
  src/main/cpp/mmkv_jni.cpp
)

add_library(senzer_mmkv SHARED
  $<TARGET_OBJECTS:senzer_mmkv_ffi>
  $<TARGET_OBJECTS:senzer_mmkv_jni>
)

target_include_directories(senzer_mmkv_ffi PRIVATE
  ../ios/Classes/cpp
  src/main/cpp
)

target_include_directories(senzer_mmkv_jni PRIVATE
  ../ios/Classes/cpp
  src/main/cpp
)

find_package(mmkv REQUIRED CONFIG)

set(senzer_mmkv_common_compile_options
  -Wall
  -Wextra
  -Wpedantic
  -fvisibility=hidden
  -ffunction-sections
  -fdata-sections
  $<$<CONFIG:Debug>:-O1;-g>
  $<$<CONFIG:Release>:-O3;-DNDEBUG;-fno-math-errno>
)

# The FFI layer translates C++ exceptions into status codes, so it must keep
# exception support. The JNI loader is a tiny no-throw bridge; compiling only
# that object without exception/RTTI metadata avoids pulling the C++ exception
# runtime into the bridge path.
target_compile_options(senzer_mmkv_ffi PRIVATE
  ${senzer_mmkv_common_compile_options}
  -fexceptions
  -frtti
)

target_compile_options(senzer_mmkv_jni PRIVATE
  ${senzer_mmkv_common_compile_options}
  -fno-exceptions
  -fno-rtti
)

target_link_options(senzer_mmkv PRIVATE -Wl,--gc-sections)

find_library(log-lib log)
target_link_libraries(senzer_mmkv_ffi PRIVATE mmkv::mmkv)
target_link_libraries(senzer_mmkv PRIVATE ${log-lib} mmkv::mmkv)
