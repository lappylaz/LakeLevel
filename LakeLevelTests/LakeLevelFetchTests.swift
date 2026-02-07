//
//  LakeLevelFetchTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 2/7/26.
//

import XCTest
@testable import LakeLevel

// MARK: - Mock URLSession

final class MockURLSession: URLSessionDataProvider, @unchecked Sendable {
    var handler: ((URL) throws -> (Data, URLResponse))?
    var requestedURLs: [URL] = []

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)
        guard let handler = handler else {
            throw URLError(.badServerResponse)
        }
        return try handler(url)
    }
}

// MARK: - Test Helpers

private func makeHTTPResponse(statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private func makeUSGSJSON(
    siteName: String = "Test Lake",
    unitCode: String = "ft",
    readings: [(value: String, dateTime: String)]
) -> Data {
    let valuesJSON = readings.map { r in
        "{\"value\":\"\(r.value)\",\"dateTime\":\"\(r.dateTime)\"}"
    }.joined(separator: ",")

    let json = """
    {
        "value": {
            "timeSeries": [{
                "sourceInfo": {"siteName": "\(siteName)"},
                "variable": {"variableName": "Gage height", "unit": {"unitCode": "\(unitCode)"}},
                "values": [{"value": [\(valuesJSON)]}]
            }]
        }
    }
    """
    return json.data(using: .utf8)!
}

private func makeEmptyUSGSJSON() -> Data {
    """
    {"value": {"timeSeries": []}}
    """.data(using: .utf8)!
}

private let testLake = Lake(
    id: "02166500",
    name: "Lake Greenwood",
    state: "SC",
    latitude: 34.1732,
    longitude: -82.1137
)

// MARK: - Fetch Tests

@MainActor
final class LakeLevelFetchTests: XCTestCase {

    var mockSession: MockURLSession!
    var service: LakeLevelService!

    override func setUp() async throws {
        LakeLevelCache.shared.clearAll()
        mockSession = MockURLSession()
        service = LakeLevelService(session: mockSession)
    }

    override func tearDown() async throws {
        LakeLevelCache.shared.clearAll()
        service = nil
        mockSession = nil
    }

    // MARK: - State Management

    func testFetchClearsErrorOnNewFetch() async {
        // Set up an error state first
        await service.fetchLakeLevel(period: .sevenDays)
        XCTAssertEqual(service.error, "No lake selected")

        // Now set up a successful fetch
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }
        service.currentLevel = nil // reset
        await service.fetchLakeLevel(for: testLake)

        XCTAssertNil(service.error, "Error should be cleared on successful fetch")
    }

    func testFetchWithNoLakeSelectedSetsError() async {
        await service.fetchLakeLevel(period: .sevenDays)
        XCTAssertEqual(service.error, "No lake selected")
    }

    func testFetchForLakeSetsCurrentLake() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertNotNil(service.currentLevel)
    }

    func testFetchPopulatesCurrentLevelAndReadings() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "438.55", dateTime: "2026-01-25T13:00:00.000-05:00"),
                (value: "438.60", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertNotNil(service.currentLevel)
        XCTAssertEqual(service.currentLevel?.value, 438.60, "Current level should be the most recent reading")
        XCTAssertEqual(service.historicalReadings.count, 3)
        XCTAssertEqual(service.currentLevel?.siteName, "Test Lake")
        XCTAssertEqual(service.currentLevel?.unit, "ft")
    }

    func testFetchSetsIsLoadingFalseAfterCompletion() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertFalse(service.isLoading, "isLoading should be false after fetch completes")
    }

    // MARK: - Data Source Labels

    func testFetchSetsDataSourceToRealtimeForIV() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        // 7-day default uses IV
        XCTAssertEqual(service.dataSource, "Real-time")
    }

    func testFetchSetsDataSourceToDailyForDV() async {
        mockSession.handler = { url in
            // Only return data for DV URLs
            if url.absoluteString.contains("/dv/") {
                let data = makeUSGSJSON(readings: [
                    (value: "438.50", dateTime: "2026-01-25")
                ])
                return (data, makeHTTPResponse())
            }
            throw URLError(.badServerResponse)
        }

        service.selectedPeriod = .thirtyDays
        await service.fetchLakeLevel(for: testLake)
        await service.fetchLakeLevel(period: .thirtyDays)

        XCTAssertEqual(service.dataSource, "Daily")
    }

    // MARK: - Period Routing

    func testSevenDaysUsesIVOnly() async {
        mockSession.handler = { url in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        // All requested URLs should be IV (not DV)
        for url in mockSession.requestedURLs {
            XCTAssertTrue(url.absoluteString.contains("/iv/"), "7-day should only use IV endpoint, got: \(url)")
            XCTAssertFalse(url.absoluteString.contains("/dv/"), "7-day should not use DV endpoint")
        }
    }

    func testThirtyDaysTriesDVFirst() async {
        var firstURL: URL?
        mockSession.handler = { url in
            if firstURL == nil { firstURL = url }
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)
        await service.fetchLakeLevel(period: .thirtyDays)

        XCTAssertNotNil(firstURL)
        // The first URL in the 30-day fetch should be DV
        // (skip the 7-day IV URLs from fetchLakeLevel(for:))
        let thirtyDayURLs = mockSession.requestedURLs.filter { $0.absoluteString.contains("P30D") }
        XCTAssertFalse(thirtyDayURLs.isEmpty, "Should have made 30-day requests")
        XCTAssertTrue(thirtyDayURLs.first!.absoluteString.contains("/dv/"), "30-day should try DV first")
    }

    func testThirtyDaysFallsBackToIVWhenDVFails() async {
        mockSession.handler = { url in
            if url.absoluteString.contains("/dv/") {
                throw URLError(.badServerResponse)
            }
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)
        await service.fetchLakeLevel(period: .thirtyDays)

        XCTAssertNotNil(service.currentLevel)
        XCTAssertEqual(service.dataSource, "Real-time", "Should fall back to IV (Real-time)")
    }

    // MARK: - Cache Behavior

    func testFetchSavesToCacheOnSuccess() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        let cached = LakeLevelCache.shared.load(lakeId: testLake.id, period: "P7D")
        XCTAssertNotNil(cached, "Successful fetch should save to cache")
        XCTAssertEqual(cached?.level.value, 438.50)
    }

    func testFetchShowsCachedDataWhenNetworkFails() async {
        // First: save some data to cache
        let level = LakeLevel(value: 435.00, unit: "ft", dateTime: Date(), siteName: "Test Lake")
        let readings = [LakeLevelReading(value: 435.00, dateTime: Date())]
        LakeLevelCache.shared.save(
            lakeId: testLake.id, level: level, readings: readings,
            period: "P7D", dataSource: "Real-time"
        )

        // Now: make all network calls fail
        mockSession.handler = { _ in throw URLError(.notConnectedToInternet) }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertNotNil(service.currentLevel)
        XCTAssertEqual(service.currentLevel?.value, 435.00)
        XCTAssertTrue(service.isFromCache)
        XCTAssertNil(service.error, "Error should be nil when cached data is available")
    }

    func testFetchSetsErrorWhenNeitherNetworkNorCacheAvailable() async {
        mockSession.handler = { _ in throw URLError(.notConnectedToInternet) }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service.error, "No water level data available for this lake")
    }

    func testFetchIsNotFromCacheOnSuccess() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertFalse(service.isFromCache, "Fresh fetch should not be marked as from cache")
    }

    // MARK: - Response Parsing

    func testParseResponseFiltersSentinelValues() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "-999999", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "-999999.00", dateTime: "2026-01-25T13:00:00.000-05:00"),
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service.historicalReadings.count, 1, "Sentinel values should be filtered out")
        XCTAssertEqual(service.currentLevel?.value, 438.50)
    }

    func testParseResponseFiltersEmptyValueStrings() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service.historicalReadings.count, 1, "Empty value strings should be filtered out")
    }

    func testParseResponseFiltersNonNumericValues() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "Ice", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "N/A", dateTime: "2026-01-25T13:00:00.000-05:00"),
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service.historicalReadings.count, 1, "Non-numeric values should be filtered out")
    }

    func testParseResponseFiltersOutOfRangeValues() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "-200.0", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "20000.0", dateTime: "2026-01-25T13:00:00.000-05:00"),
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service.historicalReadings.count, 1, "Out-of-range values should be filtered out")
    }

    func testParseResponseSortsReadingsChronologically() async {
        mockSession.handler = { _ in
            // Send readings out of order
            let data = makeUSGSJSON(readings: [
                (value: "438.60", dateTime: "2026-01-25T16:00:00.000-05:00"),
                (value: "438.40", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service.historicalReadings.count, 3)
        // Should be sorted ascending
        XCTAssertEqual(service.historicalReadings[0].value, 438.40)
        XCTAssertEqual(service.historicalReadings[1].value, 438.50)
        XCTAssertEqual(service.historicalReadings[2].value, 438.60)
    }

    func testParseResponseUsesLastReadingAsCurrentLevel() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "438.40", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "438.60", dateTime: "2026-01-25T16:00:00.000-05:00"),
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        // After sorting, 438.60 (16:00) is the most recent
        XCTAssertEqual(service.currentLevel?.value, 438.60)
    }

    // MARK: - HTTP Error Handling

    func testFetchHandlesNon200StatusCode() async {
        mockSession.handler = { _ in
            return (Data(), makeHTTPResponse(statusCode: 404))
        }

        await service.fetchLakeLevel(for: testLake)

        // Should set error since no data was parseable
        XCTAssertNotNil(service.error)
    }

    func testFetchHandlesEmptyTimeSeries() async {
        mockSession.handler = { _ in
            return (makeEmptyUSGSJSON(), makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        // Should try all parameter codes and fail gracefully
        XCTAssertNotNil(service.error)
        XCTAssertNil(service.currentLevel)
    }

    func testFetchHandlesOversizedResponse() async {
        mockSession.handler = { _ in
            // Create a response > 10MB
            let bigData = Data(count: 11_000_000)
            return (bigData, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        // Should reject oversized response and set error
        XCTAssertNotNil(service.error)
    }

    // MARK: - Parameter Code Fallthrough

    func testFetchTriesMultipleParameterCodes() async {
        var callCount = 0
        mockSession.handler = { url in
            callCount += 1
            // Only succeed on the 3rd parameter code (62615)
            if url.absoluteString.contains("parameterCd=62615") {
                let data = makeUSGSJSON(readings: [
                    (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
                ])
                return (data, makeHTTPResponse())
            }
            // Return empty for other parameter codes
            return (makeEmptyUSGSJSON(), makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertNotNil(service.currentLevel, "Should find data with 3rd parameter code")
        XCTAssertTrue(callCount >= 3, "Should have tried at least 3 parameter codes")
    }

    func testFetchContinuesAfterNetworkErrorOnOneParam() async {
        var callCount = 0
        mockSession.handler = { url in
            callCount += 1
            // Throw error on first two, succeed on third
            if callCount <= 2 {
                throw URLError(.timedOut)
            }
            let data = makeUSGSJSON(readings: [
                (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertNotNil(service.currentLevel, "Should succeed after earlier parameter codes fail")
    }

    // MARK: - URL Construction

    func testURLContainsSiteId() async {
        mockSession.handler = { _ in throw URLError(.cancelled) }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertTrue(
            mockSession.requestedURLs.allSatisfy { $0.absoluteString.contains("sites=02166500") },
            "All URLs should contain the lake's site ID"
        )
    }

    func testURLContainsPeriodCode() async {
        mockSession.handler = { _ in throw URLError(.cancelled) }

        await service.fetchLakeLevel(for: testLake)

        XCTAssertTrue(
            mockSession.requestedURLs.allSatisfy { $0.absoluteString.contains("period=P7D") },
            "All URLs should contain the period code"
        )
    }

    func testDVURLContainsStatCode() async {
        mockSession.handler = { url in
            if url.absoluteString.contains("/dv/") {
                let data = makeUSGSJSON(readings: [
                    (value: "438.50", dateTime: "2026-01-25")
                ])
                return (data, makeHTTPResponse())
            }
            throw URLError(.badServerResponse)
        }

        await service.fetchLakeLevel(for: testLake)
        await service.fetchLakeLevel(period: .thirtyDays)

        let dvURLs = mockSession.requestedURLs.filter { $0.absoluteString.contains("/dv/") }
        XCTAssertFalse(dvURLs.isEmpty)
        XCTAssertTrue(
            dvURLs.allSatisfy { $0.absoluteString.contains("statCd=00003") },
            "DV URLs should contain statCd=00003"
        )
    }

    // MARK: - Integration Tests

    func testFetchThenCacheRoundTrip() async {
        let readings = [
            (value: "438.40", dateTime: "2026-01-25T12:00:00.000-05:00"),
            (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00"),
            (value: "438.60", dateTime: "2026-01-25T16:00:00.000-05:00")
        ]
        mockSession.handler = { _ in
            return (makeUSGSJSON(readings: readings), makeHTTPResponse())
        }

        // Fetch populates cache
        await service.fetchLakeLevel(for: testLake)
        let originalLevel = service.currentLevel?.value
        let originalCount = service.historicalReadings.count

        // Create a new service with a failing session — forces cache usage
        let failingSession = MockURLSession()
        failingSession.handler = { _ in throw URLError(.notConnectedToInternet) }
        let service2 = LakeLevelService(session: failingSession)

        await service2.fetchLakeLevel(for: testLake)

        XCTAssertEqual(service2.currentLevel?.value, originalLevel, "Cached level should match original")
        XCTAssertEqual(service2.historicalReadings.count, originalCount, "Cached readings count should match")
        XCTAssertTrue(service2.isFromCache)
    }

    func testPeriodSwitchingPreservesCache() async {
        mockSession.handler = { url in
            if url.absoluteString.contains("P7D") {
                return (makeUSGSJSON(readings: [
                    (value: "438.50", dateTime: "2026-01-25T14:00:00.000-05:00")
                ]), makeHTTPResponse())
            } else if url.absoluteString.contains("P30D") {
                if url.absoluteString.contains("/dv/") {
                    return (makeUSGSJSON(readings: [
                        (value: "440.00", dateTime: "2026-01-01"),
                        (value: "439.00", dateTime: "2026-01-15"),
                        (value: "438.00", dateTime: "2026-01-25")
                    ]), makeHTTPResponse())
                }
            }
            throw URLError(.badServerResponse)
        }

        // Fetch 7-day
        await service.fetchLakeLevel(for: testLake)
        XCTAssertEqual(service.currentLevel?.value, 438.50)

        // Switch to 30-day
        await service.fetchLakeLevel(period: .thirtyDays)
        XCTAssertEqual(service.currentLevel?.value, 438.00) // most recent chronologically (Jan 25)

        // Verify both periods are cached independently
        let cached7 = LakeLevelCache.shared.load(lakeId: testLake.id, period: "P7D")
        let cached30 = LakeLevelCache.shared.load(lakeId: testLake.id, period: "P30D")

        XCTAssertNotNil(cached7)
        XCTAssertNotNil(cached30)
        XCTAssertEqual(cached7?.level.value, 438.50)
        XCTAssertEqual(cached30?.level.value, 438.00)
        XCTAssertEqual(cached7?.readings.count, 1)
        XCTAssertEqual(cached30?.readings.count, 3)
    }

    func testFullLakeDetailFlow() async {
        mockSession.handler = { _ in
            let data = makeUSGSJSON(readings: [
                (value: "435.00", dateTime: "2026-01-25T10:00:00.000-05:00"),
                (value: "436.00", dateTime: "2026-01-25T12:00:00.000-05:00"),
                (value: "437.00", dateTime: "2026-01-25T14:00:00.000-05:00"),
                (value: "438.00", dateTime: "2026-01-25T16:00:00.000-05:00")
            ])
            return (data, makeHTTPResponse())
        }

        // Step 1: Select lake and fetch
        await service.fetchLakeLevel(for: testLake)

        // Step 2: Verify current level
        XCTAssertNotNil(service.currentLevel)
        XCTAssertEqual(service.currentLevel?.value, 438.00)
        XCTAssertEqual(service.currentLevel?.unit, "ft")
        XCTAssertEqual(service.currentLevel?.siteName, "Test Lake")

        // Step 3: Verify historical readings
        XCTAssertEqual(service.historicalReadings.count, 4)

        // Step 4: Verify stats
        XCTAssertEqual(service.minLevel, 435.00)
        XCTAssertEqual(service.maxLevel, 438.00)
        XCTAssertEqual(service.averageLevel, 436.50)

        // Step 5: Verify state
        XCTAssertFalse(service.isLoading)
        XCTAssertFalse(service.isFromCache)
        XCTAssertEqual(service.dataSource, "Real-time")
        XCTAssertNil(service.error)
    }

    func testFavoriteLakesMatchCatalogAfterAddRemove() {
        let favService = FavoritesService()
        UserDefaults.standard.removeObject(forKey: "favoriteLakes")

        let lakes = Array(LakeCatalog.lakes.prefix(4))

        // Add all 4
        for lake in lakes {
            favService.addFavorite(lake)
        }
        XCTAssertEqual(favService.favoriteLakes.count, 4)

        // Remove 2
        favService.removeFavorite(lakes[1])
        favService.removeFavorite(lakes[3])

        let remaining = favService.favoriteLakes
        XCTAssertEqual(remaining.count, 2)
        XCTAssertTrue(remaining.contains { $0.id == lakes[0].id })
        XCTAssertTrue(remaining.contains { $0.id == lakes[2].id })

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "favoriteLakes")
    }

    // MARK: - Cache Integrity Tests

    func testCacheRejectsDataWithMismatchedLakeId() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let tampered = CachedLakeData(
            lakeId: "WRONG_ID", level: level, readings: [],
            period: "P7D", dataSource: "Real-time", cachedAt: Date()
        )

        // Write tampered data to the cache file for "CORRECT_ID"
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LakeLevelCache", isDirectory: true)
        let fileURL = cacheDir.appendingPathComponent("CORRECT_ID_P7D.json")
        let data = try! JSONEncoder().encode(tampered)
        try! data.write(to: fileURL, options: .atomic)

        let loaded = LakeLevelCache.shared.load(lakeId: "CORRECT_ID", period: "P7D")
        XCTAssertNil(loaded, "Cache should reject data where lakeId doesn't match request")
    }

    func testCacheRejectsDataWithFutureTimestamp() {
        let level = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        let future = CachedLakeData(
            lakeId: "FUTURE001", level: level, readings: [],
            period: "P7D", dataSource: "Real-time",
            cachedAt: Date().addingTimeInterval(86400) // 1 day in the future
        )

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LakeLevelCache", isDirectory: true)
        let fileURL = cacheDir.appendingPathComponent("FUTURE001_P7D.json")
        let data = try! JSONEncoder().encode(future)
        try! data.write(to: fileURL, options: .atomic)

        let loaded = LakeLevelCache.shared.load(lakeId: "FUTURE001", period: "P7D")
        XCTAssertNil(loaded, "Cache should reject data with future timestamp")
    }
}
