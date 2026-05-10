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
        backgroundColor = NSColor(white: 0.08, alpha: 1)
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
            ctx.duration = 0.15
            animator().alphaValue = 1
        }
    }

    private func centerNearMouse() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { center(); return }
        let size = frame.size
        var origin = NSPoint(
            x: mouse.x - size.width / 2,
            y: mouse.y - size.height - 20
        )
        // Clamp to screen bounds.
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
    var onRetry: (() -> Void)?
    private var timer: Timer?

    init(source: String) {
        self.source = source
        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.elapsed = Date().timeIntervalSince(start)
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }
}

struct TranslationView: View {
    @ObservedObject var state: TranslationState
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            HStack(spacing: 0) {
                column(title: "Source", body: state.source, isLoading: false, isSource: true)
                Divider().background(Color.white.opacity(0.08))
                column(
                    title: "Translation",
                    body: state.translation,
                    isLoading: state.isLoading,
                    isSource: false
                )
            }
        }
        .frame(minWidth: 500, minHeight: 200)
        .frame(idealWidth: Config.popupSize.width, idealHeight: Config.popupSize.height)
        .background(Color(white: 0.08))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("CopyTranslate")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.8)
                .textCase(.uppercase)
            Text("→ \(Config.targetLanguage)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
            Spacer()
            if let err = state.errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.85))
                    .lineLimit(3)
                if state.onRetry != nil {
                    Button("Retry") { state.onRetry?() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue.opacity(0.85))
                }
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            Button("") { onClose() }
                .keyboardShortcut("w", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func column(title: String, body: String, isLoading: Bool, isSource: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)
                    .textCase(.uppercase)
                if !isSource && state.isCached {
                    Text("cached")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.green.opacity(0.3)))
                }
                Spacer()
                if !isSource && !body.isEmpty {
                    Button(action: { copyToPasteboard(body) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Copy translation")
                }
            }
            ScrollView {
                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Translating... \(String(format: "%.1fs", state.elapsed))")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.92))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if isSource {
                Text("\(body.count) chars")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
