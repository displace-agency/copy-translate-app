# CopyTranslate

A native macOS menu bar app that translates text instantly. Double-tap `Cmd+C` on any selected text and a floating panel shows the translation side-by-side. Powered by Claude Haiku.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![Claude Haiku](https://img.shields.io/badge/Claude-Haiku%204.5-purple)

## Features

- **Instant translation** -- double-tap `Cmd+C` to translate any selected text
- **15 languages** -- Spanish, French, Portuguese, German, Italian, Japanese, Chinese, Korean, Arabic, Russian, Dutch, Swedish, Polish, and more
- **Auto-detect source language** -- automatically translates to your target language, or to English if text is already in target language
- **Translation cache** -- repeated translations are instant (in-memory LRU cache, 200 entries)
- **Translation history** -- last 50 translations persisted across sessions
- **Floating panel** -- dark, resizable, non-activating window that appears near your cursor
- **Settings window** -- configure target language, double-tap speed, sound, launch at login
- **Menu bar controls** -- pause/resume, language picker, recent translations, diagnostics
- **Launch at login** -- native SMAppService integration
- **Universal binary** -- runs natively on both Apple Silicon and Intel Macs
- **Zero dependencies** -- pure Swift, SwiftUI + AppKit, no external packages

## Installation

### From DMG

Download the latest `.dmg` from [Releases](https://github.com/displace-agency/copy-translate-app/releases), open it, and drag CopyTranslate to Applications.

### From source

1. Add your Anthropic API key. Easiest: launch the app and paste it in
   **Settings → API Key → Save** (stored in your macOS Keychain). Alternatively,
   put it in `~/.env.local` and the app imports it into the Keychain on first run:

   ```
   ANTHROPIC_API_KEY=sk-ant-api03-...
   ```

2. Build and install:

   ```bash
   scripts/build-app.sh 0.2.0
   scripts/install.sh
   ```

3. On first launch, macOS prompts for **Accessibility** permission. Grant it so the app can detect the `Cmd+C` double-tap globally.

## Usage

1. Select text in any app
2. Press `Cmd+C` twice within 400ms
3. A floating panel appears with source text (left) and translation (right)
4. Click the copy icon or select text to copy the translation
5. Press `Esc` or `Cmd+W` to dismiss

## Configuration

Open **Settings** from the menu bar (`Cmd+,`) to configure:

| Setting | Description | Default |
|---------|-------------|---------|
| Target language | Language to translate into | Spanish |
| Double-tap speed | Time window for double-tap detection | 0.40s |
| Sound on completion | Play a sound when translation finishes | Off |
| Launch at login | Start CopyTranslate when you log in | Off |

The API key resolves in this order: macOS Keychain → `ANTHROPIC_API_KEY` environment variable → `~/.env.local` (supports `export KEY=value` and `KEY="value"` formats). Manage it in Settings → API Key.

## Architecture

```
CopyTranslateApp.swift    App entry + AppDelegate (menu bar, translation flow)
EventTap.swift            CGEventTap for global Cmd+C double-tap detection
Anthropic.swift           Claude API client with retry logic
TranslationWindow.swift   Floating NSPanel + SwiftUI view
TranslationCache.swift    In-memory LRU translation cache
TranslationHistory.swift  Persistent translation history (JSON)
SettingsView.swift        SwiftUI Settings window
Config.swift              Runtime configuration + UserDefaults preferences
```

## Building

Requires Xcode Command Line Tools and Swift 5.9+.

```bash
# Debug build
swift build

# Release build (universal binary)
scripts/build-app.sh 0.2.0

# Full release (icon + app + DMG)
scripts/release.sh 0.2.0

# Install to /Applications
scripts/install.sh
```

## Troubleshooting

**App doesn't respond to double-tap Cmd+C**
- Check that Accessibility permission is granted in System Settings > Privacy & Security > Accessibility
- The menu bar icon shows the current status; click it to see diagnostics

**"API key: missing" in menu**
- Ensure `~/.env.local` contains `ANTHROPIC_API_KEY=sk-ant-api03-...`
- The app reads this file on startup; restart after adding the key

**Menu bar icon invisible (macOS 26)**
- macOS 26 has a regression where SF Symbol template images render at zero alpha for ad-hoc signed apps
- The app draws the icon as a CoreGraphics bitmap to avoid this; if you still see issues, try re-signing

## Stack

- Swift 5.9, SwiftUI + AppKit
- macOS 13+ (Ventura and later)
- Anthropic API (Claude Haiku 4.5)
- No external dependencies

## License

[MIT](LICENSE) -- Displace Agency
