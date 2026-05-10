import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Translation") {
                Picker("Target language", selection: $prefs.targetLanguage) {
                    ForEach(Config.supportedLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                Toggle("Sound on completion", isOn: $prefs.soundEnabled)
                HStack {
                    Text("Double-tap speed")
                    Slider(value: $prefs.doubleTapSpeed, in: 0.2...0.8, step: 0.05)
                    Text("\(String(format: "%.2fs", prefs.doubleTapSpeed))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
            }

            Section("API") {
                let hasKey = Config.apiKey() != nil
                LabeledContent("Status") {
                    Text(hasKey ? "Key loaded" : "Missing")
                        .foregroundColor(hasKey ? .green : .red)
                }
                LabeledContent("Key file") {
                    Text("~/.env.local")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                LabeledContent("Model") {
                    Text(Config.model)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Clear Translation History") {
                    TranslationHistory.shared.clear()
                }
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
        .frame(width: 420, height: 460)
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
