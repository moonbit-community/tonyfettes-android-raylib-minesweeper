cmake_minimum_required(VERSION 3.22.1)

project("raylibminesweeper" C CXX)

set(RAYLIB_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/raylib/src)
set(NATIVE_APP_GLUE_DIR ${ANDROID_NDK}/sources/android/native_app_glue)

# Build raylib as a static library from source
add_library(raylib STATIC
    ${RAYLIB_SRC_DIR}/rcore.c
    ${RAYLIB_SRC_DIR}/rshapes.c
    ${RAYLIB_SRC_DIR}/rtextures.c
    ${RAYLIB_SRC_DIR}/rtext.c
    ${RAYLIB_SRC_DIR}/rmodels.c
    ${RAYLIB_SRC_DIR}/raudio.c
)

target_include_directories(raylib PUBLIC
    ${RAYLIB_SRC_DIR}
    ${RAYLIB_SRC_DIR}/external/glfw/include
)

target_include_directories(raylib PRIVATE
    ${NATIVE_APP_GLUE_DIR}
)

target_compile_definitions(raylib PUBLIC
    PLATFORM_ANDROID
    GRAPHICS_API_OPENGL_ES2
    _DEFAULT_SOURCE
)

target_compile_options(raylib PRIVATE
    -std=c99
    -ffunction-sections
    -fdata-sections
    -fPIC
)

# Build the game shared library
add_library(raylibminesweeper SHARED
    main.cpp
    Minesweeper.cpp
    ${NATIVE_APP_GLUE_DIR}/android_native_app_glue.c
)

target_include_directories(raylibminesweeper PRIVATE
    ${NATIVE_APP_GLUE_DIR}
)

target_compile_definitions(raylibminesweeper PUBLIC
    PLATFORM_ANDROID
)

# Ensure android_native_app_glue.c sees ANativeActivity_onCreate
target_compile_definitions(raylibminesweeper PRIVATE
    NOMINMAX
)

# Force the linker to keep ANativeActivity_onCreate (called by Android framework, not by code)
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -u ANativeActivity_onCreate")

target_link_libraries(raylibminesweeper
    raylib
    android
    log
    EGL
    GLESv2
    OpenSLES
    atomic
    m
)
