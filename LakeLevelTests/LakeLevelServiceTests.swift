//
//  LakeLevelServiceTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

@MainActor
final class LakeLevelServiceTests: XCTestCase {

    // MARK: - Date Parsing Tests

    func testParseDateISO8601WithFractionalSeconds() {
        let dateString = "2026-01-25T14:30:45.123-05:00"
        let result = LakeLevelService.parseDate(dateString)

        XCTAssertNotNil(result, "Should parse ISO8601 with fractional seconds")
    }

    func testParseDateISO8601Standard() {
        let dateString = "2026-01-25T14:30:45-05:00"
        let result = LakeLevelService.parseDate(dateString)

        XCTAssertNotNil(result, "Should parse standard ISO8601")
    }

    func testParseDateWithoutTimezone() {
        let dateString = "2026-01-25T14:30:45.000"
        let result = LakeLevelService.parseDate(dateString)

        XCTAssertNotNil(result, "Should parse date without timezone")
    }

    func testParseDateBasicFormat() {
        let dateString = "2026-01-25"
        let result = LakeLevelService.parseDate(dateString)

        XCTAssertNotNil(result, "Should parse basic date format")
    }

    func testParseDateInvalidFormat() {
        let dateString = "invalid-date"
        let result = LakeLevelService.parseDate(dateString)

        XCTAssertNil(result, "Should return nil for invalid date")
    }

    func testParseDateEmptyString() {
        let dateString = ""
        let result = LakeLevelService.parseDate(dateString)

        XCTAssertNil(result, "Should return nil for empty string")
    }

    // MARK: - LakeLevelPeriod Tests

    func testPeriodCodeSevenDays() {
        XCTAssertEqual(LakeLevelPeriod.sevenDays.periodCode, "P7D")
    }

    func testPeriodCodeThirtyDays() {
        XCTAssertEqual(LakeLevelPeriod.thirtyDays.periodCode, "P30D")
    }

    func testPeriodCodeOneYear() {
        XCTAssertEqual(LakeLevelPeriod.oneYear.periodCode, "P365D")
    }

    func testPeriodDisplayNames() {
        XCTAssertEqual(LakeLevelPeriod.sevenDays.displayName, "7 Days")
        XCTAssertEqual(LakeLevelPeriod.thirtyDays.displayName, "30 Days")
        XCTAssertEqual(LakeLevelPeriod.oneYear.displayName, "1 Year")
    }

    func testPeriodChartTitles() {
        XCTAssertEqual(LakeLevelPeriod.sevenDays.chartTitle, "7-Day History")
        XCTAssertEqual(LakeLevelPeriod.thirtyDays.chartTitle, "30-Day History")
        XCTAssertEqual(LakeLevelPeriod.oneYear.chartTitle, "1-Year History")
    }

    func testPeriodStatsTitles() {
        XCTAssertEqual(LakeLevelPeriod.sevenDays.statsTitle, "7-Day Statistics")
        XCTAssertEqual(LakeLevelPeriod.thirtyDays.statsTitle, "30-Day Statistics")
        XCTAssertEqual(LakeLevelPeriod.oneYear.statsTitle, "1-Year Statistics")
    }

    // MARK: - Computed Properties Tests

    func testMinLevelReturnsSmallest() {
        let service = LakeLevelService()
        // Manually set readings via the published property
        service.historicalReadings = [
            LakeLevelReading(value: 100.0, dateTime: Date()),
            LakeLevelReading(value: 50.0, dateTime: Date()),
            LakeLevelReading(value: 200.0, dateTime: Date()),
        ]
        XCTAssertEqual(service.minLevel, 50.0)
    }

    func testMaxLevelReturnsLargest() {
        let service = LakeLevelService()
        service.historicalReadings = [
            LakeLevelReading(value: 100.0, dateTime: Date()),
            LakeLevelReading(value: 50.0, dateTime: Date()),
            LakeLevelReading(value: 200.0, dateTime: Date()),
        ]
        XCTAssertEqual(service.maxLevel, 200.0)
    }

    func testAverageLevelComputesCorrectly() {
        let service = LakeLevelService()
        service.historicalReadings = [
            LakeLevelReading(value: 100.0, dateTime: Date()),
            LakeLevelReading(value: 200.0, dateTime: Date()),
            LakeLevelReading(value: 300.0, dateTime: Date()),
        ]
        XCTAssertEqual(service.averageLevel, 200.0)
    }

    func testMinLevelReturnsNilWhenEmpty() {
        let service = LakeLevelService()
        XCTAssertNil(service.minLevel)
    }

    func testMaxLevelReturnsNilWhenEmpty() {
        let service = LakeLevelService()
        XCTAssertNil(service.maxLevel)
    }

    func testAverageLevelReturnsNilWhenEmpty() {
        let service = LakeLevelService()
        XCTAssertNil(service.averageLevel)
    }

    func testMinMaxWithSingleReading() {
        let service = LakeLevelService()
        service.historicalReadings = [
            LakeLevelReading(value: 42.0, dateTime: Date()),
        ]
        XCTAssertEqual(service.minLevel, 42.0)
        XCTAssertEqual(service.maxLevel, 42.0)
        XCTAssertEqual(service.averageLevel, 42.0)
    }

    // MARK: - Reset Tests

    func testResetClearsAllState() {
        let service = LakeLevelService()
        service.currentLevel = LakeLevel(value: 100.0, unit: "ft", dateTime: Date(), siteName: "Test")
        service.historicalReadings = [LakeLevelReading(value: 100.0, dateTime: Date())]
        service.error = "Some error"
        service.dataSource = "Real-time"
        service.isFromCache = true
        service.cacheAge = "2 hours ago"

        service.reset()

        XCTAssertNil(service.currentLevel)
        XCTAssertTrue(service.historicalReadings.isEmpty)
        XCTAssertNil(service.error)
        XCTAssertEqual(service.dataSource, "")
        XCTAssertFalse(service.isFromCache)
        XCTAssertEqual(service.cacheAge, "")
    }

    // MARK: - Fetch Guard Tests

    func testFetchWithNoLakeSelectedSetsError() async {
        let service = LakeLevelService()
        await service.fetchLakeLevel(period: .sevenDays)

        XCTAssertEqual(service.error, "No lake selected")
    }

    // MARK: - All Periods Enumerable

    func testAllPeriodsAreCovered() {
        XCTAssertEqual(LakeLevelPeriod.allCases.count, 3)
    }
}
