//
//  LakeLevelCacheTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

final class LakeLevelCacheTests: XCTestCase {

    var cache: LakeLevelCache!

    override func setUp() async throws {
        cache = LakeLevelCache.shared
        cache.clearAll()
    }

    override func tearDown() async throws {
        cache.clearAll()
        cache = nil
    }

    // MARK: - Save and Load Tests

    func testSaveAndLoad() {
        let level = LakeLevel(
            value: 438.50,
            unit: "ft",
            dateTime: Date(),
            siteName: "Test Lake"
        )
        let readings = [
            LakeLevelReading(value: 438.50, dateTime: Date()),
            LakeLevelReading(value: 438.45, dateTime: Date().addingTimeInterval(-3600))
        ]

        cache.save(
            lakeId: "TEST001",
            level: level,
            readings: readings,
            period: "P7D",
            dataSource: "Real-time"
        )

        let loaded = cache.load(lakeId: "TEST001", period: "P7D")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.lakeId, "TEST001")
        XCTAssertEqual(loaded?.level.value, 438.50)
        XCTAssertEqual(loaded?.readings.count, 2)
        XCTAssertEqual(loaded?.dataSource, "Real-time")
    }

    func testLoadNonexistent() {
        let loaded = cache.load(lakeId: "NONEXISTENT", period: "P7D")
        XCTAssertNil(loaded)
    }

    func testDifferentPeriodsAreSeparate() {
        let level = LakeLevel(
            value: 100.0,
            unit: "ft",
            dateTime: Date(),
            siteName: "Test"
        )

        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")
        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P30D", dataSource: "Daily")

        let sevenDay = cache.load(lakeId: "TEST001", period: "P7D")
        let thirtyDay = cache.load(lakeId: "TEST001", period: "P30D")

        XCTAssertNotNil(sevenDay)
        XCTAssertNotNil(thirtyDay)
        XCTAssertEqual(sevenDay?.dataSource, "Real-time")
        XCTAssertEqual(thirtyDay?.dataSource, "Daily")
    }

    // MARK: - Cache Age Tests

    func testCacheAgeFormatted() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")

        let loaded = cache.load(lakeId: "TEST001", period: "P7D")
        XCTAssertNotNil(loaded?.cacheAgeFormatted)
        // Just cached, should be "Just now" or similar
        XCTAssertFalse(loaded!.cacheAgeFormatted.isEmpty)
    }

    func testCacheIsStale() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")

        let loaded = cache.load(lakeId: "TEST001", period: "P7D")
        // Fresh cache should not be stale
        XCTAssertFalse(loaded!.isStale)
    }

    // MARK: - Clear Tests

    func testClearSpecificLake() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")

        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")
        cache.save(lakeId: "TEST002", level: level, readings: [], period: "P7D", dataSource: "Real-time")

        cache.clear(lakeId: "TEST001")

        XCTAssertNil(cache.load(lakeId: "TEST001", period: "P7D"))
        XCTAssertNotNil(cache.load(lakeId: "TEST002", period: "P7D"))
    }

    func testClearAll() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")

        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")
        cache.save(lakeId: "TEST002", level: level, readings: [], period: "P7D", dataSource: "Real-time")

        cache.clearAll()

        XCTAssertNil(cache.load(lakeId: "TEST001", period: "P7D"))
        XCTAssertNil(cache.load(lakeId: "TEST002", period: "P7D"))
    }

    // MARK: - Has Cached Data Tests

    func testHasCachedData() {
        XCTAssertFalse(cache.hasCachedData(for: "TEST001"))

        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")

        XCTAssertTrue(cache.hasCachedData(for: "TEST001"))
    }

    // MARK: - Cache Size Tests

    func testCacheSizeIncreases() {
        let initialSize = cache.cacheSize

        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let readings = (0..<100).map { i in
            LakeLevelReading(value: Double(i), dateTime: Date().addingTimeInterval(Double(-i * 3600)))
        }

        cache.save(lakeId: "TEST001", level: level, readings: readings, period: "P7D", dataSource: "Real-time")

        XCTAssertGreaterThan(cache.cacheSize, initialSize)
    }

    func testCacheSizeFormatted() {
        let formatted = cache.cacheSizeFormatted
        XCTAssertFalse(formatted.isEmpty)
        // Should contain KB or MB
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("MB") || formatted.contains("bytes") || formatted.contains("Zero"))
    }
}
