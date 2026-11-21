package postgres

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/accounts"
)

// AccountsRepo implements accounts.Repository on identity.*.
type AccountsRepo struct{ Pool *pgxpool.Pool }

var _ accounts.Repository = AccountsRepo{}

func (r AccountsRepo) Account(ctx context.Context, userID string) (accounts.AccountRow, error) {
	var a accounts.AccountRow
	err := r.Pool.QueryRow(ctx, `
		select a.id, a.status, a.age_eligible, a.age_method, a.date_of_birth, a.rules_accepted_version,
		       h.state, p.display_name, p.gender, a.created_at
		  from identity.accounts a
		  left join hosting.hosts h on h.user_id = a.id
		  left join identity.profiles p on p.user_id = a.id
		 where a.id = $1`, userID).
		Scan(&a.UserID, &a.Status, &a.AgeEligible, &a.AgeMethod, &a.DateOfBirth, &a.RulesVersion,
			&a.HostState, &a.DisplayName, &a.Gender, &a.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return a, accounts.ErrNotFound
	}
	return a, err
}

const idProfileSelect = `
	select p.user_id, p.display_name, p.bio, p.languages, p.gender, c.id, c.name, c.state, h.state,
	       %XP%,
	       array(select ph.storage_path from identity.profile_photos ph
	              where ph.user_id = p.user_id and ph.status = any($2::text[])
	              order by ph.position, ph.created_at)
	  from identity.profiles p
	  join identity.accounts a on a.id = p.user_id
	  left join identity.cities c on c.id = p.city_id
	  left join hosting.hosts h on h.user_id = p.user_id
	 where p.user_id = $1`

func idScanProfile(row pgx.Row) (accounts.ProfileRow, error) {
	var p accounts.ProfileRow
	var cityID, cityName, cityState *string
	err := row.Scan(&p.UserID, &p.DisplayName, &p.Bio, &p.Languages, &p.Gender, &cityID, &cityName, &cityState,
		&p.HostState, &p.LifetimeXP, &p.PhotoPaths)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, accounts.ErrNotFound
	}
	if cityID != nil {
		p.City = &accounts.City{Id: *cityID, Name: idDeref(cityName), State: idDeref(cityState)}
	}
	return p, err
}

func idDeref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func idProfileSQL(extra string) string {
	q := strings.Replace(idProfileSelect, "%XP%", idLifetimeXP("p.user_id"), 1)
	return q + extra
}

func (r AccountsRepo) OwnProfile(ctx context.Context, userID string) (accounts.ProfileRow, error) {
	return idScanProfile(r.Pool.QueryRow(ctx, idProfileSQL(""), userID, []string{"approved", "pending_review"}))
}

func (r AccountsRepo) PublicProfile(ctx context.Context, viewerID, userID string) (accounts.ProfileRow, error) {
	return idScanProfile(r.Pool.QueryRow(ctx, idProfileSQL(`
	   and a.status in ('active','restricted')
	   and not `+idBlockedEither("$3::uuid", "p.user_id")),
		userID, []string{"approved"}, viewerID))
}

func (r AccountsRepo) UpdateProfile(ctx context.Context, userID string, u accounts.ProfileUpdate) error {
	return idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		if u.SetCity && u.CityID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from identity.cities where id = $1 and active)`, *u.CityID).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return accounts.ErrUnknownCity
			}
		}
		var cur struct {
			name      string
			bio       *string
			languages []string
			gender    *string
			city      *string
		}
		err := tx.QueryRow(ctx, `select display_name, bio, languages, gender, city_id from identity.profiles where user_id = $1 for update`, userID).
			Scan(&cur.name, &cur.bio, &cur.languages, &cur.gender, &cur.city)
		exists := err == nil
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		if !exists {
			if u.DisplayName == nil {
				return accounts.ErrDisplayNameRequired
			}
			cur.languages = []string{}
		}
		if u.DisplayName != nil {
			cur.name = *u.DisplayName
		}
		if u.SetBio {
			cur.bio = u.Bio
		}
		if u.Languages != nil {
			cur.languages = u.Languages
		}
		if u.Gender != nil {
			cur.gender = u.Gender
		}
		if u.SetCity {
			cur.city = u.CityID
		}
		_, err = tx.Exec(ctx, `
			insert into identity.profiles (user_id, display_name, bio, languages, gender, city_id)
			values ($1, $2, $3, $4, $5, $6)
			on conflict (user_id) do update set display_name = excluded.display_name, bio = excluded.bio,
			   languages = excluded.languages, gender = excluded.gender, city_id = excluded.city_id`,
			userID, cur.name, cur.bio, cur.languages, cur.gender, cur.city)
		return err
	})
}

func (r AccountsRepo) AcceptRules(ctx context.Context, userID, version string) error {
	_, err := r.Pool.Exec(ctx, `update identity.accounts set rules_accepted_version = $2, rules_accepted_at = now() where id = $1`, userID, version)
	return err
}

func (r AccountsRepo) CreatePhoto(ctx context.Context, userID, photoID, path string, max int, sign func(string) (string, error)) (string, error) {
	var url string
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `select 1 from identity.accounts where id = $1 for update`, userID); err != nil {
			return err
		}
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from identity.profile_photos where user_id = $1 and status in ('pending_review','approved')`, userID).Scan(&n); err != nil {
			return err
		}
		if n >= max {
			return accounts.ErrPhotoLimit
		}
		u, err := sign(path)
		if err != nil {
			return err
		}
		url = u
		_, err = tx.Exec(ctx, `insert into identity.profile_photos (id, user_id, storage_path, status, position) values ($1, $2, $3, 'pending_review', $4)`,
			photoID, userID, path, n)
		return err
	})
	return url, err
}

func (r AccountsRepo) DeclareAge(ctx context.Context, userID string, dob time.Time, eligible bool) error {
	return idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		var locked bool
		if err := tx.QueryRow(ctx, `select date_of_birth is not null or age_method is not null from identity.accounts where id = $1 for update`, userID).Scan(&locked); err != nil {
			return err
		}
		if locked {
			return accounts.ErrDeclarationLocked
		}
		if _, err := tx.Exec(ctx, `
			update identity.accounts
			   set date_of_birth = $2, age_method = 'self_declared', age_eligible = $3,
			       status = case when not $3 and status = 'active' then 'restricted' else status end
			 where id = $1`, userID, dob, eligible); err != nil {
			return err
		}
		if !eligible {
			return idAudit(ctx, tx, userID, "account.restricted_under_18", userID, nil)
		}
		return nil
	})
}

func (r AccountsRepo) Consents(ctx context.Context, userID string) (accounts.ConsentState, error) {
	var c accounts.ConsentState
	err := r.Pool.QueryRow(ctx, `
		select coalesce(c.analytics, false), coalesce(c.marketing, false), coalesce(c.updated_at, a.created_at)
		  from identity.accounts a left join identity.consents c on c.user_id = a.id
		 where a.id = $1`, userID).Scan(&c.Analytics, &c.Marketing, &c.UpdatedAt)
	return c, err
}

func (r AccountsRepo) SetConsents(ctx context.Context, userID string, analytics, marketing bool) (accounts.ConsentState, error) {
	var c accounts.ConsentState
	err := r.Pool.QueryRow(ctx, `
		insert into identity.consents (user_id, analytics, marketing, updated_at) values ($1, $2, $3, now())
		on conflict (user_id) do update set analytics = excluded.analytics, marketing = excluded.marketing, updated_at = now()
		returning analytics, marketing, updated_at`, userID, analytics, marketing).Scan(&c.Analytics, &c.Marketing, &c.UpdatedAt)
	return c, err
}

// idHeldBeans returns Beans held, available or pending payout for a user.
func idHeldBeans(ctx context.Context, q Querier, userID string) (int64, error) {
	var n int64
	err := q.QueryRow(ctx, `
		select coalesce(sum(b.balance), 0)
		  from ledger.accounts la join ledger.balances b on b.account_id = la.id
		 where la.owner_user_id = $1 and la.kind in ('bean_held','bean_available','bean_payout_pending')`, userID).Scan(&n)
	return n, err
}

func (r AccountsRepo) RequestDeletion(ctx context.Context, userID string, scheduledFor time.Time) (accounts.DeletionRequest, error) {
	var d accounts.DeletionRequest
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `select 1 from identity.accounts where id = $1 for update`, userID); err != nil {
			return err
		}
		err := tx.QueryRow(ctx, `
			select id, status, scheduled_for from identity.data_requests
			 where user_id = $1 and kind = 'deletion' and status in ('received','processing')
			 order by created_at desc limit 1`, userID).Scan(&d.RequestId, &d.Status, &d.ScheduledFor)
		if err == nil {
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		beans, err := idHeldBeans(ctx, tx, userID)
		if err != nil {
			return err
		}
		var blocked bool
		if err := tx.QueryRow(ctx, `select `+idInLiveCall("$1::uuid")+` or exists (
			select 1 from payouts.withdrawals w where w.host_id = $1 and w.status in ('requested','in_cycle'))`, userID).Scan(&blocked); err != nil {
			return err
		}
		if beans > 0 || blocked {
			return accounts.ErrPendingBalance
		}
		if err := tx.QueryRow(ctx, `
			insert into identity.data_requests (user_id, kind, status, scheduled_for) values ($1, 'deletion', 'received', $2)
			returning id, status, scheduled_for`, userID, scheduledFor).Scan(&d.RequestId, &d.Status, &d.ScheduledFor); err != nil {
			return err
		}
		return idAudit(ctx, tx, userID, "account.deletion_requested", d.RequestId, nil)
	})
	return d, err
}

func (r AccountsRepo) RequestExport(ctx context.Context, userID string) (accounts.DataExportRequest, error) {
	var d accounts.DataExportRequest
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `select 1 from identity.accounts where id = $1 for update`, userID); err != nil {
			return err
		}
		err := tx.QueryRow(ctx, `
			select id, status from identity.data_requests
			 where user_id = $1 and kind = 'export' and status in ('received','processing')
			 order by created_at desc limit 1`, userID).Scan(&d.RequestId, &d.Status)
		if err == nil || !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		return tx.QueryRow(ctx, `insert into identity.data_requests (user_id, kind) values ($1, 'export') returning id, status`, userID).
			Scan(&d.RequestId, &d.Status)
	})
	return d, err
}
