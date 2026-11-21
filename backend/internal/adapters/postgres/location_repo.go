package postgres

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/location"
)

// LocationRepo implements location.Repository on identity.cities.
type LocationRepo struct{ Pool *pgxpool.Pool }

var _ location.Repository = LocationRepo{}

// idLikeEscape escapes LIKE wildcards in user input.
func idLikeEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

func (r LocationRepo) SearchCities(ctx context.Context, query string) ([]location.City, error) {
	rows, err := r.Pool.Query(ctx, `
		select id, name, state from identity.cities
		 where active and ($1 = '' or name ilike '%' || $1 || '%' or state ilike '%' || $1 || '%' or id ilike $1 || '%')
		 order by (name ilike $1 || '%') desc, name`, idLikeEscape(query))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []location.City{}
	for rows.Next() {
		var c location.City
		if err := rows.Scan(&c.Id, &c.Name, &c.State); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r LocationRepo) ActiveCityPoints(ctx context.Context) ([]location.CityPoint, error) {
	rows, err := r.Pool.Query(ctx, `select id, name, state, latitude::float8, longitude::float8 from identity.cities where active`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []location.CityPoint
	for rows.Next() {
		var c location.CityPoint
		if err := rows.Scan(&c.Id, &c.Name, &c.State, &c.Latitude, &c.Longitude); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
