package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/chat"
)

// ChatRepo implements chat.Repository on chat.* (plus reads of identity,
// safety.blocks and calls for the messaging rules).
type ChatRepo struct{ Pool *pgxpool.Pool }

var _ chat.Repository = ChatRepo{}

func (r ChatRepo) Peer(ctx context.Context, userID string) (chat.PeerAccount, error) {
	var p chat.PeerAccount
	err := r.Pool.QueryRow(ctx, `select id, status, age_eligible, who_can_message from identity.accounts where id = $1`, userID).
		Scan(&p.UserID, &p.Status, &p.AgeEligible, &p.WhoCanMessage)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, chat.ErrNotFound
	}
	return p, err
}

func (r ChatRepo) BlockedEither(ctx context.Context, a, b string) (bool, error) {
	var blocked bool
	err := r.Pool.QueryRow(ctx, `select `+idBlockedEither("$1::uuid", "$2::uuid"), a, b).Scan(&blocked)
	return blocked, err
}

func (r ChatRepo) HadBilledCall(ctx context.Context, a, b string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `
		select exists (select 1 from calls.calls
		 where ((caller_id = $1 and receiver_id = $2) or (caller_id = $2 and receiver_id = $1))
		   and phase = 'ended' and coalesce(billed_seconds, 0) > 0)`, a, b).Scan(&ok)
	return ok, err
}

func (r ChatRepo) EnsureConversation(ctx context.Context, a, b string) (string, error) {
	var id string
	err := r.Pool.QueryRow(ctx, `
		with ins as (
		  insert into chat.conversations (user_a, user_b)
		  values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid))
		  on conflict (user_a, user_b) do nothing
		  returning id
		)
		select id from ins
		union all
		select id from chat.conversations where user_a = least($1::uuid, $2::uuid) and user_b = greatest($1::uuid, $2::uuid)
		limit 1`, a, b).Scan(&id)
	return id, err
}

func (r ChatRepo) ConversationPeer(ctx context.Context, conversationID, userID string) (string, error) {
	var peer string
	err := r.Pool.QueryRow(ctx, `
		select case when user_a = $2 then user_b else user_a end
		  from chat.conversations where id = $1 and (user_a = $2 or user_b = $2)`, conversationID, userID).Scan(&peer)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", chat.ErrNotFound
	}
	return peer, err
}

// $1 is always the viewing user.
const idConversationSelect = `
	select c.id, peer.id, coalesce(pp.display_name, ''),
	       (select ph.storage_path from identity.profile_photos ph
	         where ph.user_id = peer.id and ph.status = 'approved' order by ph.position, ph.created_at limit 1),
	       c.updated_at, lm.id, lm.sender_id, lm.body, lm.sent_at,
	       (select count(*) from chat.messages m
	         where m.conversation_id = c.id and m.sender_id <> $1 and m.removed_at is null
	           and m.sent_at > coalesce(rm.last_read_at, '-infinity'::timestamptz))
	  from chat.conversations c
	  cross join lateral (select case when c.user_a = $1 then c.user_b else c.user_a end as id) peer
	  left join identity.profiles pp on pp.user_id = peer.id
	  left join chat.read_markers rm on rm.conversation_id = c.id and rm.user_id = $1
	  left join lateral (
	    select m.id, m.sender_id, m.body, m.sent_at from chat.messages m
	     where m.conversation_id = c.id and m.removed_at is null
	     order by m.sent_at desc, m.id desc limit 1) lm on true
	 where (c.user_a = $1 or c.user_b = $1)`

func idScanConversation(row pgx.Row) (chat.ConversationRow, error) {
	var c chat.ConversationRow
	var mID, mSender, mBody *string
	var mAt *time.Time
	if err := row.Scan(&c.ID, &c.PeerID, &c.PeerName, &c.PeerPhoto, &c.UpdatedAt, &mID, &mSender, &mBody, &mAt, &c.Unread); err != nil {
		return c, err
	}
	if mID != nil {
		c.LastMessage = &chat.ChatMessage{Id: *mID, ConversationId: c.ID, SenderId: idDeref(mSender), Body: idDeref(mBody), SentAt: *mAt}
	}
	return c, nil
}

func (r ChatRepo) Conversation(ctx context.Context, conversationID, userID string) (chat.ConversationRow, error) {
	c, err := idScanConversation(r.Pool.QueryRow(ctx, idConversationSelect+` and c.id = $2`, userID, conversationID))
	if errors.Is(err, pgx.ErrNoRows) {
		return c, chat.ErrNotFound
	}
	return c, err
}

func (r ChatRepo) ListConversations(ctx context.Context, userID string, after *chat.Cursor, limit int) ([]chat.ConversationRow, error) {
	var at *time.Time
	afterID := "ffffffff-ffff-ffff-ffff-ffffffffffff"
	if after != nil {
		at, afterID = &after.At, after.ID
	}
	rows, err := r.Pool.Query(ctx, idConversationSelect+`
	   and not `+idBlockedEither("$1::uuid", "peer.id")+`
	   and ($2::timestamptz is null or (c.updated_at, c.id) < ($2::timestamptz, $3::uuid))
	 order by c.updated_at desc, c.id desc
	 limit $4`, userID, at, afterID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []chat.ConversationRow
	for rows.Next() {
		c, err := idScanConversation(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r ChatRepo) ListMessages(ctx context.Context, conversationID string, after *chat.Cursor, limit int) ([]chat.ChatMessage, error) {
	var at *time.Time
	afterID := "ffffffff-ffff-ffff-ffff-ffffffffffff"
	if after != nil {
		at, afterID = &after.At, after.ID
	}
	rows, err := r.Pool.Query(ctx, `
		select id, conversation_id, sender_id, body, sent_at from chat.messages
		 where conversation_id = $1 and removed_at is null
		   and ($2::timestamptz is null or (sent_at, id) < ($2::timestamptz, $3::uuid))
		 order by sent_at desc, id desc
		 limit $4`, conversationID, at, afterID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []chat.ChatMessage{}
	for rows.Next() {
		var m chat.ChatMessage
		if err := rows.Scan(&m.Id, &m.ConversationId, &m.SenderId, &m.Body, &m.SentAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r ChatRepo) InsertMessage(ctx context.Context, conversationID, senderID, body string) (chat.ChatMessage, error) {
	var m chat.ChatMessage
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `
			insert into chat.messages (conversation_id, sender_id, body) values ($1, $2, $3)
			returning id, conversation_id, sender_id, body, sent_at`, conversationID, senderID, body).
			Scan(&m.Id, &m.ConversationId, &m.SenderId, &m.Body, &m.SentAt); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update chat.conversations set updated_at = $2 where id = $1`, conversationID, m.SentAt); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `
			insert into chat.read_markers (conversation_id, user_id, last_read_at) values ($1, $2, $3)
			on conflict (conversation_id, user_id) do update set last_read_at = greatest(chat.read_markers.last_read_at, excluded.last_read_at)`,
			conversationID, senderID, m.SentAt)
		return err
	})
	return m, err
}

func (r ChatRepo) MarkRead(ctx context.Context, conversationID, userID string) error {
	_, err := r.Pool.Exec(ctx, `
		insert into chat.read_markers (conversation_id, user_id, last_read_at) values ($1, $2, clock_timestamp())
		on conflict (conversation_id, user_id) do update set last_read_at = greatest(chat.read_markers.last_read_at, excluded.last_read_at)`,
		conversationID, userID)
	return err
}

func (r ChatRepo) WhoCanMessage(ctx context.Context, userID string) (string, error) {
	var v string
	err := r.Pool.QueryRow(ctx, `select who_can_message from identity.accounts where id = $1`, userID).Scan(&v)
	return v, err
}

func (r ChatRepo) SetWhoCanMessage(ctx context.Context, userID, value string) error {
	_, err := r.Pool.Exec(ctx, `update identity.accounts set who_can_message = $2 where id = $1`, userID, value)
	return err
}
