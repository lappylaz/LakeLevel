# LakeLevel - System State

**Last Updated:** 2026-01-25
**Version:** 1.0.0 (MVP)

---

## What's Actually Built

This document reflects the current reality of the codebase. Use this to understand what exists vs. what's planned.

---

## Architecture Overview

```
LakeLevel/
├── App/
│   ├── LakeLevelApp.swift      # App entry point, injects FavoritesService
│   └── ContentView.swift       # Root view wrapper
├── Models/
│   ├── Lake.swift              # Lake model + USGS API response types
│   └── LakeCatalog.swift       # Static catalog of 33 US lakes
├── Services/
│   ├── LakeLevelService.swift  # USGS API integration
│   └── FavoritesService.swift  # UserDefaults persistence
└── Views/
    ├── LakeListView.swift      # Main list with search/filter
    ├── LakeDetailView.swift    # Lake detail with chart
    └── Components/
        ├── LakeRowView.swift   # List row component
        ├── StatBox.swift       # Statistics display box
        └── InfoRow.swift       # Key-value row component
```

---

## Implemented Features

### Core Features
| Feature | Status | Notes |
|---------|--------|-------|
| Lake list display | ✅ Complete | Grouped by state, searchable |
| Lake detail view | ✅ Complete | Current level + chart |
| USGS API integration | ✅ Complete | IV and DV endpoints |
| Historical charts | ✅ Complete | 7-day, 30-day, 1-year |
| Favorites | ✅ Complete | UserDefaults persistence |
| Pull-to-refresh | ✅ Complete | On detail view |
| Search | ✅ Complete | By lake name or state |
| Filter (All/Favorites) | ✅ Complete | Toolbar menu |

### Data
| Item | Status | Notes |
|------|--------|-------|
| Lake catalog | ✅ Complete | 33 lakes across 16 states |
| USGS parameter codes | ✅ Complete | 5 codes for water level variants |

---

## Not Yet Implemented

| Feature | Priority | Notes |
|---------|----------|-------|
| Unit tests | High | No tests exist |
| Offline caching | Medium | No persistence of level data |
| Accessibility labels | Medium | VoiceOver not optimized |
| Widget | Low | Future consideration |
| Notifications | Low | Level threshold alerts |
| iPad optimization | Low | Works but not optimized |

---

## Technical Debt

| Item | Severity | Location | Notes |
|------|----------|----------|-------|
| DateFormatter recreation | Medium | LakeLevelService.swift:194 | Created on every parse call |
| Missing VT state name | Low | LakeListView.swift:122 | Vermont not in mapping |
| String error handling | Low | LakeLevelService.swift:51 | Should use typed errors |

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| SwiftUI | iOS 17+ | UI framework |
| Charts | iOS 16+ | Data visualization |
| os.log | Built-in | Logging |

No external dependencies (SPM, CocoaPods, etc.)

---

## API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `waterservices.usgs.gov/nwis/iv/` | Instantaneous values (real-time) |
| `waterservices.usgs.gov/nwis/dv/` | Daily values (historical) |

---

## Repository

- **GitHub:** https://github.com/lappylaz/LakeLevel
- **Branch:** main
- **Last Commit:** Initial commit (2026-01-25)

---

*Update this file after every implementation session*
