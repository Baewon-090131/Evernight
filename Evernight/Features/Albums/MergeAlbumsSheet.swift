import SwiftUI

struct MergeAlbumsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryStore.self) private var library

    @State private var targetID: String?
    @State private var sourceIDs: Set<String> = []
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("保留到目标相簿") {
                    ForEach(library.albums) { album in
                        selectionRow(
                            album,
                            selected: targetID == album.id,
                            icon: targetID == album.id ? "largecircle.fill.circle" : "circle"
                        ) {
                            targetID = album.id
                            sourceIDs.remove(album.id)
                        }
                    }
                }

                Section("合并来源") {
                    ForEach(library.albums.filter { $0.id != targetID }) { album in
                        selectionRow(
                            album,
                            selected: sourceIDs.contains(album.id),
                            icon: sourceIDs.contains(album.id) ? "checkmark.square.fill" : "square"
                        ) {
                            if sourceIDs.contains(album.id) {
                                sourceIDs.remove(album.id)
                            } else {
                                sourceIDs.insert(album.id)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.brightRed)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("合并相簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "合并中…" : "合并") {
                        Task { await merge() }
                    }
                    .disabled(targetID == nil || sourceIDs.isEmpty || isWorking)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func selectionRow(
        _ album: PhotoAlbum,
        selected: Bool,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(selected ? AppTheme.brightRed : AppTheme.muted)
                AlbumRow(album: album, isSelected: selected, showsSelection: false)
            }
        }
        .buttonStyle(.plain)
    }

    private func merge() async {
        guard
            let targetID,
            let target = library.albums.first(where: { $0.id == targetID })
        else {
            return
        }
        let sources = library.albums.filter { sourceIDs.contains($0.id) }
        guard !sources.isEmpty else { return }

        isWorking = true
        errorMessage = nil
        do {
            try await library.mergeAlbums(
                AlbumMergeSuggestion(
                    id: "\(targetID)-\(sources.map(\.id).sorted().joined(separator: "|"))",
                    target: target,
                    sources: sources
                )
            )
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        isWorking = false
    }
}
