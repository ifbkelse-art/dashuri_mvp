package location

import "context"

// CityPoint is a city with its centre coordinates (from identity.cities).
type CityPoint struct {
	City
	Latitude  float64
	Longitude float64
}

// Repository reads the curated city list.
type Repository interface {
	// SearchCities returns active cities whose name or state contains query
	// (case-insensitive); an empty query returns all, ordered by name.
	SearchCities(ctx context.Context, query string) ([]City, error)
	// ActiveCityPoints returns every active city with coordinates.
	ActiveCityPoints(ctx context.Context) ([]CityPoint, error)
}
