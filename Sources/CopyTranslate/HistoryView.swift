import SwiftUI
import AppKit

/// Searchable translation history. Click a row to re-open it in the result
/// panel; right-click to copy or delete.
struct HistoryView: View {
    @ObservedObject private var history = TranslationHistory.shared
    @State private var query = ""
    var onReopen: (TranslationRecord) -> Void
    var onClose: () -> Void

    private var filtered: [TranslationRecord] { history.search(query) }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().background(CT.Palette.hairline)
            if filtered.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { record in
                            row(record)
                            Divider().background(CT.Palette.hairline)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 300)
        .background(CT.Palette.bg)
    }

    private var searchBar: some View {
        HStack(spacing: CT.Spacing.s) {
            Image(systemName: "magnifyingglass").foregroundColor(CT.Palette.textSecondary).font(.caption)
            TextField("Search translations…", text: $query).textFieldStyle(.plain)
            if !history.records.isEmpty {
                Button("Clear All") { history.clear() }
                    .buttonStyle(.plain).font(.caption).foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(CT.Spacing.l)
    }

    private func row(_ r: TranslationRecord) -> some View {
        Button { onReopen(r) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(r.source).font(.system(size: 12)).foregroundColor(CT.Palette.textPrimary).lineLimit(1)
                    Spacer()
                    Text(r.targetLanguage).font(.system(size: 9, design: .monospaced)).foregroundColor(CT.Palette.textDim)
                }
                Text(r.translation).font(.system(size: 12)).foregroundColor(CT.Palette.textSecondary).lineLimit(2)
            }
            .padding(.horizontal, CT.Spacing.l).padding(.vertical, CT.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy translation") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(r.translation, forType: .string)
            }
            Button("Delete", role: .destructive) { history.delete(r.id) }
        }
    }

    private var empty: some View {
        VStack(spacing: CT.Spacing.s) {
            Image(systemName: "clock.arrow.circlepath").font(.title).foregroundColor(CT.Palette.textDim)
            Text(query.isEmpty ? "No translations yet." : "No matches.")
                .font(.caption).foregroundColor(CT.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
