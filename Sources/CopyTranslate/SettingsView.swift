import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var keyInput = ""
    @State private var keySource = Config.keySource()
    @State private var testResult: TestResult = .none

    enum TestResult { case none, testing, ok, failed(String) }

    var body: some View {
        Form {
            Section("Translation") {
                Picker("Target language", selection: $prefs.targetLanguage) {
                    ForEach(Config.supportedLanguages, id: \.self) { Text($0).tag($0) }
                }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in toggleLaunchAtLogin(enabled: newValue) }
                Toggle("Sound on completion", isOn: $prefs.soundEnabled)
                Toggle("Replace clipboard with translation", isOn: $prefs.replaceClipboard)
                HStack {
                    Text("Double-tap speed")
                    Slider(value: $prefs.doubleTapSpeed, in: 0.2...0.8, step: 0.05)
                    Text("\(String(format: "%.2fs", prefs.doubleTapSpeed))")
                        .font(.system(.body, design: .monospaced)).foregroundColor(.secondary).frame(width: 50)
                }
            }

            Section("API Key") {
                SecureField("Paste ANTHROPIC_API_KEY", text: $keyInput)
                HStack {
                    Button("Save") { saveKey() }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Clear") { clearKey() }
                        .disabled(Keychain.get() == nil)
                    Button("Test") { testKey() }
                        .disabled(Config.apiKey() == nil)
                    Spacer()
                    statusLabel
                }
                LabeledContent("Model") {
                    Text(Config.model).font(.system(.body, design: .monospaced)).foregroundColor(.secondary)
                }
                if keySource == .envFile || keySource == .environment {
                    Text("Using a key from \(keySource == .envFile ? "~/.env.local" : "the environment"). Save it here to store it securely in your Keychain.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Section {
                Button("Clear Translation History") { TranslationHistory.shared.clear() }
            }

            Section {
                HStack {
                    Text("CopyTranslate v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 520)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch testResult {
        case .testing:
            HStack(spacing: 4) { ProgressView().controlSize(.small); Text("Testing…").foregroundColor(.secondary) }
        case .ok:
            Label("Key works", systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .failed(let msg):
            Label(msg, systemImage: "xmark.circle.fill").foregroundColor(.red).lineLimit(1)
        case .none:
            switch keySource {
            case .keychain: Label("Saved in Keychain", systemImage: "key.fill").foregroundColor(.green)
            case .environment: Label("From environment", systemImage: "terminal").foregroundColor(.orange)
            case .envFile: Label("From ~/.env.local", systemImage: "doc").foregroundColor(.orange)
            case .none: Label("No key set", systemImage: "exclamationmark.triangle").foregroundColor(.red)
            }
        }
    }

    private func saveKey() {
        let value = keyInput.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        if Keychain.set(value) {
            keyInput = ""
            testResult = .none
            keySource = Config.keySource()
        }
    }

    private func clearKey() {
        Keychain.delete()
        testResult = .none
        keySource = Config.keySource()
    }

    private func testKey() {
        testResult = .testing
        Task {
            do {
                try await Anthropic.streamTranslate("hello", target: "Spanish") { _ in }
                await MainActor.run { testResult = .ok }
            } catch {
                let msg = (error as? AnthropicError)?.errorDescription ?? "Failed"
                await MainActor.run { testResult = .failed(msg) }
            }
        }
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
