import Foundation
import SwiftUI

struct AlbumsView: View {
    @Environment(PhotoLibraryStore.self) private var library
    @State private var showsNewAlbum = false

    var body: some View {
        ZStack {
            EvernightBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    if library.albums.isEmpty {
                        ContentUnavailableView(
                            "还没有用户相簿",
                            systemImage: "rectangle.stack.badge.plus",
                            description: Text("创建一个相簿，之后下滑整理时就能快速归档。")
                        )
                        .foregroundStyle(AppTheme.ink)
                        .padding(.top, 70)
                    }

                    ForEach(library.albums) { album in
                        Button {
                            library.targetAlbumID = album.id
                        } label: {
                            AlbumRow(
                                album: album,
                                isSelected: library.targetAlbumID == album.id
                            )
                            .padding(14)
                            .background(
                                AppTheme.surface,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        library.targetAlbumID == album.id
                                            ? AppTheme.red.opacity(0.55)
                                            : AppTheme.hairline,
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await library.reload()
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
        .task {
            await library.bootstrapIfNeeded()
        }
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
