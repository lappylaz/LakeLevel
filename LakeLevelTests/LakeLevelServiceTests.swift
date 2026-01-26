//
//  LakeLevelServiceTests.swift
//  LakeLevelTests
//
//  Created by Sabrina on 1/25/26.
//

import XCTest
@testable import LakeLevel

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
}
