import SwiftUI

struct AlbumPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoLibraryStore.self) private var library

    var showsCloseButton = false
    @State private var showsNewAlbum = false

    var body: some View {
        ZStack {
            EvernightBackground()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(library.albums) { album in
                        Button {
                            library.targetAlbumID = album.id
                            dismiss()
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

                    Button {
                        showsNewAlbum = true
                    } label: {
                        Label("新建相簿", systemImage: "plus.circle.fill")
                            .font(AppFont.pingFang(17, weight: .semibold))
                            .foregroundStyle(AppTheme.brightRed)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                AppTheme.surface,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("放入相簿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsNewAlbum = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showsNewAlbum) {
            NewAlbumSheet()
        }
    }
}
