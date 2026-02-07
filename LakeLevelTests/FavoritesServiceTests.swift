//
//  FavoritesServiceTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

@MainActor
final class FavoritesServiceTests: XCTestCase {

    var service: FavoritesService!
    let testLake = Lake(
        id: "TEST001",
        name: "Test Lake",
        state: "TS",
        latitude: 35.0,
        longitude: -80.0
    )

    override func setUp() async throws {
        // Clear any existing test data
        UserDefaults.standard.removeObject(forKey: "favoriteLakes")
        service = FavoritesService()
    }

    override func tearDown() async throws {
        // Clean up test data
        UserDefaults.standard.removeObject(forKey: "favoriteLakes")
        service = nil
    }

    // MARK: - Basic Tests

    func testInitialStateEmpty() {
        XCTAssertTrue(service.favoriteLakeIds.isEmpty)
        XCTAssertTrue(service.favoriteLakes.isEmpty)
    }

    func testIsFavoriteReturnsFalseForNonFavorite() {
        XCTAssertFalse(service.isFavorite(testLake))
    }

    // MARK: - Add/Remove Tests

    func testAddFavorite() {
        service.addFavorite(testLake)

        XCTAssertTrue(service.isFavorite(testLake))
        XCTAssertTrue(service.favoriteLakeIds.contains(testLake.id))
    }

    func testRemoveFavorite() {
        service.addFavorite(testLake)
        service.removeFavorite(testLake)

        XCTAssertFalse(service.isFavorite(testLake))
        XCTAssertFalse(service.favoriteLakeIds.contains(testLake.id))
    }

    func testToggleFavoriteAdds() {
        service.toggleFavorite(testLake)

        XCTAssertTrue(service.isFavorite(testLake))
    }

    func testToggleFavoriteRemoves() {
        service.addFavorite(testLake)
        service.toggleFavorite(testLake)

        XCTAssertFalse(service.isFavorite(testLake))
    }

    func testToggleFavoriteTwiceReturnsToOriginal() {
        XCTAssertFalse(service.isFavorite(testLake))

        service.toggleFavorite(testLake)
        service.toggleFavorite(testLake)

        XCTAssertFalse(service.isFavorite(testLake))
    }

    // MARK: - Persistence Tests

    func testFavoritesPersist() {
        service.addFavorite(testLake)

        // Create new instance to simulate app restart
        let newService = FavoritesService()

        XCTAssertTrue(newService.favoriteLakeIds.contains(testLake.id))
    }

    // MARK: - FavoriteLakes Computed Property

    func testFavoriteLakesReturnsMatchingLakes() {
        // Add a lake that exists in the catalog
        guard let catalogLake = LakeCatalog.lakes.first else {
            XCTFail("Catalog should have at least one lake")
            return
        }

        service.addFavorite(catalogLake)
        let favorites = service.favoriteLakes

        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.id, catalogLake.id)
    }

    func testFavoriteLakesExcludesNonCatalogLakes() {
        // Add a lake that doesn't exist in catalog
        service.addFavorite(testLake)

        // favoriteLakes only returns lakes that are in LakeCatalog
        let favorites = service.favoriteLakes

        XCTAssertTrue(favorites.isEmpty, "Non-catalog lakes should not appear in favoriteLakes")
    }

    // MARK: - Edge Cases

    func testAddDuplicateFavoriteIsIdempotent() {
        service.addFavorite(testLake)
        service.addFavorite(testLake)

        XCTAssertTrue(service.isFavorite(testLake))
        // Set semantics — should only have one entry
        XCTAssertEqual(service.favoriteLakeIds.count, 1)
    }

    func testRemoveNonExistentFavoriteDoesNotCrash() {
        // Should not crash or throw
        service.removeFavorite(testLake)
        XCTAssertFalse(service.isFavorite(testLake))
    }

    func testAddMultipleFavorites() {
        let lakes = (0..<5).map { i in
            Lake(id: "MULTI\(i)", name: "Lake \(i)", state: "TS", latitude: nil, longitude: nil)
        }

        for lake in lakes {
            service.addFavorite(lake)
        }

        XCTAssertEqual(service.favoriteLakeIds.count, 5)
        for lake in lakes {
            XCTAssertTrue(service.isFavorite(lake))
        }
    }

    func testRemoveFromMultipleFavorites() {
        let lakes = (0..<3).map { i in
            Lake(id: "REM\(i)", name: "Lake \(i)", state: "TS", latitude: nil, longitude: nil)
        }
        for lake in lakes {
            service.addFavorite(lake)
        }

        // Remove the middle one
        service.removeFavorite(lakes[1])

        XCTAssertTrue(service.isFavorite(lakes[0]))
        XCTAssertFalse(service.isFavorite(lakes[1]))
        XCTAssertTrue(service.isFavorite(lakes[2]))
        XCTAssertEqual(service.favoriteLakeIds.count, 2)
    }

    func testFavoriteLakesOrderMatchesCatalogOrder() {
        // Add catalog lakes in reverse order
        let catalogLakes = Array(LakeCatalog.lakes.prefix(3))
        for lake in catalogLakes.reversed() {
            service.addFavorite(lake)
        }

        let favorites = service.favoriteLakes

        // favoriteLakes filters from LakeCatalog.lakes, so order should match catalog
        XCTAssertEqual(favorites.count, 3)
        XCTAssertEqual(favorites.map { $0.id }, catalogLakes.map { $0.id })
    }

    // MARK: - Persistence Edge Cases

    func testPersistenceWithEmptyArray() {
        // Manually set an empty array in UserDefaults
        UserDefaults.standard.set([String](), forKey: "favoriteLakes")
        let newService = FavoritesService()

        XCTAssertTrue(newService.favoriteLakeIds.isEmpty)
    }

    func testPersistenceAfterRemoveAllFavorites() {
        let lakes = (0..<3).map { i in
            Lake(id: "PERSIST\(i)", name: "Lake \(i)", state: "TS", latitude: nil, longitude: nil)
        }
        for lake in lakes {
            service.addFavorite(lake)
        }
        for lake in lakes {
            service.removeFavorite(lake)
        }

        // Re-instantiate to simulate app restart
        let newService = FavoritesService()
        XCTAssertTrue(newService.favoriteLakeIds.isEmpty)
    }

    // MARK: - Rapid Toggling

    func testRapidToggling() {
        // Toggle 100 times — should end up back at original state (not favorited)
        for _ in 0..<100 {
            service.toggleFavorite(testLake)
        }
        XCTAssertFalse(service.isFavorite(testLake), "Even number of toggles should return to original state")
    }

    func testRapidTogglingOddCount() {
        // Toggle 99 times — should end up favorited
        for _ in 0..<99 {
            service.toggleFavorite(testLake)
        }
        XCTAssertTrue(service.isFavorite(testLake), "Odd number of toggles should result in favorited state")
    }
}
