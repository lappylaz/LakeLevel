//
//  LakeModelTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

final class LakeModelTests: XCTestCase {

    // MARK: - Lake Model Tests

    func testLakeDisplayName() {
        let lake = Lake(
            id: "02166500",
            name: "Lake Greenwood",
            state: "SC",
            latitude: 34.1732,
            longitude: -82.1137
        )

        XCTAssertEqual(lake.displayName, "Lake Greenwood, SC")
    }

    func testLakeUSGSURL() {
        let lake = Lake(
            id: "02166500",
            name: "Lake Greenwood",
            state: "SC",
            latitude: 34.1732,
            longitude: -82.1137
        )

        XCTAssertNotNil(lake.usgsURL)
        XCTAssertEqual(
            lake.usgsURL?.absoluteString,
            "https://waterdata.usgs.gov/monitoring-location/02166500/"
        )
    }

    func testLakeHashable() {
        let lake1 = Lake(id: "02166500", name: "Lake Greenwood", state: "SC", latitude: nil, longitude: nil)
        let lake2 = Lake(id: "02166500", name: "Lake Greenwood", state: "SC", latitude: nil, longitude: nil)

        XCTAssertEqual(lake1, lake2)
        XCTAssertEqual(lake1.hashValue, lake2.hashValue)
    }

    func testLakeIdentifiable() {
        let lake = Lake(id: "02166500", name: "Lake Greenwood", state: "SC", latitude: nil, longitude: nil)
        XCTAssertEqual(lake.id, "02166500")
    }

    // MARK: - LakeLevel Model Tests

    func testLakeLevelValueFormatted() {
        let level = LakeLevel(
            value: 438.567,
            unit: "ft",
            dateTime: Date(),
            siteName: "Test Site"
        )

        XCTAssertEqual(level.valueFormatted, "438.57")
    }

    func testLakeLevelValueFormattedRounding() {
        let level = LakeLevel(
            value: 438.994,
            unit: "ft",
            dateTime: Date(),
            siteName: "Test Site"
        )

        XCTAssertEqual(level.valueFormatted, "438.99")
    }

    // MARK: - LakeLevelReading Tests

    func testLakeLevelReadingIdentifiable() {
        let reading1 = LakeLevelReading(value: 100.0, dateTime: Date())
        let reading2 = LakeLevelReading(value: 100.0, dateTime: Date())

        // Each reading should have a unique ID
        XCTAssertNotEqual(reading1.id, reading2.id)
    }
}
