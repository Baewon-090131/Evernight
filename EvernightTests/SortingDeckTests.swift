import Foundation
import Testing
@testable import Evernight

struct SortingDeckTests {
    @Test
    func advancingMovesToNextItemAndUndoRestoresIt() throws {
        var deck = SortingDeck(assets: [asset("1"), asset("2")])

        let completion = deck.completeCurrent(.skip)
        let step = try #require(completion)
        #expect(step.asset.id == "1")
        #expect(deck.current?.id == "2")
        #expect(deck.previousStep == step)

        let undo = deck.undoLastAction()
        let undone = try #require(undo)
        #expect(undone.asset.id == "1")
        #expect(deck.current?.id == "1")
    }

    @Test
    func moveActionCarriesAlbumIdentifier() throws {
        var deck = SortingDeck(assets: [asset("1")])
        let completion = deck.completeCurrent(.moveToAlbum("album-1"))
        let step = try #require(completion)

        #expect(step.action == .moveToAlbum("album-1"))
        #expect(deck.isFinished)
    }

    @Test
    func cardWindowIncludesTwoItemsOnEachSide() {
        var deck = SortingDeck(
            assets: (1...7).map { asset("\($0)") }
        )

        #expect(deck.cardWindow().map(\.id) == ["1", "2", "3"])

        for _ in 0..<3 {
            _ = deck.completeCurrent(.skip)
        }
        #expect(deck.cardWindow().map(\.id) == ["2", "3", "4", "5", "6"])

        for _ in 0..<3 {
            _ = deck.completeCurrent(.skip)
        }
        #expect(deck.cardWindow().map(\.id) == ["5", "6", "7"])
    }

    @Test
    func undoHistoryKeepsOnlyTheLatestTenActions() throws {
        var deck = SortingDeck(
            assets: (1...12).map { asset("\($0)") }
        )
        let actions: [SortingAction] = (0..<12).map { index in
            if index.isMultiple(of: 3) {
                return .moveToAlbum("album-\(index)")
            }
            return index.isMultiple(of: 2) ? .skip : .queueDeletion
        }
        var completedSteps: [SortingStep] = []

        for action in actions {
            let completion = deck.completeCurrent(action)
            let step = try #require(completion)
            completedSteps.append(step)
        }

        #expect(deck.history.count == SortingDeck.maximumUndoDepth)

        for expectedStep in completedSteps.suffix(10).reversed() {
            let undo = deck.undoLastAction()
            let undoneStep = try #require(undo)
            #expect(undoneStep == expectedStep)
        }

        let extraUndo = deck.undoLastAction()
        #expect(extraUndo == nil)
        #expect(deck.history.isEmpty)
        #expect(deck.cursor == 2)
        #expect(deck.current?.id == "3")
    }

    @Test(arguments: MediaScope.allCases, [AssetKind.photo, .video, .other])
    func mediaScopeFiltersKinds(scope: MediaScope, kind: AssetKind) {
        let expected = switch scope {
        case .all: true
        case .photos: kind == .photo
        case .videos: kind == .video
        }
        #expect(scope.includes(kind) == expected)
    }

    @Test
    func cardRevealFollowsEveryForwardDirection() {
        #expect(
            CardRevealProgress.value(for: CGSize(width: -52.5, height: 0)) == 0.5
        )
        #expect(
            abs(CardRevealProgress.value(for: CGSize(width: 0, height: -84)) - 0.8) < 0.0001
        )
        #expect(
            CardRevealProgress.value(for: CGSize(width: 0, height: 105)) == 1
        )
    }

    @Test
    func cardRevealStaysHiddenForRightSwipeUndo() {
        #expect(
            CardRevealProgress.value(for: CGSize(width: 140, height: 12)) == 0
        )
    }

    @Test
    func livePhotoRemainsInPhotoScopeAndCarriesItsOwnLabel() {
        let livePhoto = PhotoAsset(
            id: "live",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .photo,
            pixelWidth: 3024,
            pixelHeight: 4032,
            duration: 2.1,
            estimatedBytes: 2_000_000,
            isLivePhoto: true
        )

        #expect(MediaScope.photos.includes(livePhoto.kind))
        #expect(livePhoto.mediaLabel == "实况照片")
    }

    @Test
    func regularPhotoDefaultsToStillImage() {
        let photo = asset("still")

        #expect(!photo.isLivePhoto)
        #expect(photo.mediaLabel == "照片")
    }

    private func asset(_ id: String) -> PhotoAsset {
        PhotoAsset(
            id: id,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .photo,
            pixelWidth: 3024,
            pixelHeight: 4032,
            duration: 0,
            estimatedBytes: 2_000_000
        )
    }

    @Test
    func monthKeysSortChronologically() {
        let months = [
            MonthKey(year: 2025, month: 12),
            MonthKey(year: 2026, month: 2),
            MonthKey(year: 2026, month: 1)
        ]

        #expect(months.sorted() == [
            MonthKey(year: 2025, month: 12),
            MonthKey(year: 2026, month: 1),
            MonthKey(year: 2026, month: 2)
        ])
    }

    @Test
    func statisticsRoundTripThroughCodable() throws {
        let statistics = SortStatistics(
            sortedItemCount: 12,
            queuedDeleteCount: 3,
            movedToAlbumCount: 4,
            deletedItemCount: 2,
            estimatedFreedBytes: 18_000_000
        )
        let data = try JSONEncoder().encode(statistics)
        let decoded = try JSONDecoder().decode(SortStatistics.self, from: data)

        #expect(decoded == statistics)
    }
}
