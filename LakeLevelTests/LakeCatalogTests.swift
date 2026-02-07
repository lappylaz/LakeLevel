//
//  LakeCatalogTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

final class LakeCatalogTests: XCTestCase {

    // MARK: - Catalog Tests

    func testCatalogNotEmpty() {
        XCTAssertFalse(LakeCatalog.lakes.isEmpty, "Catalog should contain lakes")
    }

    func testCatalogContainsKnownLake() {
        let lakeGreenwood = LakeCatalog.lakes.first { $0.id == "02166500" }
        XCTAssertNotNil(lakeGreenwood)
        XCTAssertEqual(lakeGreenwood?.name, "Lake Greenwood")
        XCTAssertEqual(lakeGreenwood?.state, "SC")
    }

    func testCatalogLakeCount() {
        // Should have 33 lakes as documented
        XCTAssertEqual(LakeCatalog.lakes.count, 33)
    }

    // MARK: - Search Tests

    func testSearchByName() {
        let results = LakeCatalog.search("Greenwood")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Lake Greenwood")
    }

    func testSearchByState() {
        let results = LakeCatalog.search("TX")
        XCTAssertTrue(results.count > 0, "Should find Texas lakes")
        XCTAssertTrue(results.allSatisfy { $0.state == "TX" })
    }

    func testSearchCaseInsensitive() {
        let resultsLower = LakeCatalog.search("greenwood")
        let resultsUpper = LakeCatalog.search("GREENWOOD")

        XCTAssertEqual(resultsLower.count, resultsUpper.count)
    }

    func testSearchEmptyQuery() {
        let results = LakeCatalog.search("")
        XCTAssertEqual(results.count, LakeCatalog.lakes.count, "Empty search should return all lakes")
    }

    func testSearchNoResults() {
        let results = LakeCatalog.search("NonexistentLake12345")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Lake by ID Tests

    func testLakeByIdFound() {
        let lake = LakeCatalog.lake(byId: "02166500")
        XCTAssertNotNil(lake)
        XCTAssertEqual(lake?.name, "Lake Greenwood")
    }

    func testLakeByIdNotFound() {
        let lake = LakeCatalog.lake(byId: "99999999")
        XCTAssertNil(lake)
    }

    // MARK: - Grouped Data Tests

    func testLakesByState() {
        let grouped = LakeCatalog.lakesByState
        XCTAssertFalse(grouped.isEmpty)

        // Check SC has lakes
        XCTAssertNotNil(grouped["SC"])
        XCTAssertTrue(grouped["SC"]!.count >= 2)
    }

    func testStatesArray() {
        let states = LakeCatalog.states
        XCTAssertFalse(states.isEmpty)
        XCTAssertTrue(states.contains("SC"))
        XCTAssertTrue(states.contains("TX"))

        // Should be sorted
        XCTAssertEqual(states, states.sorted())
    }

    // MARK: - Data Integrity Tests

    func testAllLakesHaveRequiredFields() {
        for lake in LakeCatalog.lakes {
            XCTAssertFalse(lake.id.isEmpty, "Lake ID should not be empty")
            XCTAssertFalse(lake.name.isEmpty, "Lake name should not be empty")
            XCTAssertFalse(lake.state.isEmpty, "Lake state should not be empty")
            XCTAssertEqual(lake.state.count, 2, "State should be 2-letter abbreviation")
        }
    }

    func testAllLakesHaveUniqueIds() {
        let ids = LakeCatalog.lakes.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All lake IDs should be unique")
    }

    func testAllLakesHaveCoordinates() {
        for lake in LakeCatalog.lakes {
            XCTAssertNotNil(lake.latitude, "\(lake.name) should have latitude")
            XCTAssertNotNil(lake.longitude, "\(lake.name) should have longitude")

            if let lat = lake.latitude {
                XCTAssertTrue(lat >= 24 && lat <= 50, "\(lake.name) latitude should be in continental US range")
            }
            if let lon = lake.longitude {
                XCTAssertTrue(lon >= -125 && lon <= -66, "\(lake.name) longitude should be in continental US range")
            }
        }
    }

    // MARK: - Search Edge Cases

    func testSearchWithWhitespaceOnly() {
        let results = LakeCatalog.search("   ")
        // Whitespace-only doesn't match any lake name or state
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchPartialStateName() {
        // "T" should match TX, TN, TS (any state containing T)
        let results = LakeCatalog.search("T")
        XCTAssertTrue(results.count > 0, "Partial state search should return results")
        // All results should have a state or name containing "t" (case-insensitive)
        for lake in results {
            let matches = lake.name.lowercased().contains("t") || lake.state.lowercased().contains("t")
            XCTAssertTrue(matches, "\(lake.name) should match search for 'T'")
        }
    }

    func testSearchWithSpecialCharacters() {
        let results = LakeCatalog.search("Lake (Special)")
        // No lakes have parentheses in their name — should return empty
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchMatchesBothNameAndState() {
        // "Lake" should match many lakes by name
        let results = LakeCatalog.search("Lake")
        XCTAssertTrue(results.count > 10, "Most lakes contain 'Lake' in name")
    }

    // MARK: - Data Integrity

    func testAllLakesHaveValidUSGSURLs() {
        for lake in LakeCatalog.lakes {
            XCTAssertNotNil(lake.usgsURL, "\(lake.name) should have a valid USGS URL")
        }
    }

    func testStatesArrayContainsOnlyValidAbbreviations() {
        let validStates: Set<String> = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
        ]

        for state in LakeCatalog.states {
            XCTAssertTrue(validStates.contains(state), "\(state) should be a valid US state abbreviation")
        }
    }

    func testLakeByIdWithEmptyString() {
        let lake = LakeCatalog.lake(byId: "")
        XCTAssertNil(lake)
    }

    func testAllLakeIdsAreNumeric() {
        // USGS site IDs should be numeric strings
        for lake in LakeCatalog.lakes {
            XCTAssertTrue(
                lake.id.allSatisfy { $0.isNumber },
                "\(lake.name) ID '\(lake.id)' should be numeric"
            )
        }
    }
}
