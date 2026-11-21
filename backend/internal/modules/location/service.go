package location

import (
	"context"
	"strings"

	"dashuri/backend/internal/platform/apperr"
)

// Service implements coarse, opt-in location (founder decision F4).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

// ListCities: GET /v1/locations/cities?query= — curated supported cities.
func (s *Service) ListCities(ctx context.Context, query string) (CityList, error) {
	if errs := validateQuery(query); len(errs) > 0 {
		return CityList{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return CityList{}, err
	}
	items, err := repo.SearchCities(ctx, strings.TrimSpace(query))
	if err != nil {
		return CityList{}, apperr.Internal(err)
	}
	if items == nil {
		items = []City{}
	}
	return CityList{Items: items}, nil
}

// Resolve: POST /v1/locations/resolve — nearest supported city within 75 km.
// The coordinates are used only here: never stored, logged or returned.
func (s *Service) Resolve(ctx context.Context, in ResolveRequest) (City, error) {
	if errs := in.validate(); len(errs) > 0 {
		return City{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return City{}, err
	}
	cities, err := repo.ActiveCityPoints(ctx)
	if err != nil {
		return City{}, apperr.Internal(err)
	}
	c, ok := Nearest(cities, *in.Latitude, *in.Longitude, MaxResolveDistanceKm)
	if !ok {
		return City{}, &apperr.Error{Kind: apperr.KindNotFound, Code: "no_supported_city_nearby",
			Detail: "no supported city within 75 km"}
	}
	return c, nil
}
