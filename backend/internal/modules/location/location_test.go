package location

import (
	"context"
	"math"
	"testing"

	"dashuri/backend/internal/platform/apperr"
)

var testCities = []CityPoint{
	{City{"mumbai", "Mumbai", "Maharashtra"}, 19.07600, 72.87770},
	{City{"pune", "Pune", "Maharashtra"}, 18.52040, 73.85670},
	{City{"delhi", "Delhi", "Delhi"}, 28.70410, 77.10250},
	{City{"noida", "Noida", "Uttar Pradesh"}, 28.53550, 77.39100},
}

func TestDistanceKm(t *testing.T) {
	// Mumbai to Pune is about 120 km as the crow flies.
	d := DistanceKm(19.0760, 72.8777, 18.5204, 73.8567)
	if d < 115 || d > 125 {
		t.Fatalf("Mumbai-Pune = %.1f km", d)
	}
	if d := DistanceKm(10, 10, 10, 10); d != 0 {
		t.Fatalf("same point = %f", d)
	}
	// Antipodes: half the circumference.
	if d := DistanceKm(0, 0, 0, 180); math.Abs(d-math.Pi*earthRadiusKm) > 0.01 {
		t.Fatalf("antipode = %f", d)
	}
}

func TestNearest(t *testing.T) {
	cases := []struct {
		name     string
		lat, lon float64
		want     string
		ok       bool
	}{
		{"pune centre (rounded)", 18.52, 73.85, "pune", true},
		{"thane goes to mumbai", 19.22, 72.98, "mumbai", true},
		{"between delhi and noida picks closer", 28.57, 77.32, "noida", true},
		{"lonavala is within 75 km of pune", 18.75, 73.41, "pune", true},
		{"middle of the sea", 15.0, 65.0, "", false},
		{"london", 51.51, -0.13, "", false},
	}
	for _, c := range cases {
		got, ok := Nearest(testCities, c.lat, c.lon, MaxResolveDistanceKm)
		if ok != c.ok || got.Id != c.want {
			t.Errorf("%s: got %q,%v want %q,%v", c.name, got.Id, ok, c.want, c.ok)
		}
	}
	if _, ok := Nearest(nil, 18.52, 73.85, MaxResolveDistanceKm); ok {
		t.Error("empty city list must not resolve")
	}
}

func f(v float64) *float64 { return &v }

func TestResolveRequestValidate(t *testing.T) {
	cases := []struct {
		in    ResolveRequest
		field string
	}{
		{ResolveRequest{nil, f(73)}, "latitude"},
		{ResolveRequest{f(18), nil}, "longitude"},
		{ResolveRequest{f(91), f(73)}, "latitude"},
		{ResolveRequest{f(-90.01), f(73)}, "latitude"},
		{ResolveRequest{f(18), f(180.5)}, "longitude"},
		{ResolveRequest{f(math.NaN()), f(73)}, "latitude"},
		{ResolveRequest{f(18), f(math.Inf(1))}, "longitude"},
	}
	for _, c := range cases {
		if errs := c.in.validate(); errs[c.field] == "" {
			t.Errorf("%+v: want error on %s, got %v", c.in, c.field, errs)
		}
	}
	if errs := (ResolveRequest{f(-90), f(180)}).validate(); len(errs) != 0 {
		t.Errorf("boundary values rejected: %v", errs)
	}
}

type fakeRepo struct{ cities []CityPoint }

func (f fakeRepo) SearchCities(context.Context, string) ([]City, error) { return nil, nil }
func (f fakeRepo) ActiveCityPoints(context.Context) ([]CityPoint, error) {
	return f.cities, nil
}

func TestServiceResolve(t *testing.T) {
	s := NewService(Deps{Repo: fakeRepo{testCities}})
	c, err := s.Resolve(context.Background(), ResolveRequest{f(18.52), f(73.86)})
	if err != nil || c.Id != "pune" {
		t.Fatalf("got %+v, %v", c, err)
	}
	_, err = s.Resolve(context.Background(), ResolveRequest{f(51.5), f(0)})
	if e := apperr.As(err); e == nil || e.Code != "no_supported_city_nearby" || e.Kind != apperr.KindNotFound {
		t.Fatalf("want no_supported_city_nearby, got %v", err)
	}
	// No database: 503, not a panic.
	_, err = NewService(Deps{}).Resolve(context.Background(), ResolveRequest{f(18.52), f(73.86)})
	if e := apperr.As(err); e == nil || e.Kind != apperr.KindUnavailable {
		t.Fatalf("want unavailable, got %v", err)
	}
	if _, err := s.ListCities(context.Background(), string(make([]rune, 41))); apperr.As(err) == nil {
		t.Fatal("long query accepted")
	}
}
