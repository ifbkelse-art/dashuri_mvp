# feature_location

Coarse city location, opt-in (decision F4). The user searches the curated city list or taps "Use my location" once; the device position is fetched with low accuracy, rounded to 2 decimals and sent to `POST /v1/locations/resolve`. Coordinates are never stored on the device or the server. The picked city is saved with `PATCH /v1/me/profile {city_id}` and `RoutePaths.cityPicker` pops with the `City`.

| Endpoint | Use |
|---|---|
| `GET /v1/locations/cities?query=` | Search |
| `POST /v1/locations/resolve` | Nearest supported city within 75 km (404 → "not available near you") |
| `PATCH /v1/me/profile` | Save `city_id` |
