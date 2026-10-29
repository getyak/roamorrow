import CoreLocation
import XCTest
@testable import SoloCompass

@MainActor
final class MapKitPOICancellationTests: XCTestCase {
    func testAlreadyCancelledTextSearchDoesNotStartProviderWork() async {
        let service = MapKitPOIService()
        let task = Task { try await service.search(
            query: "bookstore", near: .init(latitude: 35.7148, longitude: 139.7730)
        ) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled search must not become an empty success or provider failure")
        } catch is CancellationError {
            XCTAssertFalse(service.isFetching)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testAlreadyCancelledNearbySearchDoesNotStartProviderWork() async {
        let service = MapKitPOIService()
        let task = Task { try await service.fetchPOIs(
            near: .init(latitude: 35.7148, longitude: 139.7730)
        ) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled search must not issue nearby work")
        } catch is CancellationError {
            XCTAssertFalse(service.isFetching)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
