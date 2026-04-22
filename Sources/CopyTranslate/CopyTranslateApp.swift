import AppKit
import SwiftUI
import Combine

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

        // Re-render icon when paused state changes.
        prefs.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] paused in self?.refreshIcon(paused: paused) }
            .store(in: &cancellables)
    }

    private func installEventTap() {
        eventTap = EventTap(window: Config.doubleTapWindow) { [weak self] in
            self?.handleDoubleTap()
        }
        _ = eventTap.start()
    }

    private func ensureAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true,
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    private func refreshIcon(paused: Bool) {
        statusItem.button?.image = Self.renderBarIcon(
            symbol: paused ? "character.bubble.slash" : "character.bubble",
            color: paused ? .systemOrange : .white
        )
    }

    // MARK: - Double-tap -> translate

    private func handleDoubleTap() {
        guard !prefs.isPaused else { return }

        // Tiny delay lets macOS complete the second ⌘C's copy before we read
        // the pasteboard. 90ms is comfortably fast for the user and reliable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            guard let self else { return }
            guard let text = NSPasteboard.general.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.startTranslation(for: text)
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
