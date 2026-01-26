//
//  LakeCatalog.swift
//  LakeLevel
//
//  Created by Branson Blair on 1/24/26.
//

import Foundation

/// Curated catalog of popular US lakes and reservoirs with verified USGS monitoring stations
/// All sites have been tested to confirm water level data availability
struct LakeCatalog {

    /// All available lakes in the catalog
    static let lakes: [Lake] = [
        // Southeast - South Carolina
        Lake(id: "02166500", name: "Lake Greenwood", state: "SC", latitude: 34.1732, longitude: -82.1137),
        Lake(id: "02169500", name: "Lake Murray", state: "SC", latitude: 34.0454, longitude: -81.2182),

        // Southeast - North Carolina
        Lake(id: "02077280", name: "Hyco Lake", state: "NC", latitude: 36.4092, longitude: -79.0472),
        Lake(id: "02091500", name: "Falls Lake", state: "NC", latitude: 35.9551, longitude: -78.5814),
        Lake(id: "0208458892", name: "Lake Mattamuskeet", state: "NC", latitude: 35.4685, longitude: -76.2094),

        // Southeast - Georgia
        Lake(id: "02344700", name: "West Point Lake", state: "GA", latitude: 32.9101, longitude: -85.1830),
        Lake(id: "02342500", name: "Lake Harding", state: "GA", latitude: 32.7254, longitude: -85.0991),
        Lake(id: "02382200", name: "Lake Allatoona", state: "GA", latitude: 34.1551, longitude: -84.7238),
        Lake(id: "02387500", name: "Lake Weiss", state: "AL", latitude: 34.1465, longitude: -85.6127),

        // Florida
        Lake(id: "02266300", name: "Lake Tohopekaliga", state: "FL", latitude: 28.2361, longitude: -81.3878),
        Lake(id: "02270500", name: "Lake Okeechobee", state: "FL", latitude: 26.9534, longitude: -80.7914),

        // Tennessee Valley
        Lake(id: "03571000", name: "Chickamauga Lake", state: "TN", latitude: 35.2023, longitude: -85.1269),
        Lake(id: "03524000", name: "Cherokee Lake", state: "TN", latitude: 36.2015, longitude: -83.2568),
        Lake(id: "07027000", name: "Reelfoot Lake", state: "TN", latitude: 36.3504, longitude: -89.4131),

        // Texas
        Lake(id: "08051100", name: "Lake Ray Roberts", state: "TX", latitude: 33.3529, longitude: -97.0503),
        Lake(id: "08049500", name: "Lake Lewisville", state: "TX", latitude: 33.0712, longitude: -96.9753),
        Lake(id: "08064100", name: "Lake Livingston", state: "TX", latitude: 30.7093, longitude: -95.0008),
        Lake(id: "08123800", name: "Lake J.B. Thomas", state: "TX", latitude: 32.6149, longitude: -101.2228),
        Lake(id: "07227900", name: "Lake Meredith", state: "TX", latitude: 35.5789, longitude: -101.5678),
        Lake(id: "07312000", name: "Lake Kemp", state: "TX", latitude: 33.7545, longitude: -99.1489),
        Lake(id: "07332610", name: "Lake Bonham", state: "TX", latitude: 33.6287, longitude: -96.1789),

        // Northeast
        Lake(id: "04249000", name: "Lake Ontario at Oswego", state: "NY", latitude: 43.4653, longitude: -76.5119),
        Lake(id: "04294500", name: "Lake Champlain", state: "VT", latitude: 44.4759, longitude: -73.2207),

        // Midwest
        Lake(id: "04085200", name: "Lake Winnebago", state: "WI", latitude: 44.0028, longitude: -88.4262),
        Lake(id: "04176500", name: "Lake Erie at Monroe", state: "MI", latitude: 41.8981, longitude: -83.3777),

        // West - Utah/Nevada/Arizona
        Lake(id: "09380000", name: "Lake Powell", state: "UT", latitude: 37.0689, longitude: -111.2558),
        Lake(id: "09421500", name: "Lake Mead", state: "NV", latitude: 36.0160, longitude: -114.7377),
        Lake(id: "09384600", name: "Lyman Lake", state: "AZ", latitude: 34.3481, longitude: -109.3531),

        // West - California
        Lake(id: "11370500", name: "Shasta Lake", state: "CA", latitude: 40.7179, longitude: -122.4194),
        Lake(id: "11450000", name: "Clear Lake", state: "CA", latitude: 39.0335, longitude: -122.8347),
        Lake(id: "10336645", name: "Lake Tahoe", state: "CA", latitude: 39.0968, longitude: -120.0324),

        // Pacific Northwest
        Lake(id: "12472800", name: "Banks Lake", state: "WA", latitude: 47.8665, longitude: -119.1578),
        Lake(id: "14210000", name: "Bonneville Pool", state: "OR", latitude: 45.6387, longitude: -121.9406)
    ]

    /// Get lakes grouped by state
    static var lakesByState: [String: [Lake]] {
        Dictionary(grouping: lakes, by: { $0.state })
    }

    /// Get all unique states
    static var states: [String] {
        Array(Set(lakes.map { $0.state })).sorted()
    }

    /// Search lakes by name or state
    static func search(_ query: String) -> [Lake] {
        guard !query.isEmpty else { return lakes }
        let lowercased = query.lowercased()
        return lakes.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.state.lowercased().contains(lowercased)
        }
    }

    /// Get a lake by its USGS site ID
    static func lake(byId id: String) -> Lake? {
        lakes.first { $0.id == id }
    }
}
