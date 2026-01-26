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
}
