cmake_minimum_required(VERSION 3.22.1)
project(senzer_mmkv LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(senzer_mmkv SHARED
  ../ios/Classes/cpp/mmkv_ffi.cpp
  src/main/cpp/mmkv_jni.cpp
)

target_include_directories(senzer_mmkv PRIVATE
  ../ios/Classes/cpp
  src/main/cpp
)

find_package(mmkv REQUIRED CONFIG)

target_compile_options(senzer_mmkv PRIVATE
  -Wall
  -Wextra
  -Wpedantic
  -fvisibility=hidden
  -ffunction-sections
  -fdata-sections
  $<$<CONFIG:Debug>:-O1;-g>
  $<$<CONFIG:Release>:-O3;-DNDEBUG;-fno-math-errno>
)
target_link_options(senzer_mmkv PRIVATE -Wl,--gc-sections)

find_library(log-lib log)
target_link_libraries(senzer_mmkv PRIVATE ${log-lib} mmkv::mmkv)
