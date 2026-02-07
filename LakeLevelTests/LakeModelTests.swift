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

    // MARK: - Security & Edge Case Tests

    func testLakeWithEmptyId() {
        let lake = Lake(id: "", name: "Test", state: "TX", latitude: nil, longitude: nil)
        XCTAssertEqual(lake.id, "")
        XCTAssertEqual(lake.displayName, "Test, TX")
    }

    func testLakeWithEmptyName() {
        let lake = Lake(id: "123", name: "", state: "TX", latitude: nil, longitude: nil)
        XCTAssertEqual(lake.displayName, ", TX")
    }

    func testLakeWithNilCoordinates() {
        let lake = Lake(id: "123", name: "Test Lake", state: "TX", latitude: nil, longitude: nil)
        XCTAssertNil(lake.latitude)
        XCTAssertNil(lake.longitude)
        XCTAssertNotNil(lake.usgsURL)
    }

    func testLakeUSGSURLWithPathTraversalId() {
        let lake = Lake(id: "../../etc/passwd", name: "Evil", state: "XX", latitude: nil, longitude: nil)
        // The URL should percent-encode the path traversal characters
        if let url = lake.usgsURL {
            XCTAssertFalse(url.absoluteString.contains(".."), "URL should not contain unencoded path traversal")
        }
    }

    func testLakeUSGSURLWithSpecialCharacters() {
        let lake = Lake(id: "foo&bar=baz", name: "Test", state: "TX", latitude: nil, longitude: nil)
        if let url = lake.usgsURL {
            XCTAssertFalse(url.absoluteString.contains("&bar=baz"), "URL should percent-encode special characters")
        }
    }

    func testLakeCodableRoundTrip() throws {
        let lake = Lake(id: "02166500", name: "Lake Greenwood", state: "SC", latitude: 34.17, longitude: -82.11)
        let data = try JSONEncoder().encode(lake)
        let decoded = try JSONDecoder().decode(Lake.self, from: data)

        XCTAssertEqual(lake.id, decoded.id)
        XCTAssertEqual(lake.name, decoded.name)
        XCTAssertEqual(lake.state, decoded.state)
        XCTAssertEqual(lake.latitude, decoded.latitude)
        XCTAssertEqual(lake.longitude, decoded.longitude)
    }

    func testLakeCodableWithNilCoordinates() throws {
        let lake = Lake(id: "123", name: "Test", state: "TX", latitude: nil, longitude: nil)
        let data = try JSONEncoder().encode(lake)
        let decoded = try JSONDecoder().decode(Lake.self, from: data)

        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
    }

    func testLakeLevelValueFormattedZero() {
        let level = LakeLevel(value: 0.0, unit: "ft", dateTime: Date(), siteName: "Test")
        XCTAssertEqual(level.valueFormatted, "0.00")
    }

    func testLakeLevelValueFormattedNegative() {
        let level = LakeLevel(value: -12.5, unit: "ft", dateTime: Date(), siteName: "Test")
        XCTAssertEqual(level.valueFormatted, "-12.50")
    }

    func testLakeLevelValueFormattedVeryLarge() {
        let level = LakeLevel(value: 99999.99, unit: "ft", dateTime: Date(), siteName: "Test")
        XCTAssertEqual(level.valueFormatted, "99999.99")
    }

    func testLakeLevelDateFormatted() {
        let date = Date(timeIntervalSince1970: 1706200000) // Known date
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: date, siteName: "Test")
        XCTAssertFalse(level.dateFormatted.isEmpty)
    }

    func testLakeLevelCodableRoundTrip() throws {
        let level = LakeLevel(value: 438.50, unit: "ft", dateTime: Date(), siteName: "Test Lake")
        let data = try JSONEncoder().encode(level)
        let decoded = try JSONDecoder().decode(LakeLevel.self, from: data)

        XCTAssertEqual(level.value, decoded.value)
        XCTAssertEqual(level.unit, decoded.unit)
        XCTAssertEqual(level.siteName, decoded.siteName)
    }

    // MARK: - CachedLakeData Tests

    func testCacheAgeFormattedJustNow() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time", cachedAt: Date()
        )
        XCTAssertEqual(cached.cacheAgeFormatted, "Just now")
    }

    func testCacheAgeFormattedMinutes() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-1800) // 30 min ago
        )
        XCTAssertTrue(cached.cacheAgeFormatted.contains("minute"))
    }

    func testCacheAgeFormattedHours() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-7200) // 2 hours ago
        )
        XCTAssertTrue(cached.cacheAgeFormatted.contains("hour"))
    }

    func testCacheAgeFormattedDays() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-172800) // 2 days ago
        )
        XCTAssertTrue(cached.cacheAgeFormatted.contains("day"))
    }

    func testCacheAgeFormattedSingularHour() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-3660) // 1 hour 1 min ago
        )
        XCTAssertEqual(cached.cacheAgeFormatted, "1 hour ago")
    }

    func testCacheAgeFormattedSingularDay() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-90000) // 25 hours ago
        )
        XCTAssertEqual(cached.cacheAgeFormatted, "1 day ago")
    }

    func testIsStaleReturnsFalseUnderOneHour() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-3500) // Just under 1 hour
        )
        XCTAssertFalse(cached.isStale)
    }

    func testIsStaleReturnsTrueOverOneHour() {
        let cached = CachedLakeData(
            lakeId: "TEST", level: LakeLevel(value: 100, unit: "ft", dateTime: Date(), siteName: "T"),
            readings: [], period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-3700) // Just over 1 hour
        )
        XCTAssertTrue(cached.isStale)
    }

    func testCachedLakeDataCodableRoundTrip() throws {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let readings = [LakeLevelReading(value: 99.0, dateTime: Date())]
        let cached = CachedLakeData(
            lakeId: "TEST001", level: level, readings: readings,
            period: "P7D", dataSource: "Real-time", cachedAt: Date()
        )

        let data = try JSONEncoder().encode(cached)
        let decoded = try JSONDecoder().decode(CachedLakeData.self, from: data)

        XCTAssertEqual(decoded.lakeId, "TEST001")
        XCTAssertEqual(decoded.level.value, 100.0)
        XCTAssertEqual(decoded.readings.count, 1)
        XCTAssertEqual(decoded.dataSource, "Real-time")
    }

    // MARK: - USGS Response Model Decoding

    func testUSGSResponseDecodesValidJSON() throws {
        let json = """
        {
            "value": {
                "timeSeries": [{
                    "sourceInfo": {"siteName": "Test Lake"},
                    "variable": {"variableName": "Gage height", "unit": {"unitCode": "ft"}},
                    "values": [{"value": [{"value": "438.50", "dateTime": "2026-01-25T14:00:00.000-05:00"}]}]
                }]
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(USGSResponse.self, from: data)

        XCTAssertEqual(response.value.timeSeries.count, 1)
        XCTAssertEqual(response.value.timeSeries.first?.sourceInfo.siteName, "Test Lake")
        XCTAssertEqual(response.value.timeSeries.first?.values.first?.value.first?.value, "438.50")
    }

    func testUSGSResponseDecodesEmptyTimeSeries() throws {
        let json = """
        {"value": {"timeSeries": []}}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(USGSResponse.self, from: data)

        XCTAssertTrue(response.value.timeSeries.isEmpty)
    }

    func testUSGSResponseRejectsInvalidJSON() {
        let json = "not valid json"
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(USGSResponse.self, from: data))
    }

    func testUSGSResponseRejectsMissingFields() {
        let json = """
        {"value": {}}
        """
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(USGSResponse.self, from: data))
    }
}
