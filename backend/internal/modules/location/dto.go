package location

import "math"

// City is a supported (curated) city. Coarse location only.
type City struct {
	Id    string `json:"id"`
	Name  string `json:"name"`
	State string `json:"state"`
}

// CityList is the GET /v1/locations/cities response.
type CityList struct {
	Items []City `json:"items"`
}

// ResolveRequest carries rounded coordinates. They are used for one
// computation and never stored or logged.
type ResolveRequest struct {
	Latitude  *float64 `json:"latitude"`
	Longitude *float64 `json:"longitude"`
}

func (r ResolveRequest) validate() map[string]string {
	errs := map[string]string{}
	switch {
	case r.Latitude == nil:
		errs["latitude"] = "required"
	case math.IsNaN(*r.Latitude) || math.IsInf(*r.Latitude, 0) || *r.Latitude < -90 || *r.Latitude > 90:
		errs["latitude"] = "out_of_range"
	}
	switch {
	case r.Longitude == nil:
		errs["longitude"] = "required"
	case math.IsNaN(*r.Longitude) || math.IsInf(*r.Longitude, 0) || *r.Longitude < -180 || *r.Longitude > 180:
		errs["longitude"] = "out_of_range"
	}
	return errs
}

// MaxQueryLength bounds the city search query.
const MaxQueryLength = 40

func validateQuery(q string) map[string]string {
	errs := map[string]string{}
	if len([]rune(q)) > MaxQueryLength {
		errs["query"] = "too_long"
	}
	return errs
}
