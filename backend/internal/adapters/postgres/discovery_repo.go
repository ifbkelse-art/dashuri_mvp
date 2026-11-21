package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/discovery"
)

// DiscoveryRepo implements discovery.Repository (reads hosting, identity,
// safety.blocks, calls and ledger.user_xp).
type DiscoveryRepo struct{ Pool *pgxpool.Pool }

var _ discovery.Repository = DiscoveryRepo{}

// idHostCandidates selects approved hosts of active accounts with a profile,
// excluding blocks either way with the viewer ($1). where adds filters.
func idHostCandidates(where string) string {
	return fmt.Sprintf(`
	select h.user_id, p.display_name, p.bio, p.languages,
	       (select ph.storage_path from identity.profile_photos ph
	         where ph.user_id = h.user_id and ph.status = 'approved'
	         order by ph.position, ph.created_at limit 1) as photo,
	       c.id as city_id, c.name as city_name, c.state as city_state,
	       h.rate_per_minute, h.kyc_state = 'approved' as kyc,
	       case when a.age_method = 'kyc_verified' then a.date_of_birth end as dob,
	       %s as xp,
	       (h.is_available and h.last_heartbeat_at > now() - make_interval(secs => %d)) as online,
	       %s as busy
	  from hosting.hosts h
	  join identity.accounts a on a.id = h.user_id
	  join identity.profiles p on p.user_id = h.user_id
	  left join identity.cities c on c.id = p.city_id
	 where h.state = 'approved' and a.status = 'active'
	   and not %s
	   %s`,
		idLifetimeXP("h.user_id"), discovery.HeartbeatWindowSeconds, idInLiveCall("h.user_id"),
		idBlockedEither("$1::uuid", "h.user_id"), where)
}

const idHostColumns = `user_id, display_name, bio, languages, photo, city_id, city_name, city_state, rate_per_minute, kyc, dob, xp, online, busy`

func idScanHost(row pgx.Row) (discovery.HostRow, error) {
	var h discovery.HostRow
	var cityID, cityName, cityState *string
	err := row.Scan(&h.UserID, &h.DisplayName, &h.Bio, &h.Languages, &h.PhotoPath, &cityID, &cityName, &cityState,
		&h.RatePerMinute, &h.KYCApproved, &h.VerifiedDOB, &h.LifetimeXP, &h.Online, &h.Busy)
	if cityID != nil {
		h.City = &discovery.City{Id: *cityID, Name: idDeref(cityName), State: idDeref(cityState)}
	}
	return h, err
}

// idSortKeySQL mirrors discovery.SortKeys. Only whitelisted expressions.
func idSortKeySQL(sort string) (string, string) {
	switch sort {
	case discovery.SortRateLow:
		return "rate_per_minute", "0::bigint"
	case discovery.SortRateHigh:
		return "-rate_per_minute", "0::bigint"
	default:
		return "case when busy then 1::bigint else 0::bigint end", "-xp"
	}
}

func (r DiscoveryRepo) ListHosts(ctx context.Context, q discovery.ListQuery) ([]discovery.HostRow, error) {
	k1, k2 := idSortKeySQL(q.Sort)
	sql := fmt.Sprintf(`
	with cand as (%s), keyed as (
	  select *, %s as k1, %s as k2 from cand where online or busy
	)
	select %s from keyed
	 where (not $4::boolean or (k1, k2, user_id) > ($5::bigint, $6::bigint, $7::uuid))
	 order by k1, k2, user_id
	 limit $8`,
		idHostCandidates(`and h.user_id <> $1::uuid
	   and ($2::text = '' or $2::text = any(p.languages))
	   and ($3::text = '' or p.city_id = $3::text)`), k1, k2, idHostColumns)
	var after bool
	var a1, a2 int64
	afterID := "00000000-0000-0000-0000-000000000000"
	if q.After != nil {
		after, a1, a2, afterID = true, q.After.K1, q.After.K2, q.After.ID
	}
	rows, err := r.Pool.Query(ctx, sql, q.ViewerID, q.Language, q.CityID, after, a1, a2, afterID, q.Limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []discovery.HostRow
	for rows.Next() {
		h, err := idScanHost(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

func (r DiscoveryRepo) Host(ctx context.Context, viewerID, hostID string) (discovery.HostRow, error) {
	h, err := idScanHost(r.Pool.QueryRow(ctx, `select `+idHostColumns+` from (`+idHostCandidates(`and h.user_id = $2::uuid`)+`) x`, viewerID, hostID))
	if errors.Is(err, pgx.ErrNoRows) {
		return h, discovery.ErrNotFound
	}
	return h, err
}

func (r DiscoveryRepo) OnlineCount(ctx context.Context, viewerID string) (int, error) {
	var n int
	err := r.Pool.QueryRow(ctx, `select count(*) from (`+idHostCandidates(`and h.user_id <> $1::uuid`)+`) x where online or busy`, viewerID).Scan(&n)
	return n, err
}
