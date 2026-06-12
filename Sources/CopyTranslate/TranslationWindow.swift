import AppKit
import SwiftUI

/// Floating panel showing source text on the left, translation on the right.
/// Recreated per request; kept as a weak reference from AppDelegate so a
/// second double-tap replaces rather than stacks windows.
final class TranslationWindow: NSPanel {
    init() {
        let size = Config.popupSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = CT.Palette.bgNS
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    func present(state: TranslationState) {
        let view = TranslationView(state: state, onClose: { [weak self] in self?.close() })
        contentViewController = NSHostingController(rootView: view)
        centerNearMouse()
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = CT.Motion.reduce ? 0 : 0.15
            animator().alphaValue = 1
        }
    }

    private func centerNearMouse() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { center(); return }
        let size = frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 20)
        let visible = screen.visibleFrame
        origin.x = max(visible.minX + 10, min(origin.x, visible.maxX - size.width - 10))
        origin.y = max(visible.minY + 10, min(origin.y, visible.maxY - size.height - 10))
        setFrameOrigin(origin)
    }
}

final class TranslationState: ObservableObject {
    @Published var source: String
    @Published var translation: String = ""
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var isCached: Bool = false
    @Published var elapsed: TimeInterval = 0
    @Published var target: String
    var showSettingsAction: Bool = false
    var onRetry: (() -> Void)?
    var onChangeLanguage: ((String) -> Void)?
    var onOpenSettings: (() -> Void)?
    private var timer: Timer?

    init(source: String, target: String) {
        self.source = source
        self.target = target
        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsed = Date().timeIntervalSince(start)
        }
    }

    func stopTimer() { timer?.invalidate(); timer = nil }
    deinit { timer?.invalidate() }
}

struct TranslationView: View {
    @ObservedObject var state: TranslationState
    var onClose: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(CT.Palette.hairline)
            HStack(spacing: 0) {
                column(title: "Source", body: state.source, isSource: true)
                Divider().background(CT.Palette.hairline)
                translationColumn
            }
        }
        .frame(minWidth: 500, minHeight: 200)
        .frame(idealWidth: Config.popupSize.width, idealHeight: Config.popupSize.height)
        .background(CT.Palette.bg)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: CT.Spacing.s) {
            Text("CopyTranslate")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(CT.Palette.textSecondary)
                .tracking(1.8).textCase(.uppercase)

            languagePicker

            Spacer()

            if let err = state.errorMessage {
                Text(err)
                    .font(.system(size: 11)).foregroundColor(.red.opacity(0.85)).lineLimit(2)
                if state.showSettingsAction {
                    Button("Settings") { state.onOpenSettings?() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                        .foregroundColor(CT.Palette.accent)
                } else if state.onRetry != nil {
                    Button("Retry") { state.onRetry?() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                        .foregroundColor(CT.Palette.accent)
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                    .foregroundColor(CT.Palette.textSecondary).frame(width: 20, height: 20)
            }
            .buttonStyle(.plain).keyboardShortcut(.escape, modifiers: []).accessibilityLabel("Close")

            Button("") { onClose() }.keyboardShortcut("w", modifiers: .command).frame(width: 0, height: 0).opacity(0)
        }
        .padding(.horizontal, CT.Spacing.l).padding(.vertical, 10)
    }

    private var languagePicker: some View {
        Picker("", selection: Binding(
            get: { state.target },
            set: { newLang in if newLang != state.target { state.onChangeLanguage?(newLang) } }
        )) {
            ForEach(Config.supportedLanguages, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden().pickerStyle(.menu).fixedSize()
        .font(.system(size: 10, design: .monospaced))
        .accessibilityLabel("Target language")
    }

    // MARK: - Columns

    private func column(title: String, body: String, isSource: Bool) -> some View {
        VStack(alignment: .leading, spacing: CT.Spacing.s) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(CT.Palette.textSecondary).tracking(1.2).textCase(.uppercase)
                Spacer()
            }
            ScrollView {
                Text(body)
                    .font(.system(size: 13)).foregroundColor(CT.Palette.textPrimary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            if isSource {
                Text("\(body.count) chars")
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(CT.Palette.textDim)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(CT.Spacing.l).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var translationColumn: some View {
        VStack(alignment: .leading, spacing: CT.Spacing.s) {
            HStack(spacing: CT.Spacing.s) {
                Text("Translation")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(CT.Palette.textSecondary).tracking(1.2).textCase(.uppercase)
                if state.isCached { cachedBadge }
                Spacer()
                if !state.translation.isEmpty {
                    Button(action: copyTranslation) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(copied ? CT.Palette.success : CT.Palette.textSecondary)
                    }
                    .buttonStyle(.plain).help("Copy translation").accessibilityLabel("Copy translation")
                }
            }
            ScrollView {
                if state.translation.isEmpty && state.isLoading {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Translating… \(String(format: "%.1fs", state.elapsed))")
                            .font(.system(size: 12)).foregroundColor(CT.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    (Text(state.translation) + Text(state.isLoading ? " ▍" : "").foregroundColor(CT.Palette.accent))
                        .font(.system(size: 13)).foregroundColor(CT.Palette.textPrimary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(CT.Spacing.l).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var cachedBadge: some View {
        Text("cached")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(CT.Palette.success.opacity(0.8))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: CT.Radius.s).stroke(CT.Palette.success.opacity(0.3)))
    }

    private func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.translation, forType: .string)
        withAnimation(CT.Motion.quick) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(CT.Motion.quick) { copied = false }
        }
    }
}
