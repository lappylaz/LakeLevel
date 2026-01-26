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
        URL(string: "https://waterdata.usgs.gov/monitoring-location/\(id)/")
    }
}

// MARK: - Lake Level Data

struct LakeLevel {
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

struct LakeLevelReading: Identifiable {
    let id = UUID()
    let value: Double
    let dateTime: Date
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
