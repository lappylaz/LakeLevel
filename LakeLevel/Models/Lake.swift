//
//  Lake.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import Foundation

struct Lake: Identifiable, Codable, Hashable {
    let id: String  // USGS site number
    let name: String
    let state: String
    let latitude: Double?
    let longitude: Double?

    var displayName: String {
        "\(name), \(state)"
    }

    var usgsURL: URL? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_")
        guard let encodedId = id.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "https://waterdata.usgs.gov/monitoring-location/\(encodedId)/")
    }
}

// MARK: - Lake Level Data

struct LakeLevel: Codable {
    let value: Double
    let unit: String
    let dateTime: Date
    let siteName: String

    var valueFormatted: String {
        String(format: "%.2f", value)
    }

    var dateFormatted: String {
        dateTime.formatted(date: .abbreviated, time: .shortened)
    }
}

struct LakeLevelReading: Identifiable, Codable {
    let id: UUID
    let value: Double
    let dateTime: Date

    init(value: Double, dateTime: Date) {
        self.id = UUID()
        self.value = value
        self.dateTime = dateTime
    }
}

// MARK: - Cached Lake Data

struct CachedLakeData: Codable {
    let lakeId: String
    let level: LakeLevel
    let readings: [LakeLevelReading]
    let period: String
    let dataSource: String
    let cachedAt: Date

    var cacheAge: TimeInterval {
        Date().timeIntervalSince(cachedAt)
    }

    var cacheAgeFormatted: String {
        let hours = Int(cacheAge / 3600)
        let minutes = Int((cacheAge.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }

    var isStale: Bool {
        // Consider cache stale after 1 hour
        cacheAge > 3600
    }
}

// MARK: - USGS API Response Models

struct USGSResponse: Codable {
    let value: USGSValue
}

struct USGSValue: Codable {
    let timeSeries: [USGSTimeSeries]
}

struct USGSTimeSeries: Codable {
    let sourceInfo: USGSSourceInfo
    let variable: USGSVariable
    let values: [USGSValues]
}

struct USGSSourceInfo: Codable {
    let siteName: String
}

struct USGSVariable: Codable {
    let variableName: String
    let unit: USGSUnit
}

struct USGSUnit: Codable {
    let unitCode: String
}

struct USGSValues: Codable {
    let value: [USGSReading]
}

struct USGSReading: Codable {
    let value: String
    let dateTime: String
}
