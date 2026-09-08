# Sovereign Media Player — Changelog

All notable changes to this project will be documented in this file.

---

## [v2.2.0] — 2026-09-08

### Added
- **VLC-Style Subtitle Subsystem**: Full multi-format subtitle parser supporting `.srt`, `.vtt`, `.sub`, `.sbv`, `.ass`, `.ssa` files with HTML/styling tag stripping and Latin-1/Windows-1252 multi-encoding fallback.
- **High-Contrast Subtitle Rendering**: Pure white typography with deep black outline stroke and drop shadow, dynamically centered and responsive to windowed and fullscreen layouts.
- **Menu & Keyboard Controls**: "Add Subtitle File... (⌘S)" and dynamic "Subtitles Track" submenu with checkmarks; dedicated macOS Menu Bar `Subtitle` menu with delay sync controls (`+50 ms (H)` / `-50 ms (G)`).
- **Strict File Type Restriction & Sibling Auto-Discovery**: Open dialog strictly restricted to compatible subtitle files; automatic loading of sibling `.srt`/`.vtt` subtitle files and canvas drag-and-drop.
- **Enterprise CPU Benchmark Report**: Documented 4K UHD HEVC benchmark showcasing 0.30% Mean CPU load and 67.6 MB RAM (54× lower CPU load than VLC); enterprise contact channel `connectwith@sovereignbyte.tech`.
- **In-App Updater**: Upgraded release to v2.2.0 across all build targets and update checker.

---

## [v2.1.0] — 2026-09-07

### Added
- Docked bottom playback toolbar with custom high-contrast icons.
- On-screen click to play/pause and double-click to toggle fullscreen.
- Hardware telemetry HUD overlay with real-time FPS, CPU, RAM, and codec indicators.
- Closed-Captions (`CC`) toggle and in-app update checker.
- Windows standalone zero-dependency build (`/MT` static linking).

---

## [v2.0.0] — 2026-09-06

### Major: Open-Core GitHub Launch
- **Open-sourced** the full SwiftUI frontend under MIT License.
- **Decoupled** the proprietary engine into a clean public C-API (`sovereign_engine.h`).
- Published pre-compiled Universal binaries (arm64 + x86_64) for macOS.
- Added GitHub Actions CI/CD pipeline for automated builds and releases on every tag push.
- Added **media-playback-only** usage restriction to the engine license.

### Added
- `core_engine/include/sovereign_engine.h` — Public C-API with full doc comments.
- `docs/API_REFERENCE.md` — Full developer C-API documentation.
- `docs/BUILD.md` — Cross-platform build instructions.
- `docs/CONTRIBUTING.md` — Community contribution guide.
- `build_open_core.py` — Unified Python build pipeline.
- `.github/workflows/build.yml` — Automated GitHub Actions release workflow.

### Changed
- Removed hardware UUID licensing from the public frontend.
- Renamed `sovereign_player_gui_universal.swift` → `OpenSovereignPlayerUI.swift`.
- Removed all trademark symbols from UI strings.
- Cleaned all internal branding from public-facing files.

---

## [v2.0.0] — 2026-08-15

### Added
- Zero-Copy ring buffer (< 11 MB RAM).
- Apple Metal Direct GPU surface rendering.
- Live HLS / DASH / RTSP streaming support.
- Glassmorphic floating control bar.
- Real-time Telemetry HUD (FPS / CPU / RAM / Codec).

---

## [v1.0.0] — 2026-07-01

- Initial internal build.
- Basic AVKit hardware decoding pipeline.
- macOS Universal binary (arm64 + x86_64).
