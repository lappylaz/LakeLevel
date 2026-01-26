# LakeLevel - Product Requirements Document

**Last Updated:** 2026-01-25
**Version:** 1.0

---

## Overview

LakeLevel provides real-time lake water level monitoring for US lakes using USGS data.

---

## User Stories

### P0 - Must Have (MVP)

| ID | Story | Acceptance Criteria | Status |
|----|-------|---------------------|--------|
| US-01 | As a user, I can see a list of available lakes | Lakes grouped by state, sorted alphabetically | ✅ Done |
| US-02 | As a user, I can search for a lake | Filter by name or state, instant results | ✅ Done |
| US-03 | As a user, I can view current water level | Shows value, unit, timestamp | ✅ Done |
| US-04 | As a user, I can see historical trends | Chart with 7d/30d/1yr options | ✅ Done |
| US-05 | As a user, I can favorite lakes | Persist across sessions | ✅ Done |
| US-06 | As a user, I can filter to favorites only | Quick access to my lakes | ✅ Done |
| US-07 | As a user, I can refresh data | Pull-to-refresh gesture | ✅ Done |

### P1 - Should Have

| ID | Story | Acceptance Criteria | Status |
|----|-------|---------------------|--------|
| US-08 | As a user, I can see lake statistics | Min, max, average for period | ✅ Done |
| US-09 | As a user, I can link to USGS source | Opens official website | ✅ Done |
| US-10 | As a user, data loads gracefully on error | Error state with retry button | ✅ Done |

### P2 - Nice to Have (Future)

| ID | Story | Acceptance Criteria | Status |
|----|-------|---------------------|--------|
| US-11 | As a user, I can see data offline | Cached last-known values | 🔲 Backlog |
| US-12 | As a user, I get notified of level changes | Push notifications | 🔲 Backlog |
| US-13 | As a user, I can request new lakes | In-app feedback | 🔲 Backlog |
| US-14 | As a user, I can use VoiceOver | Full accessibility | 🔲 Backlog |

---

## Functional Requirements

### FR-01: Lake Catalog
- System shall maintain catalog of US lakes with USGS monitoring
- Each lake record includes: ID, name, state, coordinates, USGS URL
- Catalog shall be searchable by name and state

### FR-02: Data Retrieval
- System shall fetch data from USGS Water Services API
- System shall try instantaneous values (IV) first, fall back to daily values (DV)
- System shall handle USGS sentinel values (-999999) as missing data
- System shall support multiple USGS parameter codes for water levels

### FR-03: Data Display
- Current level shall show value, unit, and timestamp
- Historical chart shall support 7-day, 30-day, and 1-year views
- Statistics shall show min, max, and average for selected period

### FR-04: Persistence
- Favorites shall persist using UserDefaults
- Favorites shall sync across app restarts

---

## Non-Functional Requirements

### Performance
- Lake list shall render within 100ms
- API response shall timeout after 30 seconds
- Chart shall render within 500ms

### Reliability
- App shall handle network errors gracefully
- App shall not crash on malformed API responses

### Security
- App shall use HTTPS for all API calls
- App shall not store sensitive user data

---

## Technical Constraints

- iOS 17.0 minimum deployment target
- SwiftUI and Swift Charts required
- No external dependencies (pure Apple frameworks)

---

*See [[docs/00-context/vision|Vision]] for product strategy*
