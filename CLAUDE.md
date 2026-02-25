# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Android Minesweeper game written in MoonBit with Raylib for graphics. The game logic, rendering, and input handling are entirely in MoonBit (~950 lines in a single file), compiled to C via `moon build`, then linked with Raylib and the Android NDK into a native shared library.

## Build & Run

This is an Android Gradle project. The MoonBit compiler (`moon`) must be on PATH.

```bash
# Build debug APK (triggers MoonBit compilation + CMake native build)
./gradlew assembleDebug

# Install and run on connected device/emulator
./gradlew installDebug
adb shell am start -n com.example.raylibminesweeper/.MainActivity

# MoonBit type-check only (fast feedback loop)
cd app/src/main/moonbit && moon check --target native

# Run unit tests
./gradlew test
```

## Build Pipeline

The build has three stages orchestrated by CMake (`app/src/main/cpp/CMakeLists.txt`):

1. **MoonBit → C**: `moon build --target native` compiles `.mbt` files to a single C file (`_build/native/debug/build/raylibminesweeper.c`)
2. **Raylib static lib**: Vendored Raylib 5.5 sources compiled with `PLATFORM_ANDROID` + `GRAPHICS_API_OPENGL_ES2`
3. **Shared library**: Generated C + MoonBit runtime + C stub layer + Raylib linked into `libraylibminesweeper.so`

## Architecture

```
Android (MainActivity.kt - thin NativeActivity wrapper)
  └─ Native library (libraylibminesweeper.so)
       ├─ MoonBit game code (app/src/main/moonbit/main.mbt)
       ├─ Raylib FFI bindings (app/src/main/moonbit/external/raylib/)
       │    ├─ Public wrappers: type-safe API with Bytes serialization
       │    └─ internal/raylib/: extern "c" decls + C stub files
       └─ Raylib 5.5 (vendored C sources)
```

### Key files

- `app/src/main/moonbit/main.mbt` — All game logic: state machine (menu/playing/won/lost/about), board generation, flood-fill reveal, touch gesture handling (tap/long-press/pan/pinch-to-zoom), camera system, and rendering
- `app/src/main/moonbit/moon.mod.json` — MoonBit module config; depends on `tonyfettes/raylib` via local path
- `app/src/main/moonbit/moon.pkg` — Package config; imports `tonyfettes/raylib`, marked as main
- `app/src/main/cpp/CMakeLists.txt` — Orchestrates MoonBit→C compilation, Raylib build, and final linking
- `app/src/main/java/.../MainActivity.kt` — Android entry point; keeps screen on, hides system bars
- `app/src/main/moonbit/external/raylib/` — Git submodule with Raylib MoonBit bindings (has its own CLAUDE.md)

### FFI pattern (Raylib bindings)

MoonBit structs (Color, Vector2, Rectangle, Camera2D) are serialized to `Bytes` via `to_bytes()`, passed to C stubs that `memcpy` into native structs, call Raylib, and serialize results back. Passthrough functions (primitives only) are re-exported directly via `pub using @raylib.{ ... }`. See `external/raylib/CLAUDE.md` for binding-specific rules.

### Game state

All mutable state uses `Ref[T]` at module level. Game states: `state_menu` (0), `state_playing` (1), `state_won` (2), `state_lost` (3), `state_about` (4). Difficulty presets: Easy 12×8/10, Medium 20×12/40, Hard 30×16/99.

## MoonBit Conventions

- Use the `/moonbit-agent-guide` skill when working with MoonBit code
- Target is always `native` (no WASM)
- The raylib bindings submodule has its own FFI rules — read `external/raylib/CLAUDE.md` before modifying bindings
- Never use `self` as a parameter name in `extern "c"` declarations
- Use `#borrow(param)` annotation on extern functions taking opaque pointer types

## Git Conventions

- Use [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages (e.g. `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`, `build:`)

## Releasing

When publishing a GitHub release, always attach the release APK:

1. Build the release APK: `./gradlew assembleRelease`
2. The APK is at `app/build/outputs/apk/release/app-release-unsigned.apk`
3. Upload it to the release: `gh release upload <tag> app/build/outputs/apk/release/app-release-unsigned.apk`
