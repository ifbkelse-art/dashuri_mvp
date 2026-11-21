//go:build integration

package location_test

import (
	"context"
	"testing"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/location"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/testsupport/pgtest"
)

func f(v float64) *float64 { return &v }

func TestCitiesAndResolve(t *testing.T) {
	api, _ := pgtest.Pools(t)
	s := location.NewService(location.Deps{Repo: postgres.LocationRepo{Pool: api}})
	ctx := context.Background()

	all, err := s.ListCities(ctx, "")
	if err != nil || len(all.Items) < 50 {
		t.Fatalf("all: %d %v", len(all.Items), err)
	}
	pu, err := s.ListCities(ctx, "pun")
	if err != nil || len(pu.Items) == 0 || pu.Items[0].Id != "pune" {
		t.Fatalf("pun: %+v %v", pu, err)
	}
	if none, _ := s.ListCities(ctx, "%_"); len(none.Items) != 0 {
		t.Fatalf("wildcards must be literal: %+v", none)
	}
	if kerala, _ := s.ListCities(ctx, "kerala"); len(kerala.Items) != 3 {
		t.Fatalf("state search: %+v", kerala)
	}

	c, err := s.Resolve(ctx, location.ResolveRequest{Latitude: f(18.52), Longitude: f(73.85)})
	if err != nil || c.Id != "pune" || c.State != "Maharashtra" {
		t.Fatalf("pune: %+v %v", c, err)
	}
	if c, _ := s.Resolve(ctx, location.ResolveRequest{Latitude: f(19.22), Longitude: f(72.98)}); c.Id != "mumbai" {
		t.Fatalf("thane: %+v", c)
	}
	_, err = s.Resolve(ctx, location.ResolveRequest{Latitude: f(51.51), Longitude: f(-0.13)})
	if e := apperr.As(err); e == nil || e.Code != "no_supported_city_nearby" {
		t.Fatalf("london: %v", err)
	}
	if _, err := s.Resolve(ctx, location.ResolveRequest{Latitude: f(95), Longitude: f(73)}); apperr.As(err).Kind != apperr.KindValidation {
		t.Fatalf("range: %v", err)
	}
}
