import SwiftUI

struct AlbumRow: View {
    let album: PhotoAlbum
    let isSelected: Bool
    var showsSelection = true

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "rectangle.stack.fill")
                .font(AppFont.pingFang(17, weight: .medium))
                .foregroundStyle(AppTheme.brightRed)
                .frame(width: 42, height: 42)
                .background(AppTheme.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(AppFont.pingFang(17, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(album.assetCount) 项")
                    .font(AppFont.caption)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            if showsSelection && isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.brightRed)
            }
        }
        .contentShape(Rectangle())
    }
}
