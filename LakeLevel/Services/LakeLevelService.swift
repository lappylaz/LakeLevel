//
//  LakeLevelService.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.nuvotech.LakeLevel", category: "LakeLevelService")

enum LakeLevelPeriod: String, CaseIterable {
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"
    case oneYear = "1 Year"

    var displayName: String { rawValue }

    var chartTitle: String {
        switch self {
        case .sevenDays: return "7-Day History"
        case .thirtyDays: return "30-Day History"
        case .oneYear: return "1-Year History"
        }
    }

    var statsTitle: String {
        switch self {
        case .sevenDays: return "7-Day Statistics"
        case .thirtyDays: return "30-Day Statistics"
        case .oneYear: return "1-Year Statistics"
        }
    }

    var periodCode: String {
        switch self {
        case .sevenDays: return "P7D"
        case .thirtyDays: return "P30D"
        case .oneYear: return "P365D"
        }
    }
}

@MainActor
final class LakeLevelService: ObservableObject {
    @Published var currentLevel: LakeLevel?
    @Published var historicalReadings: [LakeLevelReading] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedPeriod: LakeLevelPeriod = .sevenDays
    @Published var dataSource: String = "" // Indicates IV or DV data source
    @Published var isFromCache = false
    @Published var cacheAge: String = ""

    private var currentLake: Lake?
    private let cache = LakeLevelCache.shared

    // USGS Parameter codes for water levels (in priority order)
    private let parameterCodes = ["00062", "62614", "62615", "63160", "00065"]

    private let ivBaseURL = "https://waterservices.usgs.gov/nwis/iv/"
    private let dvBaseURL = "https://waterservices.usgs.gov/nwis/dv/"

    private let maxResponseSize = 10_000_000 // 10 MB
    private let validValueRange = -100.0...15_000.0 // Reasonable water level range in feet

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    // MARK: - Cached Date Formatters (performance optimization)

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormatterWithTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()

    private static let dateFormatterBasic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()

    func fetchLakeLevel(for lake: Lake) async {
        currentLake = lake
        await fetchLakeLevel(period: selectedPeriod)
    }

    func fetchLakeLevel(period: LakeLevelPeriod) async {
        guard let lake = currentLake else {
            error = "No lake selected"
            return
        }

        isLoading = true
        error = nil
        selectedPeriod = period
        dataSource = ""
        isFromCache = false
        cacheAge = ""

        logger.info("Fetching \(period.displayName) data for \(lake.name)")

        // Load cached data first to show immediately while fetching
        if let cached = cache.load(lakeId: lake.id, period: period.periodCode) {
            applyCachedResult(cached)
            logger.info("Showing cached data while fetching fresh data")
        }

        // For 7-day period, only use IV (instantaneous values)
        // For 30-day and 1-year, try DV (daily values) first, then fall back to IV
        var fetchedDataSource: String?
        var result: FetchResult?

        if period == .sevenDays {
            result = await fetchFromEndpoint(lake: lake, period: period, useDaily: false)
            if result != nil {
                fetchedDataSource = "Real-time"
            }
        } else {
            // Try DV first for longer periods
            result = await fetchFromEndpoint(lake: lake, period: period, useDaily: true)
            if result != nil {
                fetchedDataSource = "Daily"
            } else {
                // Fall back to IV if DV not available
                logger.info("No daily values, falling back to instantaneous values for \(lake.name)")
                result = await fetchFromEndpoint(lake: lake, period: period, useDaily: false)
                if result != nil {
                    fetchedDataSource = "Real-time"
                }
            }
        }

        if let result = result, let source = fetchedDataSource {
            applyResult(result)
            dataSource = source
            isFromCache = false
            cacheAge = ""

            // Save to cache
            cache.save(
                lakeId: lake.id,
                level: result.level,
                readings: result.readings,
                period: period.periodCode,
                dataSource: source
            )
            return
        }

        // Fetch failed - check if we have cached data to show
        if let cached = cache.load(lakeId: lake.id, period: period.periodCode) {
            applyCachedResult(cached)
            self.error = nil // Clear error since we have cached data
            logger.info("Showing cached data after fetch failed")
        } else {
            // No cached data either
            self.error = "No water level data available for this lake"
        }
        isLoading = false
    }

    private func applyCachedResult(_ cached: CachedLakeData) {
        currentLevel = cached.level
        historicalReadings = cached.readings
        dataSource = cached.dataSource
        isFromCache = true
        cacheAge = cached.cacheAgeFormatted
        isLoading = false
    }

    private struct FetchResult {
        let level: LakeLevel
        let readings: [LakeLevelReading]
    }

    private func fetchFromEndpoint(lake: Lake, period: LakeLevelPeriod, useDaily: Bool) async -> FetchResult? {
        let baseURL = useDaily ? dvBaseURL : ivBaseURL

        guard let encodedSiteId = lake.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            logger.error("Failed to encode site ID: \(lake.id)")
            return nil
        }

        for parameterCode in parameterCodes {
            var urlString = "\(baseURL)?sites=\(encodedSiteId)&parameterCd=\(parameterCode)&period=\(period.periodCode)&format=json"

            if useDaily {
                urlString += "&statCd=00003"
            }

            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }

                guard data.count <= maxResponseSize else {
                    logger.warning("Response too large (\(data.count) bytes), skipping")
                    continue
                }

                let usgsResponse = try JSONDecoder().decode(USGSResponse.self, from: data)

                guard let timeSeries = usgsResponse.value.timeSeries.first,
                      let values = timeSeries.values.first,
                      !values.value.isEmpty else {
                    continue
                }

                let siteName = timeSeries.sourceInfo.siteName
                let unit = timeSeries.variable.unit.unitCode

                var readings: [LakeLevelReading] = []

                for reading in values.value {
                    guard reading.value != "-999999",
                          reading.value != "-999999.00",
                          !reading.value.isEmpty,
                          let value = Double(reading.value),
                          value > -999998,
                          validValueRange.contains(value) else {
                        continue
                    }

                    if let date = parseDate(reading.dateTime) {
                        readings.append(LakeLevelReading(value: value, dateTime: date))
                    }
                }

                if readings.isEmpty { continue }

                readings.sort { $0.dateTime < $1.dateTime }

                guard let mostRecent = readings.last else { continue }

                let level = LakeLevel(
                    value: mostRecent.value,
                    unit: unit,
                    dateTime: mostRecent.dateTime,
                    siteName: siteName
                )

                logger.info("Found \(readings.count) readings with param \(parameterCode) from \(useDaily ? "DV" : "IV")")
                return FetchResult(level: level, readings: readings)

            } catch {
                logger.debug("Error with param \(parameterCode): \(error.localizedDescription)")
                continue
            }
        }

        return nil
    }

    private func applyResult(_ result: FetchResult) {
        currentLevel = result.level
        historicalReadings = result.readings
        isLoading = false
    }

    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 with fractional seconds and timezone first
        if let date = Self.isoFormatterWithFractional.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        if let date = Self.isoFormatterStandard.date(from: dateString) {
            return date
        }

        // Try format without timezone (daily values)
        if let date = Self.dateFormatterWithTime.date(from: dateString) {
            return date
        }

        // Try basic date format
        return Self.dateFormatterBasic.date(from: dateString)
    }

    // MARK: - Date Parsing (exposed for testing)

    static func parseDate(_ dateString: String) -> Date? {
        if let date = isoFormatterWithFractional.date(from: dateString) {
            return date
        }
        if let date = isoFormatterStandard.date(from: dateString) {
            return date
        }
        if let date = dateFormatterWithTime.date(from: dateString) {
            return date
        }
        return dateFormatterBasic.date(from: dateString)
    }

    var minLevel: Double? {
        historicalReadings.map { $0.value }.min()
    }

    var maxLevel: Double? {
        historicalReadings.map { $0.value }.max()
    }

    var averageLevel: Double? {
        guard !historicalReadings.isEmpty else { return nil }
        let sum = historicalReadings.reduce(0) { $0 + $1.value }
        return sum / Double(historicalReadings.count)
    }

    func reset() {
        currentLevel = nil
        historicalReadings = []
        error = nil
        currentLake = nil
        dataSource = ""
        isFromCache = false
        cacheAge = ""
    }
}
