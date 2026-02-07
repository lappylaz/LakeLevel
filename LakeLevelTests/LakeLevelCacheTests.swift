//
//  LakeLevelCacheTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

@MainActor
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

    // MARK: - Security: Path Traversal Tests

    func testCacheWithPathTraversalLakeId() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")

        // Attempt path traversal in lake ID
        cache.save(lakeId: "../../etc/passwd", level: level, readings: [], period: "P7D", dataSource: "Test")

        // Should still be loadable with the same sanitized key
        let loaded = cache.load(lakeId: "../../etc/passwd", period: "P7D")
        XCTAssertNotNil(loaded, "Should save and load even with path traversal characters (they get sanitized)")
    }

    func testCacheWithSlashesInLakeId() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")

        cache.save(lakeId: "foo/bar/baz", level: level, readings: [], period: "P7D", dataSource: "Test")

        let loaded = cache.load(lakeId: "foo/bar/baz", period: "P7D")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.lakeId, "foo/bar/baz")
    }

    // MARK: - Edge Cases

    func testSaveOverwritesExistingCache() {
        let level1 = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let level2 = LakeLevel(value: 200.0, unit: "ft", dateTime: Date(), siteName: "Test")

        cache.save(lakeId: "TEST001", level: level1, readings: [], period: "P7D", dataSource: "Real-time")
        cache.save(lakeId: "TEST001", level: level2, readings: [], period: "P7D", dataSource: "Real-time")

        let loaded = cache.load(lakeId: "TEST001", period: "P7D")
        XCTAssertEqual(loaded?.level.value, 200.0, "Second save should overwrite the first")
    }

    func testCacheWithEmptyReadingsArray() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")

        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")

        let loaded = cache.load(lakeId: "TEST001", period: "P7D")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.readings.count, 0)
    }

    func testClearNonexistentLakeDoesNotCrash() {
        // Should not crash or throw
        cache.clear(lakeId: "NEVER_EXISTED")
    }

    func testClearAllOnEmptyCacheDoesNotCrash() {
        cache.clearAll()
        // Should not crash
        cache.clearAll()
    }

    func testHasCachedDataReturnsFalseAfterClear() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        cache.save(lakeId: "TEST001", level: level, readings: [], period: "P7D", dataSource: "Real-time")
        XCTAssertTrue(cache.hasCachedData(for: "TEST001"))

        cache.clear(lakeId: "TEST001")
        XCTAssertFalse(cache.hasCachedData(for: "TEST001"))
    }

    func testCacheWithLargeReadingsArray() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let readings = (0..<1000).map { i in
            LakeLevelReading(value: Double(i), dateTime: Date().addingTimeInterval(Double(-i * 60)))
        }

        cache.save(lakeId: "TEST001", level: level, readings: readings, period: "P7D", dataSource: "Real-time")

        let loaded = cache.load(lakeId: "TEST001", period: "P7D")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.readings.count, 1000)
    }

    // MARK: - Cache Expiration Tests

    func testLoadReturnsNilForExpiredCache() {
        // Write a CachedLakeData with an old cachedAt date directly to disk
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let expired = CachedLakeData(
            lakeId: "EXPIRED001", level: level, readings: [],
            period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-8 * 24 * 3600) // 8 days ago
        )
        writeCacheFileDirect(expired, lakeId: "EXPIRED001", period: "P7D")

        let loaded = cache.load(lakeId: "EXPIRED001", period: "P7D")
        XCTAssertNil(loaded, "Expired cache (>7 days) should return nil")
    }

    func testLoadDeletesExpiredCacheFile() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let expired = CachedLakeData(
            lakeId: "EXPIRED002", level: level, readings: [],
            period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-8 * 24 * 3600)
        )
        let fileURL = writeCacheFileDirect(expired, lakeId: "EXPIRED002", period: "P7D")

        // Load should return nil and delete the file
        _ = cache.load(lakeId: "EXPIRED002", period: "P7D")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Expired cache file should be deleted")
    }

    func testLoadReturnsCacheJustBeforeExpiration() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let almostExpired = CachedLakeData(
            lakeId: "ALMOST001", level: level, readings: [],
            period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(-7 * 24 * 3600 + 60) // 7 days minus 1 minute
        )
        writeCacheFileDirect(almostExpired, lakeId: "ALMOST001", period: "P7D")

        let loaded = cache.load(lakeId: "ALMOST001", period: "P7D")
        XCTAssertNotNil(loaded, "Cache just before expiration should still load")
    }

    // MARK: - Corruption / Malformed Data Tests

    func testLoadReturnsNilForCorruptedCacheFile() {
        let fileURL = cacheFileURL(for: "CORRUPT001", period: "P7D")
        try? "garbage bytes not json".data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let loaded = cache.load(lakeId: "CORRUPT001", period: "P7D")
        XCTAssertNil(loaded, "Corrupted cache file should return nil gracefully")
    }

    func testLoadReturnsNilForPartialJSON() {
        let fileURL = cacheFileURL(for: "PARTIAL001", period: "P7D")
        let truncated = "{\"lakeId\":\"PARTIAL001\",\"level\":{\"value\":100"
        try? truncated.data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let loaded = cache.load(lakeId: "PARTIAL001", period: "P7D")
        XCTAssertNil(loaded, "Partial/truncated JSON should return nil gracefully")
    }

    func testLoadReturnsNilForWrongJSONSchema() {
        let fileURL = cacheFileURL(for: "WRONG001", period: "P7D")
        let wrongSchema = "{\"totally\":\"different\",\"schema\":true}"
        try? wrongSchema.data(using: .utf8)!.write(to: fileURL, options: .atomic)

        let loaded = cache.load(lakeId: "WRONG001", period: "P7D")
        XCTAssertNil(loaded, "Valid JSON with wrong schema should return nil gracefully")
    }

    func testLoadReturnsNilForEmptyFile() {
        let fileURL = cacheFileURL(for: "EMPTY001", period: "P7D")
        try? Data().write(to: fileURL, options: .atomic)

        let loaded = cache.load(lakeId: "EMPTY001", period: "P7D")
        XCTAssertNil(loaded, "Empty file should return nil gracefully")
    }

    // MARK: - Helpers

    /// Construct the cache file URL matching LakeLevelCache's internal path logic
    private func cacheFileURL(for lakeId: String, period: String) -> URL {
        let safeLakeId = lakeId
            .replacingOccurrences(of: "..", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let safePeriod = period
            .replacingOccurrences(of: "..", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LakeLevelCache", isDirectory: true)
        return cacheDir.appendingPathComponent("\(safeLakeId)_\(safePeriod).json")
    }

    /// Write a CachedLakeData directly to the cache file path (bypasses LakeLevelCache.save)
    @discardableResult
    private func writeCacheFileDirect(_ cached: CachedLakeData, lakeId: String, period: String) -> URL {
        let fileURL = cacheFileURL(for: lakeId, period: period)
        let data = try! JSONEncoder().encode(cached)
        try! data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
