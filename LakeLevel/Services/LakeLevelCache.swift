//
//  LakeLevelCache.swift
//  LakeLevel
//
//  Created by Sabrina on 1/25/26.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nuvotech.LakeLevel", category: "LakeLevelCache")

/// Manages offline caching of lake level data
final class LakeLevelCache {
    static let shared = LakeLevelCache()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.nuvotech.LakeLevel.cache")

    // Cache expiration: 7 days
    private let maxCacheAge: TimeInterval = 7 * 24 * 3600

    private init() {
        let fileManager = self.fileManager
        if let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheDirectory = cachesDirectory.appendingPathComponent("LakeLevelCache", isDirectory: true)
        } else {
            logger.warning("Caches directory unavailable, falling back to temp directory")
            cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("LakeLevelCache", isDirectory: true)
        }

        // Create cache directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create cache directory: \(error.localizedDescription)")
            }
        }

        logger.info("Cache directory: \(self.cacheDirectory.path)")
    }

    // MARK: - Public API

    /// Save lake data to cache
    func save(
        lakeId: String,
        level: LakeLevel,
        readings: [LakeLevelReading],
        period: String,
        dataSource: String
    ) {
        let cached = CachedLakeData(
            lakeId: lakeId,
            level: level,
            readings: readings,
            period: period,
            dataSource: dataSource,
            cachedAt: Date()
        )

        let fileURL = cacheFileURL(for: lakeId, period: period)

        queue.sync {
            do {
                let data = try self.encoder.encode(cached)
                try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
                logger.info("Cached data for \(lakeId) (\(period))")
            } catch {
                logger.error("Failed to cache data for \(lakeId): \(error.localizedDescription)")
            }
        }
    }

    /// Load cached data for a lake
    func load(lakeId: String, period: String) -> CachedLakeData? {
        let fileURL = cacheFileURL(for: lakeId, period: period)

        return queue.sync {
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                return nil
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let cached = try self.decoder.decode(CachedLakeData.self, from: data)

                // Check if cache is too old
                if cached.cacheAge > self.maxCacheAge {
                    logger.info("Cache expired for \(lakeId) (\(period))")
                    try? self.fileManager.removeItem(at: fileURL)
                    return nil
                }

                // Integrity check: verify cached data matches request
                guard cached.lakeId == lakeId, cached.period == period else {
                    logger.warning("Cache integrity mismatch for \(lakeId) (\(period))")
                    try? self.fileManager.removeItem(at: fileURL)
                    return nil
                }

                // Integrity check: cachedAt should not be in the future
                guard cached.cachedAt <= Date() else {
                    logger.warning("Cache has future timestamp for \(lakeId)")
                    try? self.fileManager.removeItem(at: fileURL)
                    return nil
                }

                logger.info("Loaded cached data for \(lakeId) (\(period)), age: \(cached.cacheAgeFormatted)")
                return cached
            } catch {
                logger.error("Failed to load cache for \(lakeId): \(error.localizedDescription)")
                return nil
            }
        }
    }

    /// Check if we have any cached data for a lake (any period)
    func hasCachedData(for lakeId: String) -> Bool {
        let periods = ["P7D", "P30D", "P365D"]
        return periods.contains { period in
            let fileURL = cacheFileURL(for: lakeId, period: period)
            return fileManager.fileExists(atPath: fileURL.path)
        }
    }

    /// Clear all cached data
    func clearAll() {
        queue.sync {
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
                logger.info("Cleared all cache")
            } catch {
                logger.error("Failed to clear cache: \(error.localizedDescription)")
            }
        }
    }

    /// Clear cached data for a specific lake
    func clear(lakeId: String) {
        let periods = ["P7D", "P30D", "P365D"]
        queue.sync {
            for period in periods {
                let fileURL = self.cacheFileURL(for: lakeId, period: period)
                try? self.fileManager.removeItem(at: fileURL)
            }
            logger.info("Cleared cache for \(lakeId)")
        }
    }

    /// Get total cache size in bytes
    var cacheSize: Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    /// Get formatted cache size
    var cacheSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: cacheSize)
    }

    // MARK: - Private

    private func cacheFileURL(for lakeId: String, period: String) -> URL {
        let safeLakeId = sanitizePathComponent(lakeId)
        let safePeriod = sanitizePathComponent(period)
        let filename = "\(safeLakeId)_\(safePeriod).json"
        return cacheDirectory.appendingPathComponent(filename)
    }

    private func sanitizePathComponent(_ input: String) -> String {
        input.replacingOccurrences(of: "..", with: "_")
             .replacingOccurrences(of: "/", with: "_")
             .replacingOccurrences(of: "\\", with: "_")
    }
}
