# Changelog

## [0.3.0] - 2026-06-12

### Added
- **Streaming translations** — results appear live token-by-token instead of after the full response
- **API key in the Keychain** with in-app entry (Settings → API Key: paste, Save, Clear, Test). Key resolves Keychain → `ANTHROPIC_API_KEY` env → `~/.env.local`, and is auto-imported into the Keychain on first launch
- **Searchable history window** (⌘Y) — search, re-open, copy, or delete past translations; retention raised to 200
- **On-the-fly target language** — switch the language from the result window header to re-translate without changing your default
- **Friendly errors** — invalid key / offline / service errors show a clear message (with a Settings shortcut for key problems) instead of a raw HTTP body
- "Replace clipboard with translation" preference
- `CopyTranslateCore` library with unit tests (env parsing, prompt building, cache keys, double-tap timing, SSE parsing)
- New app icon (A ↔ 文 translation motif)

### Fixed
- **Double-tap speed slider is now actually wired to the event tap** — previously it was saved but ignored
- Result-window styling unified behind a design-token system

### Changed
- Single streaming request replaces the previous non-streaming call + retry loop
- QR-free; menu "Recent Translations" submenu replaced by the History window

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
