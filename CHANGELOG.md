# Changelog

## [0.2.0] - 2026-05-09

### Added
- 15-language support with configurable target language
- Translation cache (in-memory LRU, 200 entries)
- Translation history (persistent, last 50 translations)
- Settings window (target language, double-tap speed, sound, launch at login)
- Target language picker in menu bar
- Recent Translations submenu in menu bar
- Retry button on translation errors
- API retry logic (2 retries with backoff for 5xx/timeout)
- Elapsed time display during translation
- Fade-in animation on translation panel
- Resizable translation window
- Cmd+W keyboard shortcut to dismiss panel
- Character count on source text
- Cached translation indicator
- Sound on completion (optional)
- Long text guard (10,000 char limit)
- In-flight translation cancellation
- DMG distribution script
- Release script (icon + build + DMG)

### Fixed
- Cancel previous translation when starting a new one
- isAccessibilityGranted moved from free function to AppDelegate method

### Changed
- Dynamic translation prompt based on selected target language
- Error display expanded from 1 to 3 lines
- Build script no longer double-builds to find binary path
- Info.plist includes CFBundleIconFile

## [0.1.0] - 2026-04-22

### Added
- Initial release
- Double-tap Cmd+C to translate
- English/Spanish translation via Claude Haiku 4.5
- Floating dark panel with side-by-side view
- Menu bar icon with pause/resume
- Accessibility permission detection and polling
- Launch at login via SMAppService
- Universal binary (arm64 + x86_64)
- macOS 26 icon rendering workaround
