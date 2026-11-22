package postgres

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/chat"
)

// ChatRepo implements chat.Repository on chat.* (plus reads of identity,
// safety.blocks and calls for the messaging rules).
//
// MessageContext=true reads and writes the in-call metadata columns of
// migration 20261123000200 (context, call_id, client_message_id). With it
// off, the SQL is the pre-experiment SQL and every message reads as "chat".
type ChatRepo struct {
	Pool           *pgxpool.Pool
	MessageContext bool
}

// contextExpr selects a message's context ("chat" when not recorded).
func (r ChatRepo) contextExpr(alias string) string {
	if !r.MessageContext {
		return `'chat'`
	}
	return `coalesce(` + alias + `.context, 'chat')`
}

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

func (r ChatRepo) InLiveCall(ctx context.Context, a, b string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `
		select exists (select 1 from calls.calls
		 where ((caller_id = $1 and receiver_id = $2) or (caller_id = $2 and receiver_id = $1))
		   and phase in ('active', 'paused'))`, a, b).Scan(&ok)
	return ok, err
}

func (r ChatRepo) CallBetween(ctx context.Context, callID, a, b string) error {
	var ok bool
	err := r.Pool.QueryRow(ctx, `
		select exists (select 1 from calls.calls
		 where id = $1 and ((caller_id = $2 and receiver_id = $3) or (caller_id = $3 and receiver_id = $2)))`,
		callID, a, b).Scan(&ok)
	if err == nil && !ok {
		return chat.ErrNotFound
	}
	return err
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
func (r ChatRepo) conversationSelect() string {
	return strings.Replace(idConversationSelectTmpl, "{{ctx}}", r.contextExpr("m"), 1)
}

const idConversationSelectTmpl = `
	select c.id, peer.id, coalesce(pp.display_name, ''),
	       (select ph.storage_path from identity.profile_photos ph
	         where ph.user_id = peer.id and ph.status = 'approved' order by ph.position, ph.created_at limit 1),
	       c.updated_at, lm.id, lm.sender_id, lm.body, lm.sent_at, lm.context,
	       (select count(*) from chat.messages m
	         where m.conversation_id = c.id and m.sender_id <> $1 and m.removed_at is null
	           and m.sent_at > coalesce(rm.last_read_at, '-infinity'::timestamptz))
	  from chat.conversations c
	  cross join lateral (select case when c.user_a = $1 then c.user_b else c.user_a end as id) peer
	  left join identity.profiles pp on pp.user_id = peer.id
	  left join chat.read_markers rm on rm.conversation_id = c.id and rm.user_id = $1
	  left join lateral (
	    select m.id, m.sender_id, m.body, m.sent_at, {{ctx}} as context from chat.messages m
	     where m.conversation_id = c.id and m.removed_at is null
	     order by m.sent_at desc, m.id desc limit 1) lm on true
	 where (c.user_a = $1 or c.user_b = $1)`

func idScanConversation(row pgx.Row) (chat.ConversationRow, error) {
	var c chat.ConversationRow
	var mID, mSender, mBody, mCtx *string
	var mAt *time.Time
	if err := row.Scan(&c.ID, &c.PeerID, &c.PeerName, &c.PeerPhoto, &c.UpdatedAt, &mID, &mSender, &mBody, &mAt, &mCtx, &c.Unread); err != nil {
		return c, err
	}
	if mID != nil {
		c.LastMessage = &chat.ChatMessage{Id: *mID, ConversationId: c.ID, SenderId: idDeref(mSender), Body: idDeref(mBody),
			SentAt: *mAt, Context: idDeref(mCtx)}
	}
	return c, nil
}

func (r ChatRepo) Conversation(ctx context.Context, conversationID, userID string) (chat.ConversationRow, error) {
	c, err := idScanConversation(r.Pool.QueryRow(ctx, r.conversationSelect()+` and c.id = $2`, userID, conversationID))
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
	rows, err := r.Pool.Query(ctx, r.conversationSelect()+`
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

// messageColumns: $viewer is the parameter holding the viewing user.
func (r ChatRepo) messageColumns(viewer string) string {
	return `m.id, m.conversation_id, m.sender_id, m.body, m.sent_at, ` + r.contextExpr("m") + `,
	       (m.sender_id = ` + viewer + ` and exists (
	          select 1 from chat.read_markers pr
	           where pr.conversation_id = m.conversation_id and pr.user_id <> ` + viewer + `
	             and pr.last_read_at >= m.sent_at))`
}

func scanMessage(row pgx.Row, m *chat.ChatMessage) error {
	return row.Scan(&m.Id, &m.ConversationId, &m.SenderId, &m.Body, &m.SentAt, &m.Context, &m.ReadByPeer)
}

func (r ChatRepo) ListMessages(ctx context.Context, conversationID, viewerID string, after *chat.Cursor, limit int) ([]chat.ChatMessage, error) {
	var at *time.Time
	afterID := "ffffffff-ffff-ffff-ffff-ffffffffffff"
	if after != nil {
		at, afterID = &after.At, after.ID
	}
	rows, err := r.Pool.Query(ctx, `
		select `+r.messageColumns("$5::uuid")+` from chat.messages m
		 where m.conversation_id = $1 and m.removed_at is null
		   and ($2::timestamptz is null or (m.sent_at, m.id) < ($2::timestamptz, $3::uuid))
		 order by m.sent_at desc, m.id desc
		 limit $4`, conversationID, at, afterID, limit, viewerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []chat.ChatMessage{}
	for rows.Next() {
		var m chat.ChatMessage
		if err := scanMessage(rows, &m); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r ChatRepo) InsertMessage(ctx context.Context, nm chat.NewMessage) (chat.ChatMessage, bool, error) {
	var m chat.ChatMessage
	inserted := true
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		var id string
		var err error
		if r.MessageContext {
			// ON CONFLICT on the partial dedupe index: a repeat of the same
			// client_message_id inserts nothing and we return the stored row.
			err = tx.QueryRow(ctx, `
				insert into chat.messages (conversation_id, sender_id, body, context, call_id, client_message_id)
				values ($1, $2, $3, $4, $5, $6)
				on conflict (conversation_id, sender_id, client_message_id) where client_message_id is not null do nothing
				returning id`, nm.ConversationID, nm.SenderID, nm.Body, nm.Context, nm.CallID, nm.ClientMessageID).Scan(&id)
			if errors.Is(err, pgx.ErrNoRows) {
				inserted = false
				err = tx.QueryRow(ctx, `select id from chat.messages where conversation_id = $1 and sender_id = $2 and client_message_id = $3`,
					nm.ConversationID, nm.SenderID, nm.ClientMessageID).Scan(&id)
			}
		} else {
			err = tx.QueryRow(ctx, `insert into chat.messages (conversation_id, sender_id, body) values ($1, $2, $3) returning id`,
				nm.ConversationID, nm.SenderID, nm.Body).Scan(&id)
		}
		if err != nil {
			return err
		}
		if err := scanMessage(tx.QueryRow(ctx, `select `+r.messageColumns("$2::uuid")+` from chat.messages m where m.id = $1`, id, nm.SenderID), &m); err != nil {
			return err
		}
		if !inserted {
			return nil
		}
		if _, err := tx.Exec(ctx, `update chat.conversations set updated_at = $2 where id = $1`, nm.ConversationID, m.SentAt); err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `
			insert into chat.read_markers (conversation_id, user_id, last_read_at) values ($1, $2, $3)
			on conflict (conversation_id, user_id) do update set last_read_at = greatest(chat.read_markers.last_read_at, excluded.last_read_at)`,
			nm.ConversationID, nm.SenderID, m.SentAt)
		return err
	})
	return m, inserted, err
}

func (r ChatRepo) MarkRead(ctx context.Context, conversationID, userID string) (bool, error) {
	// prev reads the marker as it was before this statement's upsert.
	var advanced bool
	err := r.Pool.QueryRow(ctx, `
		with prev as (
		  select last_read_at from chat.read_markers where conversation_id = $1 and user_id = $2
		), up as (
		  insert into chat.read_markers (conversation_id, user_id, last_read_at) values ($1, $2, clock_timestamp())
		  on conflict (conversation_id, user_id) do update set last_read_at = greatest(chat.read_markers.last_read_at, excluded.last_read_at)
		)
		select exists (select 1 from chat.messages m
		 where m.conversation_id = $1 and m.sender_id <> $2 and m.removed_at is null
		   and m.sent_at > coalesce((select last_read_at from prev), '-infinity'::timestamptz))`,
		conversationID, userID).Scan(&advanced)
	return advanced, err
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
