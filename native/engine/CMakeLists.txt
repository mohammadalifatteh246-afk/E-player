cmake_minimum_required(VERSION 3.10)
project(eplayer_engine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Build a shared library
add_library(eplayer_engine SHARED src/eplayer_engine.cpp)

# Target include directories
target_include_directories(eplayer_engine PUBLIC include)

# Optional: Add ONNX Runtime dependencies here later (Phase 2B)
include(FetchContent)

# In a real production build, pre-compiled ONNX Runtime Mobile binaries for iOS/Android
# would be supplied via toolchain. For desktop/stub builds, we fetch it if not present.
set(ONNXRUNTIME_VERSION 1.17.1)

# A typical pattern for linking ONNX Runtime
# find_package(onnxruntime REQUIRED)
# target_link_libraries(eplayer_engine PUBLIC onnxruntime)

