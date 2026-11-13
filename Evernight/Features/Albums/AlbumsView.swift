import Foundation
import SwiftUI

struct AlbumsView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @State private var showsNewAlbum = false
    @State private var albumToRename: PhotoAlbum?
    @State private var albumToDelete: PhotoAlbum?
    @State private var suggestionToMerge: AlbumMergeSuggestion?
    @State private var actionError: String?
    @State private var isWorking = false

    var body: some View {
        ZStack {
            EvernightBackground()

            List {
                if !library.albumMergeSuggestions.isEmpty {
                    Section("整理建议") {
                        ForEach(library.albumMergeSuggestions) { suggestion in
                            mergeSuggestionRow(suggestion)
                        }
                    }
                }

                Section("用户相簿") {
                    if library.albums.isEmpty {
                        ContentUnavailableView(
                            "还没有用户相簿",
                            systemImage: "rectangle.stack.badge.plus",
                            description: Text("创建一个相簿，之后下滑整理时就能快速归档。")
                        )
                        .foregroundStyle(AppTheme.ink)
                        .listRowBackground(Color.clear)
                    }

                    ForEach(library.albums) { album in
                        Button {
                            library.targetAlbumID = album.id
                        } label: {
                            AlbumRow(
                                album: album,
                                isSelected: library.targetAlbumID == album.id
                            )
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                albumToDelete = album
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                albumToRename = album
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            .tint(AppTheme.red)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .refreshable { await library.reload() }
            .disabled(isWorking)
            .overlay {
                if isWorking {
                    ProgressView()
                        .tint(AppTheme.brightRed)
                        .padding(20)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .navigationTitle("相簿")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsNewAlbum = true
                } label: {
                    Label("新建相簿", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showsNewAlbum) {
            NewAlbumSheet()
        }
        .sheet(item: $albumToRename) { album in
            RenameAlbumSheet(album: album)
        }
        .confirmationDialog(
            "删除相簿？",
            isPresented: Binding(
                get: { albumToDelete != nil },
                set: { if !$0 { albumToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除相簿", role: .destructive) {
                guard let albumToDelete else { return }
                self.albumToDelete = nil
                Task { await delete(albumToDelete) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删除相簿容器，不会删除里面的照片。")
        }
        .confirmationDialog(
            "合并相簿？",
            isPresented: Binding(
                get: { suggestionToMerge != nil },
                set: { if !$0 { suggestionToMerge = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("合并") {
                guard let suggestionToMerge else { return }
                self.suggestionToMerge = nil
                Task { await merge(suggestionToMerge) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let suggestionToMerge {
                Text(
                    "将 \(suggestionToMerge.sources.map(\.title).joined(separator: "、")) 合并到“\(suggestionToMerge.target.title)”。照片本身不会删除。"
                )
            }
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .task {
            await library.bootstrapIfNeeded()
        }
    }

    private func mergeSuggestionRow(_ suggestion: AlbumMergeSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.merge")
                .foregroundStyle(AppTheme.brightRed)
                .frame(width: 36, height: 36)
                .background(AppTheme.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text("合并到“\(suggestion.target.title)”")
                    .font(AppFont.pingFang(14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(suggestion.sources.count) 个相似相簿，\(suggestion.target.assetCount) 项")
                    .font(AppFont.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            Button("合并") {
                suggestionToMerge = suggestion
            }
            .font(AppFont.pingFang(12, weight: .semibold))
            .foregroundStyle(AppTheme.brightRed)
        }
        .padding(.vertical, 4)
    }

    private func delete(_ album: PhotoAlbum) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await library.deleteAlbum(album)
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func merge(_ suggestion: AlbumMergeSuggestion) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await library.mergeAlbums(suggestion)
        } catch {
            actionError = error.localizedDescription
        }
    }
}

struct RenameAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryStore.self) private var library

    let album: PhotoAlbum
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(album: PhotoAlbum) {
        self.album = album
        _name = State(initialValue: album.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("相簿名称") {
                    TextField("相簿名称", text: $name)
                        .textInputAutocapitalization(.never)
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
            .navigationTitle("重命名相簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") {
                        Task { await save() }
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isSaving
                    )
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await library.renameAlbum(album, to: name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

struct NewAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryStore.self) private var library

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("相簿名称") {
                    TextField("例如：旅行、长夜月", text: $name)
                        .textInputAutocapitalization(.never)
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
            .navigationTitle("新建相簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "创建中…" : "创建") {
                        Task { await create() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func create() async {
        isSaving = true
        errorMessage = nil
        do {
            _ = try await library.createAlbum(named: name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
