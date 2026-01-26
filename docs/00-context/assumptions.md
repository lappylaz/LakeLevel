# LakeLevel - Assumptions & Risks

**Last Updated:** 2026-01-25

---

## Assumptions

### Technical
- USGS API will remain free and publicly accessible
- USGS API rate limits are sufficient for app usage
- All lakes in catalog have reliable data availability
- iOS 17+ provides sufficient market coverage

### Business
- Users prefer native app over mobile web for this use case
- 33 lakes is sufficient for MVP launch
- Free tier (no premium features) is viable initially

### User Behavior
- Users check lake levels weekly or more frequently
- Favorites feature will increase retention
- Historical trends are valuable for decision-making

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| USGS API downtime | Low | High | Show cached data, graceful error handling |
| USGS API changes | Medium | High | Abstract API layer, monitor for changes |
| Low App Store visibility | High | Medium | ASO optimization, consider paid acquisition |
| Limited lake coverage | Medium | Medium | User request feature, expand catalog |
| Data accuracy issues | Low | High | Link to official USGS source for verification |

---

## Open Questions

- [ ] Should we add push notifications for level thresholds?
- [ ] What's the best monetization strategy (ads, premium, donations)?
- [ ] Should we expand to other water data (flow rates, temperatures)?
- [ ] How to handle lakes with intermittent data availability?

---

## Validated Assumptions

| Date | Assumption | Validation Method | Result |
|------|------------|-------------------|--------|
| 2026-01-25 | USGS API works for all catalog lakes | Manual testing | Confirmed - all 33 lakes return data |

---

*Review monthly and after major decisions*
