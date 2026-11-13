import SwiftUI

struct GestureGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let gestures: [(String, String, String)] = [
        ("arrow.left", "左滑", "下一张"),
        ("arrow.uturn.backward", "右滑", "撤回上一个动作"),
        ("arrow.up", "上滑", "加入待删除区"),
        ("arrow.down", "下滑", "放入默认相簿"),
        ("arrow.right.to.line", "滑轨拖到右端", "确认删除"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("滑动整理")
                        .font(AppFont.pingFang(30, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("所有整理动作都会先进入可复核状态，不会直接删除照片。")
                        .font(AppFont.body)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(gestures, id: \.1) { icon, title, detail in
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(AppFont.pingFang(18, weight: .semibold))
                                .foregroundStyle(AppTheme.brightRed)
                                .frame(width: 42, height: 42)
                                .background(AppTheme.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(AppFont.pingFang(15, weight: .semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Text(detail)
                                    .font(AppFont.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AppTheme.hairline, lineWidth: 1)
                        }
                    }
                }
                .padding(20)
            }
            .background(EvernightBackground())
            .navigationTitle("手势说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
