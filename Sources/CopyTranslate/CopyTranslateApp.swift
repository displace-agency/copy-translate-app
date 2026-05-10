import AppKit
import SwiftUI
import Combine
import ServiceManagement

@main
struct CopyTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: EventTap!
    private var currentWindow: TranslationWindow?
    private var translationTask: Task<Void, Never>?
    private let prefs = Preferences.shared
    private var cancellables = Set<AnyCancellable>()

    private var accessibilityPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        statusItem.autosaveName = "agency.displace.CopyTranslate.status"
        if let button = statusItem.button {
            button.image = Self.renderBarIcon(symbol: "character.bubble", color: .white)
            button.imagePosition = .imageOnly
            button.title = ""
            button.target = self
            button.action = #selector(showMenu(_:))
        }

        installEventTap()
        ensureAccessibilityPermission()

        // Re-install the event tap as soon as the user grants Accessibility,
        // without requiring a restart. The tap cannot be created before the
        // TCC grant lands, so poll every 2s until we've hooked it once.
        accessibilityPoll = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.retryEventTapIfNeeded()
            if self.eventTap != nil {
                self.accessibilityPoll?.invalidate()
                self.accessibilityPoll = nil
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.retryEventTapIfNeeded() }

        // Re-render icon when paused state changes.
        prefs.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] paused in self?.refreshIcon(paused: paused) }
            .store(in: &cancellables)
    }

    private func retryEventTapIfNeeded() {
        guard eventTap == nil, isAccessibilityGranted() else { return }
        installEventTap()
    }

    private func installEventTap() {
        let tap = EventTap(window: Config.doubleTapWindow) { [weak self] in
            self?.handleDoubleTap()
        }
        if tap.start() {
            eventTap = tap
        } else {
            eventTap = nil
        }
    }

    private func ensureAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true,
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    private func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
}

extension AppDelegate {

    private func refreshIcon(paused: Bool) {
        statusItem.button?.image = Self.renderBarIcon(
            symbol: paused ? "character.bubble.slash" : "character.bubble",
            color: paused ? .systemOrange : .white
        )
    }

    // MARK: - Double-tap -> translate

    private func handleDoubleTap() {
        guard !prefs.isPaused else {
            NSLog("[CopyTranslate] paused, ignoring double-tap")
            return
        }

        let countBefore = NSPasteboard.general.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            guard let self else { return }
            let countAfter = NSPasteboard.general.changeCount
            if countAfter == countBefore {
                NSLog("[CopyTranslate] pasteboard unchanged after double-tap")
            }
            let raw = NSPasteboard.general.string(forType: .string) ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            NSLog("[CopyTranslate] pasteboard len=%d, trimmed len=%d", raw.count, trimmed.count)
            guard !trimmed.isEmpty else { return }
            if trimmed.count > 10_000 {
                self.showTranslationError(
                    source: String(trimmed.prefix(200)) + "...",
                    message: "Text too long (\(trimmed.count) chars). Max 10,000."
                )
                return
            }
            self.startTranslation(for: trimmed)
        }
    }

    private func showTranslationError(source: String, message: String) {
        currentWindow?.close()
        let window = TranslationWindow()
        let state = TranslationState(source: source)
        state.stopTimer()
        state.errorMessage = message
        state.isLoading = false
        window.present(state: state)
        currentWindow = window
    }

    private func startTranslation(for text: String) {
        translationTask?.cancel()
        currentWindow?.close()
        let window = TranslationWindow()
        let state = TranslationState(source: text)
        state.onRetry = { [weak self] in self?.startTranslation(for: text) }
        window.present(state: state)
        currentWindow = window

        let lang = Config.targetLanguage
        if let cached = TranslationCache.shared.lookup(source: text, targetLanguage: lang) {
            state.translation = cached
            state.isLoading = false
            state.isCached = true
            state.stopTimer()
            return
        }

        translationTask = Task {
            do {
                let result = try await Anthropic.translate(text)
                guard !Task.isCancelled else { return }
                TranslationCache.shared.store(source: text, targetLanguage: lang, translation: result)
                await MainActor.run {
                    TranslationHistory.shared.add(source: text, translation: result, targetLanguage: lang)
                    state.stopTimer()
                    state.translation = result
                    state.isLoading = false
                    if self.prefs.soundEnabled {
                        NSSound(named: "Pop")?.play()
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state.stopTimer()
                    state.errorMessage = error.localizedDescription
                    state.isLoading = false
                }
            }
        }
    }

    // MARK: - Menu

    @objc private func showMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let pause = NSMenuItem(
            title: prefs.isPaused ? "Resume" : "Pause",
            action: #selector(togglePause), keyEquivalent: "p"
        )
        pause.target = self
        menu.addItem(pause)

        menu.addItem(.separator())

        let axGranted = isAccessibilityGranted()
        let axItem = NSMenuItem(
            title: axGranted ? "Accessibility: granted" : "Accessibility: MISSING — grant to enable ⌘C detection",
            action: axGranted ? nil : #selector(openAccessibility), keyEquivalent: ""
        )
        axItem.target = self
        axItem.isEnabled = !axGranted
        menu.addItem(axItem)

        let keyItem = NSMenuItem(
            title: Config.apiKey() == nil ? "API key: missing" : "API key: loaded",
            action: nil, keyEquivalent: ""
        )
        keyItem.isEnabled = false
        menu.addItem(keyItem)

        let modelItem = NSMenuItem(title: "Model: \(Config.model)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        menu.addItem(.separator())

        let langMenu = NSMenu()
        for lang in Config.supportedLanguages {
            let item = NSMenuItem(title: lang, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.state = lang == Config.targetLanguage ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "Target: \(Config.targetLanguage)", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        let history = TranslationHistory.shared.records
        if !history.isEmpty {
            let histMenu = NSMenu()
            for record in history.prefix(5) {
                let preview = record.source.prefix(30) + (record.source.count > 30 ? "..." : "")
                let item = NSMenuItem(title: "\(preview) → \(record.targetLanguage)", action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = record.translation
                histMenu.addItem(item)
            }
            histMenu.addItem(.separator())
            let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            clearItem.target = self
            histMenu.addItem(clearItem)
            let histItem = NSMenuItem(title: "Recent Translations", action: nil, keyEquivalent: "")
            histItem.submenu = histMenu
            menu.addItem(histItem)
        }

        menu.addItem(.separator())

        let launch = NSMenuItem(
            title: "Launch at login",
            action: #selector(toggleLaunchAtLogin), keyEquivalent: ""
        )
        launch.target = self
        launch.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launch)

        let accessibility = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibility), keyEquivalent: ""
        )
        accessibility.target = self
        menu.addItem(accessibility)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings), keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit CopyTranslate",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))

        statusItem.menu = menu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePause() { prefs.isPaused.toggle() }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        prefs.targetLanguage = sender.title
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let translation = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translation, forType: .string)
    }

    @objc private func clearHistory() {
        TranslationHistory.shared.clear()
    }

    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Launch at Login

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Status icon rendering (macOS 26 safe)

    /// Renders a menu bar icon as a hand-drawn bitmap. SF Symbols +
    /// ad-hoc codesign on macOS 26 produces invisible status items,
    /// so we draw the glyph ourselves at 2x into a fixed 18x18 point image.
    private static func renderBarIcon(symbol: String, color: NSColor) -> NSImage {
        let ptSize = NSSize(width: 18, height: 18)
        let pxScale: CGFloat = 2
        let pxW = Int(ptSize.width * pxScale)
        let pxH = Int(ptSize.height * pxScale)

        guard let ctx = CGContext(
            data: nil, width: pxW, height: pxH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            let fallback = NSImage(size: ptSize)
            fallback.isTemplate = false
            return fallback
        }
        ctx.scaleBy(x: pxScale, y: pxScale)

        let c = color.cgColor
        ctx.setFillColor(c)
        ctx.setStrokeColor(c)
        ctx.setLineWidth(1.2)

        let paused = symbol.contains("slash")

        // Speech bubble body
        let bubbleRect = CGRect(x: 3, y: 5, width: 12, height: 8)
        let bubblePath = CGMutablePath()
        bubblePath.addRoundedRect(in: bubbleRect, cornerWidth: 2.5, cornerHeight: 2.5)
        ctx.addPath(bubblePath)
        ctx.strokePath()

        // Tail
        ctx.move(to: CGPoint(x: 6, y: 5))
        ctx.addLine(to: CGPoint(x: 4, y: 2))
        ctx.addLine(to: CGPoint(x: 9, y: 5))
        ctx.strokePath()

        // "T" letter inside bubble
        let midX: CGFloat = 9
        let topY: CGFloat = 11.5
        ctx.setLineWidth(1.3)
        ctx.move(to: CGPoint(x: midX - 3, y: topY))
        ctx.addLine(to: CGPoint(x: midX + 3, y: topY))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: midX, y: topY))
        ctx.addLine(to: CGPoint(x: midX, y: topY - 4.5))
        ctx.strokePath()

        // Slash when paused
        if paused {
            ctx.setLineWidth(1.6)
            ctx.move(to: CGPoint(x: 2, y: 2))
            ctx.addLine(to: CGPoint(x: 16, y: 16))
            ctx.strokePath()
        }

        guard let cgImage = ctx.makeImage() else {
            let fallback = NSImage(size: ptSize)
            fallback.isTemplate = false
            return fallback
        }
        let image = NSImage(cgImage: cgImage, size: ptSize)
        image.isTemplate = false
        return image
    }
}
