# Security Audit: Services Layer

**Scope:** `LakeLevelService.swift`, `LakeLevelCache.swift`, `FavoritesService.swift`
**Auditor:** services-auditor
**Date:** 2026-02-07

---

## Summary

The Services layer is reasonably well-written for a consumer app consuming a public government API. The most notable findings are around cache path traversal risk, missing network-layer hardening (timeouts, certificate pinning), thread safety in the cache, and the use of a force-unwrap in the cache initializer. No hardcoded secrets or credentials were found. The API endpoints use HTTPS, which is good.

**Finding Count by Severity:**
| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 2 |
| Medium | 5 |
| Low | 4 |

---

## Findings

### HIGH-1: Cache Filename Path Traversal

**File:** `LakeLevelCache.swift`, line 149
**Severity:** High

The `cacheFileURL` method constructs filenames directly from user-influenced parameters (`lakeId` and `period`) without sanitization:

```swift
private func cacheFileURL(for lakeId: String, period: String) -> URL {
    let filename = "\(lakeId)_\(period).json"
    return cacheDirectory.appendingPathComponent(filename)
}
```

If a `lakeId` contained path traversal characters (e.g., `../../etc/passwd`), the resulting file path could escape the cache directory. While the current app uses a hardcoded `LakeCatalog` of lake IDs, this is a defense-in-depth concern -- if the catalog ever becomes dynamic (e.g., fetched from a server, or user-entered custom site IDs), this becomes exploitable.

**Impact:** An attacker-controlled `lakeId` could read/write files outside the cache directory.

**Recommended Fix:**
```swift
private func cacheFileURL(for lakeId: String, period: String) -> URL {
    // Sanitize inputs to prevent path traversal
    let safeLakeId = lakeId.replacingOccurrences(of: "/", with: "_")
                           .replacingOccurrences(of: "\\", with: "_")
                           .replacingOccurrences(of: "..", with: "_")
    let safePeriod = period.replacingOccurrences(of: "/", with: "_")
                           .replacingOccurrences(of: "\\", with: "_")
                           .replacingOccurrences(of: "..", with: "_")
    let filename = "\(safeLakeId)_\(safePeriod).json"
    return cacheDirectory.appendingPathComponent(filename)
}
```

Alternatively, hash the inputs:
```swift
import CryptoKit

private func cacheFileURL(for lakeId: String, period: String) -> URL {
    let key = "\(lakeId)_\(period)"
    let hash = SHA256.hash(data: Data(key.utf8))
    let filename = hash.compactMap { String(format: "%02x", $0) }.joined() + ".json"
    return cacheDirectory.appendingPathComponent(filename)
}
```

---

### HIGH-2: Thread Safety in LakeLevelCache

**File:** `LakeLevelCache.swift`, lines 40-65 (save), 68-92 (load), 104-114 (clearAll)
**Severity:** High

`LakeLevelCache` is a singleton (`shared`) accessed from `@MainActor`-isolated `LakeLevelService`, but the cache class itself has **no actor isolation or synchronization**. If the cache is ever accessed from multiple threads (e.g., background tasks, widgets, or extensions), concurrent reads and writes to the same file could cause data corruption or crashes.

The class uses `FileManager` operations (`write`, `removeItem`, `contentsOfDirectory`) without any locking mechanism.

**Impact:** Data corruption, partial reads, or crashes under concurrent access.

**Recommended Fix:**
Either:
1. Mark `LakeLevelCache` as `@MainActor` to match its caller:
```swift
@MainActor
final class LakeLevelCache {
```

2. Or use a serial `DispatchQueue` for all file I/O:
```swift
final class LakeLevelCache {
    private let queue = DispatchQueue(label: "com.nuvotech.LakeLevel.cache")

    func save(...) {
        queue.sync {
            // existing save logic
        }
    }

    func load(...) -> CachedLakeData? {
        queue.sync {
            // existing load logic
        }
    }
}
```

---

### MEDIUM-1: Force Unwrap in Cache Initializer

**File:** `LakeLevelCache.swift`, line 26
**Severity:** Medium

```swift
let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
```

The force unwrap (`first!`) will crash the app if the caches directory is unavailable. While this is extremely unlikely on iOS, it violates the principle of defensive programming. Since this is in `init()` of a singleton, a crash here is fatal at app launch.

**Impact:** App crash on launch if the system caches directory is unavailable.

**Recommended Fix:**
```swift
guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
    // Fall back to temp directory
    cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("LakeLevelCache", isDirectory: true)
    logger.warning("Caches directory unavailable, using temp directory")
    return
}
cacheDirectory = cachesDirectory.appendingPathComponent("LakeLevelCache", isDirectory: true)
```

---

### MEDIUM-2: No URLSession Timeout Configuration

**File:** `LakeLevelService.swift`, line 201
**Severity:** Medium

```swift
let (data, response) = try await URLSession.shared.data(from: url)
```

The service uses `URLSession.shared` which has a default timeout of 60 seconds. For a mobile app fetching lake data, this could lead to poor UX where the user stares at a spinner for a full minute if the USGS API is unresponsive. More importantly, there is no way to cancel in-flight requests if the user navigates away.

Additionally, `URLSession.shared` provides no custom configuration for:
- Connection timeout
- Resource timeout
- Cellular access policy
- Caching policy at the HTTP layer

**Impact:** Long-hanging requests, poor user experience, no cancellation support.

**Recommended Fix:**
```swift
private lazy var session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 15
    config.timeoutIntervalForResource = 30
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
}()
```

---

### MEDIUM-3: No Response Size Validation

**File:** `LakeLevelService.swift`, line 201
**Severity:** Medium

The `URLSession.shared.data(from: url)` call downloads the entire response into memory without any size limit. A malicious or misconfigured API response could return an extremely large payload, leading to memory exhaustion.

**Impact:** Potential out-of-memory crash if the API returns an unexpectedly large response.

**Recommended Fix:**
Either check `Content-Length` from the HTTP response headers, or use a streaming approach with a maximum byte limit:

```swift
guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200 else {
    continue
}

// Reject unexpectedly large responses (e.g., > 10 MB)
if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
   let length = Int(contentLength), length > 10_000_000 {
    logger.warning("Response too large: \(length) bytes")
    continue
}
```

---

### MEDIUM-4: No API Response Integrity Validation

**File:** `LakeLevelService.swift`, lines 210-248
**Severity:** Medium

While the code checks for the sentinel value `-999999` and empty strings (line 222-227), there is no validation on the **range** of water level values. A corrupted or tampered API response could inject extreme values (e.g., `999999999.0`) that would be accepted and displayed to the user, potentially causing:
- Misleading data display
- Chart rendering issues (extreme axis ranges)
- Cache poisoning with bad data that persists for 7 days

**Impact:** Display of nonsensical data, chart rendering problems, 7-day cache poisoning with bad values.

**Recommended Fix:**
```swift
// Validate reasonable water level range (in feet)
// Most US lakes/reservoirs are between -50 ft and 15,000 ft elevation
guard value > -50, value < 15_000 else {
    logger.warning("Value \(value) outside reasonable range, skipping")
    continue
}
```

---

### MEDIUM-5: Silent Error Swallowing in Directory Creation

**File:** `LakeLevelCache.swift`, line 31
**Severity:** Medium

```swift
try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
```

If directory creation fails (permissions issue, disk full), the error is silently ignored with `try?`. All subsequent cache operations will fail silently, but the user will never know why offline mode is not working.

**Impact:** Silent cache failures with no diagnostic information.

**Recommended Fix:**
```swift
do {
    try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
} catch {
    logger.error("Failed to create cache directory: \(error.localizedDescription)")
}
```

---

### LOW-1: UserDefaults for Favorites (Appropriate but Unencrypted)

**File:** `FavoritesService.swift`, lines 21, 27
**Severity:** Low

```swift
if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
```

Favorites (lake IDs) are stored in `UserDefaults`, which is an unencrypted plist on disk. For this use case (storing USGS site IDs like `"02166500"`), this is **appropriate** -- these are not sensitive data. However, note that:
- UserDefaults is backed up to iCloud (could leak usage patterns)
- UserDefaults is readable by other apps in the same app group

**Impact:** Minimal. Lake ID favorites are not sensitive data. This is noted for completeness.

**Recommendation:** Acceptable as-is. If privacy of which lakes a user monitors becomes a concern, consider using the Keychain or an encrypted database.

---

### LOW-2: No Certificate Pinning

**File:** `LakeLevelService.swift`, line 201
**Severity:** Low

The USGS API calls use standard TLS validation via `URLSession.shared`. There is no certificate pinning, meaning a MITM attacker with a trusted root certificate (e.g., corporate proxy, compromised CA) could intercept the traffic.

**Impact:** Low for this app. The data being fetched (public lake levels) is not sensitive, and the USGS API is publicly accessible. Certificate pinning would be overkill here.

**Recommendation:** Not required for this app. The data is public and non-sensitive. Standard TLS is sufficient.

---

### LOW-3: Cache Data Not Encrypted at Rest

**File:** `LakeLevelCache.swift`, line 60
**Severity:** Low

```swift
try data.write(to: fileURL, options: .atomic)
```

Cached lake level data is written as plaintext JSON to the caches directory. The data is written with `.atomic` (good for integrity), but without any encryption or data protection attributes.

**Impact:** Low. Lake level data is publicly available from USGS. However, the cache could reveal which lakes a user monitors, which is minor usage-pattern leakage.

**Recommendation:** Consider adding `Data.WritingOptions.completeFileProtection` for defense in depth:
```swift
try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
```

---

### LOW-4: Logging May Expose Data in Console

**File:** `LakeLevelService.swift`, lines 112, 117, 137, 248; `LakeLevelCache.swift`, lines 34, 61, 86
**Severity:** Low

Several log statements include lake IDs, site names, and parameter codes. While this data is not sensitive, these logs are visible in Console.app and could be captured in sysdiagnose reports.

**Impact:** Minimal. The logged information is public data (USGS site IDs and names).

**Recommendation:** Acceptable as-is for a development/debug phase. For production, consider using `.debug` log level instead of `.info` for routine operational messages so they are excluded from persistent logs.

---

## Positive Security Observations

These aspects of the code are done well:

1. **HTTPS endpoints** (line 63-64 of `LakeLevelService.swift`): Both `ivBaseURL` and `dvBaseURL` use `https://`, which is correct.

2. **No hardcoded secrets**: No API keys, tokens, or credentials are present anywhere in the services layer. The USGS API is public and requires no authentication.

3. **`@MainActor` isolation**: Both `LakeLevelService` and `FavoritesService` are properly `@MainActor`-isolated, preventing UI-related data races.

4. **Sentinel value filtering** (lines 222-227): The service correctly filters out USGS sentinel values (`-999999`) which indicate missing data.

5. **Atomic file writes** (line 60 of `LakeLevelCache.swift`): Cache writes use `.atomic`, preventing partial writes from corrupting data.

6. **Cache expiration** (lines 80-84 of `LakeLevelCache.swift`): The cache has a 7-day expiration, preventing indefinitely stale data.

7. **Hardcoded lake catalog**: Using a static, hardcoded catalog of verified USGS sites eliminates injection risks from user-controlled site IDs (though the cache should still be hardened as noted in HIGH-1).

8. **No force-unwraps in data parsing**: The `fetchFromEndpoint` method uses safe optionals and `guard` statements throughout the parsing logic.

---

## Risk Summary

| ID | Severity | Finding | File | Line(s) |
|----|----------|---------|------|----------|
| HIGH-1 | High | Cache filename path traversal risk | LakeLevelCache.swift | 149 |
| HIGH-2 | High | Thread safety in singleton cache | LakeLevelCache.swift | 14-152 |
| MEDIUM-1 | Medium | Force unwrap in cache init | LakeLevelCache.swift | 26 |
| MEDIUM-2 | Medium | No URLSession timeout configuration | LakeLevelService.swift | 201 |
| MEDIUM-3 | Medium | No response size validation | LakeLevelService.swift | 201 |
| MEDIUM-4 | Medium | No value range validation on API data | LakeLevelService.swift | 222-227 |
| MEDIUM-5 | Medium | Silent error on directory creation | LakeLevelCache.swift | 31 |
| LOW-1 | Low | UserDefaults for favorites (acceptable) | FavoritesService.swift | 21, 27 |
| LOW-2 | Low | No certificate pinning (acceptable) | LakeLevelService.swift | 201 |
| LOW-3 | Low | Cache not encrypted at rest | LakeLevelCache.swift | 60 |
| LOW-4 | Low | Logging may expose data in console | Multiple | Multiple |
