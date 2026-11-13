import Foundation

nonisolated enum AssetKind: String, Hashable, Sendable {
    case photo
    case video
    case other

    var title: String {
        switch self {
        case .photo: "照片"
        case .video: "视频"
        case .other: "媒体"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        case .other: "square.stack.3d.up"
        }
    }
}

nonisolated enum MediaScope: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case photos
    case videos

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "全部媒体"
        case .photos: "照片"
        case .videos: "视频"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.stack.3d.up.fill"
        case .photos: "photo.fill"
        case .videos: "video.fill"
        }
    }

    func includes(_ kind: AssetKind) -> Bool {
        switch self {
        case .all:
            true
        case .photos:
            kind == .photo
        case .videos:
            kind == .video
        }
    }
}

nonisolated struct MonthKey: Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }
    var title: String { "\(year)年 \(month)月" }
    var shortTitle: String { "\(month)月" }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }

    static func containing(_ date: Date, calendar: Calendar = .current) -> MonthKey {
        let components = calendar.dateComponents([.year, .month], from: date)
        return MonthKey(year: components.year ?? 1970, month: components.month ?? 1)
    }

    static func current(calendar: Calendar = .current) -> MonthKey {
        containing(.now, calendar: calendar)
    }
}

nonisolated struct PhotoAsset: Identifiable, Hashable, Sendable {
    let id: String
    let creationDate: Date?
    let kind: AssetKind
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    let estimatedBytes: Int64
    let isLivePhoto: Bool

    init(
        id: String,
        creationDate: Date?,
        kind: AssetKind,
        pixelWidth: Int,
        pixelHeight: Int,
        duration: TimeInterval,
        estimatedBytes: Int64,
        isLivePhoto: Bool = false
    ) {
        self.id = id
        self.creationDate = creationDate
        self.kind = kind
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.estimatedBytes = estimatedBytes
        self.isLivePhoto = isLivePhoto
    }

    var monthKey: MonthKey? {
        creationDate.map { MonthKey.containing($0) }
    }

    var mediaLabel: String {
        if kind == .video {
            return "视频"
        }
        return isLivePhoto ? "实况照片" : "照片"
    }
}

nonisolated struct PhotoAlbum: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let assetCount: Int
}

nonisolated struct PhotoMonth: Identifiable, Hashable, Sendable {
    let key: MonthKey
    let photoCount: Int
    let videoCount: Int

    var id: MonthKey { key }
    var totalCount: Int { photoCount + videoCount }
}
