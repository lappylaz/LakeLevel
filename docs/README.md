# LakeLevel Documentation

This folder contains structured documentation following the 4-layer code development framework.

## Quick Links

- **[Dashboard](01-product/dashboard.md)** - Current implementation status
- **[System State](00-context/system-state.md)** - What's actually built
- **[PRD](01-product/prd.md)** - Product requirements

## Structure

```
docs/
├── 00-context/           # WHY and WHAT EXISTS
│   ├── vision.md         # Product purpose, boundaries, non-goals
│   ├── assumptions.md    # Risks, unknowns, open questions
│   └── system-state.md   # What's actually built (reality anchor)
├── 01-product/           # WHAT to build
│   ├── prd.md            # Requirements specification
│   └── dashboard.md      # Implementation status tracker
└── 02-features/          # HOW features are built (per-feature)
    └── feature-<name>/
        ├── feature-spec.md
        ├── tech-design.md
        ├── dev-tasks.md
        └── test-plan.md
```

## When to Update

| Document | Update Frequency |
|----------|------------------|
| system-state.md | After every implementation session |
| dashboard.md | After completing features/tasks |
| dev-tasks.md | During active development |
| prd.md | When requirements change |
| vision.md | Rarely (major pivots only) |

## Repository

- **GitHub:** https://github.com/lappylaz/LakeLevel
- **Platform:** iOS (SwiftUI)
- **Data Source:** USGS Water Services API
