package location

import "math"

// MaxResolveDistanceKm is how far the nearest supported city may be.
const MaxResolveDistanceKm = 75.0

const earthRadiusKm = 6371.0088

// DistanceKm is the great-circle (haversine) distance between two points.
func DistanceKm(lat1, lon1, lat2, lon2 float64) float64 {
	rad := math.Pi / 180
	dLat := (lat2 - lat1) * rad
	dLon := (lon2 - lon1) * rad
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*rad)*math.Cos(lat2*rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 2 * earthRadiusKm * math.Asin(math.Min(1, math.Sqrt(a)))
}

// Nearest returns the closest city within maxKm, or false.
func Nearest(cities []CityPoint, lat, lon, maxKm float64) (City, bool) {
	best, bestD := City{}, math.Inf(1)
	for _, c := range cities {
		if d := DistanceKm(lat, lon, c.Latitude, c.Longitude); d < bestD {
			best, bestD = c.City, d
		}
	}
	if bestD > maxKm {
		return City{}, false
	}
	return best, true
}
