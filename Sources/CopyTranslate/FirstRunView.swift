import SwiftUI
import AppKit

/// One-time welcome shown on first launch: explains the single Accessibility
/// grant and lets the user paste their API key (stored in the Keychain).
struct FirstRunView: View {
    var onDone: () -> Void
    @State private var keyInput = ""
    @State private var keySaved = Config.keySource() != .none

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to CopyTranslate").font(.title2).bold()
            Text("Double-tap ⌘C on any selected text to translate it instantly.")
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Grant Accessibility — one time", systemImage: "1.circle.fill").font(.headline)
                    Text("CopyTranslate listens for the ⌘C double-tap, which macOS gates behind Accessibility. You grant this once; it sticks across updates.")
                        .font(.caption).foregroundColor(.secondary)
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Add your Anthropic API key", systemImage: "2.circle.fill").font(.headline)
                    if keySaved {
                        Label("Key saved to Keychain", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green).font(.caption)
                    } else {
                        HStack {
                            SecureField("sk-ant-…", text: $keyInput)
                            Button("Save") {
                                let v = keyInput.trimmingCharacters(in: .whitespaces)
                                if !v.isEmpty, Keychain.set(v) { keySaved = true; keyInput = "" }
                            }
                            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }

            HStack {
                Spacer()
                Button("Start Translating") { onDone() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
