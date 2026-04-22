# CopyTranslate

Native macOS menu bar app. Double-tap `⌘C` on selected text anywhere and a
floating panel shows the translation (English ↔ Spanish, powered by Claude
Haiku). Swift rewrite of the original Hammerspoon module.

## Stack

- Swift 5.9, SwiftUI + AppKit
- macOS 13+ (built for macOS 26 Tahoe)
- Anthropic API (`claude-haiku-4-5`)
- Menu bar icon pre-rendered to bitmap, working around the macOS 26
  zero-alpha regression for ad-hoc-signed apps

## Setup

1. Put your key in `~/.env.local`:

   ```
   ANTHROPIC_API_KEY=sk-ant-api03-...
   ```

2. Build and install:

   ```bash
   scripts/build-app.sh
   scripts/install.sh
   ```

3. On first launch, macOS will prompt for Accessibility permission — grant
   it so the app can observe the `⌘C` double-tap globally. The menu also
   has an "Open Accessibility Settings…" shortcut.

## Use

1. Select text in any app.
2. Press `⌘C` twice within 400 ms.
3. A floating panel appears near the cursor with the original on the left
   and the translation on the right. Copy icon on the right side copies
   the translation. `Esc` or click the × closes it.

## Menu bar

- **Pause / Resume** — pauses the double-tap listener without quitting.
- **API key: loaded / missing** — diagnostic only.
- **Model** — current model name.
- **Open Accessibility Settings…** — system preferences deep link.
- **Quit**.
