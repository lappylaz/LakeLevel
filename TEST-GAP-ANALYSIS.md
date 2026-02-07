# Test Gap Analysis Report

**Date:** 2026-02-07
**Analyzed by:** test-analyst
**Scope:** All 5 test files and 5 source files in the LakeLevel project

---

## Executive Summary

The existing test suite provides solid **happy-path coverage** for the data models, catalog, favorites service, cache, and date parsing. However, there are significant gaps in **error handling**, **edge cases**, **security/robustness**, **concurrency**, and **integration-level testing**. The `LakeLevelService` -- the most complex class in the codebase -- has almost no tests beyond its static `parseDate` helper and the `LakeLevelPeriod` enum. The network-fetching logic, caching integration, state transitions, and error recovery paths are entirely untested.

---

## Current Coverage Summary

### What is well covered

| File | Coverage Quality | Notes |
|------|-----------------|-------|
| LakeModelTests.swift | Good | `Lake` properties, `LakeLevel.valueFormatted`, `LakeLevelReading` identity |
| LakeCatalogTests.swift | Good | Search, grouping, data integrity, unique IDs, coordinate ranges |
| FavoritesServiceTests.swift | Good | Add/remove/toggle, persistence, computed property filtering |
| LakeLevelCacheTests.swift | Good | Save/load, period separation, clear, size, basic staleness |
| LakeLevelServiceTests.swift | **Weak** | Only tests `parseDate` (6 tests) and `LakeLevelPeriod` enum properties (5 tests). Zero tests for actual service fetch logic, state management, or error handling. |

### What is NOT covered at all

- `LakeLevelService.fetchLakeLevel()` -- all network/fetch logic
- `LakeLevelService.fetchFromEndpoint()` -- URL construction, response parsing, parameter fallback
- `LakeLevelService` state management (`isLoading`, `error`, `isFromCache`, `dataSource`, `cacheAge`)
- `LakeLevelService` computed properties (`minLevel`, `maxLevel`, `averageLevel`)
- `LakeLevelService.reset()`
- `LakeLevelService` cache-first-then-fetch strategy
- USGS response model decoding (`USGSResponse`, etc.)
- `CachedLakeData` computed properties beyond basic staleness
- `LakeLevel.dateFormatted`
- `Lake.usgsURL` with edge-case IDs
- Cache expiration (7-day max age)
- Cache corruption / malformed file handling
- Concurrent access patterns

---

## Prioritized Gap Analysis by File

### Priority 1 (Critical) -- LakeLevelServiceTests.swift

The service is the core of the app and has almost no meaningful tests.

#### 1.1 Missing: Network Fetch Logic (requires protocol-based URLSession mock)

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 1 | `testFetchLakeLevelSetsIsLoadingTrue` | Verify loading state is set before async work begins |
| 2 | `testFetchLakeLevelClearsErrorOnNewFetch` | Previous errors should not persist across fetches |
| 3 | `testFetchLakeLevelWithNoLakeSelectedSetsError` | Guard clause at line 100-103 needs coverage |
| 4 | `testFetchLakeLevelForLakeSetsCurrentLake` | Verify `fetchLakeLevel(for:)` stores the lake |
| 5 | `testFetchLakeLevelSevenDaysUsesIVOnly` | 7-day period must only use instantaneous values endpoint |
| 6 | `testFetchLakeLevelThirtyDaysTriesDVFirst` | 30-day period should try daily values first |
| 7 | `testFetchLakeLevelThirtyDaysFallsBackToIVWhenDVFails` | Fallback path for longer periods |
| 8 | `testFetchLakeLevelOneYearTriesDVFirst` | Same DV-first behavior for 1-year |
| 9 | `testFetchPopulatesCurrentLevelAndReadings` | Verify result is applied correctly |
| 10 | `testFetchSetsDataSourceToRealtimeForIV` | Source label correctness |
| 11 | `testFetchSetsDataSourceToDailyForDV` | Source label correctness |
| 12 | `testFetchSavesToCacheOnSuccess` | Cache write after successful fetch |
| 13 | `testFetchShowsCachedDataWhenNetworkFails` | Offline fallback behavior |
| 14 | `testFetchClearsErrorWhenCachedDataAvailableAfterFailure` | Line 165: error set to nil |
| 15 | `testFetchSetsErrorWhenNeitherNetworkNorCacheAvailable` | "No water level data available" error message |
| 16 | `testFetchShowsCachedDataImmediatelyWhileFetching` | Cache-first UX strategy |

#### 1.2 Missing: Response Parsing Robustness

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 17 | `testParseResponseFiltersOutSentinelValues` | -999999 and -999999.00 must be excluded |
| 18 | `testParseResponseFiltersEmptyValueStrings` | Empty string values must be skipped |
| 19 | `testParseResponseFiltersNonNumericValues` | Malformed value strings (e.g., "N/A", "Ice") |
| 20 | `testParseResponseSortsReadingsChronologically` | Readings must be sorted by dateTime ascending |
| 21 | `testParseResponseUsesLastReadingAsCurrentLevel` | Most recent reading becomes currentLevel |
| 22 | `testParseResponseTriesMultipleParameterCodes` | Falls through parameterCodes array |
| 23 | `testParseResponseSkipsParameterWithNoValidReadings` | Empty readings after filtering should continue to next param |

#### 1.3 Missing: Computed Properties

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 24 | `testMinLevelReturnsSmallestReading` | Basic correctness |
| 25 | `testMaxLevelReturnsLargestReading` | Basic correctness |
| 26 | `testAverageLevelComputesCorrectly` | Arithmetic correctness |
| 27 | `testMinLevelReturnsNilWhenEmpty` | Empty array guard |
| 28 | `testMaxLevelReturnsNilWhenEmpty` | Empty array guard |
| 29 | `testAverageLevelReturnsNilWhenEmpty` | Empty array guard |
| 30 | `testMinMaxWithSingleReading` | Single-element edge case |
| 31 | `testAverageWithSingleReading` | Single-element edge case |

#### 1.4 Missing: Reset

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 32 | `testResetClearsAllState` | All published properties and currentLake should be nil/empty |

#### 1.5 Missing: URL Construction Security

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 33 | `testURLConstructionWithSpecialCharactersInLakeId` | Injection prevention -- lake IDs with unexpected chars |
| 34 | `testURLConstructionProducesValidURL` | Guard clause at line 198 |

---

### Priority 2 (High) -- LakeLevelCacheTests.swift

#### 2.1 Missing: Cache Expiration

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 35 | `testLoadReturnsNilForExpiredCache` | 7-day max cache age is checked but never tested with an old date |
| 36 | `testLoadDeletesExpiredCacheFile` | Expired cache files should be removed from disk |
| 37 | `testLoadReturnsCacheJustBeforeExpiration` | Boundary: cache at exactly 7 days minus 1 second |

#### 2.2 Missing: Corruption / Malformed Data

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 38 | `testLoadReturnsNilForCorruptedCacheFile` | Write garbage bytes to cache file, verify graceful nil return |
| 39 | `testLoadReturnsNilForPartialJSON` | Truncated JSON data |
| 40 | `testLoadReturnsNilForWrongJSONSchema` | Valid JSON but wrong structure |
| 41 | `testSaveHandlesDiskWriteFailure` | Verify no crash when write fails (e.g., read-only directory) |

#### 2.3 Missing: Edge Cases

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 42 | `testSaveOverwritesExistingCache` | Re-saving same lakeId+period should overwrite |
| 43 | `testCacheWithEmptyReadingsArray` | Zero readings is a valid state |
| 44 | `testCacheWithLargeReadingsArray` | Performance: 10,000+ readings |
| 45 | `testClearNonexistentLakeDoesNotCrash` | Clearing a lake that was never cached |
| 46 | `testClearAllOnEmptyCacheDoesNotCrash` | Empty cache directory |
| 47 | `testHasCachedDataReturnsFalseAfterClear` | State consistency |

#### 2.4 Missing: File Path Security

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 48 | `testCacheFileURLWithPathTraversalInLakeId` | IDs like "../../../etc" should not escape cache directory |
| 49 | `testCacheFileURLWithSpecialCharacters` | Lake IDs with slashes, spaces, unicode |

---

### Priority 3 (Medium) -- FavoritesServiceTests.swift

#### 3.1 Missing: Edge Cases

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 50 | `testAddDuplicateFavoriteIsIdempotent` | Adding same lake twice should not create duplicates |
| 51 | `testRemoveNonExistentFavoriteDoesNotCrash` | Removing a lake that was never added |
| 52 | `testAddMultipleFavorites` | Verify count and IDs with 5+ favorites |
| 53 | `testRemoveFromMultipleFavorites` | Remove middle item, verify others remain |
| 54 | `testFavoriteLakesOrderMatchesCatalogOrder` | Verify ordering behavior |

#### 3.2 Missing: Persistence Edge Cases

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 55 | `testPersistenceWithCorruptedUserDefaults` | UserDefaults contains non-[String] data for key |
| 56 | `testPersistenceWithEmptyArray` | UserDefaults has empty array stored |
| 57 | `testPersistenceAfterRemoveAllFavorites` | Remove all, re-instantiate, verify empty |

#### 3.3 Missing: Concurrent Modification

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 58 | `testRapidToggling` | Toggle same lake 100 times rapidly, verify consistent end state |

---

### Priority 3 (Medium) -- LakeModelTests.swift

#### 4.1 Missing: Lake Model Edge Cases

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 59 | `testLakeWithNilCoordinates` | Both lat/lon nil -- displayName, usgsURL should still work |
| 60 | `testLakeWithEmptyId` | Edge case: empty string ID |
| 61 | `testLakeWithEmptyName` | Edge case: displayName with empty name |
| 62 | `testLakeEqualityByIdOnly` | Two lakes with same ID but different names -- are they equal? |
| 63 | `testLakeCodable` | Encode/decode round-trip preserves all fields |
| 64 | `testLakeCodableWithNilCoordinates` | Encode/decode with nil lat/lon |

#### 4.2 Missing: LakeLevel Edge Cases

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 65 | `testLakeLevelDateFormatted` | `dateFormatted` property has zero tests |
| 66 | `testLakeLevelValueFormattedZero` | Format 0.0 correctly |
| 67 | `testLakeLevelValueFormattedNegative` | Negative water levels (below datum) |
| 68 | `testLakeLevelValueFormattedVeryLarge` | Values like 99999.99 |
| 69 | `testLakeLevelCodable` | Round-trip encode/decode |

#### 4.3 Missing: CachedLakeData Tests

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 70 | `testCacheAgeFormattedMinutes` | Age between 1-59 minutes |
| 71 | `testCacheAgeFormattedHours` | Age between 1-24 hours |
| 72 | `testCacheAgeFormattedDays` | Age > 24 hours |
| 73 | `testCacheAgeFormattedJustNow` | Age < 1 minute |
| 74 | `testCacheAgeFormattedSingularDay` | "1 day ago" (not "1 days ago") |
| 75 | `testCacheAgeFormattedSingularHour` | "1 hour ago" (not "1 hours ago") |
| 76 | `testCacheAgeFormattedSingularMinute` | "1 minute ago" (not "1 minutes ago") |
| 77 | `testIsStaleReturnsFalseUnderOneHour` | isStale boundary at 3600s |
| 78 | `testIsStaleReturnsTrueOverOneHour` | isStale boundary at 3600s |
| 79 | `testCachedLakeDataCodable` | Round-trip encode/decode |

#### 4.4 Missing: USGS Response Model Decoding

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 80 | `testUSGSResponseDecodesValidJSON` | Parse a realistic USGS JSON response |
| 81 | `testUSGSResponseDecodesEmptyTimeSeries` | Empty timeSeries array |
| 82 | `testUSGSResponseDecodesEmptyValues` | timeSeries present but values array empty |
| 83 | `testUSGSResponseDecodesMultipleTimeSeries` | Multiple time series (only first is used) |
| 84 | `testUSGSResponseRejectsInvalidJSON` | Malformed JSON throws DecodingError |

---

### Priority 4 (Medium) -- LakeCatalogTests.swift

#### 5.1 Missing: Search Edge Cases

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 85 | `testSearchWithWhitespaceOnly` | " " should probably return all or none |
| 86 | `testSearchPartialStateName` | "T" should match TX, TN, etc. |
| 87 | `testSearchById` | Searching by USGS ID (not currently supported -- may be desired) |
| 88 | `testSearchWithSpecialCharacters` | Characters like ".", "(", unicode |

#### 5.2 Missing: Data Integrity

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 89 | `testAllLakesHaveValidUSGSURLs` | Every lake should produce a non-nil usgsURL |
| 90 | `testStatesArrayContainsOnlyValidAbbreviations` | All states are valid 2-letter US state codes |

---

### Priority 5 (Low) -- Integration-Style Tests

These test multiple components working together and would require some infrastructure (mocks).

| # | Test Case | Why It Matters |
|---|-----------|---------------|
| 91 | `testFetchThenCacheRoundTrip` | Fetch real-format data, save to cache, load back, verify identical |
| 92 | `testFavoriteLakesMatchCatalogAfterAddRemove` | Add/remove favorites, verify `favoriteLakes` stays consistent |
| 93 | `testCacheServesDataWhenOffline` | Full flow: cache data, simulate network failure, verify cache-served |
| 94 | `testPeriodSwitchingPreservesCache` | Switch periods, verify each period's cache is independent |
| 95 | `testFullLakeDetailFlow` | Select lake -> fetch -> display level -> show history -> check stats |

---

## Infrastructure Recommendations

### 1. Create a URLSession Mock / Protocol

The biggest gap is testing `LakeLevelService.fetchLakeLevel()`. The service uses `URLSession.shared` directly (line 201), making it impossible to unit test without:
- Extracting a `URLSessionProtocol`
- Injecting the session via initializer
- Creating a `MockURLSession` that returns controlled responses

This is a **prerequisite** for test cases 1-23 and 33-34.

### 2. Create USGS Response Fixtures

Create JSON fixture files with:
- A valid USGS response with multiple readings
- A response with sentinel values (-999999)
- An empty response (no timeSeries)
- A response with multiple parameter codes
- A malformed response

### 3. Time-Based Test Utilities

For cache expiration and staleness tests (35-37, 70-78), either:
- Inject a `DateProvider` protocol into `CachedLakeData`
- Or create test fixtures with manually set `cachedAt` dates and test the computed properties directly

---

## Summary Statistics

| Category | Existing Tests | Missing Tests | Coverage Gap |
|----------|---------------|---------------|--------------|
| LakeLevelService (fetch/state) | 0 | 34 | **Critical** |
| LakeLevelCache (edge cases) | 10 | 15 | High |
| FavoritesService (edge cases) | 9 | 9 | Medium |
| Lake/LakeLevel models | 8 | 21 | Medium |
| LakeCatalog (edge cases) | 10 | 6 | Low |
| Integration tests | 0 | 5 | Medium |
| **TOTAL** | **37** | **90** | |

The single most impactful improvement would be making `LakeLevelService` testable via dependency injection and then covering the fetch/parse/cache-fallback logic (test cases 1-34). This alone would dramatically improve confidence in the app's core functionality.
