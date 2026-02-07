# Security Audit: Models & Views Layer

**Auditor:** views-auditor
**Date:** 2026-02-07
**Scope:** Models (`Lake.swift`, `LakeCatalog.swift`), Views (`LakeDetailView.swift`, `LakeListView.swift`, `ContentView.swift`, `LakeLevelApp.swift`), Components (`InfoRow.swift`, `LakeRowView.swift`, `StatBox.swift`)
**Services reviewed for context:** `FavoritesService.swift`, `LakeLevelService.swift`, `LakeLevelCache.swift`

---

## Executive Summary

The Models and Views layer of the LakeLevel app is **generally well-constructed** from a security standpoint. The app reads from a curated static catalog and a single trusted API (USGS), uses SwiftUI's native text rendering (immune to XSS), and has no deep link handling or user-generated content paths. Most findings are low severity. The two medium-severity findings relate to potential URL injection via the `Lake.id` field and a force-unwrap crash risk in the cache layer.

**Overall Risk Rating: LOW**

| Severity | Count |
|----------|-------|
| High     | 0     |
| Medium   | 2     |
| Low      | 5     |
| Info     | 3     |

---

## Medium Severity Findings

### M-1: URL Construction with Unsanitized `Lake.id` Could Enable Request Forgery

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Models/Lake.swift` (line 22)
**Also affects:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Services/LakeLevelService.swift` (line 192)

**Description:**
The `Lake.id` field is used directly in URL construction without sanitization or validation:

```swift
// Lake.swift:22
var usgsURL: URL? {
    URL(string: "https://waterdata.usgs.gov/monitoring-location/\(id)/")
}

// LakeLevelService.swift:192
var urlString = "\(baseURL)?sites=\(lake.id)&parameterCd=\(parameterCode)&period=\(period.periodCode)&format=json"
```

Currently, all `Lake` instances come from the hardcoded `LakeCatalog`, so the IDs are trusted. However, `Lake` conforms to `Codable`, meaning it can be decoded from external data (e.g., cache files, future API endpoints, shared links). If a crafted `Lake` object with a malicious `id` (e.g., `"foo&redirect=evil.com"` or `"../../../other-path"`) were deserialized, it could:
- Alter the USGS API query parameters (parameter injection)
- Construct unintended URLs opened via `Link(destination:)` in `LakeDetailView.swift` (line 357)

**Risk:** If the app ever adds features like shared lake links, Handoff, or URL scheme handling, this becomes exploitable. Currently mitigated by the static catalog.

**Recommended Fix:**
```swift
// Lake.swift - Add ID validation
var usgsURL: URL? {
    // Percent-encode the id to prevent path traversal or parameter injection
    guard let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
        return nil
    }
    return URL(string: "https://waterdata.usgs.gov/monitoring-location/\(encodedId)/")
}

// LakeLevelService.swift - Validate lake.id before use in URL
guard let encodedSiteId = lake.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
var urlString = "\(baseURL)?sites=\(encodedSiteId)&parameterCd=\(parameterCode)..."
```

---

### M-2: Force-Unwrap in Cache Initialization Can Crash the App

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Services/LakeLevelCache.swift` (line 26)

**Description:**
```swift
let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
```

The `first!` force-unwrap will crash the app if `urls(for:in:)` returns an empty array. While this is extremely unlikely on iOS (the caches directory always exists), it is technically possible in sandboxed or constrained environments, and it violates defensive coding principles.

**Recommended Fix:**
```swift
guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
    // Fall back to temp directory
    cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("LakeLevelCache", isDirectory: true)
    // ... continue setup
    return
}
cacheDirectory = cachesDirectory.appendingPathComponent("LakeLevelCache", isDirectory: true)
```

---

## Low Severity Findings

### L-1: Cache File Naming Uses Unsanitized Input

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Services/LakeLevelCache.swift` (line 148-150)

**Description:**
```swift
private func cacheFileURL(for lakeId: String, period: String) -> URL {
    let filename = "\(lakeId)_\(period).json"
    return cacheDirectory.appendingPathComponent(filename)
}
```

If `lakeId` contained path separators (e.g., `"../../malicious"`), the resulting file path could escape the cache directory. Currently mitigated because all IDs come from the static catalog, but this is a latent path traversal vulnerability.

**Recommended Fix:**
```swift
private func cacheFileURL(for lakeId: String, period: String) -> URL {
    // Strip any path separator characters from inputs
    let safeLakeId = lakeId.replacingOccurrences(of: "/", with: "_")
                           .replacingOccurrences(of: "\\", with: "_")
                           .replacingOccurrences(of: "..", with: "_")
    let safePeriod = period.replacingOccurrences(of: "/", with: "_")
    let filename = "\(safeLakeId)_\(safePeriod).json"
    return cacheDirectory.appendingPathComponent(filename)
}
```

---

### L-2: No Validation of Decoded Cache Data Integrity

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Services/LakeLevelCache.swift` (lines 68-91)

**Description:**
When loading cached data, the cache deserializes JSON from disk without validating the integrity or plausibility of the data:

```swift
let data = try Data(contentsOf: fileURL)
let cached = try decoder.decode(CachedLakeData.self, from: data)
```

If the cache file were tampered with (e.g., by another app in a shared container, or via a backup-restore attack), the app would display arbitrary values. For example, manipulated water level readings could show dangerously incorrect data.

**Recommended Fix:** Add basic plausibility validation after decoding (e.g., verify `lakeId` matches the requested ID, readings have reasonable value ranges, `cachedAt` is not in the future).

---

### L-3: `LakeLevelService` Creates a New Instance Per `LakeDetailView` Navigation

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Views/LakeDetailView.swift` (line 13)

**Description:**
```swift
@StateObject private var lakeLevelService = LakeLevelService()
```

Each time a user navigates to a `LakeDetailView`, a brand new `LakeLevelService` is created. This is not a security vulnerability per se, but it means:
- Multiple concurrent network requests could be in-flight if the user rapidly navigates between lakes
- There is no request cancellation when navigating away
- Memory usage scales with navigation depth in the back stack

**Risk:** Potential for excessive network requests and memory pressure. No direct security impact, but could contribute to denial-of-service conditions on the device.

**Recommended Fix:** Consider using `.task` modifier with cancellation, or implementing request deduplication.

---

### L-4: Error Messages Displayed Directly to User Could Leak Internal Details

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Views/LakeDetailView.swift` (line 167)

**Description:**
```swift
Text(error)
    .font(.subheadline)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
```

The `error` property in `LakeLevelService` is set to user-friendly strings like "No water level data available for this lake" and "No lake selected". However, if the error handling were expanded to include raw error descriptions (e.g., `error.localizedDescription`), network details, URLs, or internal state could leak to the UI.

**Current Risk:** Low, since current error strings are intentionally user-friendly. This is a note for future development.

---

### L-5: Favorites Stored in UserDefaults Without Encryption

**File:** `/Users/bblair/Documents/Nuvotech/LakeLevel/LakeLevel/Services/FavoritesService.swift` (lines 21, 27)

**Description:**
```swift
UserDefaults.standard.array(forKey: userDefaultsKey) as? [String]
UserDefaults.standard.set(Array(favoriteLakeIds), forKey: userDefaultsKey)
```

Favorite lake IDs are stored in plaintext in `UserDefaults`. While lake favorites are not sensitive personal data, UserDefaults is readable via device backups (unencrypted) and is not protected by Data Protection by default.

**Risk:** Very low for this data type. If the app ever stored more sensitive preferences (e.g., location data, user accounts), this pattern would be problematic.

---

## Informational Findings

### I-1: No Deep Link or URL Scheme Handling (Positive)

**Files:** `LakeLevelApp.swift`, `ContentView.swift`

The app does not register any URL schemes or universal links. There is no `onOpenURL` handler. This eliminates an entire class of attack vectors (deep link injection, unauthorized navigation). This is a positive security posture.

---

### I-2: SwiftUI Text Rendering Prevents XSS-equivalent Attacks (Positive)

**All view files**

SwiftUI's `Text` view does not interpret HTML or JavaScript. All data displayed in the UI (lake names, IDs, values, error messages) is rendered as plain text. There is no use of `WKWebView`, `UIWebView`, or `AttributedString` with HTML. This means server-returned data (e.g., `siteName` from the USGS API) cannot inject executable content into the UI.

---

### I-3: Good Use of `@MainActor` for Thread Safety (Positive)

**Files:** `LakeLevelService.swift` (line 47), `FavoritesService.swift` (line 11)

Both service classes are annotated with `@MainActor`, ensuring all published property mutations happen on the main thread. This prevents race conditions between async network responses and UI updates. No race condition risks were identified in the async code paths.

---

## Items Not Found (Negative Findings)

The following common vulnerability categories were checked and **no issues were found:**

- **Hardcoded credentials or API keys:** None. The USGS API is public and requires no authentication.
- **Hardcoded URLs pointing to non-production environments:** The only hardcoded URLs are the production USGS endpoints (`waterservices.usgs.gov` and `waterdata.usgs.gov`). These are appropriate.
- **Force unwraps in view code:** No force unwraps in any view files. Only the one in `LakeLevelCache.swift` (covered in M-2).
- **Insecure network configuration (HTTP):** All URLs use HTTPS. ATS compliance is maintained.
- **Keychain or sensitive data mishandling:** The app does not store any sensitive user data.
- **Logging of sensitive data:** Logger calls log lake names and IDs only, which are not sensitive.
- **Missing access control on types:** Model structs are appropriately scoped. `FavoritesService` uses `private(set)` on its published property. `LakeLevelCache` uses a private initializer for singleton enforcement.

---

## Summary of Recommendations

| ID  | Severity | Finding | Fix Effort |
|-----|----------|---------|------------|
| M-1 | Medium   | URL construction with unsanitized `Lake.id` | Low - add percent encoding |
| M-2 | Medium   | Force-unwrap in cache init | Low - add guard |
| L-1 | Low      | Cache filename path traversal | Low - sanitize filename |
| L-2 | Low      | No cache data integrity validation | Medium - add validation |
| L-3 | Low      | No request cancellation on navigation | Medium - use .task modifier |
| L-4 | Low      | Error messages could leak details | Low - maintain current pattern |
| L-5 | Low      | UserDefaults without encryption | Low - acceptable for non-sensitive data |
