# ADR-012: Location is a coarse, opt-in city

- **Status:** Accepted, 2026-11-21 (founder decision F4)

## Decision
- Profiles reference a city id from a curated list (`identity.cities`). Users pick a city, or tap "Use my location" once.
- With the device's coarse location permission, the app rounds coordinates to 2 decimals (about 1 km) and sends them to `POST /v1/locations/resolve`. The server returns the nearest supported city within 75 km. **Coordinates are neither stored nor logged.**
- The city is shown on host cards and profiles and used as a discovery filter. Gender is never public.

## Consequences
- Play data-safety form: "Approximate location, collected, not shared, optional, used for app functionality". DPDP notice text needs legal review.
- No distance-based matching (that would require storing coordinates). It can be revisited later.
