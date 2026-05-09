import AppKit
import SwiftUI
import Combine
import ServiceManagement

@main
struct CopyTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: EventTap!
    private var currentWindow: TranslationWindow?
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
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true,
        ]
        AXIsProcessTrustedWithOptions(options)
    }
}

private func isAccessibilityGranted() -> Bool {
    AXIsProcessTrusted()
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

        // Tiny delay lets macOS complete the second ⌘C's copy before we read
        // the pasteboard. 90ms is comfortably fast for the user and reliable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            guard let self else { return }
            let raw = NSPasteboard.general.string(forType: .string) ?? ""
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            NSLog("[CopyTranslate] pasteboard len=%d, trimmed len=%d", raw.count, trimmed.count)
            guard !trimmed.isEmpty else { return }
            self.startTranslation(for: trimmed)
        }
    }

    private func startTranslation(for text: String) {
        currentWindow?.close()
        let window = TranslationWindow()
        let state = TranslationState(source: text)
        window.present(state: state)
        currentWindow = window

        Task {
            do {
                let result = try await Anthropic.translate(text)
                await MainActor.run {
                    state.translation = result
                    state.isLoading = false
                }
            } catch {
                await MainActor.run {
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

    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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

    /// Pre-renders an SF Symbol into a non-template bitmap NSImage tinted
    /// with the given color. Works around the macOS 26 regression where
    /// NSStatusBarButton draws template images at zero alpha for
    /// ad-hoc-signed apps, making the menu bar icon invisible.
    private static func renderBarIcon(symbol: String, color: NSColor) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let source = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
            ?? NSImage(size: NSSize(width: 18, height: 18))
        let size = source.size
        let image = NSImage(size: size)
        image.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: size)
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        rect.fill(using: .sourceIn)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
