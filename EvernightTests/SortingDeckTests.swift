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

    @Test(arguments: MediaScope.allCases, [AssetKind.photo, .video, .other])
    func mediaScopeFiltersKinds(scope: MediaScope, kind: AssetKind) {
        let expected = switch scope {
        case .all: true
        case .photos: kind == .photo
        case .videos: kind == .video
        }
        #expect(scope.includes(kind) == expected)
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
}
