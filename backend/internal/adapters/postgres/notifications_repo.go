package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/notifications"
)

// NotificationsRepo implements notifications.Repository on notify.*.
type NotificationsRepo struct{ Pool *pgxpool.Pool }

var _ notifications.Repository = NotificationsRepo{}

func (r NotificationsRepo) UpsertDevice(ctx context.Context, userID, token, platform string) error {
	_, err := r.Pool.Exec(ctx, `
		insert into notify.devices (token, user_id, platform, updated_at) values ($1, $2, $3, now())
		on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now()`,
		token, userID, platform)
	return err
}

func (r NotificationsRepo) DeleteDevice(ctx context.Context, userID, token string) error {
	_, err := r.Pool.Exec(ctx, `delete from notify.devices where token = $1 and user_id = $2`, token, userID)
	return err
}

func (r NotificationsRepo) DeviceTokens(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.Pool.Query(ctx, `select token from notify.devices where user_id = $1 order by updated_at desc limit 20`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r NotificationsRepo) ForgetToken(ctx context.Context, token string) error {
	_, err := r.Pool.Exec(ctx, `delete from notify.devices where token = $1`, token)
	return err
}

func (r NotificationsRepo) InsertInbox(ctx context.Context, userID, kind, title, body string) (notifications.InboxItem, error) {
	var it notifications.InboxItem
	err := r.Pool.QueryRow(ctx, `
		insert into notify.inbox (user_id, kind, title, body) values ($1, $2, $3, $4)
		returning id, kind, title, body, created_at, read_at`, userID, kind, title, body).
		Scan(&it.Id, &it.Kind, &it.Title, &it.Body, &it.CreatedAt, &it.ReadAt)
	return it, err
}

func (r NotificationsRepo) ListInbox(ctx context.Context, userID string, after *notifications.Cursor, limit int) ([]notifications.InboxItem, error) {
	at, id := idAfter(after)
	rows, err := r.Pool.Query(ctx, `
		select id, kind, title, body, created_at, read_at from notify.inbox
		 where user_id = $1 and ($2::timestamptz is null or (created_at, id) < ($2::timestamptz, $3::uuid))
		 order by created_at desc, id desc limit $4`, userID, at, id, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []notifications.InboxItem
	for rows.Next() {
		var it notifications.InboxItem
		if err := rows.Scan(&it.Id, &it.Kind, &it.Title, &it.Body, &it.CreatedAt, &it.ReadAt); err != nil {
			return nil, err
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

func (r NotificationsRepo) MarkRead(ctx context.Context, userID, id string) error {
	tag, err := r.Pool.Exec(ctx, `update notify.inbox set read_at = coalesce(read_at, now()) where id = $1 and user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return notifications.ErrNotFound
	}
	return nil
}
